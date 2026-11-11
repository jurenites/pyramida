extends RefCounted
## Main-game two-click placement and independent endpoint editing.
const Bridges = preload("res://scripts/settlement/rope_bridges.gd")
const Visuals = preload("res://scripts/settlement/rope_visuals.gd")
const Tokens = preload("res://scripts/ui_visual_tokens.gd")
var game
var first: Variant = null
var moving_id := -1
var endpoint := -1
var preview := Node3D.new()
var handles := Node3D.new()
var readout := Label.new()
var hover: Variant = null
var error := ""
var last_key: Array = []
var handle_key: Array = []

func setup(owner) -> void:
	game = owner
	game.world.add_child(preview); game.world.add_child(handles)
	game.hud.root.add_child(readout)
	readout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	readout.add_theme_font_size_override("font_size", Tokens.UI_FONT_SIZE)
	readout.add_theme_color_override("font_color", Color("352719"))
	readout.add_theme_color_override("font_outline_color", Color("fff0ce"))
	readout.add_theme_constant_override("outline_size", int(Tokens.LINE_WIDTH))
	readout.hide()

func reset() -> void:
	first = null; moving_id = -1; endpoint = -1; hover = null; error = ""; last_key = []
	clear(preview); readout.hide()

func active() -> bool:
	return game.tool in ["rope_bridge", "rope_bridge_move"]

static func clear(node: Node3D) -> void:
	for child in node.get_children(): child.free()

func pick(mouse: Vector2, revealed := true) -> Variant:
	var camera: Camera3D = game.rig.camera
	var origin := camera.project_ray_origin(mouse); var ray := camera.project_ray_normal(mouse)
	if absf(ray.y) < 0.001: return null
	var best := INF; var result: Variant = null
	var nav = game.model.navigation
	for cell: Vector3i in nav.surfaces:
		if game.world.cutaway and cell.y > game.world.display_level: continue
		if not nav.walkable(cell): continue
		var rough: Vector3 = origin + ray * ((nav.surface_point(cell).y - origin.y) / ray.y)
		if absf(rough.x - cell.x) > 1.2 or absf(rough.z - cell.z) > 1.2: continue
		var corners: Array[Vector3] = []
		for offset in [Vector3(-0.5,0,-0.5),Vector3(0.5,0,-0.5),Vector3(0.5,0,0.5),Vector3(-0.5,0,0.5),Vector3.ZERO]:
			var p: Vector3 = Vector3(cell) + offset; p.y = nav.surface_height(cell, p); corners.append(p)
		for i in 4:
			var hit: Variant = Geometry3D.ray_intersects_triangle(origin, ray, corners[i], corners[(i+1)%4], corners[4])
			if hit == null or (revealed and not game.model.exploration.contains(hit)): continue
			var distance: float = origin.distance_to(hit)
			if distance < best: best = distance; result = hit
	if result == null: return null
	# Do not place through a foreground wall or an unrevealed terrain column.
	var query := PhysicsRayQueryParameters3D.create(origin, result, 1)
	var obstruction: Dictionary = game.viewport.world_3d.direct_space_state.intersect_ray(query)
	if not obstruction.is_empty() and obstruction.position.distance_to(result) > 0.65:
		return null
	return result

func object_at(mouse: Vector2) -> Dictionary:
	var origin: Vector3 = game.rig.camera.project_ray_origin(mouse)
	var ray: Vector3 = game.rig.camera.project_ray_normal(mouse)
	var hit: Dictionary = game.viewport.world_3d.direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(origin, origin + ray * 300.0, 7))
	if hit.is_empty() or not hit.collider.has_meta("bridge_id"): return {}
	var id: int = hit.collider.get_meta("bridge_id")
	var record := Bridges.get_record(game.model, id)
	if record.is_empty() or not game.model.exploration.contains(hit.position): return {}
	var end: int = hit.collider.get_meta("endpoint", -1)
	return {"kind": "rope_bridge", "cell": record.b if end == 1 else record.a,
		"bridge_id": id, "endpoint": end, "entity_key": "plan:%d" % id if game.model.plans.has(id) else "bridge:%d" % id}

func begin_move(id: int) -> void:
	if Bridges.get_record(game.model, id).is_empty(): return
	game._set_tool("rope_bridge_move")
	moving_id = id; endpoint = -1; game.hud.build_panel.hide()

