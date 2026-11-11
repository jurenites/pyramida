extends SceneTree
const Model = preload("res://scripts/settlement/world_model.gd")
const Fixture = preload("res://tests/settlement/reviewed_balance_test.gd")
const Foundation = preload("res://scripts/settlement/support_foundation.gd")
const Runtime = preload("res://scripts/settlement/support_runtime.gd")
const Frame = preload("res://scripts/settlement/structure_frame.gd")
const View = preload("res://scripts/settlement/world_view.gd")
var failures: Array[String] = []
func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message); printerr("FAIL: " + message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var fixture := Fixture.new()
	var world = fixture.fixture()
	world.generator_version = 4
	for x in range(2, 10):
		for z in range(-3, 4):
			world.ground.erase(Vector3i(x, 0, z))
			for y in range(-x, 0): world.volume_edits[Vector3i(x, y, z)] = "water"
	world.rebuild_navigation()
	var shallow := Vector3i(2, 0, 0)
	var deeper := Vector3i(3, 0, 0)
	check(Foundation.recipe(world, Vector3i.ZERO) == Model.Catalog.recipe("support"), "Dry Support keeps its base price")
	check(Foundation.depth(world, Vector3(shallow)) > 1.99, "Post reaches the edited seabed")
	check(Foundation.recipe(world, deeper).log > Foundation.recipe(world, shallow).log, "Deeper water costs more logs")
	check(not world.request_build("support", Vector3i(7, 0, 0)), "Remote water requires a construction access floor")
	check(world.request_build("support", shallow), "Shore pier queues: " + world.last_message)
	if world.plans.is_empty(): fixture.free(); quit(1); return
	var plan: Dictionary = world.plans[world.next_plan_id - 1]
	check(plan.materials == Foundation.recipe(world, shallow) and plan.required == plan.materials.log, "Construction charges the full submerged length")
	check(world.Planning.ready(world, plan), "Seabed replaces dry-ground footing")
	var planned_view := View.new(); root.add_child(planned_view); planned_view.setup(world)
	var site: Node3D = planned_view.entity_views["plan:%s" % plan.id]
	check(site.has_node("WaterPosts") and site.get_node("WaterPosts").get_child_count() == 4, "Construction site includes submerged posts")
	planned_view.free()
	var restored = Model.new()
	check(restored.restore(JSON.parse_string(JSON.stringify(world.snapshot()))), "Depth-priced construction saves and reloads")
	check(world.debug_finish_plan(plan.id), "Pier completes on the seabed")
	check(world.navigation.walkable(shallow + Vector3i.UP), "Pier deck is a real walking floor")
	check(is_equal_approx(world.navigation.surface_point(shallow + Vector3i.UP).y, Foundation.water_level(world) + 0.15), "Walking follows the lowered deck at fifteen centimetres above water")
	check(not world.navigation.route(Vector3i(1,0,0), shallow + Vector3i.UP).is_empty(), "A real plank landing connects the shore to the low pier")
	check(world.request_build("support", deeper), "Pier extends from its completed deck: " + world.last_message)
	check(world.debug_finish_plan(world.next_plan_id - 1), "Deeper extension completes")
	check(not world.navigation.route(shallow + Vector3i.UP, deeper + Vector3i.UP).is_empty(), "Neighboring pier decks connect")
	var view := View.new(); root.add_child(view); view.setup(world)
	var node: Node3D = view.entity_views["building:%s" % shallow]
	var post: MeshInstance3D = node.get_node("ConnectedStructure/Post0")
	var deck: MeshInstance3D = node.get_node("ConnectedStructure/Deck")
	check(absf((deck.global_transform * deck.mesh.get_aabb()).end.y - world.navigation.surface_point(shallow + Vector3i.UP).y) < 0.02, "Visible boards and walking surface share the low height")
	check(post.mesh.get_aabb().position.y < -1.99, "Rendered posts reach the seabed")
	check(post.get_active_material(0) is ShaderMaterial and post.get_active_material(0).get_shader_parameter("wet_wood") == true, "Water-contact wood uses a world-height wet tint")
	check(is_equal_approx(post.get_active_material(0).get_shader_parameter("water_level"), Foundation.water_level(world)), "Wet tint meets the rendered sea height")
	check(Frame.Palette.material("tree", "log", 0).albedo_color == Frame.Palette.BARK[0], "Wet wood does not mutate shared dry timber")
	check(node.get_meta("collider").get_child(0).shape is ConcavePolygonShape3D, "Pier picking uses its extended timber")
	view.free()
	check(restored.restore(JSON.parse_string(JSON.stringify(world.snapshot()))), "Completed piers and their paid costs survive reload")
	check(restored.construction_materials[deeper] == world.construction_materials[deeper], "Save retains extra foundation timber for recovery")
	check(world.request_build("support", Vector3i(2, 0, 3)), "Second pier plan queues")
	plan = world.plans[world.next_plan_id - 1]
	check(world.move_plan(plan.id, Vector3i(3, 0, 3), 0, Vector3.ZERO), "Plan can move to deeper water beside dry ground")
	check(plan.materials == Foundation.recipe(world, plan.cell), "Moved plan reprices to destination depth")
	# A rotated, off-grid footing uses its own column, including mixed shore/water.
	var lengths := Foundation.depths(world, Vector3i(2, 0, -3), Vector3(0, 0, -0.3), deg_to_rad(8))
	check(lengths.min() == 0 and lengths.max() > 0, "Rotated shoreline samples each actual post")
	check(Runtime.foundation_error(world, Vector3i(2, 0, -3), Vector3(0, 0, -0.3), deg_to_rad(8)).is_empty(), "Mixed dry and submerged footing is valid")
	check(world.request_build("support", Vector3i(1,0,0)), "Ordinary dry Support can stand beside a lowered pier")
	check(world.debug_finish_plan(world.next_plan_id - 1), "Dry neighbour completes")
	check(not world.navigation._touching(Vector3i(1,1,0), shallow + Vector3i.UP), "Different physical deck heights do not create an invisible step")
	check(world.request_build("support", shallow + Vector3i.UP), "Upper Support retains its structural socket over a pier")
	check(world.debug_finish_plan(world.next_plan_id - 1), "Upper Support completes")
	var loaded_view := View.new(); root.add_child(loaded_view); loaded_view.setup(world)
	var lower: Node3D = loaded_view.entity_views["building:%s" % shallow]
	var bearing: MeshInstance3D = lower.get_node("ConnectedStructure/Post0")
	check(is_equal_approx(bearing.mesh.get_aabb().end.y, Foundation.deck_height(world,shallow)), "Loaded pier posts meet the lowered upper frame directly")
	loaded_view.free()
	# Normal hauling must pay the extra depth, including when moving a dry frame.
	var moving = fixture.fixture()
	moving.generator_version = 4
	var target := Vector3i(2, 0, 2)
	moving.ground.erase(target)
	for y in range(-3, 0): moving.volume_edits[Vector3i(2, y, 2)] = "water"
	moving.rebuild_navigation()
	moving.add_store(Vector3i(0, 0, 4)); moving.stores[Vector3i(0, 0, 4)].capacity = 300
	moving.stores[Vector3i(0, 0, 4)].store("log", 256)
	check(moving.request_build("support", Vector3i.ZERO), "Dry relocation source queues")
	check(moving.debug_finish_plan(moving.next_plan_id - 1), "Dry relocation source completes")
	moving.workers[0].cell = Vector3i(-2, 0, 0); moving.workers[0].position = Vector3(-2, 0, 0)
	check(moving.Relocation.request(moving, Vector3i.ZERO, target, 0, Vector3.ZERO), "Dry Support can move into deeper water")
	var move_id: int = moving.next_plan_id - 1
	var extra: int = Foundation.recipe(moving, target).log - 2
	check(moving.order_build(0, move_id), "Builder accepts depth-priced relocation")
	for tick in 24000:
		moving.time += 0.1
		moving.Jobs.prepare_decisions(moving)
		moving.workers[0].hunger = 0
		moving.Citizens.tick(moving, moving.workers[0], 0.1)
		if not moving.plans.has(move_id): break
	check(moving.buildings.has(target) and not moving.plans.has(move_id), "Worker rebuilds the deeper pier with recovered and additional timber")
	check(moving.stores[Vector3i(0, 0, 4)].count("log") == 256 - extra, "Relocation recovers only original timber and charges all additional depth")
	check(restored.restore(JSON.parse_string(JSON.stringify(moving.snapshot()))), "Relocated pier saves after ordinary hauling")
	fixture.free()
	if failures.is_empty(): print("PASS: Support piers, depth costs, access, navigation, wet timber, moving and saves")
	quit(int(not failures.is_empty()))
