extends RefCounted
## Metre-sized open structures, assembled from the same carried timber stock.
const Foundation = preload("res://scripts/settlement/support_foundation.gd")
const Timber = preload("res://scripts/settlement/timber_kit.gd")
const Style = preload("res://scripts/settlement/illustration_style.gd")
const Palette = preload("res://scripts/settlement/timber_palette.gd")
const Layout = preload("res://scripts/settlement/structure_layout.gd")
const CORNERS := [Vector3(-0.5, 0, -0.5), Vector3(0.5, 0, -0.5), Vector3(0.5, 0, 0.5), Vector3(-0.5, 0, 0.5)]
const SIDES := [Vector3i.FORWARD, Vector3i.RIGHT, Vector3i.BACK, Vector3i.LEFT]

static func stock(root: Node3D, label: String, kind: String, poses: Array[Transform3D]) -> MeshInstance3D:
	var part := MeshInstance3D.new(); part.name = label; part.mesh = Timber.batch(kind, poses)
	part.set_meta("timber_stock", kind); part.set_meta("timber_count", poses.size()); root.add_child(part)
	Palette.apply(part, "tree")
	return part

static func log_poses(a: Vector3,b: Vector3) -> Array[Transform3D]:
	var direction := (b - a).normalized(); var basis := Basis(Quaternion(Vector3.RIGHT, direction))
	var poses: Array[Transform3D] = []
	for offset in Timber.centres(a.distance_to(b), Timber.LOG_LENGTH): poses.append(Transform3D(basis, (a + b) / 2 + direction * offset))
	return poses

static func log_bounds(a: Vector3,b: Vector3) -> AABB:
	var result:=AABB(); var first:=true
	for pose in log_poses(a,b):
		for source in Timber.sources("log"):
			var box: AABB=pose*source.pose*source.mesh.get_aabb()
			result=box if first else result.merge(box); first=false
	return result

static func log_member(root: Node3D, label: String, a: Vector3, b: Vector3) -> void:
	stock(root, label, "log", log_poses(a,b))

static func deck(root: Node3D, seed_: int) -> void:
	var poses: Array[Transform3D] = []
	var rng := RandomNumberGenerator.new(); rng.seed = seed_
	var bounds := AABB(); var first := true
	for source: Dictionary in Timber.sources("plank"):
		var box: AABB = source.pose * source.mesh.get_aabb(); bounds = box if first else bounds.merge(box); first = false
	# Three 22 cm boards with 12 cm gaps. Small rigid rotations retain a visible
	# gap while breaking the perfectly aligned, solid-tabletop appearance.
	for row in 3:
		for end in 2:
			var basis := Basis.from_euler(Vector3(rng.randf_range(-0.006, 0.006), rng.randf_range(-0.04, 0.04), 0))
			var at := Vector3((-0.15 if end == 0 else 0.15) + rng.randf_range(-0.006, 0.006), 1 - bounds.size.y / 2 - end * 0.003, (row - 1) * 0.34)
			poses.append(Transform3D(basis, at - basis * bounds.get_center()))
	stock(root, "Deck", "plank", poses)

static func steps(root: Node3D) -> void:
	for side in [-1, 1]: preload("res://scripts/settlement/stair_timber.gd").member(root, "Rafter%d" % side, Vector3(-0.36, 0.16, side * 0.36), Vector3(0.36, 0.88, side * 0.36),side)
	var bounds: AABB = Timber.sources("plank")[0].pose * Timber.sources("plank")[0].mesh.get_aabb()
	var basis := Basis(Vector3.UP, PI / 2)
	for i in 5:
		var at := Vector3(-0.36 + i * 0.18, (i + 1) * 0.2 - bounds.size.y / 2, 0)
		stock(root, "Step%d" % i, "plank", [Transform3D(basis, at - basis * bounds.get_center())])

