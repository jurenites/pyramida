extends SceneTree
const Model = preload("res://scripts/settlement/world_model.gd")
const Fixture = preload("res://tests/settlement/reviewed_balance_test.gd")
const Assets = preload("res://scripts/settlement/asset_library.gd")
const Posts = preload("res://scripts/settlement/house_posts.gd")
const View = preload("res://scripts/settlement/world_view.gd")
var failures: Array[String] = []
func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message); printerr("FAIL: " + message)
func _initialize() -> void: call_deferred("run")
func complete(world, plan: Dictionary) -> void:
	plan.used = plan.materials.duplicate(); plan.installed = plan.required; world._complete_plan(plan)
func run() -> void:
	Assets.Appearance.directory = "/tmp/pyramida-shared-posts-%d" % Time.get_ticks_usec()
	var fixture := Fixture.new(); var world = fixture.fixture()
	fixture.finish(world, "house", Vector3i.ZERO)
	check(world.request_build("house", Vector3i(2, 0, 0), 1), "Queue connected extension")
	var plan: Dictionary = world.plans.values()[0]
	check(plan.materials == {"grain": 2, "log": 1} and plan.required == 3 and plan.shared_frame.posts == 2, "Two reused posts save one Log")
	check(world.Houses.construction_quote(world, Vector3i(-2, 0, 0), 0, Vector3.ZERO).saving == 0, "Wall-only neighbour receives no discount")
	check(world.Houses.construction_quote(world, Vector3i(2, 0, 0), 1, Vector3(0.2, 0, 0)).saving == 0, "Misaligned frame receives no discount")
	check(world.Houses.construction_quote(world, Vector3i(2, 2, 0), 1, Vector3.ZERO).saving == 0, "Different floors do not share posts")
	check(not world.Relocation.source_error(world, Vector3i.ZERO).is_empty(), "Reused supports stay in place until construction finishes")
	var restored = Model.new()
	check(restored.restore(JSON.parse_string(JSON.stringify(world.snapshot()))), "Discounted plan saves and loads")
	check(restored.plans[plan.id].materials == plan.materials and restored.Houses.frame_needed(restored, Vector3i.ZERO), "Saved price and support dependency remain intact")
	plan.used = {"log": 1}; plan.installed = 1
	check(world.delete_plan(plan.id) and not world.Houses.frame_needed(world, Vector3i.ZERO), "Cancelling partial work releases the existing supports")
	check(plan.relocation.parts.count("log") == 1 and not plan.has("shared_frame"), "Cancellation refunds only delivered material")
	check(restored.restore(JSON.parse_string(JSON.stringify(world.snapshot()))), "Cancelled discounted site saves as salvage")
	world.plans.clear()
	check(world.request_build("house", Vector3i(2, 0, 0), 1), "Requeue extension")
	plan = world.plans.values()[0]; complete(world, plan)
	check(world.construction_materials[Vector3i(2, 0, 0)] == {"grain": 2, "log": 1}, "Completed house records actual cost")
	var view := View.new(); root.add_child(view); view.setup(world)
	var count := 0; var positions := {}
	for cell: Vector3i in [Vector3i.ZERO, Vector3i(2, 0, 0)]:
		var node: Node3D = view.entity_views["building:%s" % cell]
		for post: MeshInstance3D in node.get_node("SharedPosts").get_children():
			if not str(post.name).begins_with("Post"): continue
			count += 1; positions[Posts.Frame.key(post.global_position)] = true
			check(post.basis.get_scale().is_equal_approx(Vector3.ONE), "Posts use rigid stock")
	check(count == 6 and positions.size() == 6, "Two rooms have six unique corner posts, not eight")
	var left: Node3D = view.entity_views["building:%s" % Vector3i.ZERO]
	Posts.Frame.member(left, "AuthoredCornerPost", Vector3(0.88, 0, 0.88), Vector3(0.88, 1.8, 0.88))
	Posts.Frame.Timber.rebuild(left); left.remove_meta("shared_post_signature")
	Posts.sync(world, view.entity_views)
	check(not left.get_node("AuthoredCornerPost").visible, "Shared post replaces the authored corner member")
	var neighbour: Dictionary = world.buildings[Vector3i(2, 0, 0)]
	world.buildings.erase(Vector3i(2, 0, 0)); world.rebuild_navigation(); view.sync(world, 0, -1)
	check(not left.has_node("SharedPosts") and left.get_node("AuthoredCornerPost").visible, "Removing the neighbour restores the authored corner")
	world.buildings[Vector3i(2, 0, 0)] = neighbour; world.rebuild_navigation(); view.sync(world, 0, -1)
	# Add north/south wings; three rooms meeting a corner still share one post.
	fixture.finish(world, "house", Vector3i(0, 0, -2)); fixture.finish(world, "house", Vector3i(0, 0, 2)); view.sync(world, 0, -1)
	count = 0; positions.clear()
	for cell: Vector3i in world.Houses.members(world, Vector3i.ZERO):
		var node: Node3D = view.entity_views["building:%s" % cell]
		for post: MeshInstance3D in node.get_node("SharedPosts").get_children():
			if not str(post.name).begins_with("Post"): continue
			count += 1; positions[Posts.Frame.key(post.global_position)] = true
	check(count == 10 and positions.size() == 10, "T building has ten unique posts including three-way corners")
	check(world.Deconstruction.request(world, Vector3i.ZERO), "Whole connected building can be dismantled")
	var refund := 0
	for site: Dictionary in world.plans.values(): refund += int(site.materials.get("log", 0))
	check(refund == 5, "Dismantling refunds five paid Logs, without duplicating shared timber")
	check(restored.restore(JSON.parse_string(JSON.stringify(world.snapshot()))), "Discounted dismantling plans save and load")
	view.free()
	var queued = fixture.fixture()
	check(queued.request_build("house", Vector3i.ZERO) and queued.request_build("house", Vector3i(2, 0, 0), 1), "Queue two connected rooms")
	var first: Dictionary = queued.plans.values()[0]; var second: Dictionary = queued.plans.values()[1]
	check(second.materials.log == 2, "Unbuilt supports are not free material")
	complete(queued, first)
	check(second.materials.log == 1 and second.required == 3, "Untouched queued extension reprices after supports are built")
	check(fixture.failures.is_empty(), "Fixture buildings complete")
	fixture.free()
	print("PASS: shared posts, connected cost, queued repricing, cancellation, support protection, salvage and saves" if failures.is_empty() else "FAIL: shared posts")
	quit(0 if failures.is_empty() else 1)
