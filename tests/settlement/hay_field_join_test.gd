extends SceneTree
const Model = preload("res://scripts/settlement/world_model.gd")
const Fields = preload("res://scripts/settlement/hay_field_view.gd")
const Assets = preload("res://scripts/settlement/asset_library.gd")
const Farm = preload("res://scripts/settlement/farming.gd")
var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func field(world, cell: Vector3i, direction := 0, offset := Farm.FIELD_OFFSET) -> void:
	world.buildings[cell] = {"kind": "hay_field", "direction": direction, "placement_offset": offset}

func borders(node: Node3D) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	for mesh: MeshInstance3D in node.find_children("Edge*", "MeshInstance3D", true, false):
		if mesh.visible: result.append(mesh)
	return result

func peg_layout(node: Node3D) -> Array:
	var result: Array = []
	for peg in node.get_children():
		if peg.has_meta("hay_peg_slot"): result.append(peg.transform)
	return result

func check_peg_layouts() -> void:
	var a := Assets.create("hay_field")
	var b := Assets.create("hay_field")
	var previous: Array = []
	for index in 16:
		var cell := Vector3i(index * 4 - 32, index % 3, -index * 4)
		Fields.arrange_pegs(a, cell, 4815)
		Fields.arrange_pegs(b, cell, 4815)
		var layout := peg_layout(a)
		check(layout.size() == 20, "Six sticks per side with four shared corners: twenty total")
		check(layout == peg_layout(b), "Recreated views retain the exact peg layout")
		check(layout != previous, "Different map positions have distinct arrangements")
		check(not Fields.arrange_pegs(a, cell, 4815), "Unchanged identities reuse their layout")
		for peg in a.get_children():
			if not peg.has_meta("hay_peg_slot"): continue
			var side: int = peg.get_meta("hay_peg_side")
			var axis := 0 if side < 2 else 2
			var bounds: AABB = peg.transform * peg.mesh.get_aabb()
			check(bounds.end[axis] < -2.0 if side % 2 == 0 else bounds.position[axis] > 2.0, "Entire tilted stick stays outside the crop footprint")
			check(absf(bounds.position[axis]) < 2.25 and absf(bounds.end[axis]) < 2.25, "Sticks remain close to their field")
			check(is_equal_approx(bounds.position.y, 0.025), "Tilted sticks keep their feet on the ground")
		var corners := [0, 0, 0, 0]
		var sides := [0, 0, 0, 0]
		for peg in a.get_children():
			if not peg.has_meta("hay_peg_slot"): continue
			if peg.has_meta("hay_peg_corner"):
				var corner: int = peg.get_meta("hay_peg_corner")
				corners[corner] += 1
				sides[corner % 2] += 1
				sides[2 + int(corner >= 2)] += 1
				check(absf(peg.position.x) > 2.0 and absf(peg.position.z) > 2.0, "Corner sticks stay at the outside corners")
			else:
				sides[int(peg.get_meta("hay_peg_side"))] += 1
		check(corners == [1, 1, 1, 1], "Every corner has exactly one stick")
		check(sides == [6, 6, 6, 6], "Every side includes four middle sticks and two corner sticks")
		previous = layout
	Fields.arrange_pegs(b, Vector3i(28, 0, -60), 4816)
	check(peg_layout(a) != peg_layout(b), "Different world seeds vary the same field position")
	a.free()
	b.free()

func _initialize() -> void:
	check_peg_layouts()
	for direction in 4:
		var world = Model.new()
		field(world, Vector3i.ZERO, direction)
		field(world, Vector3i(4, 0, 0), (direction + 1) % 4)
		var a := Assets.create("hay_field")
		var b := Assets.create("hay_field")
		Fields.sync(world, Vector3i.ZERO, a)
		Fields.sync(world, Vector3i(4, 0, 0), b)
		check(borders(a).size() == 17 and borders(b).size() == 17, "Both rotated fields lose exactly one plank and six pegs including shared-edge corners")
		check(a.get_node("Plants").get_child_count() == 4, "Joining preserves all four solid crop quarters")
		var cached := a.get_node("JoinedBorderPieces")
		Fields.sync(world, Vector3i.ZERO, a)
		check(cached == a.get_node("JoinedBorderPieces"), "Unchanged borders reuse geometry")
		world.buildings.erase(Vector3i(4, 0, 0))
		Fields.sync(world, Vector3i.ZERO, a)
		check(borders(a).size() == 24, "Removing neighbour restores all original borders")
		check(a.get_node("Soil").scale == Vector3.ONE, "Standalone soil bounds are restored")
		a.free()
		b.free()
	var world = Model.new()
	field(world, Vector3i.ZERO)
	var a := Assets.create("hay_field")
	for other in [Vector3i(4, 0, 4), Vector3i(4, 1, 0), Vector3i(5, 0, 0)]:
		field(world, other)
		Fields.sync(world, Vector3i.ZERO, a)
		check(borders(a).size() == 24, "Diagonal, elevated and separated fields keep borders")
		world.buildings.erase(other)
	world.buildings[Vector3i(4, 0, 0)] = {"kind": "house"}
	Fields.sync(world, Vector3i.ZERO, a)
	check(borders(a).size() == 24, "Different building types keep borders")
	world.buildings.erase(Vector3i(4, 0, 0))
	field(world, Vector3i(4, 0, 2))
	Fields.sync(world, Vector3i.ZERO, a)
	check(borders(a).size() == 21, "Half overlap removes only half the shared border")
	var clipped_length := 0.0
	for piece: MeshInstance3D in a.get_node("JoinedBorderPieces").get_children():
		if piece.name.begins_with("EdgePlank"):
			var bounds: AABB = piece.transform * piece.mesh.get_aabb()
			clipped_length += bounds.size.z
			check(bounds.end.z <= 0.0001, "Remaining plank stays on the exposed half")
		check(piece.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "Clipped borders preserve shadow-free fields")
	check(is_equal_approx(clipped_length, 2.0), "Exposed half retains two metres of timber")
	var soil: MeshInstance3D = a.get_node("Soil")
	check(is_equal_approx((soil.transform * soil.mesh.get_aabb()).end.x, 2.0), "Soil reaches shared boundary without a sand gap")
	Fields.sync(world, Vector3i.ZERO, a, {Vector3i(4, 0, 2): true})
	check(borders(a).size() == 24, "Dismantling neighbour restores exposed border")
	world.buildings.erase(Vector3i(4, 0, 2))
	# A legacy field centre can meet a new field at a different logical separation.
	field(world, Vector3i(5, 0, 1), 0, Vector3.ZERO)
	Fields.sync(world, Vector3i.ZERO, a)
	check(borders(a).size() == 17, "Legacy and current offsets join by physical edges")
	world.buildings.clear()
	for cell in [Vector3i.ZERO, Vector3i(4, 0, 0), Vector3i(0, 0, 4), Vector3i(4, 0, 4)]: field(world, cell)
	Fields.sync(world, Vector3i.ZERO, a)
	check(borders(a).size() == 11, "A filled block keeps only its outer perimeter")
	a.free()
	for failure in failures: printerr("FAIL: " + failure)
	if failures.is_empty(): print("PASS: hay field shared borders, rotations, partial edges, soil seams and removal")
	quit(int(not failures.is_empty()))
