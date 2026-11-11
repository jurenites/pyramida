extends RefCounted
## Stable, compact component identity. Geometry is a bounded, lazy cache, never save data.
const VERSION := 1
const VARIANTS := 64
const Timber = preload("res://scripts/settlement/timber_kit.gd")
const Clip = preload("res://scripts/settlement/roof_boards.gd")
static var sources := {}
static var meshes := {}

static func record(seed_: int) -> Dictionary:
	return {"v":VERSION, "seed":seed_, "overrides":{}}

static func valid(value: Variant) -> bool:
	if not value is Dictionary or value.get("v") != VERSION or not value.get("seed") is int or not value.get("overrides") is Dictionary: return false
	if value.overrides.size() > 1024: return false
	for key in value.overrides:
		if not key is String or key.length() > 128 or not value.overrides[key] is int or value.overrides[key] < 0 or value.overrides[key] >= VARIANTS: return false
	return true

static func variant(state: Dictionary, slot: String) -> int:
	if state.overrides.has(slot): return state.overrides[slot]
	return int(("%d:%d:%s" % [state.v, state.seed, slot]).sha256_text().substr(0, 8).hex_to_int() % VARIANTS)

static func source(kind: String) -> Dictionary:
	if not sources.has(kind):
		if kind == "plank": sources[kind] = Timber.sources("plank")[0]
		else:
			var root := preload("res://data/settlement/reviewed_brick.tscn").instantiate()
			var part: MeshInstance3D = root.get_node("Brick")
			sources[kind] = {"mesh":part.mesh, "material":part.material_override, "pose":part.transform}; root.free()
	return sources[kind]

static func mesh(kind: String, index: int, detailed := true) -> Mesh:
	var base: Mesh = source(kind).mesh
	if not detailed or index == 0: return base
	var key := "%s:%d:%d" % [kind, VERSION, posmod(index, VARIANTS)]
	if meshes.has(key): return meshes[key]
	var bounds := base.get_aabb(); var half := bounds.size / 2
	var corner := Vector3(1 if index & 1 else -1, 1 if index & 2 else -1, 1 if index & 4 else -1)
	var amount := (0.008 + (index / 8) * 0.002) if kind == "brick" else (0.003 + (index / 8) * 0.0007)
	var point := bounds.get_center() + corner * half - corner * amount / 3
	var result := ArrayMesh.new()
	for surface in base.get_surface_count():
		var arrays := base.surface_get_arrays(surface); var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var faces: Array = []
		for i in range(0, indices.size() if not indices.is_empty() else vertices.size(), 3):
			var face: Array = []
			for j in 3: face.append(vertices[indices[i + j] if not indices.is_empty() else i + j])
			faces.append(face)
		var clipped := Clip.clip(faces, -corner.normalized(), point, 0)
		var builder := SurfaceTool.new(); builder.begin(Mesh.PRIMITIVE_TRIANGLES)
		for face in clipped:
			for i in range(1, face.size() - 1):
				for vertex in [face[0], face[i], face[i + 1]]: builder.add_vertex(vertex)
		builder.generate_normals(); builder.set_material(source(kind).material if source(kind).material != null else base.surface_get_material(surface)); builder.commit(result)
	meshes[key] = result
	return result

static func batch(root: Node3D, kind: String, poses: Array[Transform3D], state: Dictionary, prefix: String) -> void:
	var groups := {}
	for i in poses.size():
		var index := variant(state, "%s/%d" % [prefix, i])
		if not groups.has(index): groups[index] = []
		groups[index].append(poses[i])
	for index in groups:
		var node := MultiMeshInstance3D.new(); node.name = kind.capitalize() + "Batch"
		var multi := MultiMesh.new(); multi.transform_format = MultiMesh.TRANSFORM_3D; multi.mesh = mesh(kind, index, false); multi.instance_count = groups[index].size()
		for i in multi.instance_count: multi.set_instance_transform(i, groups[index][i])
		node.multimesh = multi; node.material_override = source(kind).material
		node.set_meta("exemplar_kind", kind); node.set_meta("exemplar_variant", index); node.set_meta("component_count", multi.instance_count); root.add_child(node)

static func detail(root: Node3D, pixels_per_metre: float) -> void:
	var detailed := pixels_per_metre * 0.02 >= 1.25
	if root.has_meta("exemplar_detail") and root.get_meta("exemplar_detail") == detailed: return
	root.set_meta("exemplar_detail", detailed)
	for node in root.find_children("*", "MultiMeshInstance3D", true, false):
		if not node.has_meta("exemplar_kind") or (node.has_meta("detail") and node.get_meta("detail") == detailed): continue
		node.multimesh.mesh = mesh(node.get_meta("exemplar_kind"), node.get_meta("exemplar_variant"), detailed); node.set_meta("detail", detailed)

static func consolidate(root: Node3D) -> void:
	var groups := {}
	for node in root.find_children("*", "MultiMeshInstance3D", true, false):
		if not node.has_meta("exemplar_kind"): continue
		var kind: String=node.get_meta("exemplar_kind"); var index: int=node.get_meta("exemplar_variant")
		var key := "%s:%d:%s" % [kind,index,node.transparency]
		if not groups.has(key): groups[key]={"kind":kind,"index":index,"alpha":node.transparency,"poses":[]}
		var pose: Transform3D=node.transform; var ancestor: Node3D=node.get_parent()
		while ancestor!=root:
			pose=ancestor.transform*pose; ancestor=ancestor.get_parent()
		for i in node.multimesh.instance_count: groups[key].poses.append(pose*node.multimesh.get_instance_transform(i))
		node.free()
	for group in groups.values():
		var multi := MultiMesh.new(); multi.transform_format=MultiMesh.TRANSFORM_3D; multi.mesh=mesh(group.kind,group.index,false); multi.instance_count=group.poses.size()
		for i in multi.instance_count: multi.set_instance_transform(i,group.poses[i])
		var node := MultiMeshInstance3D.new(); node.multimesh=multi; node.transparency=group.alpha; node.material_override=source(group.kind).material
		node.set_meta("exemplar_kind",group.kind); node.set_meta("exemplar_variant",group.index); node.set_meta("component_count",multi.instance_count); root.add_child(node)

static func inventory(root: Node) -> Dictionary:
	return inventory_roots([root])

static func inventory_roots(roots: Array) -> Dictionary:
	var geometry: Array=[]
	for root in roots: geometry.append_array(root.find_children("*","GeometryInstance3D",true,false))
	var unique := {}; var nodes := 0; var instances := 0; var materials := {}
	for node in geometry:
		nodes+=1
		if node is MeshInstance3D and node.mesh!=null: unique[node.mesh.get_instance_id()]=true; instances+=1
		elif node is MultiMeshInstance3D and node.multimesh!=null:
			unique[node.multimesh.mesh.get_instance_id()]=true; instances+=node.multimesh.instance_count
			if node.has_meta("exemplar_kind"):
				var kind: String=node.get_meta("exemplar_kind"); materials[kind]=int(materials.get(kind,0))+node.multimesh.instance_count
	return {"render_nodes":nodes,"mesh_resources":unique.size(),"physical_mesh_instances":instances,"stock_components":materials,"cached_detail_meshes":meshes.size()}
