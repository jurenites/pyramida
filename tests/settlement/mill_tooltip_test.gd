extends SceneTree
const Model = preload("res://scripts/settlement/world_model.gd")
const View = preload("res://scripts/settlement/world_view.gd")
const HUD = preload("res://scripts/settlement/hud.gd")
const Tip = preload("res://scripts/settlement/object_tooltip.gd")
var failures: Array[String] = []
func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message); printerr("FAIL: " + message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var model := Model.new(); model.streaming_enabled = false
	for x in range(-8, 9):
		for z in range(-8, 9): model.ground[Vector3i(x, 0, z)] = true
	model.buildings[Vector3i.ZERO] = {"kind": "mill", "direction": 0}
	model.rebuild_navigation()
	var view := View.new(); root.add_child(view); view.fog_enabled = false; view.setup(model)
	var hud := HUD.new(); root.add_child(hud)
	var camera := Camera3D.new(); root.add_child(camera); camera.projection = Camera3D.PROJECTION_ORTHOGONAL; camera.size = 11; camera.position = Vector3(10, 8, 12); camera.look_at(Vector3(0, 3, 0)); camera.current = true
	var target := {"kind": "mill", "cell": Vector3i.ZERO, "entity_key": "building:%s" % Vector3i.ZERO}
	var node: Node3D = view.entity_views[target.entity_key]
	var rotor: Node3D = node.get_node("WindTower/Rotor")
	var stationary := Tip.stationary_height(node, 5)
	check(stationary > 4 and stationary < 5, "Name anchors to the actual main roof rather than the blade envelope or logical socket")
	for direction in 4:
		node.rotation.y = direction * PI / 2
		for selected in [false, true]:
			hud.update_object_tooltips(view, camera, model, target if selected else {}, {} if selected else target)
			await process_frame
			hud.update_object_tooltips(view, camera, model, target if selected else {}, {} if selected else target)
			var initial: Vector2 = hud.world_tooltips[target.entity_key].position
			for frame in 24:
				rotor.rotation.z = frame * TAU / 24
				hud.update_object_tooltips(view, camera, model, target if selected else {}, {} if selected else target)
				check(hud.world_tooltips[target.entity_key].position.is_equal_approx(initial), "Hover and selection name stay fixed through a full blade rotation")
				check(is_equal_approx(Tip.stationary_height(node, 5), stationary), "Body anchor height ignores rotor")
	hud.free(); camera.free(); view.free()
	print("PASS: stationary Mill name in hover and selection at all four building rotations" if failures.is_empty() else "FAIL: Mill tooltip")
	quit(int(not failures.is_empty()))
