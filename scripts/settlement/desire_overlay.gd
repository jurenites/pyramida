extends Control
## Consumers submit model parameters; this overlay never invents utility service.
const Queue = preload("res://scripts/desire_queue.gd")
const State = preload("res://scripts/desire_state.gd")
const Bubble = preload("res://scripts/desire_bubble.gd")
var messages := Queue.new()
var model_id := 0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func sync(world, camera: Camera3D, model, enabled: bool, delta: float) -> void:
	visible = enabled
	if model_id != model.get_instance_id():
		model_id = model.get_instance_id()
		messages = Queue.new()
	if not enabled: return
	var requests: Array[Dictionary] = []
	for worker: Dictionary in model.workers:
		if worker.id >= world.actors.size(): continue
		_append(requests, "person:%s" % worker.id, worker.get("desires", {}), world.actors[worker.id], camera, 1.6)
	for cell: Vector3i in model.buildings:
		var key := "building:%s" % cell
		if world.entity_views.has(key):
			_append(requests, key, model.buildings[cell].get("desires", {}), world.entity_views[key], camera, 2.2)
	messages.sync(requests)
	messages.advance(delta)
	queue_redraw()

func _append(requests: Array[Dictionary], owner: String, parameters: Dictionary, actor: Node3D, camera: Camera3D, height: float) -> void:
	if parameters.is_empty(): return
	var anchor := actor.global_position + Vector3.UP * height
	var screen := camera.unproject_position(anchor) * size / Vector2(camera.get_viewport().size)
	var eligible := actor.is_visible_in_tree() and not camera.is_position_behind(anchor) and Rect2(Vector2.ZERO, size).has_point(screen)
	for icon in State.icons(parameters):
		requests.append({"key": owner + ":" + icon, "icon": icon, "anchor": screen, "eligible": eligible})

func _draw() -> void:
	var request := messages.current()
	if not request.is_empty(): Bubble.draw_on(self, request.anchor, request.icon)
