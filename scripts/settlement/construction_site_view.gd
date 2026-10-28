extends RefCounted
## Disposable visuals reconstructed from the site's installed materials and applied work.
const Catalog = preload("res://data/settlement/catalog.gd")
const Illustration = preload("res://scripts/settlement/illustration_style.gd")
const WEIGHTS := [0.30, 0.20, 0.35, 0.15]
const ENCLOSED := ["house", "school", "pantry", "workshop"]
const BARNS := []
const STICK = preload("res://data/settlement/stick.tscn")
const WOOD := Color("80503d")
const PLAN_TRANSPARENCY := 0.6

static func preview(node: Node3D) -> void:
	# Keep the complete authored shape and palette, including the eventual roof.
	# Instance transparency leaves shared materials and completed floors untouched.
	for mesh: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		mesh.transparency = PLAN_TRANSPARENCY
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

static func applies(plan: Dictionary) -> bool:
	if plan.kind in Catalog.SEEDS or plan.get("deconstruction", false): return false
	if plan.has("relocation") and preload("res://scripts/settlement/relocation.gd").portable_plant(plan): return false
	return plan.kind in Catalog.COSTS

static func _local_bounds(root: Node3D, mesh: MeshInstance3D) -> AABB:
	var transform := mesh.transform
	var parent := mesh.get_parent() as Node3D
	while parent != root:
		transform = parent.transform * transform
		parent = parent.get_parent() as Node3D
	return transform * mesh.mesh.get_aabb()

static func _under(node: Node, root: Node, ancestor_name: String) -> bool:
	var parent := node.get_parent()
	while parent != root:
		if str(parent.name) == ancestor_name: return true
		parent = parent.get_parent()
	return false

static func _stage(root: Node3D, mesh: MeshInstance3D) -> int:
	var part := str(mesh.name)
	if _under(mesh, root, "Canopy") or _under(mesh, root, "Roof") or part.begins_with("FloorPlank") or part in ["Canopy", "WorkshopAwning", "LinenSail"]:
		return 3
	if part.begins_with("Door"):
		return 2
	for word in ["Post", "Leg", "Support", "Rail", "Frame", "MillTower"]:
		if word in part:
			var bounds := _local_bounds(root, mesh)
			return 0 if bounds.size.y > minf(bounds.size.x, bounds.size.z) * 2 else 1
	for word in ["Beam", "Brace", "Lintel", "Crossbar", "Axle", "Spoke", "Rung", "TableTop"]:
		if word in part: return 1
	return 2

static func _timber(parent: Node3D, node_name: String, start: Vector3, end: Vector3, radius: float) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius * 0.88
	mesh.bottom_radius = radius
	mesh.height = start.distance_to(end)
	mesh.radial_segments = 6
	mesh.rings = 1
	var material := StandardMaterial3D.new()
	material.albedo_color = WOOD
	material.roughness = 1.0
	var piece := MeshInstance3D.new()
	piece.name = node_name
	piece.mesh = mesh
	piece.material_override = Illustration.flat(material)
	piece.position = (start + end) * 0.5
	piece.quaternion = Quaternion(Vector3.UP, (end - start).normalized())
	parent.add_child(piece)
	return piece

