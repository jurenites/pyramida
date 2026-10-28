extends Control
const Tokens = preload("res://scripts/ui_visual_tokens.gd")
const PlacementOutline = preload("res://scripts/settlement/placement_outline.gd")
const Life = preload("res://scripts/settlement/structure_life.gd")
const DesireQueue = preload("res://scripts/desire_queue.gd")
const Desires = preload("res://scripts/desire_state.gd")
const Bubble = preload("res://scripts/desire_bubble.gd")
var desire_queue := DesireQueue.new()
var camera: Camera3D
var buildings: Array = []
var selected := -1
var reached := {}
var cells := {}
var cutoff := 99
var placement_edges: Array[PackedVector3Array] = []
var placement_visible := false
var volume_edges: Array[PackedVector3Array] = []
var phase := 0.0
var transform_gizmo: RefCounted
var origin_visible := false
var marquee_visible := false
var marquee_rect := Rect2()

func _process(delta: float) -> void:
	phase += delta
	desire_queue.sync(_requests())
	desire_queue.advance(delta)
	queue_redraw()

func _draw() -> void:
	if marquee_visible:
		draw_rect(marquee_rect, Color(Tokens.SELECTION_COLOR, 0.08))
		draw_rect(marquee_rect, Color(Tokens.SELECTION_COLOR, 0.82), false, Tokens.LINE_WIDTH)
	if not is_instance_valid(camera): return
	for edge in volume_edges:
		if camera.is_position_behind(edge[0]) or camera.is_position_behind(edge[1]): continue
		draw_line(camera.unproject_position(edge[0]), camera.unproject_position(edge[1]), Color(0.12, 0.48, 0.52, 0.42), Tokens.LINE_WIDTH, true)
	if placement_visible and not (transform_gizmo != null and transform_gizmo.active() and transform_gizmo.mode in ["size", "face"]):
		for edge in placement_edges:
			if camera.is_position_behind(edge[0]) or camera.is_position_behind(edge[1]): continue
			draw_line(camera.unproject_position(edge[0]), camera.unproject_position(edge[1]), Color(Tokens.SELECTION_COLOR, 0.82), Tokens.LINE_WIDTH, true)
	if transform_gizmo != null: transform_gizmo.draw(self)
	if origin_visible: _origin()
	for i in buildings.size():
		var building: Dictionary = buildings[i]
		var door: Dictionary = building.get("door", {})
		if door.is_empty() or door.cell.y > cutoff: continue
		var point := camera.unproject_position(Vector3(door.cell) + Vector3(door.side) * 0.53 + Vector3.UP * 0.36)
		if not Life.connected(building, reached, cells):
			var colour := Color("f16b51")
			colour.a = 0.35 + sin(phase * 3.0) * 0.12
			draw_circle(point, 12 * Tokens.POINT, colour)
		if i == selected: _selection(building)
	var request := desire_queue.current()
	if not request.is_empty(): Bubble.draw_on(self, camera.unproject_position(request.anchor), request.icon)

func _requests() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not is_instance_valid(camera) or not is_visible_in_tree(): return result
	for building: Dictionary in buildings:
		var door: Dictionary = building.get("door", {})
		if door.is_empty() or door.cell.y > cutoff: continue
		var anchor := Vector3(door.cell) + Vector3(door.side) * 0.55 + Vector3.UP * 0.9
		var eligible := not camera.is_position_behind(anchor) and Rect2(Vector2.ZERO, size).has_point(camera.unproject_position(anchor))
		# Geometry identity survives refreshes and array reordering. Moving a
		# building intentionally retires requests at its previous location.
		var positions: Array = building.cells.keys()
		positions.sort()
		var owner := str(positions)
		for icon in Desires.icons(building.get("desires", {}), Life.connected(building, reached, cells)):
			result.append({"key": owner + ":" + icon, "icon": icon, "anchor": anchor, "eligible": eligible})
	return result

func _origin() -> void:
	# Project the actual authoring origin, never the mesh bounds or camera focus.
	if camera.is_position_behind(Vector3.ZERO): return
	var at := camera.unproject_position(Vector3.ZERO)
	var ink := Color("174f52")
	draw_circle(at, 4 * Tokens.POINT, ink)
	var font := get_theme_default_font()
	draw_string(font, at + Vector2(8, -8) * Tokens.POINT, "0, 0, 0", HORIZONTAL_ALIGNMENT_LEFT, -1, Tokens.UI_FONT_SIZE, ink)
	draw_string(font, Vector2(12 * Tokens.POINT, size.y - 12 * Tokens.POINT), "Grid 2 × 2 m", HORIZONTAL_ALIGNMENT_LEFT, -1, Tokens.UI_FONT_SIZE, ink)

func _selection(building: Dictionary) -> void:
	if building.cells.is_empty(): return
	var low := Vector3(INF, INF, INF)
	var high := Vector3(-INF, -INF, -INF)
	for cell: Vector3i in building.cells:
		low = low.min(Vector3(cell))
		high = high.max(Vector3(cell))
	low += Vector3(-0.5, 0.02, -0.5)
	high += Vector3(0.5, 0.02, 0.5)
	for x in [low.x, high.x]:
		for z in [low.z, high.z]:
			var p := Vector3(x, low.y, z)
			var sx := 0.2 if x == low.x else -0.2
			var sz := 0.2 if z == low.z else -0.2
			draw_polyline(PackedVector2Array([camera.unproject_position(p + Vector3(sx, 0, 0)), camera.unproject_position(p), camera.unproject_position(p + Vector3(0, 0, sz))]), Color(Tokens.SELECTION_COLOR, 0.75), Tokens.LINE_WIDTH, true)
