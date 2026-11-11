extends SceneTree
const Model = preload("res://scripts/settlement/world_model.gd")
const View = preload("res://scripts/settlement/world_view.gd")
const Inventory = preload("res://scripts/settlement/inventory.gd")
const Labour = preload("res://scripts/applied_labour.gd")
const TREE := Vector3i(-4, 0, 2)
const STORE := Vector3i(-6, 0, 2)
var failures: Array[String] = []
var checks := 0
var model: RefCounted
var view: Node3D

func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message)

func _initialize() -> void: call_deferred("run")

func cut(worker_id: int) -> void:
	var worker: Dictionary = model.workers[worker_id]
	var inventory: RefCounted = model.trees[TREE].inventory
	check(inventory.reserve(worker_id, "log"), "A cutter reserves one real log")
	worker.job = {"kind": "fell", "phase": "collect", "target": TREE, "source": inventory, "labour": Labour.new(0.01)}
	model.tick_citizen_job(worker, 0.1)

func deliver(worker_id: int) -> void:
	var worker: Dictionary = model.workers[worker_id]
	worker.cell = model.navigation.access_cells(STORE)[0]
	worker.position = model.Navigation.point(worker.cell)
	model.tick_citizen_job(worker, 0.1)

func step(seconds: float) -> void: view.sync(model, seconds, -1)

func run() -> void:
	model = Model.new()
	model.setup()
	model.deposits.clear()
	model.plans.clear()
	model.gardens.clear()
	model.trees.clear()
	var inventory := Inventory.new()
	inventory.store("log", 3)
	model.trees[TREE] = {"inventory": inventory, "kind": "living", "appearance_seed": 517, "regrowth": 0.0}
	model.stores[STORE].amounts.clear()
	model.buildings[STORE] = {"kind": "log_shed", "direction": 0}
	for worker in model.workers:
		worker.life_stage = "adult"
		worker.role = "idle"
		worker.job = {}
	model.rebuild_navigation()
	view = View.new()
	root.add_child(view)
	view.setup(model)
	var section: Node3D = view.tree_views[TREE].get_node("Segment3")
	var bark: MeshInstance3D = section.get_node("Trunk")
	var original_pose := bark.global_transform
	var original_material := bark.get_active_material(0)
	cut(0)
	check(view.actors[0].cargo == section and section.get_node("Bark") == bark, "The actual standing section and bark node become cargo")
	check(bark.global_transform.is_equal_approx(original_pose), "Detaching does not jump, resize or rotate a vertex")
	check(bark.get_active_material(0) == original_material, "Detaching preserves the actual bark material")
	step(0.2)
	check(not bark.global_transform.is_equal_approx(original_pose), "The severed log moves toward the hands")
	check_restore(0, "log")
	check(bark.global_basis.get_scale().is_equal_approx(Vector3.ONE), "Pickup keeps rigid stock dimensions")
	var paused := section.global_transform
	step(0)
	check(section.global_transform.is_equal_approx(paused), "Pause freezes pickup")
	model.revision += 1
	step(0.1)
	check(view.actors[0].cargo == section, "A world rebuild preserves the moving object")
	model.workers[0].cloth_color = (int(model.workers[0].cloth_color) + 1) % 5
	step(0.1)
	check(view.actors[0].cargo == section, "Changing citizen appearance preserves the moving log")
	step(1)
	check(section.transform.is_equal_approx(Transform3D.IDENTITY) and view.timber_motion.moving.is_empty(), "Pickup finishes exactly at the cargo socket")
	var before_delivery := section.global_transform
	deliver(0)
	check(model.stores[STORE].count("log") == 1 and model.workers[0].cargo.is_empty(), "Simulation deposits exactly one log")
	step(0)
	check(section.global_transform.is_equal_approx(before_delivery), "Delivery starts in the hands without snapping")
	var slot: Node3D = view.store_views[STORE].get_meta("logs")[0]
	check(not slot.visible, "The pile placeholder is hidden while the actual log arrives")
	check_restore(1, "")
	step(0.2)
	check(section.global_basis.get_scale().is_equal_approx(Vector3.ONE), "Deposit keeps rigid stock dimensions")
	paused = section.global_transform
	step(0)
	check(section.global_transform.is_equal_approx(paused), "Pause freezes deposit")
	step(1)
	check(view.store_views[STORE].get_meta("logs")[0] == section and section.get_node("Bark") == bark, "The identical tree object occupies the pile slot")
	check(section.visible and section.get_parent() == view.store_views[STORE], "The deposited log remains in the pile")
	# Two cutters finish before a rendered frame; the last cut removes the tree.
	var second: Node3D = view.tree_views[TREE].get_node("Segment2")
	var third: Node3D = view.tree_views[TREE].get_node("Segment1")
	cut(0)
	cut(1)
	deliver(1)
	check(not model.trees.has(TREE), "Final harvesting removes the exhausted source")
	step(0.1)
	check(is_instance_valid(second) and is_instance_valid(third), "Removing the tree cannot free its travelling logs")
	check(view.timber_motion.moving.size() == 2, "Simultaneous cuts have independent transfers")
	step(1)
	check(view.timber_motion.moving.size() == 1 and view.timber_motion.moving[0].stage == "deposit", "A same-frame cut and delivery still passes through the hands")
	step(1)
	check(view.store_views[STORE].get_meta("logs")[1] == third, "The final tree section survives all the way into storage")
	deliver(0)
	step(1)
	check(view.store_views[STORE].get_meta("logs")[2] == second, "Concurrent deliveries retain their own physical objects")
	check(model.stores[STORE].count("log") == 3 and model.trees.is_empty(), "Animation never changes the three-log harvest total")
	# Loading reconstructs presentation from inventory; it never replays delivery.
	var snapshot: Dictionary = JSON.parse_string(JSON.stringify(model.snapshot()))
	check(model.restore(snapshot), "A world with transferred timber restores")
	step(0)
	check(view.timber_motion.moving.is_empty() and model.stores[STORE].count("log") == 3, "Restore clears motion without duplicating resources")
	check(view.store_views[STORE].get_meta("logs").filter(func(node): return node.visible).size() == 3, "Restored pile matches saved stock")
	view.free()
	if failures.is_empty(): print("PASS: %d physical timber transfer, pause, identity, concurrency and save checks" % checks)
	else:
		for message in failures: printerr("FAIL: " + message)
	quit(int(not failures.is_empty()))

func check_restore(stored: int, cargo: String) -> void:
	var restored = Model.new()
	check(restored.restore(JSON.parse_string(JSON.stringify(model.snapshot()))), "Saving during motion preserves the authoritative inventory")
	var restored_view := View.new()
	root.add_child(restored_view)
	restored_view.setup(restored)
	check(restored_view.timber_motion.moving.is_empty(), "Loading does not replay presentation-only transfers")
	check(restored.stores[STORE].count("log") == stored and restored.workers[0].cargo == cargo, "Mid-animation saves contain each log exactly once")
	restored_view.free()
