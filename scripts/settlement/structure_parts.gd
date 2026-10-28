extends RefCounted
## Physical building kit: the settlement's assets, at their original metre scale.
const Assets = preload("res://scripts/settlement/asset_library.gd")
const Catalog = preload("res://data/settlement/catalog.gd")
const Appearance = Assets.Appearance
const SNAP := 0.05
const LIMIT := 2048
static var bounds_cache: Dictionary = {}

static func kinds() -> Array:
	return Appearance.PRIMITIVES + Appearance.buildings()

static func title(kind: String) -> String:
	if kind == "ceramic_roof_tile": return "Ceramic roof tile"
	if kind == "metal_roof_sheet": return "Metal roof sheet"
	return {"roof_face": "Roof face", "bed": "Bed", "bench": "Bench", "table": "Table", "urn": "Urn", "food_crate": "Food crate", "water_bucket": "Water bucket", "pottery": "Pottery", "stick": "Stick", "log": "Log", "plank": "Plank", "grain": "Hay", "berry": "Berry bush", "tree": "Tree", "palm": "Palm", "raw_stone": "Raw stone", "block": "Stone block", "rock": "Rock", "utility_ac": "Wall cooler", "utility_dish": "Wall dish", "utility_pipe": "Pipe"}.get(kind, Catalog.title(kind))

static func create(kind: String, component := "") -> Node3D:
	if not component.is_empty():
		var root := Node3D.new()
		root.add_child(Appearance.source(kind, component))
		Assets.Illustration.apply(root)
		return root
	# Palette entries are source pieces; applying a composite uses the same originals.
	var node := Appearance.original(kind)
	Assets.Illustration.apply(node)
	# Cargo contains three identical boards. Author one of those very same boards.
	if kind == "plank":
		for child in node.get_children():
			if child.name != "Plank0": child.free()
	node.set_meta("source_asset", kind)
	return node

static func meshes(node: Node3D, parent_transform := Transform3D.IDENTITY) -> Array:
	var result: Array = []
	for child in node.get_children():
		if not child is Node3D or not child.visible: continue
		if child is MeshInstance3D and child.layers == 0: continue
		var transform: Transform3D = parent_transform * child.transform
		if child is MeshInstance3D and child.mesh != null:
			result.append({"bounds": child.mesh.get_aabb(), "transform": transform, "mesh": child.mesh})
		result.append_array(meshes(child, transform))
	return result

static func geometry(kind: String, component := "") -> Array:
	var key := "%s:%s:%d" % [kind, component, Appearance.revision]
	if not bounds_cache.has(key):
		var node := create(kind, component)
		bounds_cache[key] = meshes(node)
		node.free()
	return bounds_cache[key]

static func transform(part: Dictionary) -> Transform3D:
	return Appearance.pose(part)

static func bounds(part: Dictionary) -> AABB:
	var result := AABB()
	var first := true
	for mesh: Dictionary in part_geometry(part):
		var box: AABB = (transform(part) * mesh.transform) * mesh.bounds
		result = box if first else result.merge(box)
		first = false
	return result

static func draw(root: Node3D, part: Dictionary, preview := false) -> Node3D:
	var node := Appearance.assembly_node(part.children) if part.kind == "assembly" else create(part.kind, part.get("component", ""))
	if part.has("timber_species"): Appearance.TimberPalette.apply(node, part.timber_species)
	Assets.Illustration.apply(node)
	node.transform = transform(part)
	root.add_child(node)
	if preview:
		# Preserve bark, cut ends and straw colours in the placement preview.
		for mesh in node.find_children("*", "MeshInstance3D", true, false):
			mesh.transparency = 0.45
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node

