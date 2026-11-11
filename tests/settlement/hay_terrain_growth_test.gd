extends SceneTree
const Model = preload("res://scripts/settlement/world_model.gd")
const Farm = preload("res://scripts/settlement/farming.gd")
const Fields = preload("res://scripts/settlement/hay_field_view.gd")
const Surface = preload("res://scripts/settlement/hay_surface.gd")
const Assets = preload("res://scripts/settlement/asset_library.gd")
var failures: Array[String] = []
var checks := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		printerr("FAIL: " + message)
func world_fixture():
	var world = Model.new()
	world.streaming_enabled = false
	world.soil_enabled = true
	for x in range(-8, 9):
		for z in range(-8, 9):
			world.ground[Vector3i(x, 0, z)] = true
	world.workers.append({"id": 0, "cell": Vector3i(-3, 0, 0), "position": Vector3(-3, 0, 0), "route": [], "route_index": 0, "job": {}, "cargo": "", "status": "idle", "distance": 0.0, "hunger": 0.0, "role": "farmer", "life_stage": "adult", "appearance": 0, "cloth_color": 0})
	world.exploration.reveal(Vector3.ZERO)
	world.Soil.rebuild(world)
	world.rebuild_navigation()
	return world
func complete(world, kind: String, cell: Vector3i) -> bool:
	if not world.request_build(kind, cell):
		check(false, "Place %s: %s" % [kind, world.last_message])
		return false
	world._complete_plan(world.plans[world.next_plan_id - 1])
	return true
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var world = world_fixture()
	var cuts: Dictionary = world.soil_cuts.duplicate()
	if not complete(world, "hay_field", Vector3i.ZERO): quit(1); return
	check(world.soil_cuts == cuts, "Field construction preserves natural relief across all four quarters")
	var crop: Dictionary = world.gardens[Vector3i.ZERO]
	Farm.water_crop(world, Vector3i.ZERO)
	Farm.tick_crops(world, Farm.GROW_SECONDS)
	check(crop.food == 4, "Water grows four harvest units")
	Farm.cut_quarter(crop, 2)
	Farm.water_crop(world, Vector3i.ZERO)
	Farm.tick_crops(world, 5.0)
	check(crop.food == 3 and crop.quarter_growth[2] == 5.0, "Cut quarter regrows while the other three stay ripe")
	var view := Assets.create("hay_field")
	var preview := view.get_node("Plants")
	preload("res://scripts/settlement/world_view.gd").sync_hay_quarters(preview, {"food": 1, "standing_quarters": 2, "growth": 0.0})
	check(not preview.get_node("Quarter0").visible and preview.get_node("Quarter1").visible and not preview.get_node("Quarter2").visible and not preview.get_node("Quarter3").visible, "Authored batched crop quarters keep independent harvest identities")
	root.add_child(view)
	Fields.sync(world, Vector3i.ZERO, view)
	Surface.sync(world, Vector3i.ZERO, view)
	check(not view.get_node("Plants").visible and not view.get_node("Soil").visible, "Runtime replaces flat slab with fitted soil and stalks")
	var stalks := view.get_node("TerrainField/Quarter2") as MultiMeshInstance3D
	check(stalks.multimesh.instance_count == 256 and stalks.multimesh.mesh.get_faces().size() == 3, "Golden field uses batched individual grass triangles instead of repeated three-stalk stamps")
	check(stalks.get_meta("roots")[0].basis.y.length() >= 0.55, "New hay is taller than the old crop")
	for visual: GeometryInstance3D in view.find_children("*", "GeometryInstance3D", true, false):
		check(visual.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "Every field mesh, including runtime grass, soil and pegs, has shadows disabled")
	check(view.find_children("EdgePlank*", "MeshInstance3D", true, false).is_empty(), "Field has no horizontal wooden edging")
	check(not view.find_children("EdgePeg*", "MeshInstance3D", true, false).is_empty(), "Upright perimeter markers remain")
	var same := Node3D.new(); var different := Node3D.new()
	Surface.build_stalks(world, Vector3i.ZERO, same)
	Surface.build_stalks(world, Vector3i(4, 0, 0), different)
	check(same.get_node("Quarter2").get_meta("roots") == stalks.get_meta("roots"), "Same field reconstructs its seeded blade arrangement")
	check(same.get_node("Quarter2").get_meta("roots") != different.get_node("Quarter2").get_meta("roots"), "Different fields have distinct arrangements")
	same.free(); different.free()
	var first: Transform3D = stalks.get_meta("roots")[0]
	var before_growth: float = stalks.get_meta("growth")
	check(is_equal_approx(first.origin.y, Surface.height(world, Vector3i.ZERO, first.origin) + 0.02), "Stalk roots sit on the actual terrain triangle")
	Farm.tick_crops(world, 5.0)
	Surface.animate(world, Vector3i.ZERO, view)
	check(stalks.get_meta("roots")[0].origin == first.origin and float(stalks.get_meta("growth")) > before_growth, "Growth raises stalks without moving their roots")
	var partial = Model.new()
	check(partial.restore(JSON.parse_string(JSON.stringify(world.snapshot()))), "Partly regrown field reloads")
	for quarter in 4:
		check(is_equal_approx(float(partial.gardens[Vector3i.ZERO].quarter_growth[quarter]), float(crop.quarter_growth[quarter])), "Partly regrown quarter retains its progress on reload")
	var fitted := view.get_node("TerrainField")
	Fields.sync(world, Vector3i.ZERO, view)
	Surface.sync(world, Vector3i.ZERO, view)
	check(view.get_node("TerrainField") == fitted, "Unchanged geometry is cached")
	world.soil_cuts[world.Soil.sample_key(Vector3i(2, 0, 2), Vector2.ZERO)] = true
	world.Soil.rebuild(world)
	world.terrain_revision += 1
	world.rebuild_navigation()
	Fields.sync(world, Vector3i.ZERO, view)
	Surface.sync(world, Vector3i.ZERO, view)
	check(view.get_node("TerrainField") != fitted, "Terrain edits rebuild field geometry automatically")
	# The house shares the field anchor; the other quarters must remain farmable.
	check(complete(world, "house", Vector3i.ZERO), "A house may occupy one quarter at the field anchor")
	Farm.tick_crops(world, 0.0)
	check(world.buildings[Vector3i.ZERO].kind == "house" and Farm.is_hay(world, Vector3i.ZERO), "Building and field retain independent identities at one anchor")
	check(not Farm.quarter_open(world, Vector3i.ZERO, 0) and Farm.quarter_open(world, Vector3i.ZERO, 1), "Only the covered quarter is blocked")
	Farm.water_crop(world, Vector3i.ZERO)
	Farm.tick_crops(world, Farm.GROW_SECONDS)
	check(crop.food == 3 and Farm.standing_quarters(crop) == 14, "Covered quarter never grows; three open quarters mature")
	var restored = Model.new()
	check(restored.restore(JSON.parse_string(JSON.stringify(world.snapshot()))), "Covered field and independent quarter state survive saves")
	check(Farm.is_hay(restored, Vector3i.ZERO) and restored.gardens[Vector3i.ZERO].quarter_water == crop.quarter_water, "Reload preserves the underlying field and moisture")
	var renderer := preload("res://scripts/settlement/world_view.gd").new()
	root.add_child(renderer)
	renderer.setup(world)
	var rendered_field: Node3D = renderer.garden_views[Vector3i.ZERO]
	check(rendered_field.has_node("TerrainField") and rendered_field.position == Farm.FIELD_OFFSET, "Main renderer fits the field at its own offset beneath a same-anchor building")
	check(renderer.entity_views.has("building:%s" % Vector3i.ZERO) and not rendered_field.get_node("TerrainField/Quarter0").visible, "Main renderer shows the house and suppresses only its crop quarter")
	var tooltip := preload("res://scripts/settlement/object_tooltip.gd")
	var field_info: Dictionary = tooltip.describe(world, {"kind": "hay_field", "cell": Vector3i.ZERO})
	var house_info: Dictionary = tooltip.describe(world, {"kind": "house", "cell": Vector3i.ZERO})
	check(field_info.rows[0].icon == "grain" and house_info.rows[0].icon == "citizens", "Shared-anchor tooltips describe the clicked field or house separately")
	renderer.free()
	# Exercise real dismantling, rather than erasing the building by hand.
	check(world.Deconstruction.request(world, Vector3i.ZERO), "Covering house can be dismantled")
	var plan: Dictionary = world.plans[world.next_plan_id - 1]
	var worker: Dictionary = world.workers[0]
	worker.cell = Vector3i(-2, 0, 0)
	worker.position = world.navigation.surface_point(worker.cell)
	worker.route = []
	worker.route_index = 0
	worker.job = {"kind": "relocate", "plan_id": plan.id, "labour": plan.relocation.labour}
	world.Relocation.tick_work(world, worker, 100.0)
	check(world.gardens.has(Vector3i.ZERO) and world.buildings[Vector3i.ZERO].kind == "hay_field", "Removing the house restores the original field without removing its crops")
	check(world.construction_materials[Vector3i.ZERO] == world.Catalog.recipe("hay_field"), "Field retains its own construction materials")
	world.plans.clear()
	worker.job = {}
	world.rebuild_navigation()
	Farm.water_crop(world, Vector3i.ZERO)
	Farm.tick_crops(world, Farm.GROW_SECONDS)
	check(crop.food == 4, "Uncovered quarter can be watered and regrown")
	# Rain and manual water use the same quarter moisture state.
	for quarter in 4: Farm.cut_quarter(crop, quarter)
	world.platforms[Vector3i(2, 1, 2)] = 1
	world.rebuild_navigation()
	world.weather.seconds = 91
	world.Hydrology.tick(world, 1.0)
	check(crop.quarter_water == [1, 1, 1, 0], "Rain waters exposed quarters but cannot pass through an overhead platform")
	Farm.tick_crops(world, Farm.GROW_SECONDS)
	check(crop.food == 3 and Farm.standing_quarters(crop) == 7, "Rain alone grows the three exposed quarters")
	world.platforms.clear()
	world.rebuild_navigation()
	for quarter in 4: Farm.cut_quarter(crop, quarter)
	var near = world.Inventory.new()
	near.store("water", 3)
	var far = world.Inventory.new()
	far.store("water", 3)
	world.water_sources[Vector3i(-4, 0, 0)] = {"kind": "puddle", "inventory": near}
	world.water_sources[Vector3i(7, 0, 7)] = {"kind": "puddle", "inventory": far}
	world.rebuild_navigation()
	check(world.Jobs._assign_farm(world, worker) and worker.job.get("kind") == "water" and worker.job.get("source") == near, "Farmer chooses the nearer reachable water source")
	var carried := false
	for frame in 800:
		world.Jobs._tick_worker(world, worker, 0.05)
		carried = carried or worker.cargo == "water"
		if worker.job.is_empty(): break
	check(carried and crop.quarter_water == [1, 1, 1, 1] and near.count("water") == 2, "Manual watering physically carries and consumes one bucket")
	check(preload("res://scripts/settlement/structure_parts.gd").title("food_crate").contains("Unused"), "Retained box is labelled unused")
	view.free()
	if failures.is_empty(): print("PASS: %d hay terrain, coverage, quarter growth, rain, hauling and save checks" % checks)
	quit(int(not failures.is_empty()))
