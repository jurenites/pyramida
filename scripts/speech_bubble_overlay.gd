class_name SpeechBubbleOverlay
extends CanvasLayer

const UIVisualTokens = preload("res://scripts/ui_visual_tokens.gd")

const IconLibrary = preload("res://scripts/speech_icon_library.gd")
const Palette = preload("res://scripts/game_palette.gd")

const BUBBLE_HEIGHT := 48.0 * UIVisualTokens.POINT
const BUBBLE_TAIL_HEIGHT := 4.0
const BUBBLE_GAP := 4.0
const SCREEN_MARGIN := 4.0

var _camera: Camera3D
var _world_root: Node3D
var _message_bus: ActorMessageBus
var _bubbles: Dictionary = {}


func configure(camera: Camera3D, world_root: Node3D, message_bus: ActorMessageBus) -> void:
	_camera = camera
	_world_root = world_root
	_message_bus = message_bus
	layer = 104
	name = "ActorSpeechBubbles"


func _process(_delta: float) -> void:
	if not is_instance_valid(_camera) or not is_instance_valid(_message_bus):
		return
	var messages := _message_bus.visible_messages()
	var live_keys: Dictionary = {}
	var candidates: Array[Dictionary] = []
	for message in messages:
		var message_key := str(message.get("key", ""))
		var actor := message.get("actor") as Node3D
		if message_key.is_empty() or not is_instance_valid(actor):
			continue
		live_keys[message_key] = true
		var bubble := _bubble_for_message(message)
		if not _actor_is_visible(actor):
			bubble.visible = false
			continue
		var anchor := _speech_anchor(actor)
		var screen_anchor := _camera.unproject_position(anchor)
		var desired_position := screen_anchor - Vector2(
			bubble.size.x * 0.5,
			bubble.size.y + 6.0
		)
		candidates.append({
			"key": message_key,
			"bubble": bubble,
			"desired_position": desired_position,
		})

	for bubble_key_value in _bubbles.keys():
		var bubble_key := str(bubble_key_value)
		if live_keys.has(bubble_key):
			continue
		var stale_bubble := _bubbles[bubble_key] as Control
		if is_instance_valid(stale_bubble):
			stale_bubble.queue_free()
		_bubbles.erase(bubble_key)

	candidates.sort_custom(_candidate_precedes)
	var placed_rectangles: Array[Rect2] = []
	var viewport_size := get_viewport().get_visible_rect().size
	for candidate in candidates:
		var bubble := candidate.get("bubble") as Control
		var bubble_position: Vector2 = candidate.get("desired_position", Vector2.ZERO)
		var bubble_rectangle := Rect2(bubble_position, bubble.size)
		for placed_rectangle in placed_rectangles:
			if bubble_rectangle.intersects(placed_rectangle.grow(BUBBLE_GAP)):
				bubble_rectangle.position.y = placed_rectangle.position.y - bubble_rectangle.size.y - BUBBLE_GAP
		bubble_rectangle.position.x = clampf(
			bubble_rectangle.position.x,
			SCREEN_MARGIN,
			maxf(SCREEN_MARGIN, viewport_size.x - bubble_rectangle.size.x - SCREEN_MARGIN)
		)
		bubble_rectangle.position.y = clampf(
			bubble_rectangle.position.y,
			SCREEN_MARGIN,
			maxf(SCREEN_MARGIN, viewport_size.y - bubble_rectangle.size.y - SCREEN_MARGIN)
		)
		bubble.position = bubble_rectangle.position
		bubble.visible = true
		placed_rectangles.append(bubble_rectangle)


func visible_bubble_count() -> int:
	var result := 0
	for bubble_value in _bubbles.values():
		var bubble := bubble_value as Control
		if is_instance_valid(bubble) and bubble.visible:
			result += 1
	return result


func _bubble_for_message(message: Dictionary) -> Control:
	var message_key := str(message.get("key", ""))
	if _bubbles.has(message_key):
		var existing_bubble := _bubbles[message_key] as Control
		_update_bubble_content(existing_bubble, message)
		return existing_bubble
	var bubble := _create_bubble(message)
	add_child(bubble)
	_bubbles[message_key] = bubble
	return bubble


