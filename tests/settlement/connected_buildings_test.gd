extends SceneTree
const Model = preload("res://scripts/settlement/world_model.gd")
const Fixture = preload("res://tests/settlement/reviewed_balance_test.gd")
const Frame = preload("res://scripts/settlement/connected_frames.gd")
const Assets = preload("res://scripts/settlement/asset_library.gd")
const View = preload("res://scripts/settlement/world_view.gd")
var failures: Array[String] = []
func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message); printerr("FAIL: " + message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	Assets.Appearance.directory = "/tmp/pyramida-connected-source-%d" % Time.get_ticks_usec()
	for kind: String in Frame.KINDS:
		for direction in 4:
			var model = Model.new()
			var size := Model.Catalog.Reviewed.size(kind)
			var step := Vector3.RIGHT.rotated(Vector3.UP, -direction * PI / 2) * size.x
			var views := {}
			for i in 2:
				var cell := Vector3i(roundi(step.x * i), 0, roundi(step.z * i))
				model.buildings[cell] = {"kind": kind, "direction": direction}
				var node := Assets.create(kind); node.rotation.y = -direction * PI / 2; node.position = Vector3(cell); root.add_child(node)
				views[cell] = node
			Frame.sync(model, views)
			var posts := 0; var beams := 0
			for node: Node3D in views.values():
				check(node.has_node("ConnectedFrame"), kind + " forms joined frame")
				if not node.has_node("ConnectedFrame"): continue
				for member_: MeshInstance3D in node.get_node("ConnectedFrame").get_children():
					posts += int(str(member_.name).begins_with("Post")); beams += int(str(member_.name).begins_with("Beam"))
					check(member_.get_meta("timber_stock", "") in ["log", "plank"], "Frame uses stock logs or planks")
					check(member_.basis.get_scale().is_equal_approx(Vector3.ONE), "Stock is assembled without stretching")
			check(posts == 6 and beams == 7, "%s has six posts and one shared boundary beam" % kind)
			var first: Node3D = views[Vector3i.ZERO]
			var old_frame := first.get_node_or_null("ConnectedFrame")
			Frame.sync(model, views)
			check(first.get_node_or_null("ConnectedFrame") == old_frame, "Unchanged frame is reused")
			var second: Vector3i = views.keys()[1]
			model.buildings.erase(second); views[second].free(); views.erase(second)
			Frame.sync(model, views)
			check(not first.has_node("ConnectedFrame"), "Removal restores standalone building")
			check(first.get_children().filter(func(child): return child is MeshInstance3D and Frame.frame_part(str(child.name))).all(func(child): return child.visible), "Standalone frame restored")
			first.free()
	# Three-way and four-way corners must share one post, including removal.
	var cluster = Model.new(); var cluster_views := {}
	for cell: Vector3i in [Vector3i.ZERO, Vector3i(3, 0, 0), Vector3i(0, 0, 3), Vector3i(3, 0, 3)]:
		cluster.buildings[cell] = {"kind": "stone_storage", "direction": 0}
		var node := Assets.create("stone_storage"); node.position = Vector3(cell); root.add_child(node); cluster_views[cell] = node
	for count in [4, 3]:
		Frame.sync(cluster, cluster_views)
		var positions := {}; var posts := 0; var beams := 0
		for node: Node3D in cluster_views.values():
			for member_: MeshInstance3D in node.get_node("ConnectedFrame").get_children():
				if str(member_.name).begins_with("Post"):
					posts += 1; positions[Frame.key(member_.global_position)] = true
				else: beams += 1
		check(posts == (9 if count == 4 else 8) and positions.size() == posts, "Cluster has one post per shared corner")
		check(beams == (12 if count == 4 else 10), "Cluster has one beam per shared edge")
		if count == 4:
			var cell := Vector3i(3, 0, 3); cluster.buildings.erase(cell); cluster_views[cell].free(); cluster_views.erase(cell)
	for node: Node3D in cluster_views.values(): node.free()
	var fixture := Fixture.new(); var world = fixture.fixture()
	fixture.finish(world, "house", Vector3i.ZERO); fixture.finish(world, "house", Vector3i(2, 0, 0))
	world.buildings[Vector3i(2, 0, 0)].direction = 1
	check(Model.Houses.members(world, Vector3i.ZERO).size() == 2, "Door-to-wall houses become one building")
	var view := View.new(); root.add_child(view); view.setup(world)
	var left: Node3D = view.entity_views["building:%s" % Vector3i.ZERO]
	var right: Node3D = view.entity_views["building:%s" % Vector3i(2, 0, 0)]
	check(not left.get_node("PlasterWall2").visible and not right.get_node("DoorSide").visible, "Both interior walls open")
	check(left.get_node("BackWall").visible and right.get_node("BackWall").visible, "Outer walls stay intact")
	for member_: MeshInstance3D in left.get_node("JoinedWalls").get_children():
		if str(member_.name).begins_with("Threshold"): continue
		check(member_.get_meta("timber_stock", "") in ["log", "plank"], "Every shared House portal member uses stock")
	var restored = Model.new()
	check(restored.restore(JSON.parse_string(JSON.stringify(world.snapshot()))) and Model.Houses.members(restored, Vector3i.ZERO).size() == 2, "Connections survive save/load")
	var sun := DirectionalLight3D.new(); Assets.Illustration.configure_sun(sun)
	check(sun.shadow_blur > 0 and is_zero_approx(sun.light_angular_distance), "Shared filtered shadow settings")
	sun.free(); view.queue_free(); fixture.free(); await process_frame
	print("PASS: connected timber frames, four rotations, removal, house openings and shadows" if failures.is_empty() else "FAIL: connected buildings")
	quit(0 if failures.is_empty() else 1)
