extends RefCounted
## Curved coopered staves use exactly the same material as plank stock.
const Wood=preload("res://scripts/settlement/timber_palette.gd")
const Illustration=preload("res://scripts/settlement/illustration_style.gd")
const PROFILE=[Vector2(0.0,0.265),Vector2(0.08,0.28),Vector2(0.20,0.315),Vector2(0.35,0.33),Vector2(0.50,0.315),Vector2(0.62,0.28),Vector2(0.70,0.265)]
static func radius_at(height: float) -> float:
	for i in range(1,PROFILE.size()):
		if height<=PROFILE[i].x: return lerpf(PROFILE[i-1].y,PROFILE[i].y,inverse_lerp(PROFILE[i-1].x,PROFILE[i].x,height))
	return PROFILE.back().y
static func build(parent: Node3D,ghost := false) -> void:
	for stave in 16:
		var surface:=SurfaceTool.new(); surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		var a: float=stave*TAU/16+0.004; var b: float=(stave+1)*TAU/16-0.004
		for i in range(1,PROFILE.size()):
			var points: Array=[]
			for layer in [0.0,0.035]:
				for ring in [PROFILE[i-1],PROFILE[i]]:
					for angle in [a,b]: points.append(Vector3(cos(angle)*(ring.y-layer),ring.x,sin(angle)*(ring.y-layer)))
			for face in [[0,1,3,2],[4,6,7,5],[0,2,6,4],[1,5,7,3]]:
				for index in [face[0],face[1],face[2],face[0],face[2],face[3]]: surface.add_vertex(points[index])
			if i==1:
				for index in [0,4,5,0,5,1]: surface.add_vertex(points[index])
			if i==PROFILE.size()-1:
				for index in [2,3,7,2,7,6]: surface.add_vertex(points[index])
		surface.generate_normals()
		var node:=MeshInstance3D.new(); node.name="PlankStave%d" % stave; node.mesh=surface.commit()
		var material: StandardMaterial3D=Wood.material("tree","plank",stave%3)
		# Keep the plank hue readable under an eave, matching illustrated timber.
		material=material.duplicate(); material.cull_mode=BaseMaterial3D.CULL_DISABLED
		if ghost: material.albedo_color=Color("89c6c4")
		node.set_meta("timber_stock","plank"); node.material_override=Illustration.shadowed(material,true); parent.add_child(node)
	var bottom:=MeshInstance3D.new(); var disk:=CylinderMesh.new(); disk.top_radius=0.25; disk.bottom_radius=0.25; disk.height=0.04; disk.radial_segments=32
	bottom.name="PlankBottom"; bottom.mesh=disk; bottom.position.y=0.035; bottom.material_override=Illustration.shadowed(Wood.material("tree","plank",0),true); parent.add_child(bottom)
	for height in [0.09,0.23,0.53,0.63]:
		var ring:=MeshInstance3D.new(); var torus:=TorusMesh.new(); var radius:=radius_at(height)
		torus.inner_radius=radius-0.006; torus.outer_radius=radius+0.018; torus.rings=32; torus.ring_segments=6
		ring.name="BarrelHoop"; ring.mesh=torus; ring.position.y=height; ring.scale.y=1.6
		var material:=StandardMaterial3D.new(); material.albedo_color=Color("62574b"); material.roughness=0.82; ring.material_override=material; parent.add_child(ring)
