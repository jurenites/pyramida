extends SceneTree
const Assets = preload("res://scripts/settlement/asset_library.gd")
const Catalog = preload("res://data/settlement/catalog.gd")
const Relative = preload("res://scripts/settlement/timber_frame.gd")
const Mill = preload("res://scripts/settlement/mill_view.gd")
const Generator = preload("res://tools/settlement/mill_model.gd")
const Model = preload("res://scripts/settlement/world_model.gd")
var failures: Array[String] = []
func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message); printerr("FAIL: " + message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var node := Assets.create("mill"); root.add_child(node)
	check(Catalog.Reviewed.size("mill") == Vector3(3, 5, 3) and Catalog.building_height("mill") == 5, "Mill reserves only its 3 X 3 base horizontally and stacks above its main roof")
	var world := Model.new()
	for direction in 4:
		world.buildings[Vector3i.ZERO] = {"kind": "mill", "direction": direction}
		check(world.Farming.footprint("mill", Vector3i.ZERO, Vector3.ZERO, direction).size == Vector2(3, 3), "Footprint stays 3 X 3 at every heading")
		for neighbour: Vector3i in [Vector3i(3, 0, 0), Vector3i(0, 0, 3), Vector3i(-3, 0, 0), Vector3i(0, 0, -3)]:
			check(not world.occupied(neighbour, "mill", Vector3.ZERO, direction), "Adjacent mills may touch their base footprints despite blade overhang")
		check(world.occupied(Vector3i(2, 0, 0), "mill", Vector3.ZERO, direction), "Actual base overlap is still rejected")
	check(Catalog.recipe("mill") == {"plank": 4, "stone": 4}, "Reviewed construction price is unchanged")
	check(node.get_node("RoofSocket").position.y == 5, "Roof socket matches new height")
	check(node.get_node("WindTower/Ridge").position.y > 4, "Tower itself is taller")
	var rotor := node.get_node("WindTower/Rotor") as Node3D
	check(rotor.scale.is_equal_approx(Vector3.ONE), "No oversized scaled propeller")
	for part: MeshInstance3D in rotor.find_children("*", "MeshInstance3D", true, false):
		check(part.get_meta("timber_stock", "") == "plank", "Propeller contains only planks")
		var cut: Vector3 = part.get_meta("cut_size")
		check(cut.x <= 0.7001 and cut.y <= 0.0551 and cut.z <= 0.2201, "Every blade piece fits inside the original Plank stock")
		check(is_equal_approx(cut.y, 0.055), "Blade plank thickness is unchanged")
		for vertex: Vector3 in part.mesh.get_faces():
			var at := Relative.relative(rotor, part) * vertex
			var radius := Vector2(at.x, at.y).length()
			check(radius <= 3.0001, "Full radial sweep fits within 6 metre width")
	var reference := Node3D.new()
	var wide_rotor := Generator.rotor_model(reference, 2.0)
	for index in 4:
		var narrow := blade_bounds(rotor.get_node("Sail%d" % index))
		var wide := blade_bounds(wide_rotor.get_node("Sail%d" % index))
		check(is_equal_approx(narrow.size.x, wide.size.x * 0.5), "Blade short side is exactly half as wide")
		check(is_equal_approx(narrow.position.y, wide.position.y) and is_equal_approx(narrow.end.y, wide.end.y), "Blade length and radial placement are unchanged")
	reference.free()
	check(is_equal_approx(rotor.position.y, 5 - float(node.get_meta("reference_rotor_radius"))), "Tower and axle keep their previous height")
	for turn in 16:
		rotor.rotation.z = turn * TAU / 16
		for part: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
			if not part.is_visible_in_tree() or part.layers == 0: continue
			var pose := Relative.relative(node, part)
			for vertex: Vector3 in part.mesh.get_faces():
				var at := pose * vertex
				check(absf(at.x) <= 3.0001 and absf(at.z) <= 1.5001 and at.y <= 7.0001, "Visible model stays inside its dimensions through a full turn")
	var angle := rotor.rotation.z; Mill.animate(node, 3, 0.2, true)
	check(not is_equal_approx(angle, rotor.rotation.z), "Propeller animation is retained")
	node.free()
	print("PASS: 3 X 3 Mill placement, half-width blades, unchanged blade length, five-metre roof socket, costs and animation" if failures.is_empty() else "FAIL: Mill shape")
	quit(0 if failures.is_empty() else 1)

func blade_bounds(blade: Node3D) -> AABB:
	var bounds := AABB()
	var first := true
	for part: MeshInstance3D in blade.find_children("*", "MeshInstance3D", true, false):
		var box := Relative.relative(blade, part) * part.mesh.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	return bounds