func _create_bubble(message: Dictionary) -> Control:
	var bubble_width := 48.0 * UIVisualTokens.POINT

	var bubble := Control.new()
	bubble.name = "ActorSpeechBubble"
	bubble.size = Vector2(bubble_width, BUBBLE_HEIGHT + BUBBLE_TAIL_HEIGHT)
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var tail_fill := Polygon2D.new()
	tail_fill.name = "TailFill"
	tail_fill.polygon = PackedVector2Array([
		Vector2(bubble_width * 0.5 - 4.0, BUBBLE_HEIGHT - 1.0),
		Vector2(bubble_width * 0.5 + 4.0, BUBBLE_HEIGHT - 1.0),
		Vector2(bubble_width * 0.5, BUBBLE_HEIGHT + BUBBLE_TAIL_HEIGHT),
	])
	tail_fill.color = _bubble_background(message)
	tail_fill.z_index = -1
	bubble.add_child(tail_fill)

	var bubble_panel := Panel.new()
	bubble_panel.name = "BubblePanel"
	bubble_panel.size = Vector2(bubble_width, BUBBLE_HEIGHT)
	bubble_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bubble_style := StyleBoxFlat.new()
	bubble_style.bg_color = _bubble_background(message)
	bubble_style.corner_radius_top_left = 7
	bubble_style.corner_radius_top_right = 7
	bubble_style.corner_radius_bottom_left = 7
	bubble_style.corner_radius_bottom_right = 7
	bubble_panel.add_theme_stylebox_override("panel", bubble_style)
	bubble.add_child(bubble_panel)

	var icon := TextureRect.new()
	icon.name = "MessageIcon"
	icon.position = Vector2.ONE * 8 * UIVisualTokens.PADDING_UNIT
	icon.size = Vector2.ONE * 32 * UIVisualTokens.POINT
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble.add_child(icon)

	_update_bubble_content(bubble, message)
	return bubble


func _update_bubble_content(bubble: Control, message: Dictionary) -> void:
	var icon := bubble.get_node("MessageIcon") as TextureRect
	var tail_fill := bubble.get_node("TailFill") as Polygon2D
	var bubble_panel := bubble.get_node("BubblePanel") as Panel
	var bubble_style := bubble_panel.get_theme_stylebox("panel") as StyleBoxFlat
	var background_colour := _bubble_background(message)
	tail_fill.color = background_colour
	if bubble_style != null:
		bubble_style.bg_color = background_colour
	icon.texture = IconLibrary.texture(str(message.get("icon", "walk")))


func _bubble_background(message: Dictionary) -> Color:
	return Color.WHITE if str(message.get("speaker_kind", "utility")) == "citizen" else Palette.FOG_AND_SHADOW


func _speech_anchor(actor: Node3D) -> Vector3:
	if actor.has_method("speech_anchor_world_position"):
		return actor.call("speech_anchor_world_position") as Vector3
	return actor.global_position + Vector3.UP * float(actor.get_meta("speech_anchor_height", 1.8))


func _actor_is_visible(actor: Node3D) -> bool:
	var anchor := _speech_anchor(actor)
	if _camera.is_position_behind(anchor):
		return false
	var screen_position := _camera.unproject_position(anchor)
	var viewport_rectangle := Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size).grow(32.0)
	if not viewport_rectangle.has_point(screen_position):
		return false
	var visibility_target := actor.global_position + Vector3.UP * float(actor.get_meta("visibility_height", 1.1))
	var query := PhysicsRayQueryParameters3D.create(_camera.global_position, visibility_target)
	query.collide_with_areas = false
	var hit := _world_root.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return true
	var collider := hit.get("collider") as Node
	if collider == null:
		return true
	var hit_world_object: Variant = collider.get_meta("world_object") if collider.has_meta("world_object") else null
	if hit_world_object == actor:
		return true
	# Another small speaking actor does not count as a mountain or building.
	return hit_world_object is Node3D and (hit_world_object as Node3D).has_method("speech_anchor_world_position")


func _candidate_precedes(first: Dictionary, second: Dictionary) -> bool:
	var first_position: Vector2 = first.get("desired_position", Vector2.ZERO)
	var second_position: Vector2 = second.get("desired_position", Vector2.ZERO)
	return first_position.y < second_position.y
