extends RefCounted
const Bridges = preload("res://scripts/settlement/rope_bridges.gd")
const TimberPalette = preload("res://scripts/settlement/timber_palette.gd")
const Illustration = preload("res://scripts/settlement/illustration_style.gd")
const Palette = preload("res://scripts/game_palette.gd")
const WOOD := TimberPalette.BARK[0]
const PLANK := TimberPalette.WOOD[0]
const ROPE := Color("d8ba7c")

static func material(color: Color) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 1.0
	return result

static func box(parent: Node3D, size: Vector3, at: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new(); mesh.size = size
	var node := MeshInstance3D.new(); node.mesh = mesh; node.material_override = material(color)
	node.position = at; parent.add_child(node)
	return node

static func beam(parent: Node3D, a: Vector3, b: Vector3, radius: float, color: Color) -> void:
	if a.distance_to(b) < 0.001: return
	var mesh := CylinderMesh.new(); mesh.top_radius = radius; mesh.bottom_radius = radius
	mesh.height = a.distance_to(b); mesh.radial_segments = 6
	var node := MeshInstance3D.new(); node.mesh = mesh; node.material_override = material(color)
	parent.add_child(node); node.position = (a + b) * 0.5
	var up := (b - a).normalized()
	var right := up.cross(Vector3.FORWARD if absf(up.z) < 0.9 else Vector3.RIGHT).normalized()
	node.basis = Basis(right, up, right.cross(up))

static func coil() -> Node3D:
	var result := Node3D.new()
	for i in 3:
		var mesh := TorusMesh.new(); mesh.inner_radius = 0.12; mesh.outer_radius = 0.23; mesh.rings = 16; mesh.ring_segments = 6
		var node := MeshInstance3D.new(); node.mesh = mesh; node.material_override = material(ROPE)
		node.position.y = 0.05 + i * 0.055; result.add_child(node)
	Illustration.apply(result, false, true)
	return result

static func maker() -> Node3D:
	var result := Node3D.new()
	for x in [-0.85, 0.85]:
		for z in [-1.25, 1.25]: beam(result, Vector3(x, 0, z), Vector3(x, 1.8, z), 0.085, WOOD)
	for side in [-1, 1]:
		var roof := box(result, Vector3(1.12, 0.09, 2.85), Vector3(side * 0.5, 1.95, 0), PLANK)
		roof.rotation.z = -side * 0.32
	box(result, Vector3(0.7, 0.10, 2.1), Vector3(0, 0.75, 0), PLANK)
	for z in [-0.9, 0.9]:
		beam(result, Vector3(0, 0, z), Vector3(0, 1.2, z), 0.07, WOOD)
		beam(result, Vector3(-0.3, 1.1, z), Vector3(0.3, 1.1, z), 0.055, WOOD)
	for x in [-0.2, 0.0, 0.2]: beam(result, Vector3(x, 1.1, -0.9), Vector3(x, 1.1, 0.9), 0.025, ROPE)
	var spindle := Node3D.new(); spindle.name = "Spindle"; spindle.position = Vector3(0, 1.1, 0.95); result.add_child(spindle)
	beam(spindle, Vector3(-0.27, 0, 0), Vector3(0.27, 0, 0), 0.04, WOOD)
	var output := coil(); output.position = Vector3(0.57, 0.1, 0.95); result.add_child(output)
	for i in 5: box(result, Vector3(0.11, 0.13, 0.7), Vector3(-0.62 + i * 0.08, 0.12, -0.9), Palette.HAY_FIELD)
	Illustration.apply(result, false, true)
	return result

static func gate(at: Vector3, towards: Vector3, color := PLANK) -> Node3D:
	var node := Node3D.new()
	node.name = "Landing"
	node.position = at
	var forward := Vector3(towards.x - at.x, 0, towards.z - at.z).normalized()
	if forward.length_squared() < 0.01: forward = Vector3.FORWARD
	node.basis = Basis(forward.cross(Vector3.UP), Vector3.UP, -forward)
	for side in [-1, 1]:
		var foot := Vector3(side * 0.57, 0, 0)
		beam(node, foot - Vector3.UP * 0.15, foot + Vector3.UP * 1.25, 0.09, color)
		# Short inward ties make the facing of an unattached pair legible.
		beam(node, foot + Vector3.UP, foot + Vector3.UP + Vector3.FORWARD * 0.25, 0.035, ROPE)
	Illustration.apply(node, false, true)
	return node

static func bridge(record: Dictionary, progress := 1.0) -> Node3D:
	var result := Node3D.new()
	var points := Bridges.curve(record)
	var across: Vector3 = (record.end - record.start).cross(Vector3.UP).normalized()
	result.add_child(gate(record.start, record.end))
	result.add_child(gate(record.end, record.start))
	for i in range(1, points.size()):
		var a: Vector3 = points[i - 1]; var b: Vector3 = points[i]
		var board := box(result, Vector3(Bridges.WIDTH, 0.065, a.distance_to(b) * 0.91), (a + b) * 0.5 - Vector3.UP * 0.033, PLANK)
		var forward := (b - a).normalized()
		board.basis = Basis(across, forward.cross(across), forward)
		if float(i) / (points.size() - 1) > progress: board.transparency = 0.82
		for sign_ in [-1, 1]:
			var offset: Vector3 = across * sign_ * 0.48
			beam(result, a + offset + Vector3.UP, b + offset + Vector3.UP, 0.027, ROPE)
			beam(result, a + offset, b + offset, 0.035, ROPE)
			if i % 3 == 0: beam(result, b + offset, b + offset + Vector3.UP, 0.021, ROPE)
	Illustration.apply(result, false, true)
	return result

static func sync(parent: Node3D, world) -> void:
	for child in parent.get_children(): child.free()
	for id: int in world.bridges:
		var node := bridge(world.bridges[id]); parent.add_child(node)
		add_picking(node, world.bridges[id], id, false)
	for plan: Dictionary in world.plans.values():
		if plan.kind == "rope_bridge":
			var node := bridge(plan.bridge, float(plan.installed) / maxi(1, plan.required)); parent.add_child(node)
			add_picking(node, plan.bridge, plan.id, true)

static func roof_landing(node: Node3D, world, cell: Vector3i) -> void:
	var kind: String = world.buildings.get(cell, {}).get("kind", "")
	var attached: bool = not node.get_meta("planned", false) and Bridges.supports_bridge(world, cell, kind)
	var terrace := node.get_node_or_null("BridgeLandingDeck") as Node3D
	if terrace != null:
		terrace.visible = attached
		return
	if not attached: return
	terrace = Node3D.new(); terrace.name = "BridgeLandingDeck"
	terrace.set_meta("variation_exempt", true); node.add_child(terrace)
	var rect: Rect2 = world.Farming.footprint(kind, Vector3i.ZERO)
	var boards := maxi(1, ceili(rect.size.y / 0.22))
	var depth: float = rect.size.y / boards
	for i in boards:
		box(terrace, Vector3(rect.size.x,0.1,depth-0.008), Vector3(0,world.Catalog.building_height(kind)-0.05,rect.position.y+(i+0.5)*depth), PLANK)
	Illustration.apply(terrace,false,true)

static func add_picking(node: Node3D, record: Dictionary, id: int, planned: bool) -> void:
	node.set_meta("bridge_id", id)
	var points := Bridges.curve(record)
	for endpoint in 2:
		var point: Vector3 = record.start if endpoint == 0 else record.end
		var body := StaticBody3D.new(); body.collision_layer = 4; body.collision_mask = 0; node.add_child(body)
		body.position = point + Vector3.UP * 0.6
		body.rotation.y = atan2(record.end.x - record.start.x, record.end.z - record.start.z)
		var shape := CollisionShape3D.new(); shape.shape = BoxShape3D.new(); shape.shape.size = Vector3(1.4, 1.5, 0.35); body.add_child(shape)
		body.set_meta("bridge_id", id); body.set_meta("endpoint", endpoint); body.set_meta("planned", planned)
	var deck_body := StaticBody3D.new(); deck_body.collision_layer = 4; deck_body.collision_mask = 0; node.add_child(deck_body)
	deck_body.set_meta("bridge_id", id); deck_body.set_meta("endpoint", -1); deck_body.set_meta("planned", planned)
	for i in range(1, points.size()):
		var shape := CollisionShape3D.new(); shape.shape = BoxShape3D.new()
		shape.shape.size = Vector3(Bridges.WIDTH, 0.12, points[i - 1].distance_to(points[i]) + 0.02)
		shape.position = (points[i - 1] + points[i]) * 0.5
		var direction: Vector3 = (points[i] - points[i - 1]).normalized()
		shape.basis = Basis.looking_at(-direction)
		deck_body.add_child(shape)
