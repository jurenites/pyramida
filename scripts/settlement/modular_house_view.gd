extends RefCounted
## Geometry consumes the same spatial records used by the prototype checks.
const Rules = preload("res://scripts/settlement/modular_house_rules.gd")
const Draw = preload("res://scripts/settlement/rope_visuals.gd")
const Frame = preload("res://scripts/settlement/structure_frame.gd")
const Timber = preload("res://scripts/settlement/timber_kit.gd")
const Wood = preload("res://scripts/settlement/timber_palette.gd")
const P = preload("res://scripts/game_palette.gd")
const Generator = preload("res://scripts/settlement/modular_house_generator.gd")
const Exemplars = preload("res://scripts/settlement/material_exemplars.gd")
const Resources = preload("res://scripts/settlement/resource_palette.gd")
const Railing = preload("res://scripts/settlement/terrace_railing.gd")

static func box(root: Node3D, size: Vector3, at: Vector3, color: Color) -> MeshInstance3D:
	return Draw.box(root, size, at, color)

static func deck(root: Node3D, rect: Rect2, height: float, hole := AABB()) -> void:
	if not _detail(root):
		box(root, Vector3(rect.size.x, Timber.BOARD.y, rect.size.y), Vector3(rect.get_center().x, height - Timber.BOARD.y * 0.5, rect.get_center().y), Wood.WOOD[0]); return
	preload("res://scripts/settlement/walkable_planks.gd").build(root,rect,height,int(_exemplars(root).seed),hole)

static func wall(root: Node3D, spec: Dictionary, color: Color, short := false) -> void:
	var node := Node3D.new(); root.add_child(node); node.position = spec.center - root.position; node.rotation.y = spec.yaw
	var opening: String = spec.opening
	var low: float = spec.offset - spec.width / 2
	var high: float = spec.offset + spec.width / 2
	var height: float = 0.4 if short else spec.get("height",1.85)
	var length_: float = spec.get("length",2.0)
	if opening.is_empty() or (short and opening != "door"):
		box(node, Vector3(length_, height, 0.10), Vector3(0, height / 2 + 0.035, 0), color)
		return
	for span in [Vector2(-length_/2, low), Vector2(high, length_/2)]:
		box(node, Vector3(span.y - span.x, height, 0.10), Vector3((span.x + span.y) / 2, height / 2 + 0.035, 0), color)
	if not short: box(node, Vector3(spec.width, 0.3, 0.10), Vector3(spec.offset, 1.8, 0), color)
	if opening == "window":
		box(node, Vector3(spec.width, 0.85, 0.10), Vector3(spec.offset, 0.46, 0), color)
		box(node, Vector3(spec.width + 0.17, 0.08, 0.24), Vector3(spec.offset, 0.89, 0.02), Wood.WOOD[0])
		# An open aperture with an outer frame and sill, no glass or inner bars.
	for edge in [low, high]: box(node, Vector3(0.06, 1.63 if opening == "door" else 0.8, 0.16), Vector3(edge, 0.83 if opening == "door" else 1.25, 0), Wood.BARK[0])
	box(node, Vector3(spec.width + 0.16, 0.09, 0.17), Vector3(spec.offset, 1.65, 0), Wood.BARK[0])
	if opening == "door": box(node, Vector3(spec.width, 0.045, 0.3), Vector3(spec.offset, 0.025, 0), Wood.WOOD[0])

