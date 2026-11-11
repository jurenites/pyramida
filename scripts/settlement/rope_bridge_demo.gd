extends Node3D
## Isolated live prototype: real production/construction/jobs, no player saves.
const Fixture = preload("res://scripts/settlement/rope_bridge_fixture.gd")
const Visuals = preload("res://scripts/settlement/rope_visuals.gd")
const Assets = preload("res://scripts/settlement/asset_library.gd")
const Tokens = preload("res://scripts/ui_visual_tokens.gd")
var model
var rig = preload("res://scripts/settlement/camera_rig.gd").new()
var actors: Array = []
var buildings := Node3D.new()
var spans := Node3D.new()
var preview := Node3D.new()
var revision := -1
var placing := false
var first: Variant = null
var hover: Variant = null
var stats := Label.new()
var hint := Label.new()
var bridge_button := Button.new()
var running := true
var speed := 4.0

func _ready() -> void:
	get_viewport().msaa_3d = Viewport.MSAA_4X
	var environment := WorldEnvironment.new(); environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("77a6a0")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("fff0d5"); environment.environment.ambient_light_energy = 0.75
	add_child(environment)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-55, -32, 0); sun.light_energy = 0.9; sun.shadow_enabled = true; add_child(sun)
	Visuals.box(self, Vector3(90, 0.1, 90), Vector3(0, -0.45, 0), Color("77a6a0"))
	_terrace(Rect2(-9.5, -5.5, 8, 10), 2.0)
	_terrace(Rect2(4.5, -1.5, 7, 9), 5.0)
	add_child(buildings); add_child(spans); add_child(preview)
	add_child(rig); rig.setup(); rig.focus = Vector3(0.5, 2, 0.5); rig.yaw = -0.28; rig.pitch = 0.64; rig.zoom = 19; rig.update_camera()
	_ui(); reset()

func _terrace(rect: Rect2, height: float) -> void:
	Visuals.box(self, Vector3(rect.size.x, 0.16, rect.size.y), Vector3(rect.get_center().x, height - 0.08, rect.get_center().y), Color("e9c38e"))
	var corners: Array[Vector3] = []
	for p in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]: corners.append(Vector3(p.x, height - 0.16, p.y))
	var surface := SurfaceTool.new(); surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 4:
		var a := corners[i]; var b := corners[(i + 1) % 4]
		var center := Vector3(rect.get_center().x, 0, rect.get_center().y)
		var lower_a := Vector3(a.x, -0.45, a.z) + (Vector3(a.x, 0, a.z) - center).normalized() * 0.9
		var lower_b := Vector3(b.x, -0.45, b.z) + (Vector3(b.x, 0, b.z) - center).normalized() * 0.9
		var mid := (a + b + lower_a + lower_b) * 0.25
		for tri in [[a,b,mid], [b,lower_b,mid], [lower_b,lower_a,mid], [lower_a,a,mid]]:
			surface.set_color(Color("c79565").lightened(float(i % 3) * 0.07))
			for p: Vector3 in tri: surface.add_vertex(p)
	surface.generate_normals()
	var mesh := MeshInstance3D.new(); mesh.mesh = surface.commit()
	var mat := Visuals.material(Color.WHITE); mat.vertex_color_use_as_albedo = true; mat.cull_mode = BaseMaterial3D.CULL_DISABLED; mesh.material_override = mat; add_child(mesh)

func _ui() -> void:
	var layer := CanvasLayer.new(); add_child(layer)
	var panel := PanelContainer.new(); layer.add_child(panel)
	var style := StyleBoxFlat.new(); style.bg_color = Color("fff0ce"); style.border_color = Color("684c37")
	style.set_border_width_all(int(Tokens.LINE_WIDTH)); style.content_margin_left = 8 * Tokens.POINT; style.content_margin_right = 8 * Tokens.POINT
	style.content_margin_top = 8 * Tokens.POINT; style.content_margin_bottom = 8 * Tokens.POINT; panel.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 8 * Tokens.POINT); panel.add_child(row)
	bridge_button.text = "Bridge"; bridge_button.toggle_mode = true
	bridge_button.toggled.connect(func(on): placing = on; first = null; hint.text = ""; _preview())
	row.add_child(bridge_button)
	var remove := Button.new(); remove.text = "Remove bridge"; row.add_child(remove)
	remove.pressed.connect(func():
		if not model.bridges.is_empty():
			Fixture.Bridges.remove(model, model.bridges.keys().back()); hint.text = model.last_message
		elif not model.plans.is_empty():
			for plan: Dictionary in model.plans.values():
				if plan.kind == "rope_bridge": model.delete_plan(plan.id)
	)
	var restart := Button.new(); restart.text = "Reset"; restart.pressed.connect(reset); row.add_child(restart)
	var rate := Button.new(); rate.text = "4×"; row.add_child(rate)
	rate.pressed.connect(func(): speed = 1.0 if speed == 4.0 else 4.0; rate.text = "1×" if speed == 1.0 else "4×")
	row.add_child(stats)
	for control in row.get_children(): control.add_theme_font_size_override("font_size", Tokens.UI_FONT_SIZE)
	stats.add_theme_color_override("font_color", Color("684c37"))
	hint.position = Vector2(16, 72); hint.add_theme_font_size_override("font_size", Tokens.UI_FONT_SIZE); hint.add_theme_color_override("font_color", Color("fff0ce")); layer.add_child(hint)

