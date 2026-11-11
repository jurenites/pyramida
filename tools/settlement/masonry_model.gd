extends RefCounted
const Frame = preload("res://scripts/settlement/structure_frame.gd")
const Depot = preload("res://scripts/settlement/stone_storage_view.gd")

static func populate(node: Node3D) -> void:
	var floor_ := node.get_node("Floor") as MeshInstance3D
	floor_.mesh = Depot.pad_mesh(); floor_.scale = Vector3(0.56, 1.5, 0.56); floor_.position.y = Depot.PAD_HEIGHT * 0.75
	floor_.material_override = Depot.Stone.material(); floor_.set_meta("keep_lighting", true)
	var frame := Node3D.new(); frame.name = "ShadeFrame"; frame.set_meta("variation_exempt", true); node.add_child(frame)
	for z in [-1.2, 1.2]:
		for x in [-1.25, 1.25]: Frame.log_member(frame, "Upright", Vector3(x, 0, z), Vector3(x, 1.9, z))
		Frame.log_member(frame, "Crossbar", Vector3(-1.35, 1.88, z), Vector3(1.35, 1.88, z))
	# Two open pi-shaped frames carry a low-poly cloth, with a slack centre.
	var cloth := MeshInstance3D.new(); cloth.name = "ClothShade"; cloth.set_meta("variation_exempt", true); node.add_child(cloth)
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z in 6:
		for x in 4:
			var points: Array[Vector3] = []
			for q in [Vector2(x, z), Vector2(x + 1, z), Vector2(x + 1, z + 1), Vector2(x, z + 1)]:
				var px: float = q.x / 4.0; var pz: float = q.y / 6.0
				points.append(Vector3(lerpf(-1.36, 1.36, px), 2.15 - 0.22 * sin(clampf((lerpf(-1.38, 1.38, pz) + 1.2) / 2.4, 0, 1) * PI) + 0.025 * sin(px * TAU + pz * 4), lerpf(-1.38, 1.38, pz)))
			for index in [0, 1, 2, 0, 2, 3]: st.add_vertex(points[index])
	st.generate_normals(); cloth.mesh = st.commit()
	var material := StandardMaterial3D.new(); material.albedo_color = Color("faf4e5"); material.cull_mode = BaseMaterial3D.CULL_DISABLED; material.roughness = 1
	cloth.material_override = preload("res://scripts/settlement/illustration_style.gd").flat(material); cloth.set_meta("keep_lighting", true); cloth.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
	var bench := MeshInstance3D.new(); bench.name = "Workbench"; node.add_child(bench)
	var box := BoxMesh.new(); box.size = Vector3(1.18, 0.58, 0.82); bench.mesh = box; bench.position.y = 0.53
	var stone := StandardMaterial3D.new(); stone.albedo_color = Color("c5ad8e"); bench.material_override = stone
	var work := MeshInstance3D.new(); work.name = "WorkStone"; work.mesh = Depot.Stone.raw_mesh(48); work.material_override = Depot.Stone.material(); work.scale = Vector3.ONE * 0.54; work.position = Vector3(0.16, 0.92, 0); node.add_child(work)
	var slab := MeshInstance3D.new(); slab.name = "CutSlab"; slab.mesh = Depot.Stone.block_mesh(23); slab.material_override = Depot.Stone.material(); slab.scale = Vector3(0.45, 0.25, 0.4); slab.position = Vector3(-0.35, 0.89, 0.1); node.add_child(slab)
