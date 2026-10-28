extends SceneTree
const Model = preload("res://scripts/settlement/world_model.gd")
const Generator = preload("res://scripts/settlement/world_generator.gd")
const Greece = preload("res://scripts/settlement/greece_landscape.gd")
const Scenery = preload("res://scripts/settlement/scenery_view.gd")
const Slots = preload("res://scripts/settlement/save_slots.gd")
const Settings = preload("res://scripts/gameplay_settings.gd")
var failures: Array[String] = []
var checks := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value and not failures.has(message): failures.append(message)
func run() -> void:
	for seed_ in [1409, 42, 9182]:
		var whole := Generator.generate_region(seed_, Generator.INITIAL_BOUNDS, 0, "easy")
		var merged := {"ground": {}, "shapes": {}, "grass": {}, "nature": {}}
		for x in range(2, -4, -1):
			for z in range(2, -4, -1):
				var chunk := Generator.generate_chunk(seed_, Vector2i(x, z), "easy")
				for field in merged: merged[field].merge(chunk[field])
		for field in merged: check(merged[field] == whole[field], "Coastal %s matches reversed chunk generation" % field)
		check(whole.grass.size() > whole.ground.size() * 0.7, "Meadows cover most land")
		check(whole.shapes.size() > 100, "Broad hills are present")
		for cell: Vector3i in whole.ground:
			check(cell.x <= Greece.coast(cell.z, seed_), "Sea has no walkable ground")
			if maxi(absi(cell.x), absi(cell.z)) < 10: check(not whole.shapes.has(cell), "Opening remains flat for construction")
		for cell: Vector3i in whole.grass: check(not whole.water.has(cell), "Grass excludes freshwater")
		for cell: Vector3i in whole.shapes:
			var h: Array = whole.shapes[cell]
			check(float(h.max()) - float(h.min()) < 0.6, "Hills stay gentle")
	var world = Model.new()
	world.setup(1409, "easy")
	var restored = Model.new()
	check(restored.restore(JSON.parse_string(JSON.stringify(world.snapshot()))), "Easy JSON roundtrip")
	check(restored.difficulty == "easy" and restored.ground == world.ground and restored.terrain_shapes.size() == world.terrain_shapes.size(), "Easy landscape persists")
	for cell: Vector3i in world.terrain_shapes:
		for index in 4:
			check(is_equal_approx(restored.terrain_shapes.get(cell, [0, 0, 0, 0])[index], world.terrain_shapes[cell][index]), "Saved hill corners preserve their heights")
	Model.Chunks.load_chunk(restored, Vector2i(-5, 0))
	var expected := Generator.generate_chunk(1409, Vector2i(-5, 0), "easy")
	check(restored.chunk_details[Vector2i(-5, 0)].grass == expected.grass, "Exploration after reload keeps Greece")
	var scenery := Scenery.new()
	root.add_child(scenery)
	scenery.setup(world)
	scenery.sync_grass(world, false)
	var hillside_tufts := 0
	for node in scenery.chunks.values():
		var grass: MultiMeshInstance3D = node.get_node("Grass")
		check(grass.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "Grass never casts shadows")
		if grass.multimesh == null: continue
		if DisplayServer.get_name() == "headless": continue
		for index in grass.multimesh.instance_count:
			var p := grass.multimesh.get_instance_transform(index).origin
			var cell := Vector3i(roundi(p.x), 0, roundi(p.z))
			check(is_equal_approx(p.y, world.navigation.surface_height(cell, p) + 0.012), "Tuft roots follow the real triangle surface")
			if world.terrain_shapes.has(cell): hillside_tufts += 1
	if DisplayServer.get_name() != "headless": check(hillside_tufts > 100, "Grass covers hills as well as flats")
	var slots := Slots.new()
	slots.directory = "/tmp/pyramida-greece-test-%d" % Time.get_ticks_usec()
	check(slots.write_slot(0, world) and slots.read_slot(0).get("difficulty") == "easy", "Easy slot writes and reads")
	check(slots.entries()[0].get("difficulty") == "easy", "Slot summary preserves the saved landscape")
	world.time = Settings.SIMULATION_DAY_SECONDS * 1.5
	check(slots.write_slot(0, world), "Easy autosave retains a recovery snapshot")
	var broken := FileAccess.open(slots.path_for(0), FileAccess.WRITE)
	broken.store_string("broken json")
	broken.close()
	var recovered := slots.read_slot(0)
	check(recovered.get("recovered", false) and recovered.get("difficulty") == "easy" and recovered.get("elapsed") == 0, "Recovery preserves the Fields landscape and previous progress")
	check(slots.entries()[0].get("difficulty") == "easy", "Recovered slot summary uses the backup landscape")
	slots.delete_slot(0)
	scenery.free()
	await check_menu()
	if failures.is_empty():
		print("PASS: %d Greece generation, streaming, save and grass checks" % checks)
		quit()
	else:
		for failure in failures: push_error("FAIL: " + failure)
		quit(1)

