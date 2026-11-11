extends RefCounted
## A single hover-only underground cutaway, without terrain edits or colliders.
const Reviewed = preload("res://scripts/settlement/reviewed_balance.gd")
const Navigation = preload("res://scripts/settlement/navigation.gd")

static func material(colour: Color, priority: int) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = colour; result.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	result.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; result.no_depth_test = true
	result.cull_mode = BaseMaterial3D.CULL_DISABLED; result.render_priority = priority
	return result

static func cylinder(parent: Node3D, label: String, radius: float, height: float, y: float, colour: Color, priority: int, caps := true) -> MeshInstance3D:
	var part := MeshInstance3D.new(); part.name = label
	var mesh := CylinderMesh.new(); mesh.top_radius = radius; mesh.bottom_radius = radius; mesh.height = height; mesh.radial_segments = 16; mesh.rings = 1; mesh.cap_top = caps; mesh.cap_bottom = caps
	part.mesh = mesh; part.position.y = y; part.material_override = material(colour, priority); part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; parent.add_child(part)
	return part

static func populate(node: Node3D, tier: int, water: int, capacity: int) -> void:
	var signature := [tier, water, capacity]
	if node.get_meta("shaft_state", []) == signature: return
	node.set_meta("shaft_state", signature)
	for child in node.get_children(): child.free()
	var depth := float(Reviewed.data.well.depths_m[clampi(tier, 1, 3) - 1])
	node.set_meta("depth_m", depth)
	cylinder(node, "Shaft", 0.28, depth, -depth / 2, Color(0.38, 0.26, 0.17, 0.12), 1, false)
	# Rings and three thin vertical lines make the depth legible through soil.
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_LINES)
	var rings: Array[float]=[0.0,depth]
	for metre in range(1,int(ceil(depth))): rings.append(float(metre))
	for level in rings:
		for i in 16:
			for angle in [TAU * i / 16.0, TAU * (i + 1) / 16.0]: st.add_vertex(Vector3(cos(angle) * 0.285, -level, sin(angle) * 0.285))
	for i in 4:
		var p := Vector3(cos(TAU * i / 4.0) * 0.285, 0, sin(TAU * i / 4.0) * 0.285)
		st.add_vertex(p); st.add_vertex(p + Vector3.DOWN * depth)
	var outline := MeshInstance3D.new(); outline.name = "ShaftOutline"; outline.mesh = st.commit(); outline.material_override = material(Color(0.35, 0.24, 0.15, 0.65), 3); outline.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; node.add_child(outline)
	var height := (depth - 0.12) * clampf(float(water) / maxi(1, capacity), 0, 1)
	node.set_meta("water_height", height)
	if height > 0:
		cylinder(node, "WaterVolume", 0.25, height, -depth + height / 2, Color(0.22, 0.61, 0.72, 0.40), 2)
		cylinder(node, "WaterLevel", 0.255, 0.012, -depth + height, Color(0.43, 0.81, 0.88, 0.85), 4)

static func sync(view: Node3D, model, target: Dictionary) -> void:
	var node := view.get_node_or_null("HoveredWellShaft") as Node3D
	var cell: Vector3i = target.get("cell", Vector3i.ZERO)
	var valid: bool = target.get("kind", "") == "well" and model.wells.has(cell) and not str(target.get("entity_key", "")).begins_with("plan:")
	if not valid:
		if node != null: node.hide()
		return
	if node == null:
		node = Node3D.new(); node.name = "HoveredWellShaft"; view.add_child(node)
	node.show(); node.position = Navigation.point(cell) + model.buildings.get(cell, {}).get("placement_offset", Vector3.ZERO)
	populate(node, model.Hydrology.units(model.buildings.get(cell, {})), model.wells[cell].count("water"), model.wells[cell].capacity)