static func populate(root: Node3D, kind: String, loaded := false, posts: Array = [true, true, true, true], beams: Array = [true, true, true, true], corners: Array = [], seed_ := 0, open_deck := false) -> void:
	root.set_meta("variation_exempt", true)
	if corners.is_empty():
		for corner: Vector3 in CORNERS: corners.append(corner * 0.76)
	for i in 4:
		if posts[i] and (kind == "support" or loaded or i in [1, 2]):
			# Without a bearing/deck at the seam, overlap rigid stock to reach the
			# next frame exactly; the old single log left an 8 cm floating gap.
			var height := 1.0 if open_deck or (kind == "stair" and loaded) else Timber.LOG_LENGTH
			if kind=="stair" and not loaded:
				preload("res://scripts/settlement/stair_timber.gd").member(root,"Post%d" % i,corners[i],corners[i]+Vector3.UP*height,1 if corners[i].z>0 else -1)
			else: log_member(root, "Post%d" % i, corners[i], corners[i] + Vector3.UP * height)
	if kind == "support" or loaded:
		for i in 4:
			if beams[i]: log_member(root, "Beam%d" % i, corners[i] + Vector3.UP * 0.85, corners[(i + 1) % 4] + Vector3.UP * 0.85)
	if kind == "support":
		if not open_deck: deck(root, seed_)
	else: steps(root)

static func loaded(model, cell: Vector3i) -> bool:
	return model.buildings.get(cell + Vector3i.UP, {}).get("kind", "") == "support"

static func preview_deck(node: Node3D, enabled: bool) -> void:
	if not node.has_node("RestoreDeck"):
		var top := Node3D.new(); top.name = "RestoreDeck"; node.add_child(top)
		deck(top, 0)
	for part: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		if node.get_node("RestoreDeck").is_ancestor_of(part): continue
		if not part.has_meta("deck_preview_visible"): part.set_meta("deck_preview_visible", part.visible)
		part.visible = not enabled and part.get_meta("deck_preview_visible") and not part.get_meta("pier_hidden_post",false)
	node.get_node("RestoreDeck").visible = enabled

static func sync(model, views: Dictionary) -> void:
	var fitted := false
	for data: Dictionary in model.buildings.values():
		if data.get("kind","")=="support" and data.has("support_group"): fitted = true; break
	if fitted: sync_fitted(model,views)

	var nodes := {}; var full := {}; var owners := {}; var inward := {}; var touches := {}
	for node: Node3D in views.values():
		var cell: Vector3i = node.get_meta("cell", Vector3i.ZERO); var kind: String = node.get_meta("asset", "")
		if (fitted and kind == "support") or kind not in ["support", "stair"] or node.get_meta("planned", false) or node.has_meta("construction_parts") or not model.buildings.has(cell): continue
		nodes[cell] = node
		if kind == "support" or loaded(model, cell): full[cell] = true
	var cells: Array = full.keys(); cells.sort()
	for cell: Vector3i in cells:
		for corner: Vector3 in CORNERS:
			var key := Vector3(cell) + corner
			if not owners.has(key): owners[key] = cell
			inward[key] = inward.get(key, Vector3.ZERO) - corner
			touches[key] = touches.get(key, 0) + 1
	for cell: Vector3i in nodes:
		var node: Node3D = nodes[cell]; var kind: String = model.buildings[cell].kind
		var posts: Array = [true, true, true, true]; var beams: Array = [true, true, true, true]; var corners: Array = []
		for corner: Vector3 in CORNERS:
			# Convert each local corner/edge to the shared world-grid frame.
			var world_corner := (node.basis * corner).snapped(Vector3.ONE * 0.5)
			var key := Vector3(cell) + world_corner; var i := corners.size()
			var at := world_corner * 0.76
			if full.has(cell):
				# A straight shared edge is part of one longer bench, not another
				# pair of legs. Retain only outer and concave turning corners.
				var straight: bool = touches.get(key, 0) == 2 and not inward.get(key, Vector3.ZERO).is_zero_approx()
				posts[i] = owners.get(key) == cell and touches.get(key, 0) < 4 and not straight
				at = world_corner + inward.get(key, Vector3.ZERO).sign() * 0.12
			var side := Vector3i((node.basis * Vector3(SIDES[i])).round())
			beams[i] = not full.has(cell + side)
			corners.append(node.basis.inverse() * at)
		var seed_ := hash([model.world_seed, cell])
		var open_deck := kind == "support" and not Layout.has_deck(model, cell)
		if open_deck: beams.fill(false) # No waist-high crossbars through the passage.
		if kind == "stair" and loaded(model, cell) and not Layout.has_deck(model, cell + Vector3i.UP):
			beams[1] = false; beams[3] = false # Keep the flight's entrance and exit open.
		var signature := [kind, full.has(cell), posts, beams, corners, seed_, open_deck]
		if node.get_meta("structure_signature", []) == signature: continue
		node.set_meta("structure_signature", signature.duplicate(true))
		if node.has_node("ConnectedStructure"): node.get_node("ConnectedStructure").free()
		# Leave source components available to Blueprints; runtime owns this assembly.
		for part: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false): part.visible = false
		var frame := Node3D.new(); frame.name = "ConnectedStructure"; node.add_child(frame)
		populate(frame, kind, full.has(cell), posts, beams, corners, seed_, open_deck); Style.apply(frame, false, true)
		node.remove_meta("timber_frame_slots")