static func prepare(node: Node3D, kind: String, ground_markers := true) -> void:
	if node.has_meta("construction_parts"): return
	var groups: Array = [[], [], [], []]
	for mesh: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		# Optional stacked decks and living crops are not part of this building's shell.
		var excluded := _under(mesh, node, "StackSupport") or _under(mesh, node, "Plants")
		excluded = excluded or (kind == "well" and node.has_meta("well_plan_units") and not mesh.visible)
		excluded = excluded or (_under(mesh, node, "Roof") and kind not in Catalog.NATURAL_ROOFS)
		mesh.hide()
		if excluded: continue
		groups[_stage(node, mesh)].append(mesh)
	# Sort authored pieces from low to high inside each phase, with stable tie breaks.
	for group: Array in groups:
		group.sort_custom(func(a, b):
			var ay := _local_bounds(node, a).position.y
			var by := _local_bounds(node, b).position.y
			return str(node.get_path_to(a)) < str(node.get_path_to(b)) if is_equal_approx(ay, by) else ay < by)
	var markers := Node3D.new()
	markers.name = "ConstructionCorners"
	markers.visible = ground_markers
	node.add_child(markers)
	var bounds: Vector3 = Catalog.DEFINITIONS[kind].size
	var base := -float(node.get_meta("platform_tier", 1)) if kind == "platform" else 0.0
	var corners: Array[Vector3] = []
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var point := Vector3(corner.x * (bounds.x * 0.5 + 0.025), base, corner.y * (bounds.z * 0.5 + 0.025))
		var branch := STICK.instantiate() as Node3D
		branch.name = "Branch%d" % corners.size()
		branch.position = point
		branch.scale = Vector3(corner.x, 1, corner.y)
		markers.add_child(branch)
		Illustration.apply(branch)
		corners.append(point)
	if kind in ENCLOSED or kind in BARNS:
		var frame := Node3D.new()
		frame.name = "ConstructionFrame"
		node.add_child(frame)
		var height := Catalog.LEVEL_HEIGHT - 0.16
		var frame_corners: Array[Vector3] = []
		for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			frame_corners.append(Vector3(corner.x * 0.83, 0, corner.y * 0.80))
		for index in 4:
			if kind in ENCLOSED:
				groups[0].append(_timber(frame, "Upright%d" % index, frame_corners[index], frame_corners[index] + Vector3.UP * (height + 0.05), 0.065))
			groups[1].append(_timber(frame, "Beam%d" % index, frame_corners[index] + Vector3.UP * height, frame_corners[(index + 1) % 4] + Vector3.UP * height, 0.065))
		for timber: MeshInstance3D in frame.get_children():
			# Uprights and beams use the same stock as the finished buildings.
			timber.name = "Post" + str(timber.name)
		preload("res://scripts/settlement/timber_kit.gd").rebuild(frame)
		Illustration.apply(frame)
	var weight := 0.0
	for stage in 4:
		if not groups[stage].is_empty(): weight += WEIGHTS[stage]
	var parts: Array[Dictionary] = []
	var start := 0.0
	for stage in 4:
		if groups[stage].is_empty(): continue
		for index in groups[stage].size():
			var part: MeshInstance3D = groups[stage][index]
			part.hide()
			parts.append({"mesh": part, "stage": stage,
				"threshold": (start + WEIGHTS[stage] * float(index + 1) / groups[stage].size()) / weight})
		start += WEIGHTS[stage]
	node.set_meta("construction_parts", parts)
	# Replace each ground marker as soon as its own corner gains a post, wall
	# or foundation. Cache this against the same earned-work thresholds as the
	# building pieces, so unrelated corners and reloads keep their exact state.
	for marker: Node3D in markers.get_children():
		var threshold := 1.0
		for part: Dictionary in parts:
			if part.stage == 3: continue
			var piece_bounds := _local_bounds(node, part.mesh)
			if piece_bounds.position.y > base + 0.405 or piece_bounds.end.y < base: continue
			var nearest := Vector2(
				clampf(marker.position.x, piece_bounds.position.x, piece_bounds.end.x),
				clampf(marker.position.z, piece_bounds.position.z, piece_bounds.end.z))
			if nearest.distance_to(Vector2(marker.position.x, marker.position.z)) <= 0.3:
				threshold = minf(threshold, part.threshold)
		marker.set_meta("construction_threshold", threshold)

static func sync(node: Node3D, plan: Dictionary, workers: Array) -> void:
	prepare(node, plan.kind)
	var installed: float = plan.installed
	for worker: Dictionary in workers:
		var job: Dictionary = worker.job
		if job.get("kind") == "build" and job.get("plan_id") == plan.id:
			installed += job.labour.progress_ratio()
	var ratio := clampf(installed / maxf(plan.required, 1.0), 0, 1)
	# Relocation's destination is only stakes until its source has been dismantled.
	if plan.has("relocation") and plan.relocation.stage == "dismantle": ratio = 0.0
	for part: Dictionary in node.get_meta("construction_parts"):
		part.mesh.visible = ratio + 0.00001 >= part.threshold
	for marker: Node3D in node.get_node("ConstructionCorners").get_children():
		marker.visible = ratio + 0.00001 < float(marker.get_meta("construction_threshold"))
