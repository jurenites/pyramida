extends SceneTree
const Model = preload("res://scripts/settlement/world_model.gd")
const Volume = preload("res://scripts/settlement/stone_volume.gd")
const Stone = preload("res://scripts/settlement/stone_view.gd")
const Inventory = preload("res://scripts/settlement/inventory.gd")
var failures: Array[String] = []
var checks := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)
func _initialize() -> void:
	var cube: Array[Vector3] = []
	for y in [0, 1]:
		for corner in Volume.CORNERS: cube.append(corner + Vector3.UP * y)
	check(is_equal_approx(Volume.volume(cube) * Volume.STONES_PER_CUBIC_METRE, 9), "A cubic metre yields nine stones")
	var capacities := {}
	for index in 8:
		var cell := Vector3i(index * 7, 0, 3)
		var parts := Volume.sections(cell, 1409)
		var capacity := Volume.capacity(cell, 1409)
		capacities[capacity] = true
		check(capacity >= 54 and capacity <= 72, "Solid formation supplies volume-based stone")
		var total := 0.0
		for part in parts:
			var fragments := Volume.fragments(part)
			var fragmented := 0.0
			for fragment in fragments:
				fragmented += float(fragment.volume)
				check(fragment.volume <= 0.125001, "Mining subdivision occupies at most one eighth of a cubic metre")
			check(absf(fragmented - Volume.volume(part.vertices)) < 0.0001, "Subdivisions conserve the filled column volume")
			total += Volume.volume(part.vertices)
		check(capacity == roundi(total * 9), "Capacity follows occupied volume rather than the number of columns")
	check(capacities.size() > 1, "Different shapes yield different capacities")
	# Filled joins have no diagonal channels; the silhouette does not set occupancy.
	var full := Volume.capacity(Vector3i.ZERO, 1409)
	for x in range(-3, 4):
		for z in range(-3, 4):
			check(Volume.solid_at(Vector3i.ZERO, 1409, full, Vector3(x * 0.25, 0.1, z * 0.25)), "Ground layer is filled across every column seam")
	# Check the actual rendered corners across different formations, not just the
	# deformation helper: neighbouring faces must share all four corner positions.
	for sample in 8:
		var parts := Volume.sections(Vector3i(sample * 7, 0, 3), 1409)
		var shared := {}
		for part in parts:
			check(is_equal_approx(part.vertices[1].x - part.vertices[0].x, 1.0), "Logical column is exactly one metre wide")
			var faces := Volume.visual_faces(part, part.count)
			var corners: Array[Vector3] = []
			for face in faces:
				var n: Vector3 = (face[1] - face[0]).cross(face[2] - face[0]).normalized()
				check(absf(n.dot(face[3] - face[0])) < 0.00001, "Every varied quad is planar")
				for point: Vector3 in face:
					if not corners.has(point): corners.append(point)
			check(corners.size() == 8 and faces.size() == 6, "Variation adds no bevels or corner vertices")
			for face_index in Volume.FACES.size():
				for corner_index in 4:
					var source: Vector3 = part.vertices[Volume.FACES[face_index][corner_index]].rotated(Vector3.UP, part.turn) + Vector3(part.offset)
					var key := source.snapped(Vector3.ONE * 0.001)
					var actual: Vector3 = faces[face_index][corner_index]
					if shared.has(key): check(shared[key].is_equal_approx(actual), "Shared rendered corners meet without cracks")
					shared[key] = actual
			check(absf(faces[0][0].y - faces[0][1].y) > 0.01, "Cap deviation is visible rather than a nearly regular cube")
	var last: Dictionary = Volume.sections(Vector3i.ZERO, 1409).back()
	var full_faces := Volume.visual_faces(last, last.count)
	var unique_corners: Array[Vector3] = []
	check(full_faces.size() == 6, "Intact stone has exactly six faces without bevels")
	for face in full_faces:
		check(face.size() == 4, "Every intact face uses four corners")
		for point: Vector3 in face:
			if not unique_corners.has(point): unique_corners.append(point)
		var normal: Vector3 = (face[1] - face[0]).cross(face[2] - face[0]).normalized()
		check(absf(normal.dot(face[3] - face[0])) < 0.00001, "Slightly angled faces remain planar")
	check(unique_corners.size() == 8, "Intact stone needs only eight geometric corners")
	check(Volume.visual_faces(last, last.count - 1).size() <= 24, "One chip is rendered as at most four simple cuboids")
	for remaining in range(0, 10):
		var remaining_volume := 0.0
		for chunk in Volume.remaining_chunks(last, remaining): remaining_volume += Volume.polygon_volume(chunk)
		check(absf(remaining_volume - remaining / 9.0) < 0.00001, "Every mining step retains its proportional volume through exhaustion")
	var before := Volume.volume(last.vertices)
	var after := 0.0
	for chunk in Volume.remaining_chunks(last, last.count - 1): after += Volume.polygon_volume(chunk)
	check(absf(before - after - 1.0 / 9) < 0.00001, "One pickup removes one ninth of a cubic metre")
	for face in Volume.visual_faces(last, last.count):
		for point: Vector3 in face: check(point.y <= 6.0001, "Natural silhouette stays below the three-storey ceiling")
	var inventory = Inventory.new()
	inventory.capacity = Volume.capacity(Vector3i.ZERO, 1409)
	inventory.store("stone", inventory.capacity)
	var node := Node3D.new()
	Stone.sync(node, Vector3i.ZERO, 1409, inventory)
	var full_count := node.get_child_count()
	for part: MeshInstance3D in node.get_children():
		var arrays := part.mesh.surface_get_arrays(0)
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		check(points.size() == 24 and indices.size() == 36, "Six flat faces share indexed triangle corners")
		for index in range(0, indices.size(), 3):
			var a := indices[index]
			var b := indices[index + 1]
			var c := indices[index + 2]
			check((points[b] - points[a]).cross(points[c] - points[a]).dot(normals[a]) < 0.000001, "Rendered exteriors use clockwise winding and outward shadow normals")
	inventory.reserve(99, "stone")
	inventory.pickup(99)
	Stone.sync(node, Vector3i.ZERO, 1409, inventory)
	check(node.get_child_count() == full_count, "One stone does not erase a metre-sized section")
	inventory.amounts.stone = 0
	Stone.sync(node, Vector3i.ZERO, 1409, inventory)
	check(node.get_child_count() == 0, "Exhausted outcrop has no remaining geometry")
	node.free()
	var quarry = Model.new()
	for x in range(-3, 4):
		for z in range(-3, 4): quarry.ground[Vector3i(x, 0, z)] = true
	var stock = Inventory.new()
	stock.capacity = Volume.capacity(Vector3i.ZERO, quarry.world_seed)
	quarry.deposits[Vector3i.ZERO] = {"kind": "limestone", "inventory": stock, "regrowth": 0.0}
	stock.amounts.stone = stock.capacity
	quarry.rebuild_navigation()
	check(not quarry.navigation.walkable(Vector3i(1, 0, 1)), "Full footprint blocks walking away from the deposit centre")
	check(quarry.navigation.access_cells(Vector3i.ZERO).size() > 0, "Miners can reach the filled formation from its perimeter")
	check(quarry.rock_blocks_build("well", Vector3i(1, 0, 1)), "Construction cannot overlap rock away from the deposit centre")
	var crown: Dictionary = Volume.sections(Vector3i.ZERO, quarry.world_seed).back()
	var roof := Vector3i(roundi(crown.offset.x), roundi(crown.vertices[4].y), roundi(crown.offset.z))
	check(quarry.rock_supports(roof), "Logical crown provides its exact metre-grid support plane")
	check(not quarry.rock_blocks_build("well", roof), "A supported footprint can stand above the crown")
	check(quarry.rock_blocks_build("well", roof - Vector3i.UP), "Construction cannot intersect the highest storey")
	quarry.plans[999] = {"cell": roof, "kind": "well"}
	check(quarry.rock_in_use(Vector3i.ZERO), "A plan on the highest storey prevents undermining")
	quarry.plans.clear()
	var found := false
	for count in range(1, stock.capacity):
		stock.amounts.stone = count
		if quarry.rock_supports(Vector3i(0, 1, 0)):
			found = true
			break
	check(found, "Mining can expose a solid one-metre ledge")
	quarry.rebuild_navigation()
	if found: check(quarry.navigation.surfaces.has(Vector3i(0, 1, 0)), "Exposed rock becomes an actual support surface")
	quarry.buildings[Vector3i(0, 1, 0)] = {"kind": "well", "direction": 0}
	check(quarry.rock_in_use(Vector3i.ZERO), "Mining cannot undermine a building")
	quarry.buildings.clear()
	stock.amounts.stone = 0
	quarry.rebuild_navigation()
	check(not quarry.navigation.blocked.has(Vector3i.ZERO) and not quarry.occupied(Vector3i.ZERO, "house"), "Fully mined rock frees the ground")
	var world = Model.new()
	world.setup()
	var cell: Vector3i = world.deposits.keys().filter(func(key): return world.deposits[key].kind == "limestone")[0]
	var deposit: Dictionary = world.deposits[cell]
	deposit.inventory.reserve(0, "stone")
	deposit.inventory.pickup(0)
	deposit.inventory.reserve(0, "stone")
	var saved := world.snapshot()
	var restored = Model.new()
	check(restored.restore(JSON.parse_string(JSON.stringify(saved))), "Mined volume saves and restores")
	check(restored.deposits[cell].inventory.count("stone") == deposit.inventory.count("stone"), "Remaining stone persists exactly")
	check(restored.deposits[cell].inventory.reservations.has(0), "In-flight reservation persists")
	deposit.inventory.capacity = Volume.sections(cell, world.world_seed).size() * 64 * 8
	deposit.inventory.amounts.stone = deposit.inventory.capacity / 2
	var wide = Model.new()
	check(wide.restore(JSON.parse_string(JSON.stringify(world.snapshot()))), "Earlier two-metre quarry saves still load")
	check(wide.deposits[cell].inventory.count("stone") == deposit.inventory.count("stone"), "Resizing preserves existing goods")
	check(Volume.logical_amount(cell, world.world_seed, 1, deposit.inventory.capacity) == 1, "Last saved stone keeps a visible remnant")
	deposit.inventory.capacity = Volume.legacy_capacity(cell, world.world_seed)
	deposit.inventory.amounts.stone = deposit.inventory.capacity - 2
	var legacy = Model.new()
	check(legacy.restore(JSON.parse_string(JSON.stringify(world.snapshot()))), "Previous tapered-volume save still restores")
	check(legacy.deposits[cell].inventory.count("stone") == deposit.inventory.count("stone"), "Previous stone quantities are not multiplied by the larger geometry")
	check(legacy.deposits[cell].inventory.reservations.has(0), "Previous quarry reservations survive the new shape")
	deposit.inventory.capacity = 6
	deposit.inventory.amounts.stone = 3
	Model.Economy.upgrade_stone(deposit, cell, world.world_seed)
	check(deposit.inventory.count("stone") == roundi(deposit.inventory.capacity * 0.5), "Old six-section deposits preserve their mined fraction")
	check(deposit.inventory.reservations.has(0), "Migration preserves pickup reservations")
	for failure in failures: printerr("FAIL: " + failure)
	if failures.is_empty(): print("PASS: %d stone volume checks" % checks)
	quit(int(not failures.is_empty()))