static func sync_fitted(model, views: Dictionary) -> void:
	var Runtime = preload("res://scripts/settlement/support_runtime.gd")
	var cells := Runtime.ordered(model)
	var assembly = Runtime.assembly(model,cells)
	for cell in cells: assembly.open_tops.append(not Layout.has_deck(model,cell))
	var layouts: Array[Dictionary] = assembly.layouts()
	for index in cells.size():
		var cell := cells[index]
		var node: Node3D = null
		for view: Node3D in views.values():
			if view.get_meta("cell",Vector3i(0,-999,0))==cell and view.get_meta("asset","")=="support" and not view.get_meta("planned",false): node=view; break
		if node==null or node.has_meta("construction_parts"): continue
		var data: Dictionary = model.buildings[cell]
		node.rotation.y = float(data.get("support_yaw",0.0))
		var layout := layouts[index]
		var depths: Array[float] = []
		for corner: Vector3 in layout.corners:
			depths.append(maxf(0, Foundation.depth(model, Vector3(cell) + data.get("placement_offset", Vector3.ZERO) + node.basis * corner)))
		var drop := Foundation.deck_drop(model, cell, data.get("placement_offset", Vector3.ZERO), float(data.get("support_yaw",0.0)))
		var landings := Foundation.landing_paths(model, cell)
		var signature := [layout,hash([model.world_seed,cell]),int(data.direction),depths,drop,landings]
		if node.get_meta("fitted_signature",[])==signature: continue
		node.set_meta("fitted_signature",signature.duplicate(true))
		if node.has_node("ConnectedStructure"): node.get_node("ConnectedStructure").free()
		for part: MeshInstance3D in node.find_children("*","MeshInstance3D",true,false): part.visible=false
		var frame := Node3D.new(); frame.name="ConnectedStructure"; node.add_child(frame)
		for i in 4:
			if layout.posts[i]: log_member(frame,"Post%d"%i,layout.corners[i]-Vector3.UP*depths[i],layout.corners[i]+Vector3.UP*((1.0 if layout.open_top else 1.12) + drop))
			if layout.beams[i]: log_member(frame,"Beam%d"%i,layout.corners[i]+Vector3.UP*(0.84+drop),layout.corners[(i+1)%4]+Vector3.UP*(0.84+drop))
		if not layout.open_top:
			deck(frame,hash([model.world_seed,cell]))
			frame.get_node("Deck").position.y = drop
			frame.get_node("Deck").rotation.y = (posmod(hash([model.world_seed,cell]),2)+int(data.direction))*PI/2
		for shore: Vector3i in landings:
			var points: Array = landings[shore]
			for segment in range(1, points.size()):
				landing_boards(frame, "PierLanding%d_%d" % [landings.keys().find(shore), segment], node.transform.affine_inverse() * points[segment - 1], node.transform.affine_inverse() * points[segment])
		Style.apply(frame,false,true)
		if depths.max() > 0: wet_wood(frame, Foundation.water_level(model))
		if node.has_meta("collider"):
			var body: StaticBody3D = node.get_meta("collider")
			for child in body.get_children(): child.free()
			for visual: MeshInstance3D in frame.find_children("*","MeshInstance3D",true,false):
				var shape := CollisionShape3D.new()
				shape.shape=visual.mesh.create_trimesh_shape(); shape.transform=visual.transform
				body.add_child(shape)
		node.remove_meta("timber_frame_slots")

