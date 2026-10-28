extends SceneTree
const Queue = preload("res://scripts/desire_queue.gd")
const State = preload("res://scripts/desire_state.gd")
const Shape = preload("res://scripts/settlement/structure_blueprint.gd")
const Life = preload("res://scripts/settlement/structure_life.gd")
const Overlay = preload("res://scripts/settlement/structure_workshop_overlay.gd")
const Icons = preload("res://scripts/speech_icon_library.gd")
class ModelFixture extends RefCounted:
	var workers: Array = []
	var buildings := {}
class WorldFixture extends Node3D:
	var actors: Array[Node3D] = []
	var entity_views := {}
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var queue := Queue.new()
	var requests: Array[Dictionary] = []
	for index in 70: requests.append({"key": "building:%d:electricity" % index, "icon": "electricity"})
	queue.sync(requests)
	queue.advance(1)
	check(queue.current().is_empty(), "Requests should wait before appearing")
	queue.advance(1)
	for index in 70:
		check(queue.current().get("key") == requests[index].key, "Every building gets a turn before repeats: %d" % index)
		queue.sync(requests)
		queue.advance(4)
		check(queue.current().is_empty(), "A quiet gap separates bubbles")
		queue.advance(1)
	check(queue.current().get("key") == requests[0].key, "Unresolved requests repeat fairly")
	requests.pop_front()
	queue.sync(requests)
	check(queue.current().is_empty(), "Resolved active request disappears immediately")
	queue.sync([])
	check(queue.entries.is_empty(), "Deleted speakers leave no stale queue entries")
	requests = [{"key": "hidden", "eligible": false}, {"key": "visible"}]
	queue.sync(requests)
	queue.advance(2)
	check(queue.current().get("key") == "visible", "Off-screen requests do not block visible speakers")
	requests[1].eligible = false
	queue.sync(requests)
	check(queue.current().is_empty(), "Moving off-screen hides active bubbles")
	check(State.icons({}).is_empty(), "No invented cooling or power need")
	check(State.icons({"hot": true, "thirsty": true}) == ["water", "heat"], "Personal needs have separate icons")
	check(State.icons({"requires_electricity": true}) == ["electricity"], "Required missing power requests electricity")
	check(State.icons({"requires_electricity": true, "electricity_connected": true}).is_empty(), "Working power resolves desire")
	check(State.icons({}, false) == ["door_blocked"], "Door access is distinct from electricity")
	var building := Shape.preset(5)
	building.desires = {"hot": true, "requires_electricity": true, "electricity_connected": false}
	var saved := Shape.encode(building)
	var restored := Shape.decode(JSON.parse_string(JSON.stringify(saved)))
	check(restored.get("desires") == building.desires, "Building parameters survive JSON save/load")
	check(Shape.transformed(building, Vector3i.RIGHT, 1).desires == building.desires, "Moving and rotating preserve parameters")
	saved.desires.hot = "true"
	check(Shape.decode(saved).is_empty(), "Malformed parameters rejected")
	var legacy := Shape.encode(Shape.preset(5))
	legacy.erase("desires")
	check(Shape.decode(legacy).desires.is_empty(), "Legacy buildings default to no invented needs")
	var overlay := Overlay.new()
	root.add_child(overlay)
	overlay.size = Vector2(800, 600)
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.position = Vector3(5, 5, 8)
	camera.look_at(Vector3.ZERO)
	overlay.camera = camera
	var upper := Shape.transformed(Shape.preset(5), Vector3i.UP, 0)
	overlay.buildings = [upper]
	overlay.cells = Life.occupancy(overlay.buildings)
	overlay.reached = Life.reachable(overlay.buildings)
	check(overlay._requests().size() == 1 and overlay._requests()[0].icon == "door_blocked", "Actual inaccessible blueprint requests door icon")
	overlay.buildings = [building]
	overlay.cells = Life.occupancy(overlay.buildings)
	overlay.reached = Life.reachable(overlay.buildings)
	check(overlay._requests().size() == 2, "Connected building reports only its own parameters")
	var bubble_overlay := SpeechBubbleOverlay.new()
	root.add_child(bubble_overlay)
	var bubble := bubble_overlay._create_bubble({"icon": "water", "short_text": "Should never be visible"})
	check(not bubble.has_node("ShortText"), "Legacy bubble must remain icon-only even if text is supplied")
	for icon in ["water", "heat", "door_blocked", "electricity"]:
		check(Icons.texture(icon) != null and Icons.texture(icon).get_size() == Vector2(32, 32), "Editable SVG loads: " + icon)
	var bus := ActorMessageBus.new()
	var first := Node3D.new()
	var second := Node3D.new()
	root.add_child(first)
	root.add_child(second)
	var one := bus.post_message(first, "need_electricity")
	var two := bus.post_message(second, "need_electricity")
	check(one != two, "Legacy bus preserves each building's need")
	bus._process(2.0)
	check(bus.visible_messages().size() == 1 and bus.visible_messages()[0].actor == first, "Legacy bus shows one speaker")
	bus.clear_message(first, "need_electricity")
	bus._process(1.0)
	check(bus.visible_messages().size() == 1 and bus.visible_messages()[0].actor == second, "Clearing one owner preserves another's request")
	bus.free()
	var runtime := preload("res://scripts/settlement/desire_overlay.gd").new()
	root.add_child(runtime)
	runtime.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	runtime.size = Vector2(800, 600)
	var world := WorldFixture.new()
	root.add_child(world)
	world.actors = [first]
	world.entity_views = {"building:(0, 0, 0)": second}
	var model := ModelFixture.new()
	model.workers = [{"id": 0, "desires": {"thirsty": true}}]
	model.buildings = {Vector3i.ZERO: {"desires": {"requires_electricity": true}}}
	runtime.sync(world, camera, model, true, 2.0)
	check(runtime.messages.entries.size() == 2 and runtime.messages.current().get("icon") == "water", "People and buildings share the live settlement queue")
	model.workers[0].desires.clear()
	runtime.sync(world, camera, model, true, 1.0)
	check(runtime.messages.current().get("icon") == "electricity", "Resolved thirst lets the building speak")
	model.buildings[Vector3i.ZERO].desires.electricity_connected = true
	runtime.sync(world, camera, model, true, 0.0)
	check(runtime.messages.current().is_empty(), "Power connection removes the live building request")
	runtime.sync(world, camera, model, false, 1.0)
	check(not runtime.visible, "Menus hide live speech bubbles")
	runtime.free()
	world.free()
	first.free()
	second.free()
	bubble.free()
	bubble_overlay.free()
	overlay.free()
	camera.free()
	print("PASS: desire queue, state, persistence and icon-only bubbles" if failures == 0 else "FAIL: %d checks" % failures)
	quit(0 if failures == 0 else 1)