static func hit_box(ray: Vector3, direction: Vector3, box: AABB) -> Dictionary:
	var near := -INF
	var far := INF
	var normal := Vector3.ZERO
	for axis in 3:
		if absf(direction[axis]) < 0.000001:
			if ray[axis] < box.position[axis] or ray[axis] > box.end[axis]: return {}
			continue
		var a: float = (box.position[axis] - ray[axis]) / direction[axis]
		var b: float = (box.end[axis] - ray[axis]) / direction[axis]
		if minf(a, b) > near:
			near = minf(a, b)
			normal = Vector3.ZERO
			normal[axis] = -1 if direction[axis] > 0 else 1
		far = minf(far, maxf(a, b))
		if near > far: return {}
	return {"distance": near, "normal": normal} if near >= 0 else {}

static func pick(parts: Array, ray: Vector3, direction: Vector3, cutoff := INF) -> Dictionary:
	var closest := {}
	var distance := INF
	for i in parts.size():
		if parts[i].at.y > cutoff: continue
		for mesh: Dictionary in part_geometry(parts[i]):
			var world: Transform3D = transform(parts[i]) * mesh.transform
			var inverse := world.affine_inverse()
			var hit := hit_box(inverse * ray, inverse.basis * direction, mesh.bounds)
			if not hit.is_empty() and hit.distance < distance:
				distance = hit.distance
				closest = {"index": i, "point": ray + direction * distance, "normal": (world.basis.inverse().transposed() * hit.normal).normalized()}
	return closest

static func placement(kind: String, rotation: Vector3, point: Vector3, normal: Vector3, component := "", scale := Vector3.ONE, basis := Basis.IDENTITY) -> Dictionary:
	var part := {"kind": kind, "at": Vector3.ZERO, "rotation": rotation}
	if not component.is_empty(): part.component = component
	if scale != Vector3.ONE: part.scale = scale
	if basis != Basis.IDENTITY: part.basis = basis
	var minimum := INF
	for mesh: Dictionary in geometry(kind, component):
		var world: Transform3D = transform(part) * mesh.transform
		for corner in 8:
			minimum = minf(minimum, normal.dot(world * (mesh.bounds as AABB).get_endpoint(corner)))
	var snapped := point.snapped(Vector3.ONE * SNAP)
	# Snap along the face, while keeping the new mesh exactly against that face.
	part.at = snapped + normal * (normal.dot(point - snapped) - minimum)
	return part

static func encode(parts: Array) -> Array:
	return Appearance.encode(parts)

static func decode(value: Variant) -> Dictionary:
	return Appearance.decode(value)

static func cabin() -> Array:
	var parts: Array = []
	# Original-length logs form three walls and two door jambs.
	for level in 7:
		for x in [-0.45, 0.45]:
			parts.append({"kind": "log", "at": Vector3(x, level * 0.21, -0.85), "rotation": Vector3.ZERO})
		for x in [-0.85, 0.85]:
			for z in [-0.45, 0.45]:
				parts.append({"kind": "log", "at": Vector3(x, level * 0.21, z), "rotation": Vector3(0, PI / 2, 0)})
	for x in [-0.68, 0.68]:
		for y in [0.46, 1.16]:
			for offset in [-0.11, 0.11]:
				parts.append({"kind": "plank", "at": Vector3(x + offset, y, 0.85), "rotation": Vector3(0, PI / 2, PI / 2)})
	for x in [-0.7, 0.0, 0.7]:
		for z in range(-4, 5):
			parts.append({"kind": "plank", "at": Vector3(x, 0.03, z * 0.22), "rotation": Vector3.ZERO})
	# Two pitched slopes, made only from the same bound hay carried by citizens.
	for side in [-1, 1]:
		for row in 3:
			for column in range(-3, 4):
				var z: float = side * (0.16 + row * 0.30)
				parts.append({"kind": "grain", "at": Vector3(column * 0.32, 2.04 - absf(z) * 0.5, z), "rotation": Vector3(side * atan(0.5), 0, 0)})
	return parts

static func part_geometry(part: Dictionary) -> Array:
	if part.kind != "assembly": return geometry(part.kind, part.get("component", ""))
	var result: Array = []
	for child: Dictionary in part.children:
		for mesh: Dictionary in part_geometry(child):
			result.append({"bounds": mesh.bounds, "transform": transform(child) * mesh.transform, "mesh": mesh.mesh})
	return result