static func wet_wood(root: Node3D, water_level := -0.08) -> void:
	for mesh: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		if not mesh.has_meta("timber_stock"): continue
		var tint: Material = mesh.material_override
		for surface in mesh.mesh.get_surface_count():
			var source: Material = tint if tint != null else mesh.get_active_material(surface)
			if source is ShaderMaterial and source.get_shader_parameter("wet_wood") == true: continue
			var material := ShaderMaterial.new()
			material.shader = preload("res://shaders/settlement_painted_shadow.gdshader")
			var colour: Color = Palette.material("tree", mesh.get_meta("timber_stock"), surface).albedo_color
			if source is StandardMaterial3D: colour = source.albedo_color
			elif source is ShaderMaterial and source.get_shader_parameter("fill_colour") is Color: colour = source.get_shader_parameter("fill_colour")
			material.set_shader_parameter("fill_colour", colour)
			material.set_shader_parameter("wet_wood", true)
			material.set_shader_parameter("water_level", water_level)
			mesh.set_surface_override_material(surface, material)
		mesh.material_override = null

static func sync_foundation(node: Node3D, model, cell: Vector3i, offset := Vector3.ZERO, yaw := 0.0) -> bool:
	var depths := Foundation.depths(model, cell, offset, yaw)
	var reach: float = maxf(0.0, depths.max())
	var drop := Foundation.deck_drop(model, cell, offset, yaw)
	var top := 1.0 + drop
	reach = maxf(reach, -top + 0.1)
	node.set_meta("placement_edges", preload("res://scripts/settlement/placement_outline.gd").box_edges(Vector3(0, (top - reach) * 0.5, 0), Vector3(1, top + reach, 1)))
	var signature := [depths, drop]
	if node.get_meta("water_foundation", []) == signature: return false
	node.set_meta("water_foundation", signature)
	if node.has_meta("collider"):
		for shape: CollisionShape3D in node.get_meta("collider").get_children():
			if shape.shape is BoxShape3D:
				shape.shape.size = Vector3(1, top + reach, 1)
				shape.position = Vector3(0, (top - reach) * 0.5, 0)
	if node.has_meta("construction_parts"):
		node.remove_meta("construction_parts")
		if node.has_node("ConstructionCorners"): node.get_node("ConstructionCorners").free()
	if node.has_node("WaterPosts"): node.get_node("WaterPosts").free()
	for part: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		if node.has_node("RestoreDeck") and node.get_node("RestoreDeck").is_ancestor_of(part): continue
		if str(part.name).begins_with("Post") or str(part.name).begins_with("Beam") or part.name == "Deck":
			if not part.has_meta("pier_original_pose"): part.set_meta("pier_original_pose", part.transform)
			part.transform = part.get_meta("pier_original_pose")
			if part.name == "Deck" or str(part.name).begins_with("Beam"): part.position.y += drop
			if str(part.name).begins_with("Post"):
				part.set_meta("pier_hidden_post", not is_zero_approx(drop))
				part.visible = is_zero_approx(drop)
	var frame := Node3D.new(); frame.name = "WaterPosts"; node.add_child(frame)
	for i in 4:
		if depths[i] <= 0: continue
		var corner: Vector3 = CORNERS[i] * 0.76
		log_member(frame, "WaterPost%d" % i, corner - Vector3.UP * depths[i], corner + Vector3.UP * (top + 0.12))
	Palette.apply(node, "tree")
	Style.apply(node, false, true)
	if depths.max() > 0: wet_wood(node, Foundation.water_level(model))
	return true

static func landing_boards(root: Node3D, label: String, start: Vector3, end: Vector3) -> void:
	var direction := (end - start).normalized()
	var across := Vector3(-direction.z, 0, direction.x).normalized()
	var basis := Basis(direction, across.cross(direction).normalized(), across)
	var source: Dictionary = Timber.sources("plank")[0]
	var centre: Vector3 = (source.pose * source.mesh.get_aabb()).get_center()
	var poses: Array[Transform3D] = []
	for along in Timber.centres(start.distance_to(end), Timber.BOARD.x):
		for row in [-0.23, 0.0, 0.23]:
			poses.append(Transform3D(basis, (start + end) * 0.5 + direction * along + basis.z * row - basis * (centre + Vector3.UP * Timber.BOARD.y * 0.5)))
	stock(root, label, "plank", poses)
