extends RefCounted
## The reviewed Mill: a taller tower with long, narrow white plank blades.
const Frame = preload("res://scripts/settlement/structure_frame.gd")
const Relative = preload("res://scripts/settlement/timber_frame.gd")
const HEIGHT := 5.0

static func plank(parent: Node3D, label: String, a: Vector3, b: Vector3, width := 0.06) -> void:
	var scale_: float = parent.get_meta("blade_scale", 1.0)
	var width_scale: float = parent.get_meta("blade_width_scale", 1.0)
	# Rails run along the blade; slats run across it. Narrow only the local X axis.
	width *= scale_ * (width_scale if absf(b.y - a.y) > absf(b.x - a.x) else 1.0)
	a *= Vector3(scale_ * width_scale, scale_, 1); b *= Vector3(scale_ * width_scale, scale_, 1)
	var length := minf(0.7, a.distance_to(b)); var strip := minf(0.22, width); var direction := (b - a).normalized()
	var basis := Basis(Quaternion(Vector3.UP, direction)); var lap := 0
	for across in Frame.Timber.centres(width, strip):
		for offset in Frame.Timber.centres(a.distance_to(b), length):
			var part := MeshInstance3D.new(); part.name = label
			var box := BoxMesh.new(); box.size = Vector3(strip, length, 0.055); part.mesh = box
			part.basis = basis; part.position = (a + b) / 2 + direction * offset + basis.x * across + Vector3(0, 0, lap * 0.0005)
			lap += 1
			# Assemble additional rigid cuts rather than stretching stock for larger blades.
			part.set_meta("timber_stock", "plank"); part.set_meta("source_asset", "plank")
			part.set_meta("cut_size", Vector3(length, 0.055, strip)); parent.add_child(part)
			if label.begins_with("Slat"): part.set_meta("timber_paint", Color("f5f1e6"))
			Frame.Palette.apply(part, "tree")

static func rotor_model(tower: Node3D, blade_scale: float, blade_width_scale := 1.0) -> Node3D:
	var rotor := Node3D.new(); rotor.name = "Rotor"; tower.add_child(rotor)
	for index in 4:
		var blade := Node3D.new(); blade.name = "Sail%d" % index; blade.rotation.z = index * PI / 2 + PI / 4
		blade.set_meta("blade_scale", blade_scale); rotor.add_child(blade)
		blade.set_meta("blade_width_scale", blade_width_scale)
		plank(blade, "Spine", Vector3(0, 0.10, 0), Vector3(0, 1.44, 0))
		plank(blade, "OuterRail", Vector3(0.52, 0.32, 0), Vector3(0.52, 1.36, 0), 0.045)
		for slat in 6:
			var y := 0.40 + slat * 0.17
			plank(blade, "Slat%d" % slat, Vector3(-0.05, y, 0.045 + slat * 0.001), Vector3(0.55, y, 0.045 + slat * 0.001), 0.20)
	plank(rotor, "Hub", Vector3(-0.13, 0, 0.10), Vector3(0.13, 0, 0.10), 0.22)
	return rotor

static func radius_of(rotor: Node3D) -> float:
	var radius := 0.0
	for part: MeshInstance3D in rotor.find_children("*", "MeshInstance3D", true, false):
		for vertex: Vector3 in part.mesh.get_faces():
			var at := Relative.relative(rotor, part) * vertex
			radius = maxf(radius, Vector2(at.x, at.y).length())
	return radius

static func create() -> Node3D:
	var node := (load("res://data/settlement/windmill.tscn") as PackedScene).instantiate() as Node3D
	node.name = "Mill"; node.set_meta("reviewed_model", true)
	preload("res://scripts/settlement/mill_view.gd").sync(node, 3)
	var tower := node.get_node("WindTower") as Node3D
	tower.get_node("Rotor").free()
	var original_rotor := rotor_model(tower, 1.0)
	var original_radius := radius_of(original_rotor); original_rotor.free()
	var rotor := rotor_model(tower, 2.0, 0.5); var radius := radius_of(rotor)
	assert(radius <= 3.0)
	# Preserve the approved tower and axle height independently of blade width.
	var hub_y := 5.0 - original_radius; var rise := hub_y - 3.04
	rotor.position = Vector3(0, hub_y, 1.05)
	for child: Node3D in tower.get_children():
		if child == rotor: continue
		if str(child.name).begins_with("Post") or child.name in ["CentralShaft", "RotorAxle"]: child.free()
		else: child.position.y += rise
	# Keep the gearbox underneath the pitched covering; the old tall box
	# intersected the slope and appeared as a dark bar through the roof.
	var housing := tower.get_node("GearHousing") as MeshInstance3D
	var housing_mesh := BoxMesh.new(); housing_mesh.size = Vector3(1.24, 0.42, 1.20)
	housing.mesh = housing_mesh; housing.position.y = 2.52 + rise
	var index := 0
	for x in [-0.72, 0.72]:
		for z in [-0.64, 0.64]:
			Frame.log_member(tower, "Post%d" % index, Vector3(x, 0, z), Vector3(x * 0.88, 2.72 + rise, z * 0.88)); index += 1
	Frame.log_member(tower, "CentralShaft", Vector3(0, 0.42, 0), Vector3(0, hub_y, 0))
	plank(tower, "RotorAxle", Vector3(0, hub_y, 0.45), Vector3(0, hub_y, 1.05), 0.12)
	# The optional roof frame makes upper buildings visibly bear on the tower.
	# It follows the five-metre roof socket, independently of the rotor sweep.
	var support := node.get_node("StackSupport") as Node3D
	for child in support.get_children(): child.free()
	for x in [-0.72, 0.72]:
		for z in [-0.64, 0.64]:
			var foot := Vector3(x * 0.88, 2.72 + rise, z * 0.88)
			Frame.log_member(support, "RoofPost", foot, Vector3(foot.x, HEIGHT - 0.12, foot.z))
	for z in [-0.64 * 0.88, 0.64 * 0.88]:
		Frame.log_member(support, "RoofBeam", Vector3(-1.42, HEIGHT - 0.14, z), Vector3(1.42, HEIGHT - 0.14, z))
	for x in [-1, 0, 1]:
		for z in [-1, 0, 1]:
			var tile := Node3D.new(); tile.name = "RoofDeck"; support.add_child(tile)
			tile.position = Vector3(x, HEIGHT - 1, z)
			Frame.deck(tile, hash(Vector2i(x, z)))
	support.visible = false
	node.get_node("RoofSocket").position.y = HEIGHT
	node.set_meta("rotor_radius", radius)
	node.set_meta("reference_rotor_radius", original_radius)
	return node
