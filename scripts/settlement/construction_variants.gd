extends RefCounted
## Swap authored meshes at their actual size; never scale a placed construction.
static var scenes: Dictionary = {}

static func apply(node: Node3D, kind: String) -> void:
	if node.get_meta("construction_variant", "") == kind: return
	if node.has_meta("custom_appearance"):
		# Applied authoring is placed as-is, including on an upgraded platform.
		node.scale = Vector3.ONE
		return
	if not scenes.has(kind): scenes[kind] = load("res://data/settlement/%s.tscn" % kind)
	var source := (scenes[kind] as PackedScene).instantiate() as Node3D
	for part in source.get_children():
		var target := node.get_node_or_null(NodePath(part.name))
		if target == null: continue
		if part is MeshInstance3D and target is MeshInstance3D:
			target.mesh = part.mesh
			target.material_override = part.material_override
			target.transform = part.transform
		elif part is Marker3D: target.transform = part.transform
	node.scale = Vector3.ONE
	node.set_meta("construction_variant", kind)
	source.free()
	preload("res://scripts/settlement/timber_palette.gd").prepare(node, kind)
	preload("res://scripts/settlement/illustration_style.gd").apply(node)

static func stairs(node: Node3D, rise: int) -> void:
	apply(node, "stairs_1m" if rise == 1 else "stairs")