static func room(root: Node3D, plan: Dictionary, section: int, tier: int, utilities := true) -> void:
	var record: Dictionary = plan.record
	var node := Node3D.new(); node.name = "Room%d" % record.id; root.add_child(node); node.position = record.origin
	var color: Color = plan.color
	var cut := section == (1 if record.origin.y == 0 else 2)
	deck(node, Rect2(0, 0, 2, 2), float(plan.get("floor_height",0.0)), AABB(Generator.SHAFT.position - record.origin, Generator.SHAFT.size) if tier == 0 and record.origin.y == 2 else AABB())
	# The generator resolves openings against structural envelopes before rendering.
	for spec in plan.walls:
		wall(node, spec, color, cut and (spec.side in [0, 3] or (record.id == 0 and spec.side == 1)))

	for x in [0.06, 1.94]:
		for z in [0.06, 1.94]:
			if plan.get("omit_west_posts", false) and x < 1: continue
			Frame.log_member(node, "Post", Vector3(x, 0, z), Vector3(x, 0.44 if cut and z > 1 else 1.96, z))
	if not cut:
		for z in [0.06, 1.94]: Frame.log_member(node, "Bearing", Vector3(0.06, 1.9, z), Vector3(1.94, 1.9, z))
	if record.origin.y == 2 and not cut: roof(node, plan, tier)
	if record.id == 0 and utilities:
		if tier == 0: brick_stack(node, Vector3(1.35, 0, 0.35), 4, "stove")
		else: box(node, Vector3(0.48, 0.6, 0.48), Vector3(1.35, 0.38, 0.35), P.TOOL_METAL)
		box(node, Vector3(0.29, 0.24, 0.025), Vector3(1.35, 0.38, 0.71), P.TOOL_METAL)

static func roof(root: Node3D, plan: Dictionary, tier: int) -> void:
	var slope: float = plan.roof_slope
	var extra: float = plan.roof_overhang
	var shaft_x: float = plan.get("shaft",Vector3(-0.65,0,-0.65)-root.position).x
	var shaft_z: float = plan.get("shaft",Vector3(-0.65,0,-0.65)-root.position).z
	var has_shaft: bool = (tier == 0 or plan.has("shaft")) and shaft_x >= 0 and shaft_x <= 2 and shaft_z >= 0 and shaft_z <= 2
	# Close the wedge above the rectangular wall so interior light only leaves
	# through the authored openings, not through a gap beneath the roof.
	for z in [0.0, 2.0]:
		var vertices := [Vector3(0, 1.84, z - 0.05), Vector3(2, 1.84, z - 0.05), Vector3(2, 2.11 + slope, z - 0.05), Vector3(0, 2.11 - slope, z - 0.05), Vector3(0, 1.84, z + 0.05), Vector3(2, 1.84, z + 0.05), Vector3(2, 2.11 + slope, z + 0.05), Vector3(0, 2.11 - slope, z + 0.05)]
		var surface := SurfaceTool.new(); surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for index in [0, 2, 1, 0, 3, 2, 4, 5, 6, 4, 6, 7, 0, 4, 7, 0, 7, 3, 1, 2, 6, 1, 6, 5, 3, 7, 6, 3, 6, 2]: surface.add_vertex(vertices[index])
		surface.generate_normals()
		var infill := MeshInstance3D.new(); infill.mesh = surface.commit(); infill.material_override = Draw.material(plan.color); root.add_child(infill)
	for x in [0.0, 2.0]:
		var top: float = 2.11 + slope * (x - 1)
		box(root, Vector3(0.1, top - 1.84, 2), Vector3(x, (top + 1.84) / 2, 1), plan.color)
	var width := (2 + extra * 2) / 9
	for i in (0 if plan.get("covering", "plank") in ["hay","imbrex"] else 9):
		var x := -extra + (i + 0.5) * width
		var spans := [Vector2(-extra, 2 + extra)]
		if has_shaft and absf(x - shaft_x) < 0.38 + width / 2:
			spans = [Vector2(-extra, shaft_z - 0.38), Vector2(shaft_z + 0.38, 2 + extra)]
		for span in spans:
			if span.y <= span.x: continue
			var sheet := box(root, Vector3(width + 0.01, 0.08, span.y - span.x), Vector3(x, 2.15 + slope * (x - 1), (span.x + span.y) / 2), plan.get("roof_color",P.WOODEN_ROOF))
			sheet.rotation.z = slope
			box(root, Vector3(0.028, 0.035, span.y - span.x), Vector3(x - width / 2, 2.21 + slope * (x - 1), (span.x + span.y) / 2), P.HOME_DOORWAY)
	if plan.get("covering", "plank")=="hay":
		var hole:=Rect2(shaft_x-0.38,shaft_z-0.38,0.76,0.76) if has_shaft else Rect2()
		preload("res://scripts/settlement/thatch_roof.gd").build(root,Rect2(-extra,-extra,2+extra*2,2+extra*2),2.16,slope,int(_exemplars(root).seed),hole)
	if plan.get("covering", "plank")=="imbrex":
		var covering=preload("res://scripts/settlement/roof_covering.gd")
		var kind: String=plan.covering
		var mesh: Mesh=covering.hay() if kind=="hay" else covering.imbrex()
		var poses: Array[Transform3D]=[]
		var rng := RandomNumberGenerator.new(); rng.seed=int(_exemplars(root).get("seed",0))
		for row in 8:
			for column in 9:
				var x: float=-extra+0.16+row*(2+2*extra-0.32)/7
				var z: float=-extra+0.14+column*(2+2*extra-0.28)/8
				if kind=="hay": z+=0.05*(row%2)
				if has_shaft and absf(x-shaft_x)<0.65 and absf(z-shaft_z)<0.51: continue
				var basis := Basis(Vector3.UP,rng.randf_range(-0.035,0.035) if kind=="hay" else 0.0)
				basis=Basis(Vector3.FORWARD,-atan(slope))*basis
				poses.append(Transform3D(basis,Vector3(x,2.20+slope*(x-1)+0.008*(7-row),z)))
		var batch := MultiMesh.new(); batch.transform_format=MultiMesh.TRANSFORM_3D; batch.mesh=mesh; batch.instance_count=poses.size()
		for i in poses.size(): batch.set_instance_transform(i,poses[i])
		var surface := MultiMeshInstance3D.new(); surface.multimesh=batch; surface.material_override=Draw.material(plan.roof_color); root.add_child(surface)
	if plan.get("gutter",true): roof_gutter(root,plan)
	if has_shaft:
		var at := Vector3(shaft_x,0,shaft_z)
		# Four fitted masonry flashing pieces close the shaft's roof penetration.
		for side in [-1, 1]:
			for along_x in [true, false]:
				var center := Vector3(at.x + (side * 0.35 if along_x else 0), 0, at.z + (0 if along_x else side * 0.35))
				center.y = 2.2 + slope * (center.x - 1)
				var flashing := box(root, Vector3(0.26, 0.07, 0.96) if along_x else Vector3(0.44, 0.07, 0.26), center, P.LIMESTONE_SIDE)
				flashing.rotation.z = slope

