extends RefCounted
## Small seed markers and rooted grass share the world's illustrated palette.
static func seed() -> Node3D:
	var root := Node3D.new()
	root.name = "Seed"
	var earth := MeshInstance3D.new()
	var mound := SphereMesh.new()
	mound.radius = 0.24
	mound.height = 0.12
	earth.mesh = mound
	earth.position.y = 0.035
	var soil := StandardMaterial3D.new()
	soil.albedo_color = Color("a57c53")
	earth.material_override = soil
	root.add_child(earth)
	var green := StandardMaterial3D.new()
	green.albedo_color = Color("6d9753")
	for side in [-1, 1]:
		var leaf := MeshInstance3D.new()
		var shape := SphereMesh.new()
		shape.radius = 0.12
		shape.height = 0.10
		leaf.mesh = shape
		leaf.scale = Vector3(1, 1, 0.55)
		leaf.position = Vector3(side * 0.08, 0.17, 0)
		leaf.rotation.z = side * 0.55
		leaf.material_override = green
		root.add_child(leaf)
	return root

static func grass() -> Node3D:
	var root := Node3D.new()
	root.name = "GrassPatch"
	var plants := Node3D.new()
	plants.name = "Plants"
	root.add_child(plants)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for blade in 5:
		var x := (blade - 2) * 0.07
		for point in [Vector3(x - 0.045, 0, 0), Vector3(x + 0.045, 0, 0), Vector3(x + sin(blade * 2.7) * 0.08, 0.3 + blade % 3 * 0.08, 0)]:
			surface.set_color(Color("50922f"))
			surface.set_uv(Vector2(0, 1 if point.y > 0 else 0))
			surface.add_vertex(point)
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/settlement_grass.gdshader")
	surface.set_material(material)
	var mesh := surface.commit()
	for index in 12:
		var tuft := MeshInstance3D.new()
		tuft.name = "Tuft%d" % index
		tuft.mesh = mesh
		tuft.position = Vector3((index % 4 - 1.5) * 0.22, 0, (floori(index / 4.0) - 1) * 0.26)
		tuft.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		plants.add_child(tuft)
	return root
