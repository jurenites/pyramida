extends RefCounted
## Closed polygon solids: contour vertices are authored in metres, never cell addresses.
const Palette = preload("res://scripts/game_palette.gd")

static func material(colour: Color) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = colour
	result.roughness = 1.0
	return result

static func triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, area_epsilon := 0.00000001) -> void:
	if (b - a).cross(c - a).length_squared() < area_epsilon: return
	# Outward mathematical winding; Godot renders clockwise exteriors.
	surface.set_normal((b - a).cross(c - a).normalized())
	for point in [a, c, b]: surface.add_vertex(point)

# Contours below are independent authored profiles, ordered around each solid.
# Some shelf edges coincide: the ledge ends there and becomes an uninterrupted
# cliff. Other upper profiles project beyond the supporting neck into an overhang.
static func terraces(seed_value := 1409) -> ArrayMesh:
	var base := [Vector2(12,0), Vector2(12,6), Vector2(9,11), Vector2(2,13), Vector2(-5,12), Vector2(-12,8), Vector2(-14,1), Vector2(-12,-6), Vector2(-6,-10), Vector2(3,-10), Vector2(9,-7), Vector2(11,-3)]
	var bench := [Vector2(11,0), Vector2(10.8,5), Vector2(8.4,9), Vector2(2,12), Vector2(-5,11), Vector2(-11,7), Vector2(-12,1), Vector2(-10,-5), Vector2(-5,-8), Vector2(2,-8), Vector2(8,-6), Vector2(11,-3)]
	var neck := [Vector2(10.5,0), Vector2(8.5,4), Vector2(6,6.5), Vector2(1.5,8), Vector2(-3,7.5), Vector2(-7,5.8), Vector2(-8.8,1), Vector2(-7.9,-4), Vector2(-4,-7), Vector2(2,-8), Vector2(8,-6), Vector2(11,-3)]
	var crown := [Vector2(12,0), Vector2(11,5), Vector2(8,9), Vector2(2,10), Vector2(-3,9), Vector2(-7,6), Vector2(-9,1), Vector2(-8,-4), Vector2(-4,-7), Vector2(2,-8), Vector2(8,-6), Vector2(11,-3)]
	return loft([ring(base,-2), ring(bench,2.0), ring(neck,2.0), ring(neck,4.7), ring(crown,5.15), ring(crown,6.6)], seed_value)

static func ridge(seed_value := 1409) -> ArrayMesh:
	# A narrow, high western mass. Its small front shelf dies into the rear wall.
	var foot := [Vector2(-3,-2),Vector2(-3,2),Vector2(-6,3),Vector2(-10,1),Vector2(-12,-2),Vector2(-11,-6),Vector2(-8,-8),Vector2(-4,-7)]
	var ledge := [Vector2(-4,-2),Vector2(-4,1),Vector2(-6,2),Vector2(-9,0),Vector2(-10.5,-2),Vector2(-10,-5.5),Vector2(-8,-7),Vector2(-4.2,-6)]
	var upper := [Vector2(-4.8,-2.5),Vector2(-5,-0.8),Vector2(-6.7,-0.4),Vector2(-9,-1.8),Vector2(-10.5,-2),Vector2(-10,-5.5),Vector2(-8,-7),Vector2(-4.2,-6)]
	var summit := [Vector2(-5.1,-3),Vector2(-5.3,-1.2),Vector2(-6.8,-0.8),Vector2(-8.8,-2),Vector2(-10,-2.4),Vector2(-9.5,-5.2),Vector2(-7.8,-6.7),Vector2(-4.5,-5.7)]
	var undercut := ledge.duplicate()
	undercut[1] = Vector2(-4.7,-0.3); undercut[2] = Vector2(-6.2,0.7); undercut[3] = Vector2(-9,-0.3)
	return loft([ring(foot,-2),ring(undercut,7.6),ring(ledge,8.0),ring(ledge,8.5),ring(upper,8.5),ring(summit,11.7)], seed_value, 0.24)

