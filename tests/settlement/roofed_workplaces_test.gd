extends SceneTree
const Assets = preload("res://scripts/settlement/asset_library.gd")
const Catalog = preload("res://data/settlement/catalog.gd")
const Barn = preload("res://scripts/settlement/barn_roof.gd")
const Fixture = preload("res://tests/settlement/reviewed_balance_test.gd")
const View = preload("res://scripts/settlement/world_view.gd")
var failures: Array[String] = []
func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message); printerr("FAIL: " + message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	for kind in ["bakery", "kiln"]:
		var node := Assets.create(kind)
		check(Catalog.Reviewed.size(kind) == Vector3(2,2,3), "Two by three by two body")
		check(node.has_node("Walls/LeftWall") and node.has_node("Walls/BackWall") and node.has_node("Walls/DoorSide1") and node.has_node("Walls/WindowSillWall"), kind + " has actual enclosing walls, doorway and window")
		var oven: MeshInstance3D = node.get_node("Oven"); var bounds := oven.transform * oven.mesh.get_aabb()
		check(bounds.position.x > -0.78 and bounds.end.x < 0.78 and bounds.position.z > -1.28 and bounds.end.z < 1.28 and bounds.end.y < 1.82, "Oven fits inside the room")
		var covering := node.get_node("Roof").get_children().filter(func(part): return part.has_meta("roof_material"))
		check(covering.size() > 15 and covering.all(func(part): return part.get_meta("roof_material") == ("hay" if kind == "bakery" else "plank")), "Correct physical roof material")
		check(kind in Catalog.NATURAL_ROOFS, "Roof appears immediately without an upper floor")
		node.free()
	var barn := Assets.create("hay_barn"); root.add_child(barn); Barn.sync(barn, 12)
	var roof: MeshInstance3D = barn.get_node("Canopy/GeneratedRoof/PlankRoof")
	check(roof.get_meta("source_component") == "Canopy/RoofCourse0", "Barn reuses Shed's beveled planks")
	var triangles := roof.mesh.get_faces()
	for x in [-0.4, 0, 0.4]:
		for z in [-0.85, -0.3, 0.3, 0.85]:
			var covered := false
			for i in range(0, triangles.size(), 3):
				if Geometry3D.ray_intersects_triangle(Vector3(x, 4, z), Vector3.DOWN, triangles[i], triangles[i+1], triangles[i+2]) != null: covered = true; break
			check(covered, "Pointed Barn roof remains fully covered")
	Barn.sync(barn, 12); check(barn.get_node("Canopy/GeneratedRoof/PlankRoof") == roof, "Barn roof stays stable between updates"); barn.free()
	var fixture := Fixture.new(); var world = fixture.fixture()
	fixture.finish(world, "bakery", Vector3i.ZERO); fixture.finish(world, "kiln", Vector3i(5,0,0))
	var view := View.new(); root.add_child(view); view.setup(world)
	for cell in [Vector3i.ZERO, Vector3i(5,0,0)]: check(view.entity_views["building:%s" % cell].get_node("Roof").visible, "Completed workplace roof is visible in game")
	view.queue_free(); fixture.free(); await process_frame
	print("PASS: enclosed ovens, Hay/Plank roofs, pointed Barn coverage, live roof visibility" if failures.is_empty() else "FAIL: roofed workplaces")
	quit(0 if failures.is_empty() else 1)
