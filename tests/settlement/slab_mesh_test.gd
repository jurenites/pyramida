extends SceneTree
const Stone = preload("res://scripts/settlement/stone_view.gd")
const Assets = preload("res://scripts/settlement/asset_library.gd")
var failures := 0
var checks := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + message)

func check_mesh(mesh: Mesh, label: String) -> void:
	var centre := mesh.get_aabb().get_center()
	for surface in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var count := vertices.size() if indices.is_empty() else indices.size()
		check(count == 36, label + " retains all six solid faces")
		for offset in range(0, count, 3):
			var a := offset if indices.is_empty() else indices[offset]
			var b := offset + 1 if indices.is_empty() else indices[offset + 1]
			var c := offset + 2 if indices.is_empty() else indices[offset + 2]
			var outside := (vertices[a] + vertices[b] + vertices[c]) / 3.0 - centre
			check((vertices[b] - vertices[a]).cross(vertices[c] - vertices[a]).dot(outside) < 0.0, label + " front face points outside")
			check(normals[a].dot(outside) > 0.0, label + " shading normal points outside")

func _initialize() -> void:
	for seed_value in [23, 1409, 8903]:
		check_mesh(Stone.block_mesh(seed_value), "Generated slab %d" % seed_value)
	var slab := Assets.create("block")
	var visual := slab.get_node("Stone") as MeshInstance3D
	check_mesh(visual.mesh, "Game slab")
	var material := visual.get_active_material(0) as StandardMaterial3D
	check(material != null and material.cull_mode == BaseMaterial3D.CULL_BACK and material.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED, "Game slab remains opaque with back-face culling")
	slab.free()
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var error := document.append_from_file("res://data/settlement/block.glb", state)
	check(error == OK, "Editable slab GLB loads")
	if error == OK:
		var exported := document.generate_scene(state)
		var meshes := exported.find_children("*", "MeshInstance3D", true, false)
		check(meshes.size() == 1, "Editable slab contains one mesh")
		for mesh: MeshInstance3D in meshes: check_mesh(mesh.mesh, "Exported slab")
		exported.free()
	if failures == 0: print("PASS: %d slab geometry, material and export checks" % checks)
	quit(int(failures > 0))