func endpoint_at(mouse: Vector2) -> int:
	var record := Bridges.get_record(game.model, moving_id)
	if record.is_empty(): return -1
	var closest: float = 28.0 * game.viewport.size.y / game.hud.root.size.y
	var chosen := -1
	for i in 2:
		var p: Vector3 = record.start if i == 0 else record.end
		var screen: Vector2 = game.rig.camera.unproject_position(p + Vector3.UP * 0.55)
		var distance := screen.distance_to(mouse)
		if distance < closest: closest = distance; chosen = i
	var hit := object_at(mouse)
	if hit.get("bridge_id", -1) == moving_id and hit.get("endpoint", -1) != -1: return hit.endpoint
	return chosen

func click(mouse: Vector2) -> void:
	if moving_id != -1 and endpoint == -1:
		endpoint = endpoint_at(mouse); last_key = []; return
	var at: Variant = pick(mouse)
	if at == null: return
	if moving_id != -1:
		var next_id := Bridges.move_end(game.model, moving_id, endpoint, at)
		if next_id != -1:
			moving_id = next_id; endpoint = -1
			game.selected_object = {"kind": "rope_bridge", "cell": game.model.plans[next_id].cell, "bridge_id": next_id, "entity_key": "plan:%d" % next_id}
	elif first == null:
		first = at
	elif Bridges.request(game.model, first, at):
		var id: int = game.model.next_plan_id - 1
		game.selected_object = {"kind": "rope_bridge", "cell": game.model.plans[id].cell, "bridge_id": id, "entity_key": "plan:%d" % id}
		game._set_tool("inspect")
	last_key = []
	game._message(game.model.last_message)

func update(mouse: Vector2, pointer_active: bool) -> void:
	var id: int = game.selected_object.get("bridge_id", -1)
	var record := Bridges.get_record(game.model, id)
	var span: Node3D = game.world.bridge_node(id)
	var visible_span := is_instance_valid(span) and span.is_visible_in_tree()
	var next_handles := [id, record.duplicate(), game.menu.visible, game.tool, visible_span]
	if next_handles != handle_key:
		handle_key = next_handles; clear(handles)
		if not record.is_empty() and not game.menu.visible and visible_span:
			handles.add_child(Visuals.gate(record.start, record.end, Color("ffc471")))
			handles.add_child(Visuals.gate(record.end, record.start, Color("ffc471")))
			for handle: Node3D in handles.get_children(): handle.scale = Vector3.ONE * 1.015
	if not active() or not pointer_active:
		preview.hide(); readout.hide(); last_key = []; return
	preview.show()
	var key := [mouse, game.rig.camera.global_transform, game.viewport.size, game.world.cutaway, game.world.display_level, game.model.revision, first, moving_id, endpoint]
	if key == last_key: return
	last_key = key; clear(preview); readout.hide()
	if moving_id != -1 and endpoint == -1: return
	hover = pick(mouse)
	if hover == null:
		if first != null: preview.add_child(Visuals.gate(first, first + Vector3.FORWARD, Color("ffc471")))
		return
	var a: Vector3 = hover; var b: Vector3 = hover + Vector3.FORWARD
	var full := first != null or moving_id != -1
	if moving_id != -1:
		record = Bridges.get_record(game.model, moving_id)
		if record.is_empty(): game._set_tool("inspect"); return
		a = hover if endpoint == 0 else record.start; b = hover if endpoint == 1 else record.end
	elif first != null: a = first; b = hover
	if not full:
		preview.add_child(Visuals.gate(a, b, Color("ffc471"))); return
	error = Bridges.error(game.model, a, b, moving_id)
	if not game.model.building_unlocked("rope_bridge"): error = "Build the material producers first"
	var colour := Color("ffc471") if error.is_empty() else Color("e16d53")
	preview.add_child(Visuals.gate(a, b, colour)); preview.add_child(Visuals.gate(b, a, colour))
	if a.distance_to(b) > 0.05:
		var ghost := Visuals.bridge({"start": a, "end": b, "curve_version": 2}, 0.0); preview.add_child(ghost)
		# The tinted anchor pairs above own the preview's posts.
		ghost.get_child(1).free(); ghost.get_child(0).free()
		for mesh in ghost.find_children("*", "MeshInstance3D", true, false): mesh.transparency = 0.65
	var price := Bridges.cost(a, b)
	readout.text = "%d Plank · %d Rope" % [price.plank, price.rope] if error.is_empty() else error
	readout.position = mouse * game.hud.root.size / Vector2(game.viewport.size) + Vector2(20, 24)
	readout.position.x = minf(readout.position.x, game.hud.root.size.x - readout.get_minimum_size().x - 12)
	readout.show()