func reset() -> void:
	for actor in actors: actor.free()
	actors.clear(); model = Fixture.create(); revision = -1
	for worker: Dictionary in model.workers:
		var actor = preload("res://scripts/settlement/worker_view.gd").new(); actor.setup(worker.id); add_child(actor); actors.append(actor)
	bridge_button.button_pressed = false; placing = false; first = null; hover = null; hint.text = ""; _preview(); refresh()

func refresh() -> void:
	if revision != model.revision:
		revision = model.revision
		for child in buildings.get_children(): child.free()
		for cell: Vector3i in model.buildings:
			var kind: String = model.buildings[cell].kind
			var node := Assets.create(kind); buildings.add_child(node); node.position = Vector3(cell)
			if kind == "log_shed":
				for resource in ["log", "plank"]:
					for i in mini(8, model.stores[cell].count(resource)):
						var stock := Assets.create(resource); buildings.add_child(stock)
						stock.position = Vector3(cell) + Vector3(-0.22 if resource == "log" else 0.22, 0.15 + (i / 3) * 0.18, -0.65 + (i % 3) * 0.3)
		Visuals.sync(spans, model)
		for plan: Dictionary in model.plans.values():
			if not model.Deconstruction.is_salvage(plan): continue
			var index := 0
			for resource: String in plan.relocation.parts.amounts:
				for i in mini(12, plan.relocation.parts.count(resource)):
					var item := Assets.create(resource); buildings.add_child(item)
					item.position = Vector3(plan.cell) + Vector3((index % 3) * 0.2 - 0.2, 0.08 + (index / 3) * 0.12, 0.2); index += 1
	stats.text = "Hay %d   Rope %d   Plank %d" % [model.resource_total("grain"), model.resource_total("rope"), model.resource_total("plank")]
	for i in actors.size(): actors[i].sync(model.workers[i], 0.016, false, rig.camera, model.navigation)
	for worker: Dictionary in model.workers:
		if worker.job.get("kind") == "process" and worker.job.get("phase") == "work":
			for node in buildings.get_children():
				if node.has_node("Spindle"): node.get_node("Spindle").rotation.z = model.time * 5.0

func _process(delta: float) -> void:
	if model == null: return
	rig.advance(delta)
	if running:
		var remaining := minf(delta, 0.1) * speed
		while remaining > 0:
			var step := minf(remaining, 0.05); model.tick(step); remaining -= step
	refresh()

func pick(screen: Vector2) -> Variant:
	var origin: Vector3 = rig.camera.project_ray_origin(screen)
	var direction: Vector3 = rig.camera.project_ray_normal(screen)
	var best := INF; var result: Variant = null
	for cell: Vector3i in model.navigation.surfaces:
		if not model.navigation.walkable(cell) or absf(direction.y) < 0.001: continue
		var t := (float(cell.y) - origin.y) / direction.y
		if t < 0 or t >= best: continue
		var p := origin + direction * t
		if absf(p.x - cell.x) <= 0.5 and absf(p.z - cell.z) <= 0.5: best = t; result = p
	return result

func _unhandled_input(event: InputEvent) -> void:
	rig.handle(event)
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE: bridge_button.button_pressed = false
	if not placing: return
	if event is InputEventMouseMotion:
		hover = pick(event.position); _preview()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var point: Variant = pick(event.position)
		if point == null: return
		if first == null: first = point; hint.text = ""; _preview(); return
		if Fixture.Bridges.request(model, first, point): bridge_button.button_pressed = false; hint.text = ""
		else: hint.text = model.last_message

func _preview() -> void:
	for child in preview.get_children(): child.free()
	if not placing: return
	if first != null: preview.add_child(Visuals.gate(first, hover if hover != null else first + Vector3.FORWARD, Color("ffc471")))
	if hover == null: return
	preview.add_child(Visuals.gate(hover, first if first != null else hover + Vector3.FORWARD, Color("ffc471")))
	if first == null: return
	var message := Fixture.Bridges.error(model, first, hover)
	if not message.is_empty(): hint.text = message; return
	var price := Fixture.Bridges.cost(first, hover)
	hint.text = "%d Plank · %d Rope" % [price.plank, price.rope]
	var ghost := Visuals.bridge({"start": first, "end": hover, "curve_version": 2}, 0.0); preview.add_child(ghost)
	ghost.get_child(1).free(); ghost.get_child(0).free()