static func rail(root: Node3D, a: Vector3, b: Vector3, seed_: int = 0) -> void:
	Railing.build(root, a, b, seed_)

static func terrace(root: Node3D, records: Array[Dictionary], tier: int) -> void:
	var tiles := Rules.terrace_tiles(records)
	for at in tiles:
		deck(root, Rect2(at.x - 0.5, at.z - 0.5, 1, 1), 2, Generator.SHAFT if tier == 0 else AABB())
		for d in [Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]:
			if at + d in tiles: continue
			if records.any(func(room): return room.origin.y == 2 and Rules.bounds(room).has_point(at + d + Vector3.UP * 0.1)): continue
			var center: Vector3 = at + d * 0.5
			if is_equal_approx(center.x, -2) and absf(center.z) < 1: continue # Stair landing.
			var tangent := Vector3(-d.z, 0, d.x) * 0.5
			rail(root, center - tangent, center + tangent)
	rail(root, Vector3(-2, 2, -1), Vector3(-2, 2, -0.45))
	rail(root, Vector3(-2, 2, 0.45), Vector3(-2, 2, 1))

static func stairs(root: Node3D) -> void:
	# 10 x 20 cm rises; a 90 cm landing meets the west terrace opening.
	deck(root, Rect2(-2.9, -0.45, 0.9, 0.9), 2)
	for i in 10:
		var z := 2.83 - i * 0.25
		box(root, Vector3(0.9, 0.08, 0.28), Vector3(-2.45, (i + 1) * 0.2 - 0.04, z), Wood.WOOD[0])
	for x in [-2.84, -2.06]:
		Frame.log_member(root, "StairStringer", Vector3(x, 0.03, 2.96), Vector3(x, 1.94, 0.45))
		rail(root, Vector3(x, 0.2, 2.83), Vector3(x, 2, 0.45))
	Frame.log_member(root, "LandingPost", Vector3(-2.84, 0, -0.39), Vector3(-2.84, 2, -0.39))
	rail(root, Vector3(-2.9, 2, -0.45), Vector3(-2.9, 2, 0.45))