static func fin(seed_value := 1409) -> ArrayMesh:
	# A fractured vertical blade, with an inclined broken summit rather than a cap.
	var foot := [Vector2(-1.8,-3.8),Vector2(-1.1,0),Vector2(-2.7,2.6),Vector2(-4.1,1.3),Vector2(-4.6,-2),Vector2(-3.6,-4.3)]
	var shoulder := [Vector2(-2.1,-3),Vector2(-1.8,-0.5),Vector2(-2.8,1.4),Vector2(-3.5,0.7),Vector2(-4,-2),Vector2(-3.4,-3.5)]
	var peak := PackedVector3Array([Vector3(-2.6,14.3,-2.6),Vector3(-2.5,13.0,-0.9),Vector3(-2.9,10.2,0.5),Vector3(-3.2,10.7,0.2),Vector3(-3.5,13.8,-1.9),Vector3(-3.1,14.6,-2.8)])
	return loft([ring(foot,-1.5),ring(shoulder,9.3),peak], seed_value, 0.33)

static func ring(outline: Array, height: float) -> PackedVector3Array:
	var points := PackedVector3Array()
	for point: Vector2 in outline: points.append(Vector3(point.x, height, point.y))
	return points

static func loft(profiles: Array, seed_value: int, shade := 0.16, jitter := 0.12, area_epsilon := 0.00000001) -> ArrayMesh:
	var rng := RandomNumberGenerator.new(); rng.seed = seed_value
	# One small shared displacement per contour vertex keeps adjoining faces
	# welded and never turns a flat terrace into a noisy triangulated heightfield.
	var offsets := PackedVector3Array()
	for index in profiles[0].size(): offsets.append(Vector3(rng.randf_range(-jitter,jitter),0,rng.randf_range(-jitter,jitter)))
	for level in profiles.size():
		for index in profiles[level].size(): profiles[level][index] += offsets[index]
	var top := SurfaceTool.new(); top.begin(Mesh.PRIMITIVE_TRIANGLES)
	var wall := SurfaceTool.new(); wall.begin(Mesh.PRIMITIVE_TRIANGLES)
	var underside := SurfaceTool.new(); underside.begin(Mesh.PRIMITIVE_TRIANGLES)
	var has_underside := false
	for level in range(profiles.size() - 1):
		for index in profiles[level].size():
			var next: int = (index + 1) % profiles[level].size()
			var a: Vector3 = profiles[level][index]; var b: Vector3 = profiles[level + 1][index]
			var c: Vector3 = profiles[level + 1][next]; var d: Vector3 = profiles[level][next]
			for face in [[a,b,c],[a,c,d]]:
				var normal: Vector3 = (face[1] - face[0]).cross(face[2] - face[0]).normalized()
				var surface := top if normal.y > 0.99 else (underside if normal.y < -0.1 else wall)
				if normal.y < -0.1: has_underside = true
				triangle(surface, face[0], face[1], face[2], area_epsilon)
	for level in [0, profiles.size()-1]:
		var outline := PackedVector2Array()
		for point: Vector3 in profiles[level]: outline.append(Vector2(point.x,point.z))
		var triangles := Geometry2D.triangulate_polygon(outline)
		for index in range(0,triangles.size(),3):
			var a: Vector3 = profiles[level][triangles[index]]
			var b: Vector3 = profiles[level][triangles[index+1]]
			var c: Vector3 = profiles[level][triangles[index+2]]
			if level == 0: triangle(wall,a,b,c,area_epsilon)
			else: triangle(top,a,c,b,area_epsilon)
	top.set_material(material(Palette.SAND_SURFACE))
	wall.set_material(material(Palette.LIMESTONE_SIDE.darkened(shade)))
	underside.set_material(material(Palette.LIMESTONE_SIDE.darkened(0.4)))
	top.index(); wall.index()
	var mesh := top.commit(); wall.commit(mesh)
	if has_underside:
		underside.index(); underside.commit(mesh)
	return mesh

