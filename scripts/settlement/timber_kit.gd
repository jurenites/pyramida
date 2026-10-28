extends RefCounted
## Construction stock comes from the same meshes as hauled logs and sawn planks.
## Arrange rigid copies; never inflate a tree trunk or stretch a board to fit.
const LOG_LENGTH := 0.918 # Includes the two cut-end discs on the 0.9 m trunk.
const LOG_DIAMETER := 0.23
const BOARD := Vector3(0.7, 0.055, 0.22)
static var stock: Dictionary = {}

static func sources(kind: String) -> Array:
	if not stock.has(kind):
		var root := (load("res://data/settlement/%s.tscn" % kind) as PackedScene).instantiate()
		var pieces: Array = []
		for child in root.get_children():
			if not child is MeshInstance3D or (kind == "plank" and child.name != "Plank0"): continue
			var pose: Transform3D = child.transform
			if kind == "log": pose.origin.y -= 0.12
			pieces.append({"mesh": child.mesh, "material": child.material_override, "pose": pose})
		stock[kind] = pieces
		root.free()
	return stock[kind]

static func centres(span: float, length: float) -> Array[float]:
	var count := maxi(1, ceili(span / length))
	var result: Array[float] = []
	for index in count:
		result.append(0.0 if count == 1 else lerpf(-(span - length) / 2, (span - length) / 2, float(index) / (count - 1)))
	return result

static func batch(kind: String, poses: Array[Transform3D]) -> ArrayMesh:
	var result := ArrayMesh.new()
	for source: Dictionary in sources(kind):
		for surface in source.mesh.get_surface_count():
			var shades := mini(3, poses.size()) if kind == "plank" else 1
			for shade in shades:
				var builder := SurfaceTool.new()
				builder.begin(Mesh.PRIMITIVE_TRIANGLES)
				for index in poses.size():
					if index % shades == shade: builder.append_from(source.mesh, surface, poses[index] * source.pose)
				var material: Material = source.material if source.material != null else source.mesh.surface_get_material(surface)
				if shade > 0 and material is StandardMaterial3D:
					material = material.duplicate()
					material.albedo_color = material.albedo_color.lightened(shade * 0.035)
				builder.set_material(material)
				builder.commit(result)
	return result

static func member(node: MeshInstance3D, pose := Transform3D.IDENTITY) -> bool:
	if node.has_meta("timber_stock") or node.mesh == null: return false
	var label := str(node.name).to_lower()
	# Stone, plaster, roof tiles, mechanisms and small pegs retain their authored form.
	var timber := false
	for word in ["post", "beam", "brace", "rafter", "rail", "rung", "lintel", "plank", "board", "timber", "tabletop", "leg", "seat", "shelf", "crossbar", "sawframe", "ladder", "border", "frame", "shaft", "lever", "axle", "strut", "deck"]:
		if word in label: timber = true
	for word in ["stone", "foot", "rope", "peg", "metal", "water", "roof", "linen"]:
		if word in label: timber = false
	if not timber: return false
	var box := node.mesh.get_aabb()
	var size := box.size * pose.basis.get_scale().abs()
	var length_axis := size.max_axis_index()
	var thin_axis := size.min_axis_index()
	# The larger stock cross-section needs clearance at diagonal ladder ends.
	# Shorten the assembled span by overlapping the same full-length pieces.
	if label.begins_with("ladderrail") or label.begins_with("ladderbrace"): size[length_axis] -= 0.25
	if size[length_axis] < BOARD.x - 0.001 or length_axis == thin_axis: return false
	var width_axis := 3 - length_axis - thin_axis
	var kind := "log" if size[width_axis] <= LOG_DIAMETER + 0.01 and size[length_axis] >= LOG_LENGTH else "plank"
	# Rungs, floors, panels and shelves are always sawn boards.
	for word in ["rung", "floor", "plank", "board", "tabletop", "shelf", "seat", "border"]:
		if word in label: kind = "plank"
	var x := pose.basis[length_axis].normalized()
	var y := pose.basis[thin_axis].normalized()
	var z := x.cross(y).normalized()
	y = z.cross(x).normalized()
	var orientation := Basis(x, y, z)
	var centre: Vector3 = pose * box.get_center()
	var poses: Array[Transform3D] = []
	var stock_length := LOG_LENGTH if kind == "log" else BOARD.x
	var rows: Array = [0.0] if kind == "log" else centres(maxi(1, roundi(size[width_axis] / BOARD.z)) * BOARD.z, BOARD.z)
	if kind == "plank": centre += y * (size[thin_axis] - BOARD.y) * 0.5
	for along in centres(size[length_axis], stock_length):
		for across in rows:
			# Tiny lap offsets separate the overlapping ends, avoiding coplanar flicker.
			var lap := y * (poses.size() % 3) * 0.0015 if kind == "plank" else Vector3.ZERO
			poses.append(Transform3D(orientation, centre - pose.origin + x * along + z * across - lap))
	node.mesh = batch(kind, poses)
	node.transform = Transform3D.IDENTITY
	node.position = pose.origin
	node.material_override = null
	node.set_meta("timber_stock", kind)
	node.set_meta("timber_count", poses.size())
	preload("res://scripts/settlement/timber_palette.gd").apply(node, "tree")
	return true

static func rebuild(root: Node3D) -> void:
	for node: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		var parent_pose := Transform3D.IDENTITY
		var ancestor := node.get_parent() as Node3D
		while ancestor != root:
			parent_pose = ancestor.transform * parent_pose
			ancestor = ancestor.get_parent() as Node3D
		if member(node, parent_pose * node.transform):
			# Meshes are built in metres, including beneath animated/scaled parents.
			node.transform = parent_pose.affine_inverse() * node.transform

static func fit_ladder(root: Node3D, rise: float) -> void:
	for node in root.get_children():
		if not node is MeshInstance3D: continue
		var bounds: AABB = node.transform * node.mesh.get_aabb()
		var lower := Vector3(-1, 0, -1)
		var upper := Vector3(1, rise, 1)
		assert(bounds.size.x <= 2.001 and bounds.size.y <= rise + 0.001 and bounds.size.z <= 2.001)
		for axis in 3:
			if bounds.position[axis] < lower[axis]: node.position[axis] += lower[axis] - bounds.position[axis]
			elif bounds.end[axis] > upper[axis]: node.position[axis] -= bounds.end[axis] - upper[axis]

static func well_shape(asset: Node3D, wrapped: bool) -> void:
	for child in asset.get_children():
		if not child is MeshInstance3D: continue
		var part := str(child.name)
		if part.begins_with("WellStone") and not wrapped:
			child.position.y *= 0.62
			child.scale.y *= 0.62
		if part.begins_with("Well") or part in ["Water", "Axle", "Rope", "Canopy"] or part.begins_with("Pot"):
			var width := 0.85 if wrapped else 0.55
			child.position.x *= width
			child.position.z *= width
			child.scale.x *= width
			child.scale.z *= width
	asset.set_meta("authored_well", true)
