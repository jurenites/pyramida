extends RefCounted
## Automatic safety edging cut from the shared timber stock, regenerated with the deck.
const Timber = preload("res://scripts/settlement/timber_kit.gd")
const Wood = preload("res://scripts/settlement/timber_palette.gd")
const WIDTH := 0.065
const HEIGHT := 0.68
const SPACING := 0.85
const MAX_ANGLE := 5.0
# Includes panel yaw, offset and the physical half-width of the wood.
const CLEARANCE := 0.105
static var meshes: Dictionary = {}

static func triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	for point in [a, b, c]: surface.add_vertex(point)

static func cut_stock(length: float) -> ArrayMesh:
	var key := roundi(length * 10000)
	if meshes.has(key): return meshes[key]
	var side := SurfaceTool.new(); side.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ends := SurfaceTool.new(); ends.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half := WIDTH / 2.0
	var corner := half * 0.65
	var profile := [Vector2(-corner, -half), Vector2(corner, -half), Vector2(half, -corner), Vector2(half, corner), Vector2(corner, half), Vector2(-corner, half), Vector2(-half, corner), Vector2(-half, -corner)]
	for i in profile.size():
		var p: Vector2 = profile[i]; var q: Vector2 = profile[(i + 1) % profile.size()]
		var a := Vector3(-length / 2, p.x, p.y); var b := Vector3(length / 2, p.x, p.y)
		var c := Vector3(length / 2, q.x, q.y); var d := Vector3(-length / 2, q.x, q.y)
		triangle(side, a, b, c); triangle(side, a, c, d)
		triangle(ends, Vector3.LEFT * length / 2, a, d)
		triangle(ends, Vector3.RIGHT * length / 2, c, b)
	side.generate_normals(); ends.generate_normals()
	side.set_material(Wood.material("tree", "log", 0))
	ends.set_material(Wood.material("tree", "log", 1))
	var mesh := side.commit(); ends.commit(mesh)
	meshes[key] = mesh
	return mesh

static func member(root: Node3D, label: String, a: Vector3, b: Vector3) -> void:
	var part := MeshInstance3D.new(); part.name = label
	part.mesh = cut_stock(a.distance_to(b))
	part.basis = Basis(Quaternion(Vector3.RIGHT, (b - a).normalized()))
	part.position = (a + b) / 2
	part.set_meta("timber_stock", "log")
	part.set_meta("timber_cut_profile", "quartered")
	root.add_child(part)

static func parts(a: Vector3, b: Vector3, seed_: int = 0) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var length := a.distance_to(b)
	if length < WIDTH * 2: return result
	var direction := (b - a) / length
	var across := direction.cross(Vector3.UP).normalized()
	var count := maxi(1, ceili(length / SPACING))
	var rng := RandomNumberGenerator.new(); rng.seed = hash([seed_, a, b])
	# Independent short panels follow one overall edge, rather than drifting apart.
	for i in count:
		var center := length * (i + 0.5) / count
		var span := length / count
		var angle := deg_to_rad(rng.randf_range(-MAX_ANGLE, MAX_ANGLE))
		var shift := rng.randf_range(-0.018, 0.018)
		var lean := rng.randf_range(-0.018, 0.018)
		var height := HEIGHT + rng.randf_range(-0.025, 0.025)
		# Some rails overlap at their ends; others have a narrow visible joint gap.
		var reach := span / 2 + rng.randf_range(-0.045, 0.025)
		var post_reach := maxf(WIDTH / 2, minf(span / 2 - 0.08, reach - 0.055))
		var diagonal := span > 0.45 and rng.randf() < 0.18
		var rise := rng.randf_range(-0.018, 0.018)
		var point := func(x: float, y: float) -> Vector3:
			# End stock never protrudes into a gate. Posts also remain inside the run.
			var along := clampf(center + x * cos(angle) + lean * y, WIDTH, length - WIDTH)
			return a + direction * along + across * (shift + (along - center) * tan(angle)) + Vector3.UP * (y + rise * x)
		for side in [-1, 1]:
			result.append({"name":"TerraceFencePost", "a":point.call(side * post_reach, 0)-Vector3.UP*0.025, "b":point.call(side * post_reach, height)})
		result.append({"name":"TerraceFenceTop", "a":point.call(-reach, height - 0.10), "b":point.call(reach, height - 0.10)})
		# A displaced lower member gives occasional N-shaped wear. The top stays intact.
		result.append({"name":"TerraceFenceDiagonal" if diagonal else "TerraceFenceBottom", "a":point.call(-reach, 0.12), "b":point.call(reach, height - 0.14 if diagonal else 0.12)})
	# Some neighbouring panels share a real post; others keep their separate ends.
	for i in range(1, count):
		if rng.randf() > 0.5: continue
		var left: Dictionary = result[(i - 1) * 4 + 1]
		var right: Dictionary = result[i * 4]
		var foot: Vector3 = (left.a + right.a) / 2
		var head: Vector3 = (left.b + right.b) / 2
		left.a = foot; left.b = head; right.name = ""
		for index in [2, 3]:
			var previous: Dictionary = result[(i - 1) * 4 + index]
			var next: Dictionary = result[i * 4 + index]
			previous.b = Vector3(head.x, previous.b.y, head.z) + direction * WIDTH * 0.4
			next.a = Vector3(head.x, next.a.y, head.z) - direction * WIDTH * 0.4
	return result.filter(func(part): return not part.name.is_empty())

static func build(root: Node3D, a: Vector3, b: Vector3, seed_: int = 0) -> void:
	for part in parts(a, b, seed_): member(root, part.name, part.a, part.b)
