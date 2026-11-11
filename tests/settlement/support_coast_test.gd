extends SceneTree
const Model = preload("res://scripts/settlement/world_model.gd")
const Foundation = preload("res://scripts/settlement/support_foundation.gd")
const Runtime = preload("res://scripts/settlement/support_runtime.gd")
var failures: Array[String] = []
func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message); printerr("FAIL: " + message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var world := Model.new(); world.setup(1409, "easy")
	world.trees.clear(); world.deposits.clear(); world.rebuild_navigation()
	var found := false
	var start := Vector3i.ZERO
	var outward := Vector3i.ZERO
	var land: Array = world.ground.keys()
	land.sort_custom(func(a, b): return Vector3(a).length_squared() < Vector3(b).length_squared())
	for shore: Vector3i in land:
		if shore.y != 0: continue
		for direction: Vector3i in world.DIRECTIONS:
			var candidate := shore + direction
			if not Foundation.water(world, candidate): continue
			if not world.build_error("support", candidate).is_empty() or not Runtime.foundation_error(world, candidate, Vector3.ZERO, 0).is_empty(): continue
			start = candidate; outward = direction; found = true; break
		if found: break
	check(found, "Generated coastline offers an accessible pier footing")
	if not found: quit(1); return
	var game = load("res://scenes/settlement/Terraces.tscn").instantiate()
	game.capture = true; game.launch_to_menu = false
	game.slot_directory = "/tmp/town-pier-test-%d" % Time.get_ticks_usec()
	root.add_child(game); game.set_process(false); game.speed = 0
	game.model = world; game.world.last_revision = -1; game.world.sync(world, 0, -1)
	game.world.fog_enabled = false; game.fog.visible = false; game.hud.hide()
	game.rig.focus = Vector3(start); game.rig.zoom = 11; game.rig.pitch = 0.6; game.rig.update_camera()
	game._set_tool("support")
	for frame in 3: await physics_frame
	var at := Vector3(start); at.y = Foundation.water_level(world)
	var cursor: Vector2 = game.rig.camera.unproject_position(at)
	var placement: Dictionary = game.placement_at(cursor, false)
	check(placement.get("cell") == start and placement.get("support") == "water", "Cursor targets the sea surface instead of submerged terrain")
	var built := 0
	for index in 5:
		var cell := start + outward * index
		if not Foundation.water(world, cell): break
		if not world.request_build("support", cell): break
		var plan: Dictionary = world.plans[world.next_plan_id - 1]
		check(plan.materials == Foundation.recipe(world, cell), "Generated seabed determines the paid timber")
		if not world.debug_finish_plan(plan.id): break
		built += 1
	check(built >= 2, "Completed pier extends over generated deepening seabed")
	check(is_equal_approx(world.navigation.surface_point(start + Vector3i.UP).y, Foundation.water_level(world) + 0.15), "Generated-coast deck sits fifteen centimetres above water")
	var landings := Foundation.landing_paths(world, start)
	check(not landings.is_empty(), "Coastal pier has a clear shore landing")
	if not landings.is_empty(): check(not world.navigation.route(landings.keys()[0], start + outward * (built - 1) + Vector3i.UP).is_empty(), "Shore landing reaches the far end of the pier")
	var widened := 0
	for index in range(1, mini(3, built)):
		var cell := start + outward * index + Vector3i(-outward.z,0,outward.x)
		if world.request_build("support", cell) and world.debug_finish_plan(world.next_plan_id - 1):
			widened += 1
			check(is_equal_approx(world.navigation.surface_point(cell + Vector3i.UP).y, Foundation.water_level(world) + 0.15), "Sideways extension keeps one flat surface")
	check(widened > 0, "Adjacent Supports form a wider flat waterside platform")
	var home := start + outward * 3 + Vector3i.UP
	var deck_cells: Array[Vector3i] = []
	for x in range(-1,2):
		for z in range(-1,2): deck_cells.append(home + Vector3i(x,-1,z))
	deck_cells.append(home + Vector3i(0,-1,2))
	for cell in deck_cells:
		if world.buildings.has(cell): continue
		check(world.request_build("support",cell),"Extend generated-coast pier for a Home: "+world.last_message)
		if world.plans.has(world.next_plan_id-1): check(world.debug_finish_plan(world.next_plan_id-1),"Complete Home bearing")
	check(world.request_build("house",home,0,Vector3.ZERO,false),"Place Home directly on generated-coast pier: "+world.last_message)
	if world.plans.has(world.next_plan_id-1): check(world.debug_finish_plan(world.next_plan_id-1),"Complete generated-coast Home")
	check(is_equal_approx(world.navigation.surface_point(home).y,Foundation.water_level(world)+Foundation.DECK_CLEARANCE+0.06),"Real coastline Home floor follows the lowered deck")
	check(not world.navigation.route(home+Vector3i.BACK*2,home).is_empty(),"Generated-coast pier connects to the Home doorway")
	game.world.sync(world, 0, -1); game._set_tool("inspect")
	if game.world.entity_views.has("building:%s" % home):
		check(is_equal_approx(game.world.entity_views["building:%s" % home].position.y,Foundation.water_level(world)+Foundation.DECK_CLEARANCE),"Generated-coast Home model rests on the pier")
	game.rig.focus = Vector3(start) + Vector3(outward) * (built - 1) * 0.5
	game.rig.yaw = atan2(float(outward.x), float(outward.z)) + 0.9
	game.rig.pitch = 0.45; game.rig.zoom = 9; game.rig.update_camera()
	if DisplayServer.get_name() != "headless":
		for frame in 16: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/settlement/support-pier.png")
	game.free()
	if failures.is_empty(): print("PASS: generated-coast pier placement, sea-surface picking and depth-priced extension")
	quit(int(not failures.is_empty()))
