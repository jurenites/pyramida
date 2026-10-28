extends SceneTree
const Model = preload("res://scripts/settlement/world_model.gd")
const Economy = preload("res://scripts/settlement/economy.gd")
const Chunks = preload("res://scripts/settlement/chunk_stream.gd")
const Settings = preload("res://scripts/gameplay_settings.gd")
const Scene = preload("res://scenes/settlement/Terraces.tscn")
const Tooltip = preload("res://scripts/settlement/object_tooltip.gd")
var failures: Array[String] = []
var checks := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

func _initialize() -> void:
	call_deferred("run")

func state(bush: Dictionary, amount: int, capacity: int, message: String) -> void:
	check(bush.inventory.count("food") == amount and bush.inventory.capacity == capacity, message)

func run() -> void:
	var interval: float = Settings.SIMULATION_DAY_SECONDS * 2.0
	var world = Model.new()
	world.setup()
	var cell := Vector3i.ZERO
	for candidate: Vector3i in world.deposits:
		if world.deposits[candidate].kind == "berry":
			cell = candidate
			state(world.deposits[candidate], 3, 3, "Natural bushes begin at 3/3")
	var bush: Dictionary = world.deposits[cell]
	check(not world.request_build("seed_bush", Vector3i.ZERO), "Bushes are no longer available as unlimited seeds")
	# Older saves can still contain young bushes; their established growth continues.
	world.deposits[cell] = Chunks.entry("berry", "food", 1)
	bush = world.deposits[cell]
	state(bush, 1, 1, "Young bush fixture starts at 1/1")
	check(bush.inventory.reserve(99, "food"), "Young bush berry can be reserved")
	state(bush, 1, 1, "Reservation leaves physical berry on bush")
	check(bush.inventory.pickup(99) == "food", "Pickup yields one berry")
	state(bush, 0, 1, "Picking retains young capacity")
	Economy.tick(world, interval - 0.25)
	state(bush, 0, 1, "No early growth before two whole day/night cycles")
	var restored = Model.new()
	check(restored.restore(JSON.parse_string(JSON.stringify(world.snapshot()))), "Partial bush growth saves and restores")
	world = restored
	bush = world.deposits[cell]
	Economy.tick(world, 0.25)
	state(bush, 1, 2, "Picked young bush becomes 1/2 after two cycles")
	Economy.tick(world, interval)
	state(bush, 2, 3, "Unpicked 1/2 becomes 2/3 after another two cycles")
	Economy.tick(world, interval)
	state(bush, 3, 3, "Mature bush regrows its final berry")
	Economy.tick(world, interval * 10.0)
	bush.inventory.reserve(99, "food")
	bush.inventory.pickup(99)
	Economy.tick(world, interval - 0.25)
	state(bush, 2, 3, "Full bush does not bank an immediate refill")
	Economy.tick(world, 0.25)
	state(bush, 3, 3, "Partly harvested bush regrows without becoming empty")
	bush.inventory.amounts.clear()
	for amount in [1, 2, 3]:
		Economy.tick(world, interval)
		state(bush, amount, 3, "Empty mature bush refills one berry per two cycles")
	world.deposits[cell] = Chunks.entry("berry", "food", 1)
	bush = world.deposits[cell]
	Economy.tick(world, interval)
	state(bush, 2, 2, "Unharvested young bush grows to 2/2")
	Economy.tick(world, interval)
	state(bush, 3, 3, "Unharvested bush matures at 3/3")
	world.deposits[cell] = Chunks.entry("berry", "food", 1)
	bush = world.deposits[cell]
	Economy.tick(world, interval * 2.5)
	state(bush, 3, 3, "Large time steps apply all growth intervals without overfilling")
	check(not world.replant_bush(Vector3i(999, 0, 999)), "Replant rejects non-bush cells")
	test_streaming(interval)
	await test_presentation()
	for failure in failures: printerr("FAIL: " + failure)
	if failures.is_empty(): print("PASS: %d bush growth, replanting, save, streaming, dot and UI checks" % checks)
	quit(int(not failures.is_empty()))

func test_streaming(interval: float) -> void:
	var world = Model.new()
	world.setup()
	var chunk := Vector2i(12, -11)
	Chunks.load_chunk(world, chunk)
	var cell: Vector3i = world.surface_at(chunk.x * 16, chunk.y * 16)
	world.trees.erase(cell)
	world.water_sources.erase(cell)
	world.deposits[cell] = Chunks.entry("berry", "food", 1)
	world.deposits[cell].inventory.amounts.clear()
	world.deposits[cell].regrowth = interval * 0.5
	Chunks.unload_chunk(world, chunk)
	world.time += interval
	var restored = Model.new()
	check(restored.restore(JSON.parse_string(JSON.stringify(world.snapshot()))), "Dormant young bush saves with its growth clock")
	Chunks.load_chunk(restored, chunk)
	var bush: Dictionary = restored.deposits[cell]
	state(bush, 1, 2, "Unloaded bush continues growing in simulation time")
	check(is_equal_approx(bush.regrowth, interval * 0.5), "Streaming preserves fractional growth time")
	Economy.tick(restored, interval * 0.5)
	state(bush, 2, 3, "Reloaded bush reaches next stage on schedule")

func test_presentation() -> void:
	var game = Scene.instantiate()
	game.launch_to_menu = false
	root.add_child(game)
	game.capture = true
	game.set_process(false)
	game.speed = 0
	var cell := Vector3i.ZERO
	for candidate: Vector3i in game.model.deposits:
		if game.model.deposits[candidate].kind == "berry":
			cell = candidate
			break
	var bush: Dictionary = game.model.deposits[cell]
	var target := {"cell": cell, "kind": "berry", "entity_key": "deposit:%s" % cell}
	for capacity in [1, 2, 3]:
		bush.inventory.capacity = capacity
		for amount in range(capacity + 1):
			bush.inventory.amounts.food = amount
			game.model.revision += 1
			game.world.sync(game.model, 0, -1)
			var node: Node3D = game.world.entity_views[target.entity_key]
			var dots := 0
			for child in node.get_children():
				if child is MeshInstance3D and str(child.name).begins_with("Berry") and child.visible: dots += 1
			check(dots == amount, "Exterior berry dots match %d/%d" % [amount, capacity])
			check(node.get_node("Leaves0").visible, "Empty bushes retain their leaves")
			check(Tooltip.describe(game.model, target).rows[0].value == "%d/%d" % [amount, capacity], "Selected readout follows growth and stock")
			game.hud.update(game.model, -1, 1, target)
			check(game.hud.move_button.visible and game.hud.move_label == "Move", "Any selected bush offers Move in the toolbar")
	bush.inventory.amounts.clear()
	game.hud.update(game.model, -1, 1, target)
	game.model.exploration.reveal(game.model.navigation.point(cell))
	game.selected_object = target
	game.hud.move_button.pressed.emit()
	check(game.model.plans.values().any(func(plan): return plan.get("collect_bush", false) and plan.cell == cell), "Move queues uprooting before destination placement")
	state(bush, 0, 3, "Queuing uprooting does not instantly change the bush")
	game._clear_selection()
	game.hud.update(game.model, -1, 1, {})
	check(not game.hud.detail_panel.visible, "Deselection hides the action panel")
	game.free()