func check_menu() -> void:
	var game = preload("res://scenes/settlement/Terraces.tscn").instantiate()
	game.slot_directory = "/tmp/pyramida-greece-menu-%d" % Time.get_ticks_usec()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	var seed_: int = game.menu_preview.world_seed
	game.menu.buttons.settlements.pressed.emit()
	game.menu.buttons.slot_0.pressed.emit()
	game.menu.buttons.easy.pressed.emit()
	check(game.session_started and game.model.difficulty == "easy" and game.model.world_seed == seed_, "Easy menu starts Greece with the offered seed")
	check(game.saves.read_slot(0).get("difficulty") == "easy", "Easy menu creates a readable coastal save")
	game.model.time = Settings.SIMULATION_DAY_SECONDS * 1.5
	game.rig.zoom = 31.0
	game._leave_settlement()
	check(game.menu.slots[0].text == "Fields Night 2", "Fields slot shows its saved landscape and night count")
	game.menu.show_page("delete_slots")
	check(game.menu.slots[0].text == "Fields Night 2", "Delete menu identifies the Fields save correctly")
	game.menu.show_page("slots")
	game.menu.buttons.slot_1.pressed.emit()
	game.menu.buttons.normal.pressed.emit()
	var sand_seed: int = game.model.world_seed
	check(game.model.difficulty == "normal", "A separate slot starts Sand independently")
	game._leave_settlement()
	check(game.menu.slots[0].text == "Fields Night 2" and game.menu.slots[1].text == "Sand Day 1", "Mixed save slots each show their own world type")
	game.menu.buttons.settlements.pressed.emit()
	game.menu.buttons.slot_0.pressed.emit()
	check(game.session_started and game.model.difficulty == "easy" and game.model.world_seed == seed_, "Slot switching restores the original Fields world")
	check(game.model.time == Settings.SIMULATION_DAY_SECONDS * 1.5 and game.rig.zoom == 31.0, "Fields progress and camera survive slot switching")
	game.model.time = Settings.SIMULATION_DAY_SECONDS * 2.0
	game._leave_settlement()
	var directory: String = game.slot_directory
	game.free()
	game = preload("res://scenes/settlement/Terraces.tscn").instantiate()
	game.slot_directory = directory
	root.add_child(game)
	game.set_process(false)
	check(game.menu.slots[0].text == "Fields Day 3" and game.menu.slots[1].text == "Sand Day 1", "A fresh launch reads world labels and progress from each saved slot")
	game.menu.buttons.resume.pressed.emit()
	check(game.session_started and game.active_slot == 0 and game.model.difficulty == "easy" and game.model.world_seed == seed_, "Continue after relaunch restores the latest Fields world")
	check(game.model.time == Settings.SIMULATION_DAY_SECONDS * 2.0 and game.rig.zoom == 31.0, "Continue preserves Fields progress and camera")
	var sand: Dictionary = game.saves.read_slot(1)
	var restored = Model.new()
	check(restored.restore(sand.world) and restored.difficulty == "normal" and restored.world_seed == sand_seed and restored.time == 0, "Fields autosaves preserve the independent Sand slot")
	game.saves.delete_slot(0)
	game.saves.delete_slot(1)
	game.session_started = false
	game.active_slot = -1
	game.free()
