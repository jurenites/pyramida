extends RefCounted
const Stone = preload("res://scripts/settlement/stone_view.gd")
const Frame = preload("res://scripts/settlement/structure_frame.gd")
const Terrain = preload("res://scripts/settlement/terrain_mesh.gd")

static func triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, colour: Color) -> void:
	if (b - a).cross(c - a).y < 0: Terrain.triangle(st, a, c, b, colour)
	else: Terrain.triangle(st, a, b, c, colour)

static func part(root: Node3D, label: String, mesh: Mesh) -> MeshInstance3D:
	var node := MeshInstance3D.new(); node.name = label; node.mesh = mesh; node.material_override = Stone.material(); node.set_meta("keep_lighting", true); node.set_meta("variation_exempt", true); root.add_child(node)
	return node

static func populate(root: Node3D) -> void:
	root.get_node("Floor").free()
	var rng := RandomNumberGenerator.new(); rng.seed = 4107
	var outer: Array[Vector3] = []; var crest: Array[Vector3] = []; var inner: Array[Vector3] = []
	for i in 14:
		var angle := TAU * i / 14.0
		var radius := rng.randf_range(0.94, 1.04)
		var p := Vector3(cos(angle) * 1.38 * radius, 0.012, sin(angle) * 1.23 * radius)
		outer.append(p)
		var rim := p * 0.83; rim.y = rng.randf_range(0.19, 0.29)
		# The front bank is low enough to work at the water's edge.
		if p.z > 0.8: rim.y *= 0.6
		crest.append(rim)
		var bed := p * rng.randf_range(0.57, 0.64); bed.y = 0.035; inner.append(bed)
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 14:
		var j := (i + 1) % 14
		var dry := Color("d9b08a").lightened(rng.randf_range(-0.035, 0.025))
		var wet := Color("ad8066").lightened(rng.randf_range(-0.025, 0.025))
		triangle(st, outer[i], outer[j], crest[j], dry); triangle(st, outer[i], crest[j], crest[i], dry)
		triangle(st, crest[i], crest[j], inner[j], wet); triangle(st, crest[i], inner[j], inner[i], wet)
		triangle(st, Vector3(0, 0.035, 0), inner[i], inner[j], Color("9b715b"))
	part(root, "ClayBank", st.commit())
	var water := SurfaceTool.new(); water.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 14:
		var a := inner[i] * 1.12; var b := inner[(i + 1) % 14] * 1.12; a.y = 0; b.y = 0
		triangle(water, Vector3.ZERO, a, b, Color("b58b69"))
	var surface := part(root, "Water", water.commit()); surface.position.y = 0.095; surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Low sandstone edging follows the earthen bank, never a tall enclosure.
	for i in [0, 2, 5, 7, 9, 12]:
		var block := part(root, "BorderStone%d" % i, Stone.raw_mesh(730 + i))
		block.scale = Vector3(rng.randf_range(0.34, 0.47), rng.randf_range(0.23, 0.32), 0.38)
		block.position = outer[i] * 0.86; block.position.y = crest[i].y * 0.35
		block.rotation.y = TAU * i / 14.0 + PI / 2 + rng.randf_range(-0.15, 0.15)
	var timber := Node3D.new(); timber.name = "BankTimber"; timber.set_meta("variation_exempt", true); root.add_child(timber)
	Frame.stock(timber, "Edging", "log", [Transform3D(Basis(Vector3.UP, -0.12), Vector3(-0.45, 0.20, -1.02)), Transform3D(Basis(Vector3.UP, 0.09), Vector3(0.44, 0.20, -1.02))])
	for i in 3:
		var clay := part(root, "ClayLump%d" % i, Stone.raw_mesh(980 + i)); clay.scale = Vector3(0.24, 0.18, 0.28); clay.position = Vector3(0.72 + i * 0.15, 0.035 + (0.1 if i == 1 else 0), 0.67 - i * 0.07); clay.rotation.y = i * 0.8
		var paint := StandardMaterial3D.new(); paint.albedo_color = Color("bd8666"); clay.material_override = preload("res://scripts/settlement/illustration_style.gd").shadowed(paint)