static func build(root: Node3D, records: Array[Dictionary], section: int, variant: int, exterior: bool, tier := 0, exemplars := {}, detailed := true) -> Dictionary:
	root.set_meta("exemplar_state", Exemplars.record(variant) if exemplars.is_empty() else exemplars)
	root.set_meta("detailed", detailed)
	if root.has_meta("exemplar_detail"): root.remove_meta("exemplar_detail")
	for child in root.get_children(): child.free()
	var generated := Generator.generate(records, variant, tier)
	for plan in generated.rooms:
		if section == 1 and plan.record.origin.y == 2: continue
		room(root, plan, section, tier)
		if detailed and section != (1 if plan.record.origin.y == 0 else 2): interior_light(root.get_node("Room%d" % plan.record.id))
	if section != 1: terrace(root, records, tier)
	stairs(root)
	for support in generated.supports:
		if support.kind=="balcony_joist": Draw.beam(root,support.a,support.b,0.045,Wood.WOOD[0])
		else: Frame.log_member(root, support.kind, support.a, support.b)
	# Weather canopy belongs to the entrance.
	var canopy := box(root, Vector3(1.15, 0.07, 0.55), Vector3(-1, 1.78, 1.18), P.WOODEN_ROOF); canopy.rotation.x = 0.12
	var points := Rules.flue(records, exterior) if tier > 0 else Generator.brick_flue(records)
	var blocked := Rules.obstruction(records, points) if tier > 0 else {}
	for i in range(1, points.size()) if tier > 0 else []:
		Draw.beam(root, points[i - 1], points[i], Rules.PIPE_RADIUS, P.TOOL_METAL)
		var joint := MeshInstance3D.new(); var mesh := SphereMesh.new(); mesh.radius = 0.077; mesh.height = 0.154
		joint.mesh = mesh; joint.material_override = Draw.material(P.TOOL_METAL); root.add_child(joint); joint.position = points[i - 1]
	var end: Vector3 = points.back()
	# Roof collar physically ties the outlet assembly to the selected roof.
	if tier == 0:
		brick_chimney(root, end.y)
	elif exterior and records.any(func(room): return room.origin.y == 2):
		box(root, Vector3(0.27, 0.06, 0.27), Vector3(end.x, 4.15, end.z), P.TOOL_METAL)
		Draw.beam(root, Vector3(end.x, 4.15, end.z), Vector3(end.x, 4.5, end.z), 0.04, P.TOOL_METAL)
	elif blocked.is_empty(): box(root, Vector3(0.28, 0.07, 0.28), Vector3(end.x, 2.035, end.z), P.TOOL_METAL)
	# A dark open mouth rather than a solid cap.
	box(root, Vector3(0.11, 0.012, 0.11), end, P.HOME_DOORWAY.darkened(0.6))
	if not blocked.is_empty():
		var marker := MeshInstance3D.new(); var torus := TorusMesh.new(); torus.inner_radius = 0.13; torus.outer_radius = 0.22
		marker.mesh = torus; marker.material_override = Draw.material(P.PLACEMENT_BLOCKED); root.add_child(marker); marker.position = blocked.point + Vector3.UP * 0.07
	lantern(root, Vector3(-1.65, 1.52, 1.19))
	if section != 1:
		Draw.beam(root, Rules.balcony(records) + Vector3(0.36, 0, 0.38), Rules.balcony(records) + Vector3(0.36, 1.08, 0.38), 0.035, P.TOOL_METAL)
		lantern(root, Rules.balcony(records) + Vector3(0.36, 0.87, 0.38))
	Exemplars.consolidate(root)
	return {"outlet": end, "blocked": not blocked.is_empty(), "generated": generated}

	paint(root)

