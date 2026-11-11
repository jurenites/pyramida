extends SceneTree
const Roof = preload("res://scripts/settlement/house_roofs.gd")
const Planes = preload("res://scripts/settlement/roof_planes.gd")
const Style = preload("res://scripts/settlement/illustration_style.gd")
var failures: Array[String] = []
func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message); printerr("FAIL: " + message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var tiles := {}; var rooms: Array = []
	for at: Vector2 in [Vector2.ZERO, Vector2(2, 0), Vector2(0, 2)]:
		rooms.append({"at": at, "axis": 0 if at.x == 2 else 1})
		for x in 2:
			for z in 2: tiles[Vector2i(at) + Vector2i(x - 1, z - 1)] = true
	var shape := Roof.profile(tiles, rooms)
	var triangles := PackedVector3Array(); var colours := {}; var changed := false
	for tile: Vector2i in tiles:
		var source := Roof.tile_mesh(tile, shape)
		var a := Planes.mesh(source, tile, shape, 17).surface_get_arrays(0)
		var b := Planes.mesh(source, tile, shape, 17).surface_get_arrays(0)
		var c := Planes.mesh(source, tile, shape, 18).surface_get_arrays(0)
		check(a[Mesh.ARRAY_VERTEX] == b[Mesh.ARRAY_VERTEX] and a[Mesh.ARRAY_COLOR] == b[Mesh.ARRAY_COLOR], "Same seed recreates exactly the same roof")
		changed = changed or a[Mesh.ARRAY_VERTEX] != c[Mesh.ARRAY_VERTEX]
		for normal: Vector3 in a[Mesh.ARRAY_NORMAL]: check(normal.y > 0.1, "Roof has slope planes only, without side or bottom faces")
		for colour: Color in a[Mesh.ARRAY_COLOR]: colours[colour] = true
		triangles.append_array(a[Mesh.ARRAY_VERTEX])
	check(changed and colours.size() > 8, "Length, angle and colour vary across generated boards")
	for tile: Vector2i in tiles:
		for offset: Vector2 in [Vector2(0.17, 0.19), Vector2(0.5, 0.5), Vector2(0.82, 0.81)]:
			var at := Vector2(tile) + offset; var covered := false
			for i in range(0, triangles.size(), 3):
				if Geometry3D.ray_intersects_triangle(Vector3(at.x + 0.00001, 5, at.y - 0.00001), Vector3.DOWN, triangles[i], triangles[i + 1], triangles[i + 2]) != null:
					covered = true; break
			check(covered, "Overlaps cover the complete roof including T valleys at %s" % at)
	var low := Planes.variation(17, 2, 1, 0, 0); var high := Planes.variation(17, 2, 1, 0, 1)
	check(high.lift > low.lift + 0.02, "Alternating boards sit above and below their neighbours")
	var paint := StandardMaterial3D.new(); paint.albedo_color = Color("eee2c8")
	var shadow := Style.shadowed(paint)
	check(shadow is ShaderMaterial and shadow.shader == preload("res://shaders/settlement_painted_shadow.gdshader"), "Building paint receives occluder shadows")
	check(Style.shadowed(paint) == shadow, "Building shadow materials are reused")
	var sun := DirectionalLight3D.new(); Style.configure_sun(sun)
	check(sun.shadow_blur > 0 and is_zero_approx(sun.light_angular_distance), "Ground and wall shadows use filtering without noisy contact-hardening samples")
	sun.free()
	print("PASS: thin roof planes, stable variation, alternating overlaps, coverage and shadow materials" if failures.is_empty() else "FAIL: procedural roof planes")
	quit(0 if failures.is_empty() else 1)