static func _exemplars(root: Node) -> Dictionary:
	var node := root
	while node != null:
		if node.has_meta("exemplar_state"): return node.get_meta("exemplar_state")
		node = node.get_parent()
	return Exemplars.record(0)

static func _detail(root: Node) -> bool:
	var node := root
	while node != null:
		if node.has_meta("detailed"): return node.get_meta("detailed")
		node = node.get_parent()
	return true

static func brick_stack(root: Node3D, at: Vector3, courses: int, slot: String) -> void:
	var poses: Array[Transform3D] = []
	# Four unchanged 45 × 20 × 25 cm game bricks form a bonded hollow course.
	for course in courses:
		for side in 4:
			var rotation := Basis(Vector3.UP, (side + course % 2) * PI / 2)
			var offset := rotation * Vector3(-0.125, 0, -0.225)
			poses.append(Transform3D(rotation, at + offset + Vector3.UP * (0.1 + course * 0.2)))
	Exemplars.batch(root, "brick", poses, _exemplars(root), slot)

static func brick_chimney(root: Node3D, height: float) -> void:
	brick_stack(root, Vector3(-0.65, 0.8, -0.65), ceili((height - 0.8) / 0.2), "chimney")

static func bulb(root: Node3D, at: Vector3, energy: float, reach: float) -> void:
	var lamp := OmniLight3D.new(); lamp.position = at; lamp.light_color = P.SUN; lamp.light_energy = energy
	lamp.omni_range = reach; lamp.shadow_enabled = true; lamp.shadow_bias = 0.03; lamp.shadow_normal_bias = 0.1
	lamp.set_meta("powered_energy", energy); root.add_child(lamp)
	var glow := box(root, Vector3(0.11, 0.16, 0.11), at, P.SUN)
	glow.set_meta("powered_glow", true)
	glow.set_meta("keep_lighting", true)
	glow.material_override=preload("res://scripts/settlement/illustration_style.gd").ungraded(glow.material_override)

static func interior_light(root: Node3D) -> void:
	bulb(root, Vector3(1, 1.65, 1), 1.6, 3.0)
	box(root, Vector3(0.22, 0.04, 0.22), Vector3(1, 1.76, 1), P.TOOL_METAL)

static func lantern(root: Node3D, at: Vector3) -> void:
	bulb(root, at, 1.3, 2.3)
	for y in [-0.13, 0.13]: box(root, Vector3(0.22, 0.035, 0.22), at + Vector3.UP * y, P.TOOL_METAL)
	for x in [-0.09, 0.09]:
		for z in [-0.09, 0.09]: box(root, Vector3(0.018, 0.26, 0.018), at + Vector3(x, 0, z), P.TOOL_METAL)

static func set_power(targets: Array, brightness: float) -> void:
	for node in targets:
		if node is OmniLight3D: node.light_energy = float(node.get_meta("powered_energy", 1)) * brightness
		elif node.has_meta("powered_glow"):
			node.visible=brightness>0.001
			var colour:=P.TOOL_METAL.lerp(P.SUN,brightness)
			if node.material_override is ShaderMaterial:
				node.material_override.set_shader_parameter("fill_colour",Vector4(colour.r,colour.g,colour.b,colour.a))
			else:
				node.material_override.albedo_color=colour

static func roof_gutter(root: Node3D, plan: Dictionary) -> void:
	var x: float=-plan.roof_overhang-0.06 if plan.roof_slope>0 else 2+plan.roof_overhang+0.06
	var y: float=2.1+plan.roof_slope*(x-1)
	var run: float=2+plan.roof_overhang*2+0.16
	# Open ceramic U-channel; the low eave collects the sloping roof.
	for side in [-1,1]: box(root,Vector3(0.035,0.14,run),Vector3(x+side*0.09,y,1),Resources.colour("pottery"))
	box(root,Vector3(0.21,0.035,run),Vector3(x,y-0.07,1),Resources.colour("pottery"))

static func paint(root: Node3D) -> void:
	var style=preload("res://scripts/settlement/illustration_style.gd")
	style.apply(root,false,true)
	for part in root.find_children("*","MultiMeshInstance3D",true,false):
		if part.material_override!=null: part.material_override=style.shadowed(part.material_override)
