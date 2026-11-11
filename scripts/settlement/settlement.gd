extends Node
const Perf = preload("res://scripts/settlement/performance_log.gd")
const VisualTokens = preload("res://scripts/ui_visual_tokens.gd")
const Text = preload("res://scripts/settlement/text.gd")
const Model = preload("res://scripts/settlement/world_model.gd")
const WorldView = preload("res://scripts/settlement/world_view.gd")
const CameraRig = preload("res://scripts/settlement/camera_rig.gd")
const HUD = preload("res://scripts/settlement/hud.gd")
const HouseSelection = preload("res://scripts/settlement/house_selection.gd")
const Assets = preload("res://scripts/settlement/asset_library.gd")
const Navigation = preload("res://scripts/settlement/navigation.gd")
const SaveSlots = preload("res://scripts/settlement/save_slots.gd")
const MainMenu = preload("res://scripts/settlement/main_menu.gd")
const Illustration = preload("res://scripts/settlement/illustration_style.gd")
const Soundscape = preload("res://scripts/settlement/soundscape.gd")
const Hotkeys = preload("res://scripts/settlement/hotkeys.gd")
var room_editor
var generated_building_tool
var rain_editor
var hotkeys = Hotkeys.new()
var soundscape: Node3D
var fog: Node3D
const SIMULATION_STEP := 0.05
const MAX_STEPS_PER_FRAME := 16
@export var illustrated := true
var world_container: SubViewportContainer
const PixelCursor = preload("res://scripts/settlement/pixel_cursor.gd")
@export var slot_directory := "user://settlements"
@export var launch_to_menu := true
var saves = SaveSlots.new()
var menu: CanvasLayer
var structure_workshop: CanvasLayer
var active_slot := -1
var session_started := false
var autosave_elapsed := 0.0
var autosave_worker = preload("res://scripts/settlement/background_save.gd").new()
var preferences := {"fullscreen": false, "routes": false}
var chunk_loader = preload("res://scripts/settlement/chunk_loader.gd").new()
var model = Model.new()
var menu_preview: RefCounted
var menu_return_view: Dictionary = {}
var world: Node3D
var rig: Node3D
var hud: CanvasLayer
var viewport: SubViewport
var desire_overlay: Control
var citizen_outline: Control
var preview: Node3D
var hover_offset := Vector3.ZERO
var support_yaw := 0.0
var tool := "inspect"
var relocation_source: Variant = null
var moving_plan_id := -1
var house_stamp: Array = []
var level := 1
var direction := 0
var speed := 1.0
var selected := -1
var selected_workers: Array[int] = []
var last_idle_citizen := -1
var left_origin := Vector2.ZERO
var left_selecting := false
var right_origin := Vector2.ZERO
var hovered := Vector3i.ZERO
var hover_valid := false
var accumulator := 0.0
var message_timer := 0.0
var capture := false
var capture_frames := 0
@export var showcase := false
@export var gallery := false
var preview_error := "uninitialised"
var selected_object := {}
var bridge_editor = preload("res://scripts/settlement/rope_bridge_editor.gd").new()
var gallery_labels: Array[Dictionary] = []
var setup_complete := false
var operation_busy := false
var close_requested := false
var operation_thread: Thread
var loading_overlay: CanvasLayer

func _ready() -> void:
	Illustration.enabled = illustrated
	add_child(PixelCursor.new())
	var preview_launch := launch_to_menu and not showcase and not gallery
	for argument in ["--capture", "--gallery", "--showcase"]:
		preview_launch = preview_launch and not OS.get_cmdline_user_args().has(argument)
	var demonstration := showcase or gallery or OS.get_cmdline_user_args().has("--showcase") or OS.get_cmdline_user_args().has("--gallery")
	model.setup(randi() if preview_launch else Model.Generator.DEFAULT_SEED, "normal" if demonstration else "easy")
	if preview_launch:
		menu_preview = model
	var container := preload("res://scripts/window_world_surface.gd").new()
	container.fill_window = true
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.stretch = true
	world_container = container
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(container)
	viewport = SubViewport.new()
	viewport.world_3d = World3D.new()
	viewport.size = Vector2i(720, 450)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	Illustration.configure(container, viewport)
	container.add_child(viewport)
	if Perf.enabled: RenderingServer.viewport_set_measure_render_time(viewport.get_viewport_rid(), true)
	world = Node3D.new()
	world.set_script(WorldView)
	viewport.add_child(world)
	world.setup(model)
	rig = Node3D.new()
	rig.set_script(CameraRig)
	viewport.add_child(rig)
	rig.hotkeys = hotkeys
	rig.setup()
	citizen_outline = preload("res://scripts/settlement/citizen_outline.gd").new()
	add_child(citizen_outline)
	fog = preload("res://scripts/settlement/fog_view.gd").new()
	rig.camera.add_child(fog)
	soundscape = Soundscape.new()
	viewport.add_child(soundscape)
	hud = CanvasLayer.new()
	hud.set_script(HUD)
	hud.hotkeys = hotkeys
	add_child(hud)
	bridge_editor.setup(self)
	desire_overlay = preload("res://scripts/settlement/desire_overlay.gd").new()
	hud.add_child(desire_overlay)
	hud.reset_view_requested.connect(rig.reset_view)
	hud.tool_changed.connect(_set_tool)
	hud.idle_citizen_requested.connect(_select_next_idle_citizen)
	hud.level_changed.connect(func(value): level = value; world.display_level = value)
	hud.speed_changed.connect(func(value): speed = value)
	hud.leave_settlement_requested.connect(_leave_settlement)
	hud.structure_workshop_requested.connect(_open_structure_workshop)
	hud.upgrade_requested.connect(func():
		if selected_object.get("kind", "") == "house": model.request_build("house", selected_object.cell))
	hud.utilities_requested.connect(func():
		var homes=preload("res://scripts/settlement/home_assembly.gd")
		var uid: int=model.buildings.get(selected_object.get("cell"),{}).get("home_uid",-1)
		var context=homes.context_for(model,uid)
		if context!=null: homes.U.install(context,homes.U.owner_for(context,homes.U.room(context,uid))))
	hud.rain_edit_requested.connect(func():
		var cell: Vector3i=selected_object.get("cell",Vector3i.ZERO)
		if selected_object.get("kind")=="support": cell+=Vector3i.UP
		rain_editor.begin(cell))
	hud.relocation_requested.connect(_begin_relocation)
	hud.copy_requested.connect(_copy_selected_building)
	hud.removal_requested.connect(_remove_selected_building)
	hud.finish_requested.connect(_finish_selected_building)
	hud.collect_water_requested.connect(func(cell):
		model.request_collect_water(cell)
		_message(model.last_message)
	)
	menu = CanvasLayer.new()
	menu.set_script(MainMenu)
	menu.hotkeys = hotkeys
	add_child(menu)
	menu.root.theme = hud.root.theme
	loading_overlay = preload("res://scripts/settlement/loading_overlay.gd").new()
	add_child(loading_overlay)
	loading_overlay.root.theme = hud.root.theme
	menu.resume_requested.connect(_resume_game)
	menu.slot_requested.connect(_choose_slot)
	menu.delete_slot_requested.connect(_delete_slot)
	menu.settings_changed.connect(_change_settings)
	menu.quit_requested.connect(_quit_game)
	menu.structure_workshop_requested.connect(_open_structure_workshop)
	saves.directory = slot_directory
	get_tree().auto_accept_quit = false
	capture = OS.get_cmdline_user_args().has("--capture")
	gallery = gallery or OS.get_cmdline_user_args().has("--gallery")
	showcase = showcase or OS.get_cmdline_user_args().has("--showcase")
	if showcase:
		_build_showcase()
	if gallery:
		_show_gallery()
	if capture:
		for index in 100:
			model.tick(0.05)
		selected = 0
		world.show_routes = true
		selected_object = {}
	if launch_to_menu and not capture and not gallery and not showcase:
		preferences = saves.read_settings()
		_apply_settings()
		if slot_directory == "user://settlements":
			saves.import_legacy("user://terraces_save.json")
		_open_menu()
		menu.show_page("home")
	if OS.get_cmdline_user_args().has("--capture-menu"):
		_open_menu()
	if OS.get_cmdline_user_args().has("--structure-editor"):
		_open_structure_workshop()
	# Retain saved room rendering and the isolated prototype; normal play has no room editor entry.
	room_editor=preload("res://scripts/settlement/room_editor.gd").new()
	add_child(room_editor); room_editor.setup(self)
	generated_building_tool=preload("res://scripts/settlement/generated_building_tool.gd").new()
	add_child(generated_building_tool); generated_building_tool.setup(self)
	rain_editor=preload("res://scripts/settlement/roof_rain_editor.gd").new(); add_child(rain_editor); rain_editor.setup(self)
	setup_complete = true

func _process(delta: float) -> void:
	if operation_busy:
		return
	_poll_autosave()
	var frame_started := Perf.begin()
	var section_started := Perf.begin()
	var paused_by_menu: bool = menu.visible or (is_instance_valid(structure_workshop) and structure_workshop.is_open())
	if not paused_by_menu:
		rig.world_limit = float(Model.Generator.WORLD_LIMIT if model.streaming_enabled else Model.Catalog.WORLD_RADIUS) * Navigation.CELL_SIZE
		if room_editor==null or not room_editor.active or (room_editor.shape.is_empty() and room_editor.edit_action.is_empty()):
			rig.advance(delta)
	Perf.end("camera", section_started)
	if not gallery:
		section_started = Perf.begin()
		var visual_delta := 0.0 if paused_by_menu else _advance_simulation(delta)
		Perf.end("simulation", section_started)
		section_started = Perf.begin()
		var showing_preview: bool = menu.visible and menu_preview != null
		var displayed_model = menu_preview if showing_preview else model
		if not paused_by_menu and not capture:
			var radius := _streaming_radius()
			chunk_loader.advance(model, rig.focus, radius)
		Perf.end("streaming", section_started)
		section_started = Perf.begin()
		world.fog_enabled = not showing_preview and not gallery
		fog.sync(displayed_model, world.fog_enabled, rig.focus)
		Perf.end("fog", section_started)
		section_started = Perf.begin()
		world.planning = not showing_preview and tool not in ["inspect", "remove"]
		world.sync(displayed_model, visual_delta, -1 if showing_preview else selected)
		if room_editor!=null: room_editor.sync()
		Perf.end("world_view", section_started)
		section_started = Perf.begin()
		world.water_view.rain.position = Vector3(rig.focus.x, 36.0, rig.focus.z)
		soundscape.update(model, rig.camera, rig.focus, delta, not paused_by_menu and speed > 0 and not capture)
		Illustration.update(world_container.material, displayed_model.time)
		Perf.end("audio_and_lighting", section_started)
		section_started = Perf.begin()
		if selected_object.has("bridge_id"):
			var bridge_id: int = selected_object.bridge_id
			if Model.RopeBridges.get_record(model, bridge_id).is_empty(): selected_object = {}
			elif model.bridges.has(bridge_id): selected_object.entity_key = "bridge:%d" % bridge_id
		if not showing_preview and not selected_object.has("bridge_id") and not selected_object.has("worker_id") and not selected_object.get("entity_key", "").is_empty() and not world.entity_views.has(selected_object.entity_key):
			selected_object = {}
		for id in selected_workers:
			if not showing_preview and id < world.actors.size():
				world.actors[id].ring.visible = model.can_control(model.workers[id])
		if selected_object.has("worker_id") and selected_object.worker_id < world.actors.size():
			world.actors[selected_object.worker_id].ring.visible = true
		var hud_started := Perf.begin()
		citizen_outline.sync(world, rig.camera, displayed_model, not paused_by_menu)
		Perf.end("hud.citizen_outline", hud_started)
		hud_started = Perf.begin()
		desire_overlay.sync(world, rig.camera, displayed_model, not paused_by_menu, delta)
		Perf.end("hud.desires", hud_started)
		hud_started = Perf.begin()
		hud.update(model, selected, speed, selected_object)
		Perf.end("hud.values", hud_started)
		hud.update_selection(world, rig.camera, selected_object, model)
		Perf.end("hud", section_started)
		section_started = Perf.begin()
		if not paused_by_menu:
			_update_hover()
		else:
			hud.update_placement_outline(rig.camera)
			bridge_editor.update(_viewport_mouse(), false)
			if is_instance_valid(preview): preview.hide()
			preload("res://scripts/settlement/well_shaft.gd").sync(world, model, {})
			hud.update_ground_hover(rig.camera, null)
			hud.update_object_hover(world, rig.camera, model, selected_object, {})
		Perf.end("hover", section_started)
		section_started = Perf.begin()
		if session_started and not paused_by_menu:
			autosave_elapsed += delta
			if autosave_elapsed >= SaveSlots.AUTOSAVE_SECONDS:
				autosave_elapsed = 0.0
				if not autosave():
					_open_menu(false)
					menu.status.text = tr("settlement_autosave_failed_text")
		Perf.end("autosave", section_started)
		message_timer = maxf(0.0, message_timer - delta)
	if gallery:
		for entry: Dictionary in gallery_labels:
			entry.label.position = rig.camera.unproject_position(entry.anchor) * Vector2(get_viewport().get_visible_rect().size) / Vector2(viewport.size) - Vector2(85, 0)
	if capture:
		capture_frames += 1
		if capture_frames == 90:
			_capture.call_deferred()

	Perf.end("frame_cpu", frame_started)
	Perf.frame(delta, model, viewport, accumulator)

func _streaming_radius() -> int:
	# Cover the camera footprint at both desert and summit height, plus one
	# chunk of prefetch. Zoom/aspect/pitch changes must not reveal missing land.
	var extent := 0.0
	var size_: Vector2 = viewport.size
	for corner in [Vector2.ZERO, Vector2(size_.x, 0), size_, Vector2(0, size_.y)]:
		var origin: Vector3 = rig.camera.project_ray_origin(corner)
		var ray: Vector3 = rig.camera.project_ray_normal(corner)
		if absf(ray.y) < 0.001: continue
		for height in [0.0, Model.Generator.MAX_HEIGHT * Navigation.LEVEL_HEIGHT]:
			var point: Vector3 = origin + ray * ((height - origin.y) / ray.y)
			extent = maxf(extent, maxf(absf(point.x - rig.focus.x), absf(point.z - rig.focus.z)))
	return maxi(2, ceili(extent / (Model.Generator.CHUNK_SIZE * Navigation.CELL_SIZE)) + 1)

func _advance_simulation(delta: float) -> float:
	# Speed changes how many fixed steps run, never the size of a gameplay step.
	# Keep slow-frame debt for later frames instead of silently losing game time.
	var previous_fraction := minf(accumulator, SIMULATION_STEP)
	accumulator += maxf(0.0, delta) * speed
	var steps := mini(MAX_STEPS_PER_FRAME, int(floor((accumulator + 0.000000001) / SIMULATION_STEP)))
	for index in steps:
		model.tick(SIMULATION_STEP)
	accumulator = maxf(0.0, accumulator - steps * SIMULATION_STEP)
	# Smooth between ticks, but don't animate ahead of a simulation catching up.
	return maxf(0.0, steps * SIMULATION_STEP + minf(accumulator, SIMULATION_STEP) - previous_fraction)

func _input(event: InputEvent) -> void:
	# Rendering setup can dispatch input before _ready has built the UI and rig.
	if not setup_complete or operation_busy:
		return
	if is_instance_valid(structure_workshop) and structure_workshop.is_open():
		return
	if menu.visible and (not menu.capturing_action.is_empty() or menu.current_page == "hotkeys"):
		return
	if generated_building_tool!=null and generated_building_tool.active and event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:
		generated_building_tool.cancel(); get_viewport().set_input_as_handled(); return
	if rain_editor!=null and rain_editor.active and event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:
		rain_editor.handle(event); get_viewport().set_input_as_handled(); return
	if room_editor!=null and room_editor.active and not menu.visible and event is InputEventKey and event.pressed and Hotkeys.keycode(event)==KEY_ESCAPE:
		room_editor.cancel(); get_viewport().set_input_as_handled(); return
	if hotkeys.matches(event, "blueprints"):
		_open_structure_workshop()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and not event.pressed:
		if event.button_index in [MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			rig.rotating = false
		if event.button_index == MOUSE_BUTTON_LEFT and left_selecting and get_viewport().gui_get_hovered_control() != null:
			left_selecting = false
			hud.selection_drag = Rect2()
	if event is InputEventKey and event.pressed and not event.echo and Hotkeys.keycode(event) == KEY_ESCAPE and not gallery:
		if menu.visible:
			menu.escape()
		else:
			_clear_selection()
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if not setup_complete or operation_busy:
		return
	if menu.visible or (is_instance_valid(structure_workshop) and structure_workshop.is_open()):
		return
	if rain_editor!=null:
		if rain_editor.active: rig.handle(event)
		if rain_editor.handle(event): return
	if generated_building_tool!=null and generated_building_tool.active:
		rig.handle(event); generated_building_tool.handle(event); return
	if generated_building_tool!=null and tool=="inspect" and generated_building_tool.handle_fixture(event): return
	if room_editor!=null and room_editor.active:
		if event is InputEventMouseButton or event is InputEventMouseMotion: rig.handle(event)
		room_editor.handle(event); return
	if tool=="support" and moving_plan_id == -1 and relocation_source == null and event is InputEventKey and event.pressed and event.keycode in [KEY_BRACKETLEFT,KEY_BRACKETRIGHT]:
		support_yaw=clampf(support_yaw+deg_to_rad(-2.0 if event.keycode==KEY_BRACKETLEFT else 2.0),-PI/12,PI/12)
		_refresh_preview(); return
	rig.handle(event)
	if hotkeys.matches(event, "move"): _begin_relocation()
	elif hotkeys.matches(event, "remove"):
		if tool == "inspect": _remove_selected_building()
	elif hotkeys.matches(event, "rotate_remove"):
		if tool == "inspect": _remove_selected_building()
		else:
			direction = (direction + 1) % 4
			_refresh_preview()
	elif hotkeys.matches(event, "floor_down"): hud.set_level(level - 1)
	elif hotkeys.matches(event, "floor_up"): hud.set_level(level + 1)
	elif hotkeys.matches(event, "copy_cutaway"):
		if _selected_building_kind().is_empty(): world.cutaway = not world.cutaway
		else: _copy_selected_building()
	elif hotkeys.matches(event, "build"): hud.build_panel.visible = not hud.build_panel.visible
	elif hotkeys.matches(event, "inspect"): _set_tool("inspect")
	if bridge_editor.active() and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed: bridge_editor.click(_viewport_mouse())
		return
	if event is InputEventMouseMotion and left_selecting:
		hud.selection_drag = Rect2(left_origin, get_viewport().get_mouse_position() - left_origin).abs()
		hud.selection_outline.queue_redraw()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed:
			right_origin = get_viewport().get_mouse_position()
		elif get_viewport().get_mouse_position().distance_to(right_origin) < 6.0:
			if tool != "inspect":
				_set_tool("inspect")
			else:
				_command_selected()
	if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT and left_selecting:
		left_selecting = false
		var rect := Rect2(left_origin, get_viewport().get_mouse_position() - left_origin).abs()
		hud.selection_drag = Rect2()
		if rect.size.length() > 10:
			if not event.shift_pressed:
				selected_workers.clear()
			for worker in model.workers:
				var screen: Vector2 = rig.camera.unproject_position(worker.position + Vector3.UP * 0.6) * Vector2(get_viewport().get_visible_rect().size) / Vector2(viewport.size)
				if model.can_control(worker) and rect.has_point(screen) and worker.id not in selected_workers:
					selected_workers.append(worker.id)
			selected = selected_workers[0] if not selected_workers.is_empty() else -1
			selected_object = {}
		else:
			_select_worker(event.shift_pressed)
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_update_hover()
		if tool == "inspect":
			left_origin = get_viewport().get_mouse_position()
			left_selecting = true
		elif hover_valid:
			if tool in Model.TerrainEditor.TOOL_KINDS:
				if Model.TerrainEditor.apply_edit(model, hovered, tool):
					world.sync(model, 0.0, selected)
			elif moving_plan_id != -1:
				_commit_plan_move(hovered, hover_offset)
			elif not house_stamp.is_empty():
				if Model.Houses.request(model, house_stamp, hovered, direction, hover_offset, relocation_source != null):
					if relocation_source != null: _set_tool("inspect")
			elif relocation_source != null:
				if model.Relocation.request(model, relocation_source, hovered, direction, hover_offset):
					selected_object = {"cell": hovered, "kind": tool, "entity_key": "plan:%s" % (model.next_plan_id - 1)}
					_set_tool("inspect")
			elif tool == "remove":
				model.Deconstruction.request(model, hovered)
			else:
				if model.request_build(tool, hovered, direction, hover_offset,true,support_yaw if tool=="support" else 0.0) and tool == "seed_bush": _refresh_preview()
			_message(model.last_message)

func _select_next_idle_citizen() -> void:
	var idle_ids: Array[int] = model.idle_citizen_ids()
	if idle_ids.is_empty():
		hud.update(model, selected, speed, selected_object)
		return
	var next_id := idle_ids[0]
	for id in idle_ids:
		if id > last_idle_citizen:
			next_id = id
			break
	_clear_selection()
	selected = next_id
	selected_workers.assign([next_id])
	last_idle_citizen = next_id
	rig.focus = model.workers[next_id].position
	rig.update_camera()
	world.actors[next_id].ring.show()
	hud.update(model, selected, speed, selected_object)
	hud.update_selection(world, rig.camera, selected_object, model)

func _clear_selection() -> void:
	selected = -1
	selected_workers.clear()
	selected_object = {}
	left_selecting = false
	rig.rotating = false
	hover_valid = false
	hud.selection_drag = Rect2()
	hud.update_ground_hover(rig.camera, null)
	_set_tool("inspect")
	for actor in world.actors:
		actor.ring.hide()
	hud.update(model, selected, speed, selected_object)
	hud.update_selection(world, rig.camera, selected_object, model)
	hud.update_object_tooltips(world, rig.camera, model, selected_object)

func _set_tool(kind: String) -> void:
	if rain_editor!=null: rain_editor.cancel()
	hud.set_housing_preview(model,0)
	if generated_building_tool!=null:
		generated_building_tool.cancel()
		if kind=="generated_plan":
			_set_tool("inspect"); room_editor.set_active(false); generated_building_tool.begin(); return
	bridge_editor.reset()
	if room_editor!=null and kind!="inspect": room_editor.set_active(false)
	house_stamp = []
	relocation_source = null
	moving_plan_id = -1
	tool = kind
	hud.select_tool(kind)
	_refresh_preview()

func _begin_relocation() -> void:
	if selected_object.has("bridge_id"):
		bridge_editor.begin_move(selected_object.bridge_id); return
	var plan_id := _selected_plan_id()
	var pending_move: Dictionary = model.Relocation.pending_move(model, selected_object.cell) if selected_object.has("cell") and plan_id == -1 else {}
	if not pending_move.is_empty() and HouseSelection.members(model, selected_object).size() > 1: return
	if not pending_move.is_empty():
		if not model.Relocation.source_error(model, selected_object.cell, true).is_empty(): return
		plan_id = pending_move.id
	if plan_id != -1:
		var plan: Dictionary = pending_move if not pending_move.is_empty() else model.editable_plan(plan_id)
		if plan.is_empty(): return
		_set_tool(plan.kind)
		moving_plan_id = plan_id
		if not pending_move.is_empty(): relocation_source = pending_move.relocation.source
		direction = plan.direction
		support_yaw=float(plan.get("support_yaw",0.0))
		selected = -1
		selected_workers.clear()
		hud.build_panel.hide()
		_refresh_preview()
		return
	if not selected_object.has("cell"): return
	var cell: Vector3i = selected_object.cell
	if selected_object.get("kind") == "hay_field" and model.Relocation.kind_at(model, cell) != "hay_field": return
	if not model.Relocation.source_error(model, cell).is_empty(): return
	if HouseSelection.is_house(selected_object) and not HouseSelection.source_error(model, selected_object).is_empty(): return
	if model.deposits.get(cell, {}).get("kind") == "berry":
		if model.replant_bush(cell):
			hud.update(model, selected, speed, selected_object)
		return
	_set_tool(model.Relocation.kind_at(model, cell))
	relocation_source = cell
	if tool == "house": house_stamp = Model.Houses.stamp(model, cell, HouseSelection.members(model, selected_object))
	direction = int(model.buildings.get(cell, {}).get("direction", model.stairs.get(cell, 0)))
	support_yaw=float(model.buildings.get(cell,{}).get("support_yaw",0.0))
	selected = -1
	selected_workers.clear()
	hud.build_panel.hide()
	_refresh_preview()

func _selected_plan_id() -> int:
	var key := str(selected_object.get("entity_key", ""))
	return int(key.trim_prefix("plan:")) if selected < 0 and key.begins_with("plan:") else -1

func _commit_plan_move(cell: Vector3i, offset: Vector3) -> bool:
	if not model.move_plan(moving_plan_id, cell, direction, offset): return false
	selected_object = {"cell": cell, "kind": tool, "entity_key": "plan:%s" % moving_plan_id}
	_set_tool("inspect")
	return true

func _selected_building_kind() -> String:
	if selected >= 0 or not selected_object.has("cell") or str(selected_object.get("entity_key", "")).begins_with("plan:"): return ""
	var cell: Vector3i = selected_object.cell
	if model.Relocation.locked(model, cell) and model.Relocation.pending_move(model, cell).is_empty(): return ""
	var kind: String = model.Relocation.kind_at(model, cell)
	if selected_object.get("kind") == "hay_field" and kind != "hay_field": return ""
	return kind if kind in Model.Catalog.COSTS else ""

func _copy_selected_building() -> void:
	var kind := _selected_building_kind()
	if kind.is_empty() or not model.building_unlocked(kind): return
	var cell: Vector3i = selected_object.cell
	direction = int(model.buildings.get(cell, {}).get("direction", model.stairs.get(cell, 0)))
	support_yaw=float(model.buildings.get(cell,{}).get("support_yaw",0.0))
	if kind == "garden" and model.gardens[cell].has("species"):
		if model.gardens[cell].species == "grass": return
		kind = "seed_vegetables"
	_set_tool(kind)
	if kind == "house": house_stamp = Model.Houses.stamp(model, cell, HouseSelection.members(model, selected_object))
	_refresh_preview()
	selected_workers.clear()
	hud.build_panel.hide()

func _remove_selected_building() -> void:
	if selected_object.has("bridge_id"):
		var id: int = selected_object.bridge_id
		var removed: bool = model.delete_plan(id) if model.plans.has(id) else Model.RopeBridges.remove(model, id)
		if removed: _clear_selection(); world.sync(model, 0, selected)
		else: _message(model.last_message)
		return
	var plan_id := _selected_plan_id()
	if plan_id != -1:
		if not model.delete_plan(plan_id): return
		_clear_selection()
		world.sync(model, 0, selected)
		return
	if _selected_building_kind().is_empty(): return
	var cell: Vector3i = selected_object.cell
	if HouseSelection.is_house(selected_object):
		if not Model.Houses.remove(model, cell, HouseSelection.members(model, selected_object)): return
	elif not model.Deconstruction.request(model, cell): return
	selected_object = {"cell": cell, "kind": model.plans[model.next_plan_id - 1].kind, "entity_key": "plan:%s" % (model.next_plan_id - 1)}
	_set_tool("inspect")
	hud.update(model, selected, speed, selected_object)
	world.sync(model, 0, selected)

func _finish_selected_building() -> void:
	if not model.debug_finish_plan(_selected_plan_id()): return
	_clear_selection()
	world.sync(model, 0, selected)

func _refresh_preview() -> void:
	hud.update_placement_outline(rig.camera)
	if is_instance_valid(preview):
		preview.free()
	if tool == "inspect" or tool == "remove":
		return
	if tool in ["rope_bridge", "rope_bridge_move"]: return
	preview_error = "uninitialised"
	if tool in Model.TerrainEditor.TOOL_KINDS:
		preview = Node3D.new()
		var cube_view := MeshInstance3D.new()
		cube_view.mesh = BoxMesh.new()
		cube_view.position.y = 0.5
		cube_view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		preview.add_child(cube_view)
		world.add_child(preview)
		preview.hide()
		return
	var asset_kind: String = model.construction_kind(tool, hovered)
	if tool == "vine_tree": asset_kind = "seed_vine"
	if tool == "tree" and relocation_source != null: asset_kind = preload("res://scripts/settlement/tree_view.gd").asset(model.trees[relocation_source])
	if tool == "garden" and relocation_source != null and model.gardens[relocation_source].get("species") == "grass": asset_kind = "grass_patch"
	var bush_payload: Dictionary = {}
	if tool == "seed_bush":
		if moving_plan_id != -1: bush_payload = model.plans.get(moving_plan_id, {}).get("bush_payload", {})
		elif not model.uprooted_bushes.is_empty(): bush_payload = model.uprooted_bushes[0]
	preview = Assets.create("berry" if tool == "seed_bush" else asset_kind)
	preview.set_meta("placement_kind", "vine_tree" if tool == "vine_tree" else asset_kind)
	if house_stamp.size() > 1:
		preview.free()
		preview = Node3D.new()
		var cells := {}
		var rooms := Model.Houses.targets(house_stamp, Vector3i.ZERO, 0)
		for room: Dictionary in rooms: cells[room.cell] = true
		for room: Dictionary in rooms:
			var asset := Assets.create("house")
			asset.position = Navigation.point(room.cell)+room.offset_delta
			asset.rotation.y = -int(room.direction) * PI * 0.5
			preview.add_child(asset)
			var neighbours: Array = []
			for side: Vector3i in Model.Houses.SIDES:
				if cells.has(room.cell + side * 2): neighbours.append(side)
			WorldView.HouseShell.apply(asset, neighbours, [Model.Houses.SIDES[room.direction]])
		var logical := {}
		for cell: Vector3i in cells: logical[Vector3i(int(cell.x / 2.0), int(cell.y / 2.0), int(cell.z / 2.0))] = true
		var edges := HUD.PlacementOutline.cell_edges(logical)
		for edge in edges:
			for i in edge.size(): edge[i] *= 2.0
		preview.set_meta("placement_edges", edges)
	if tool == "tree" and relocation_source != null:
		preload("res://scripts/settlement/tree_view.gd").sync(preview, model.trees[relocation_source])
	if tool == "berry" and relocation_source != null:
		for child in preview.get_children():
			if child is MeshInstance3D and str(child.name).begins_with("Berry"):
				child.visible = int(str(child.name).trim_prefix("Berry")) < model.deposits[relocation_source].inventory.count("food")
	if tool == "seed_bush":
		WorldView.BushView.sync(preview, Vector3i.ZERO, model.world_seed)
		if not bush_payload.is_empty(): WorldView.BushView.transplant(preview, bush_payload)
	viewport.add_child(preview)
	if asset_kind == "house" and house_stamp.size() <= 1:
		var appearance_model = Model.new()
		var roof_level := preload("res://scripts/settlement/house_tiers.gd").tier(model.buildings.get(relocation_source, {})) if relocation_source != null else 1
		appearance_model.buildings[Vector3i.ZERO] = {"kind": "house", "direction": 0, "house_tier": roof_level}
		preview.set_meta("asset", "house"); preview.set_meta("cell", Vector3i.ZERO)
		preload("res://scripts/settlement/house_roofs.gd").sync(appearance_model, {Vector3i.ZERO: preview})

func _viewport_mouse() -> Vector2:
	return world_container.viewport_point(get_viewport().get_mouse_position(), viewport)

func placement_at(mouse: Vector2, require_revealed := true) -> Dictionary:
	if tool in Model.TerrainEditor.TOOL_KINDS: return terrain_placement_at(mouse, require_revealed)
	var origin: Vector3 = rig.camera.project_ray_origin(mouse)
	var ray: Vector3 = rig.camera.project_ray_normal(mouse)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + ray * 300.0, 3 if tool not in ["inspect", "remove"] else 1)
	var hit := viewport.world_3d.direct_space_state.intersect_ray(query)
	# Trees remain selectable, but placement looks through every canopy to the
	# actual surface behind it. Keep the original ray so the cursor never shifts.
	while tool not in ["inspect", "remove"] and not hit.is_empty() and (hit.collider.get_meta("kind", "") in (["tree", "vine_tree"] if tool in ["seed_vine", "vine_tree"] else ["tree"]) or (moving_plan_id != -1 and hit.collider.get_meta("entity_key", "") == "plan:%s" % moving_plan_id)):
		var excluded := query.exclude
		excluded.append(hit.rid)
		query.exclude = excluded
		hit = viewport.world_3d.direct_space_state.intersect_ray(query)
	if not hit.is_empty() and hit.collider.has_meta("cell"):
		var cell: Vector3i = hit.collider.get_meta("cell")
		var kind: String = hit.collider.get_meta("kind")
		if require_revealed and not model.exploration.contains(Navigation.point(cell)):
			return {}
		# Aim at the open frame's side to restore its deck; the top still stacks.
		if tool == "support" and kind == "support" and relocation_source == null and moving_plan_id == -1 and hit.normal.y < 0.5 and not model.StructureLayout.has_deck(model, cell):
			return _placement_result(cell, kind, origin, ray)
		if tool != "remove" and hit.normal.y > 0.5 and (kind in Model.Catalog.ROOFS or kind == "platform"):
			cell.x = roundi(hit.position.x / Navigation.CELL_SIZE)
			cell.z = roundi(hit.position.z / Navigation.CELL_SIZE)
		if kind == "limestone" and tool not in ["inspect", "remove"] and hit.normal.y > 0.5:
			var top := Vector3i(roundi(hit.position.x / Navigation.CELL_SIZE), roundi(hit.position.y / Navigation.LEVEL_HEIGHT), roundi(hit.position.z / Navigation.CELL_SIZE))
			if model.rock_supports(top): cell = top
		if tool in ["seed_vine", "vine_tree"]:
			var placement := _placement_result(cell, kind, origin, ray)
			if require_revealed and not model.exploration.contains(Navigation.point(placement.cell) + placement.offset): return {}
			return placement
		return _placement_result(model.snap_cell(tool, kind, cell, model.Platforms.tier(model.platforms[relocation_source]) if tool == "platform" and relocation_source != null else 1), kind, origin, ray)
	# The sea plane wins over submerged terrain when placing a pier.
	if tool == "support" and (hit.is_empty() or hit.get("position", Vector3.ZERO).y < preload("res://scripts/settlement/support_foundation.gd").water_level(model)):
		var sea: Variant = Plane(Vector3.UP, preload("res://scripts/settlement/support_foundation.gd").water_level(model)).intersects_ray(origin, ray)
		if sea != null:
			var cell := Vector3i(roundi(sea.x), 0, roundi(sea.z))
			if model.Volume.shore_platform(model, cell) and (not require_revealed or model.exploration.contains(sea)):
				return _placement_result(cell, "water", origin, ray)
	if not hit.is_empty() and hit.collider.has_meta("terrain"):
		if model.SolidIslands.enabled(model) and tool=="support" and hit.normal.y<0.5:
			if require_revealed and not model.exploration.contains(hit.position): return {}
			var inside: Vector3=hit.position-hit.normal*0.05
			var cell:=Vector3i(roundi(inside.x),floori(hit.position.y+0.001),roundi(inside.z))
			var nudge:=Vector3(clampf(snappedf(inside.x-cell.x,0.1),-0.5,0.5),0,clampf(snappedf(inside.z-cell.z,0.1),-0.5,0.5))
			return {"cell":cell,"support":"ground","offset":nudge}
		if hit.normal.y < 0.5: return {}
		var cell: Vector3i = terrain_floor_at(hit.position)
		if require_revealed and not model.exploration.contains(hit.position):
			return {}
		return _placement_result(model.snap_cell(tool, "ground", cell, model.Platforms.tier(model.platforms[relocation_source]) if tool == "platform" and relocation_source != null else 1), "ground", origin, ray)
	var ground: Variant = Plane(Vector3.UP, 0).intersects_ray(origin, ray)
	if ground == null:
		return {}
	var ground_cell := Vector3i(roundi(ground.x / Navigation.CELL_SIZE), 0, roundi(ground.z / Navigation.CELL_SIZE))
	if (not model.ground.has(ground_cell) and not (tool in ["platform", "support"] and model.Volume.shore_platform(model, ground_cell))) or (require_revealed and not model.exploration.contains(ground)):
		return {}
	return _placement_result(model.snap_cell(tool, "ground", ground_cell, model.Platforms.tier(model.platforms[relocation_source]) if tool == "platform" and relocation_source != null else 1), "ground", origin, ray)

func _placement_result(cell: Vector3i, support: String, origin: Vector3, ray: Vector3) -> Dictionary:
	# Use the target floor plane, including when the ray first hits a facade.
	var cursor: Variant = Plane(Vector3.UP, preload("res://scripts/settlement/support_foundation.gd").water_level(model) if support == "water" else cell.y * Navigation.LEVEL_HEIGHT + preload("res://scripts/settlement/structure_elevation.gd").base_shift(model,cell,tool,direction)).intersects_ray(origin, ray)
	if tool == "hay_barn" and cursor != null:
		var attachment := preload("res://scripts/settlement/hay_barn_view.gd").attachment(model, cell, cursor, direction)
		if not attachment.is_empty():
			attachment.support = support
			return attachment
	if tool in ["seed_vine", "vine_tree"] and cursor != null:
		cell = model.surface_at(roundi(cursor.x / Navigation.CELL_SIZE), roundi(cursor.z / Navigation.CELL_SIZE))
		cursor = Plane(Vector3.UP, cell.y * Navigation.LEVEL_HEIGHT).intersects_ray(origin, ray)
	var offset: Vector3 = Vector3.ZERO if cursor == null else model.placement_offset(tool, cell, cursor)
	if tool=="support" and model.buildings.get(cell+Vector3i.DOWN,{}).get("kind","")=="support":
		offset=model.buildings[cell+Vector3i.DOWN].get("placement_offset",Vector3.ZERO)
	if tool=="support" and cursor!=null and Input.is_key_pressed(KEY_SHIFT):
		var delta: Vector3 = cursor-Navigation.point(cell)
		offset=Vector3(clampf(delta.x,-0.5,0.5),0,clampf(delta.z,-0.5,0.5))
	if tool == "house":
		offset = Model.Houses.stamp_offset(model, house_stamp, cell, direction, offset) if not house_stamp.is_empty() else Model.Houses.snap_offset(model, cell, direction, offset)
	return {"cell": cell, "support": support, "offset": offset}

func terrain_placement_at(mouse_position: Vector2, require_revealed := true) -> Dictionary:
	var ray_origin: Vector3 = rig.camera.project_ray_origin(mouse_position)
	var ray_direction: Vector3 = rig.camera.project_ray_normal(mouse_position)
	var ray_query := PhysicsRayQueryParameters3D.create(ray_origin, ray_origin + ray_direction * 300.0)
	var terrain_hit := viewport.world_3d.direct_space_state.intersect_ray(ray_query)
	if terrain_hit.is_empty() or not terrain_hit.collider.has_meta("terrain"): return {}
	var target_point: Vector3 = terrain_hit.position
	var side_face: bool = terrain_hit.normal.y < 0.5
	if side_face:
		if absf(terrain_hit.normal.y) > 0.1: return {}
		# Fill chooses the empty side, Dig the solid side. A surface-column
		# tool only changes the cube adjoining that column's current top.
		target_point += terrain_hit.normal * (0.01 if tool == "terrain_fill" else -0.01)
	var surface_cell: Vector3i = model.surface_at(roundi(target_point.x), roundi(target_point.z))
	var cube_bottom := surface_cell.y - (1 if tool == "terrain_dig" else 0)
	if side_face and (target_point.y < cube_bottom or target_point.y > cube_bottom + 1.0): return {}
	if not model.ground.has(surface_cell): return {}
	if require_revealed and not model.exploration.contains(terrain_hit.position): return {}
	return {"cell": surface_cell, "offset": Vector3.ZERO, "support": "ground"}

# Ground hover uses the terrain hit itself, never a room-sized placement socket.
func sand_cell_at(mouse: Vector2) -> Variant:
	var origin: Vector3 = rig.camera.project_ray_origin(mouse)
	var ray: Vector3 = rig.camera.project_ray_normal(mouse)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + ray * 300.0, 3)
	var hit := viewport.world_3d.direct_space_state.intersect_ray(query)
	if hit.is_empty() or not hit.collider.has_meta("terrain") or hit.normal.y < 0.99:
		return null
	var cell: Vector3i = terrain_floor_at(hit.position)
	if not model.ground.has(cell) or model.terrain_shapes.has(cell) or not model.exploration.contains(hit.position):
		return null
	if model.soil_enabled and model.soil_shapes.has(cell) and model.soil_shapes[cell].max() > cell.y + 0.0001:
		return null
	return cell

func _update_hover() -> void:
	if generated_building_tool!=null and (generated_building_tool.active or not generated_building_tool.service_hit.is_empty()):
		hud.set_housing_preview(model,0)
		return
	if room_editor!=null and room_editor.active:
		preload("res://scripts/settlement/well_shaft.gd").sync(world, model, {})
		hud.set_housing_preview(model,0)
		room_editor.update_hover(); return
	# Full-resolution controls must never leak mouse input into the pixel viewport.
	var over_ui := get_viewport().gui_get_hovered_control() != null
	var placing := tool not in ["inspect", "remove"]
	var pointer_active: bool = not over_ui and not left_selecting and not rig.rotating
	bridge_editor.update(_viewport_mouse(), pointer_active)
	if bridge_editor.active():
		hud.set_housing_preview(model,0)
		hud.update_ground_hover(rig.camera, null)
		hud.update_placement_outline(rig.camera)
		hud.update_object_tooltips(world, rig.camera, model, {}, {})
		return
	var hovered_object := object_at(_viewport_mouse()) if pointer_active and not placing else {}
	preload("res://scripts/settlement/well_shaft.gd").sync(world, model, hovered_object)
	hud.update_object_tooltips(world, rig.camera, model, selected_object, hovered_object)
	var ground_cell: Variant = sand_cell_at(_viewport_mouse()) if pointer_active and not placing and hovered_object.is_empty() else null
	hud.update_ground_hover(rig.camera, ground_cell)
	hud.update_placement_outline(rig.camera)
	var placement := placement_at(_viewport_mouse()) if pointer_active else {}
	hover_valid = not placement.is_empty()
	if is_instance_valid(preview):
		preview.visible = hover_valid
	if not hover_valid:
		hud.set_housing_preview(model,0)
		return
	hovered = placement.cell
	hover_offset = placement.offset
	if tool in Model.TerrainEditor.TOOL_KINDS:
		preview.position = Vector3(hovered) + (Vector3.DOWN if tool == "terrain_dig" else Vector3.ZERO)
		var terrain_error: String = Model.TerrainEditor.edit_error(model, hovered, tool)
		if preview_error != terrain_error:
			Assets.tint(preview, Color(0.75, 0.9, 0.75, 0.38) if terrain_error.is_empty() else Color(0.95, 0.40, 0.29, 0.38), true)
			preview_error = terrain_error
		hud.update_placement_outline(rig.camera, preview, tool, terrain_error.is_empty())
		return
	if is_instance_valid(preview) and preview.get_meta("placement_kind", tool) != model.construction_kind(tool, hovered):
		_refresh_preview()
	if is_instance_valid(preview):
		if tool == "stone_storage":
			var tier := mini(3, int(model.buildings.get(hovered, {}).get("storage_tier", 0)) + 1)
			if relocation_source != null: tier = int(model.buildings[relocation_source].get("storage_tier", 1))
			preload("res://scripts/settlement/stone_storage_view.gd").sync(preview, tier)
		if tool == "windmill":
			var mill_tier: int = mini(3, int(model.buildings[hovered].get("mill_tier", 3)) + 1) if model.buildings.get(hovered, {}).get("kind") == "windmill" else 1
			if relocation_source != null: mill_tier = int(model.buildings[relocation_source].get("mill_tier", 3))
			preload("res://scripts/settlement/mill_view.gd").sync(preview, mill_tier)
		if preview.get_meta("placement_kind", tool) == "sawmill":
			var saw_tier: int = 3 if tool == "house" else (2 if model.buildings.get(hovered, {}).get("kind") == "sawmill" else 1)
			if relocation_source != null: saw_tier = int(model.buildings.get(relocation_source, {}).get("sawmill_tier", 2))
			preload("res://scripts/settlement/sawmill_view.gd").sync(preview, saw_tier)
		if tool == "well":
			var count: int = model.Hydrology.units(model.buildings.get(hovered, {})) if model.wells.has(hovered) else 0
			count += model.Hydrology.units(model.buildings.get(relocation_source, {})) if relocation_source != null else 1
			var expected: int = model.Hydrology.capacity(model, hovered, count)
			preview.set_meta("expected_water_capacity", expected)
			preview.set_meta("expected_water_yield",model.Hydrology.rain_yield(model,hovered)*count)
			preload("res://scripts/settlement/well_view.gd").sync(preview, count, 0, expected)
		preview.position = Navigation.point(hovered) + hover_offset + Vector3.UP * preload("res://scripts/settlement/structure_elevation.gd").base_shift(model,hovered,tool,direction,hover_offset)
		var restoring_deck: bool = tool == "support" and relocation_source == null and moving_plan_id == -1 and model.buildings.get(hovered, {}).get("kind") == "support"
		if tool == "support": preload("res://scripts/settlement/structure_frame.gd").preview_deck(preview, restoring_deck)
		if tool in Model.Farming.GROUND_SEEDS and model.ground.has(hovered):
			preview.position.y = model.navigation.surface_height(hovered, preview.position)
		preview.rotation.y = -(preload("res://scripts/settlement/hay_barn_view.gd").direction_for(model, hovered, direction) if tool == "hay_barn" else direction) * PI * 0.5
		if tool == "platform":
			var platform_height: int = model.Platforms.tier(model.platforms[relocation_source]) if relocation_source != null else 1
			if model.Platforms.merge_base(model, hovered, platform_height, true, moving_plan_id) != hovered: platform_height = 2
			if preview.get_meta("platform_tier", 0) != platform_height: preview_error = "uninitialised"
			model.Platforms.sync(preview, platform_height)
		if tool == "stairs": preload("res://scripts/settlement/construction_variants.gd").stairs(preview, model.navigation.stair_landing(hovered, direction).y - hovered.y)
		if house_stamp.size() > 1:
			var rooms := Model.Houses.targets(house_stamp, hovered, direction)
			for index in rooms.size():
				Assets.Variation.apply(preview.get_child(index), "house", rooms[index].cell, model.world_seed)
		else:
			Assets.Variation.apply(preview, preview.get_meta("placement_kind", tool), hovered, model.world_seed)
		if preview.has_node("Floor"):
			preview.get_node("Floor").visible = tool in Model.Catalog.NATURAL_ROOFS or hovered.y > model.surface_at(hovered.x, hovered.z).y
		if tool=="support":
			preview.rotation.y=support_yaw
			if restoring_deck:
				preview.get_node("RestoreDeck").position.y = preload("res://scripts/settlement/support_foundation.gd").deck_drop(model,hovered,hover_offset,support_yaw)
				if preview.has_meta("placement_edges"): preview.remove_meta("placement_edges")
			elif preload("res://scripts/settlement/structure_frame.gd").sync_foundation(preview, model, hovered, hover_offset, support_yaw): preview_error = "uninitialised"
			if preview.has_node("Deck"): preview.get_node("Deck").rotation.y=(posmod(hash([model.world_seed,hovered]),2)+direction)*PI/2
		if tool=="house" and house_stamp.size()<=1 and preview.get_meta("placement_kind",tool)=="house":
			var tier: int=preload("res://scripts/settlement/house_tiers.gd").tier(model.buildings.get(relocation_source,{})) if relocation_source!=null else mini(3,int(model.buildings.get(hovered,{}).get("house_tier",0))+1)
			if preload("res://scripts/settlement/home_placement_preview.gd").sync(preview,model,hovered,direction,hover_offset,tier): preview_error="uninitialised"
		var error: String = model.Relocation.destination_error(model, relocation_source, hovered, direction, hover_offset) if relocation_source != null else model.build_error(tool, hovered, direction, hover_offset)
		if tool=="support" and error.is_empty() and not restoring_deck:
			error=preload("res://scripts/settlement/support_runtime.gd").foundation_error(model,hovered,hover_offset,support_yaw)
		if not house_stamp.is_empty():
			error = Model.Houses.placement_error(model, house_stamp, hovered, direction, hover_offset, relocation_source != null)
		if moving_plan_id != -1:
			error = model.move_plan_error(moving_plan_id, hovered, direction, hover_offset)
		elif relocation_source == null and not restoring_deck and not model.building_unlocked(model.construction_kind(tool, hovered)):
			error = "Build the material producer first"
		if preview_error != error:
			Assets.tint(preview, Color(0.75, 0.9, 0.75) if error.is_empty() else Color(0.95, 0.40, 0.29))
			preview_error = error
			if tool == "support" and preload("res://scripts/settlement/support_foundation.gd").water(model, hovered, hover_offset, support_yaw): preload("res://scripts/settlement/structure_frame.gd").wet_wood(preview, preload("res://scripts/settlement/support_foundation.gd").water_level(model))
		hud.set_housing_preview(model,Model.Houses.ROOM_RESIDENTS*maxi(1,house_stamp.size()) if tool=="house" and error.is_empty() and relocation_source==null and moving_plan_id==-1 and not model.buildings.has(hovered) else 0)
		hud.update_placement_outline(rig.camera, preview, tool, error.is_empty())
		if message_timer == 0:
			hud.status_label.text = Text.message(error) if not error.is_empty() else tr("settlement_place_hint_text") % ["0" if restoring_deck else Model.Catalog.cost_text(model.construction_kind(tool, hovered)), hovered.y]
	elif message_timer == 0:
		hud.status_label.text = tr("settlement_remove_hint_text") if tool == "remove" else tr("settlement_hint_text")

func _select_worker(additive := false, mouse := Vector2.INF) -> void:
	if mouse == Vector2.INF:
		mouse = _viewport_mouse()
	if not additive:
		selected_workers.clear()
	selected = -1
	var previous := selected_object
	selected_object = {}
	var target := object_at(mouse)
	if target.has("worker_id") and model.can_control(model.workers[target.worker_id]):
		selected = target.worker_id
		if selected not in selected_workers:
			selected_workers.append(selected)
	elif not target.is_empty():
		selected_object = HouseSelection.select(model, previous, target)
	if additive and not selected_workers.is_empty():
		selected = selected_workers[0]

# Hover and click share picking, including children who can be inspected but not ordered.
func object_at(mouse: Vector2) -> Dictionary:
	var result := {}
	var best := INF
	var origin: Vector3 = rig.camera.project_ray_origin(mouse)
	var direction_: Vector3 = rig.camera.project_ray_normal(mouse)
	for worker in model.workers:
		if worker.id >= world.actors.size() or not world.actors[worker.id].is_visible_in_tree():
			continue
		var actor = world.actors[worker.id]
		if (world.fog_enabled and not model.exploration.contains(actor.global_position)) or rig.camera.is_position_behind(actor.global_position):
			continue
		var distance: float = actor.pick_distance(origin, direction_)
		if distance < best:
			best = distance
			result = {"worker_id": worker.id}
	if not result.is_empty():
		return result
	var bridge_target: Dictionary = bridge_editor.object_at(mouse)
	if not bridge_target.is_empty(): return bridge_target
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction_ * 300.0, 3)
	var hit := viewport.world_3d.direct_space_state.intersect_ray(query)
	if not hit.is_empty() and hit.collider.has_meta("cell") and model.exploration.contains(Navigation.point(hit.collider.get_meta("cell"))):
		var cell: Vector3i = hit.collider.get_meta("cell")
		var kind: String = hit.collider.get_meta("kind")
		var key: String = hit.collider.get_meta("entity_key", "")
		return {"cell": cell, "kind": kind, "entity_key": key}
	return {}

# Commands pick entity floors, including plans; placement's roof snapping is unrelated.
func command_target_at(mouse: Vector2) -> Dictionary:
	var origin: Vector3 = rig.camera.project_ray_origin(mouse)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + rig.camera.project_ray_normal(mouse) * 300.0, 3)
	var hit := viewport.world_3d.direct_space_state.intersect_ray(query)
	if not hit.is_empty() and hit.collider.has_meta("cell"):
		var cell: Vector3i = hit.collider.get_meta("cell")
		if not model.exploration.contains(Navigation.point(cell)):
			return {"cell": model.surface_at(cell.x, cell.z), "explore": true}
		return {"cell": cell, "kind": hit.collider.get_meta("kind"), "entity_key": hit.collider.get_meta("entity_key", "")}
	if not hit.is_empty() and hit.collider.has_meta("terrain"):
		# Movement targets the actual talus hit, without placement's flat-floor rules.
		if hit.normal.y <= 0.05: return {}
		var cell: Vector3i = terrain_floor_at(hit.position)
		if not model.navigation.surfaces.has(cell): return {}
		return {"cell": cell, "explore": not model.exploration.contains(hit.position)}
	var target := placement_at(mouse, false)
	if not target.is_empty():
		target["explore"] = not model.exploration.contains(Navigation.point(target.cell))
	return target

func _command_selected() -> void:
	command_at(_viewport_mouse())

func command_at(mouse: Vector2) -> void:
	if selected_workers.is_empty():
		return
	var placement := command_target_at(mouse)
	if placement.is_empty():
		return
	var cell: Vector3i = placement.cell
	if placement.get("explore", false):
		# Same as the old app: a blind click is only a move order, never a hidden job.
		for id in selected_workers:
			if not model.navigation.route(model.workers[id].cell, cell).is_empty():
				model.set_role(id, "idle")
				model.order_move(id, cell)
		return
	var role := ""
	if model.trees.has(cell): role = "woodcutter"
	if model.deposits.has(cell): role = "forager" if model.deposits[cell].kind == "berry" else "miner"
	var kind: String = placement.get("kind", model.buildings.get(cell, {}).get("kind", ""))
	if model.gardens.has(cell) and kind in ["hay_field", "garden", "grass_patch"]: role = "farmer"
	if Model.Economy.is_workplace(kind): role = Model.Economy.workplace_role(kind)
	if kind == "mine_camp": role = "miner"
	if kind == "log_shed": role = "woodcutter"
	if kind == "hay_barn": role = "farmer"
	var destinations: Array[Vector3i] = [cell]
	var assigned_plan_id := -1
	for plan: Dictionary in model.plans.values():
		if placement.get("entity_key", "") == "plan:%s" % plan.id:
			role = "builder"
			assigned_plan_id = plan.id
			destinations = model.work_cells(plan.kind, plan.cell, plan.direction)
	var accepted := false
	for id in selected_workers:
		if assigned_plan_id != -1:
			accepted = model.order_build(id, assigned_plan_id) or accepted
			continue
		if Model.Economy.is_workplace(kind):
			accepted = model.order_workplace(id, cell) or accepted
			continue
		if kind in ["puddle", "stream", "well", "waterworks"] and model.Hydrology.inventory_at(model, cell) != null:
			accepted = model.order_collect_water(id, cell) or accepted
			continue
		var route: Array[Vector3i] = model.nearest_route(model.workers[id].cell, destinations)
		if route.is_empty():
			continue
		if model.set_role(id, "idle" if role.is_empty() else role):
			model.order_move(id, route.back())
			accepted = true
	_message("economy_order_text" if accepted else "waiting · destination unreachable")

func _message(value: String) -> void:
	hud.status_label.text = Text.message(value)
	message_timer = 4.0

func autosave() -> bool:
	# True means queued (or already saving); completion is handled by polling.
	if operation_busy: return false
	if not session_started or active_slot < 0 or autosave_worker.busy(): return true
	var started := Perf.begin()
	var record := {"format": 1, "difficulty": model.difficulty, "saved_at": Time.get_unix_time_from_system(),
		"elapsed": model.time, "view": _save_view().duplicate(true), "world": Model.SaveCodec.capture(model)}
	Perf.end("autosave.capture", started)
	var accepted: bool = autosave_worker.start(saves.directory, active_slot, record)
	if accepted: autosave_elapsed = 0.0
	return accepted

func _poll_autosave() -> void:
	var result: Dictionary = autosave_worker.poll()
	if not result.is_empty() and not result.success:
		_open_menu(false)
		menu.status.text = tr("settlement_autosave_failed_text")

func _wait_for_autosave() -> bool:
	# Serialize all slot writes/deletion. Exit always writes a fresh snapshot
	# after the periodic save, including progress made while it was running.
	while autosave_worker.busy():
		var result: Dictionary = autosave_worker.poll()
		if not result.is_empty(): return result.success
		await get_tree().process_frame
	return true

func _save_view() -> Dictionary:
	var view := {"focus": [rig.focus.x, rig.focus.y, rig.focus.z], "yaw": rig.yaw,
		"pitch": rig.pitch, "zoom": rig.zoom, "level": level, "cutaway": world.cutaway, "speed": speed}
	if menu.visible and not menu_return_view.is_empty():
		view.merge(menu_return_view, true)
	return view

func _background(action: Callable) -> Variant:
	operation_thread = Thread.new()
	if operation_thread.start(action) != OK:
		operation_thread = null
		return action.call()
	while operation_thread.is_alive():
		await get_tree().process_frame
	var result: Variant = operation_thread.wait_to_finish()
	operation_thread = null
	return result

func _loading_stage(label: String) -> void:
	loading_overlay.show_stage(label)
	# Let layout and a complete draw happen before snapshotting or scene work.
	await get_tree().process_frame
	await get_tree().process_frame

func _save_during_operation(slot: int, source, view: Dictionary = {}) -> bool:
	await _loading_stage("Saving…")
	await _wait_for_autosave()
	var snapshot := {"format": 1, "difficulty": source.difficulty, "saved_at": Time.get_unix_time_from_system(),
		"elapsed": source.time, "view": view.duplicate(true), "world": Model.SaveCodec.capture(source)}
	var result: Dictionary = await _background(autosave_worker._write.bind(saves.directory, slot, snapshot))
	if result.success: autosave_elapsed = 0.0
	return result.success

func _finish_operation() -> void:
	loading_overlay.hide()
	operation_busy = false
	if close_requested:
		close_requested = false
		_quit_game.call_deferred()

# Only private model data is touched on the worker. Precompute the deterministic
# chunk details here too, so the renderer never generates terrain on the UI thread.
static func _prepare_slot_model(next_model, storage, slot: int, create: bool, seed_value: int, difficulty: String) -> Dictionary:
	var data := {}
	if create:
		next_model.setup(seed_value, difficulty)
	else:
		data = storage.read_slot(slot, next_model)
		if data.is_empty(): return {}
	for chunk: Vector2i in next_model.loaded_chunks:
		if next_model.chunk_details.has(chunk): continue
		var generated := Model.Generator.generate_chunk(next_model.world_seed, chunk, next_model.difficulty, next_model.generator_version)
		next_model.chunk_details[chunk] = {"grass": generated.grass, "border": generated.border, "border_shapes": generated.border_shapes}
	return {"data": data}

func _prepare_menu_preview() -> void:
	if menu_preview == null:
		menu_preview = Model.new()
		var seed_value := randi()
		while seed_value == model.world_seed:
			seed_value = randi()
		menu_preview.setup(seed_value, "easy")
	if not menu.visible:
		menu_return_view = {"focus": [rig.focus.x, rig.focus.y, rig.focus.z],
			"yaw": rig.yaw, "pitch": rig.pitch, "zoom": rig.zoom, "cutaway": world.cutaway}
	rig.focus = Vector3(-6, 2, -1)
	rig.yaw = 1.0
	rig.pitch = 0.55
	rig.zoom = 78.0
	rig.update_camera()
	world.cutaway = false
	world.last_revision = -1
	world.fog_enabled = false
	fog.sync(menu_preview, false)
	world.sync(menu_preview, 0.0, -1)
	menu.set_preview_seed(menu_preview.world_seed)

func _open_menu(save_first := true) -> void:
	if room_editor!=null: room_editor.set_active(false)
	var saving := save_first and session_started and active_slot >= 0
	if saving and operation_busy: return
	var success := true
	if saving:
		operation_busy = true
		success = await _save_during_operation(active_slot, model, _save_view())
	rig.rotating = false
	_set_tool("inspect")
	hover_valid = false
	hud.visible = false
	_prepare_menu_preview()
	menu.open_menu(saves.entries(), session_started or showcase or not launch_to_menu, active_slot, preferences)
	if not success:
		menu.status.text = tr("settlement_autosave_failed_text")
	if saving: _finish_operation()

func _leave_settlement() -> void:
	if operation_busy: return
	operation_busy = true
	if session_started and active_slot >= 0 and not await _save_during_operation(active_slot, model, _save_view()):
		_finish_operation()
		_open_menu(false)
		menu.status.text = tr("settlement_autosave_failed_text")
		return
	session_started = false
	active_slot = -1
	selected = -1
	selected_workers.clear()
	selected_object = {}
	accumulator = 0.0
	rig.rotating = false
	_set_tool("inspect")
	hover_valid = false
	hud.visible = false
	menu_preview = null
	_prepare_menu_preview()
	menu_return_view = {}
	menu.open_menu(saves.entries(), false, -1, preferences)
	_finish_operation()

func _resume_game() -> void:
	if not session_started and not showcase and launch_to_menu:
		return
	if not menu_return_view.is_empty():
		_restore_view(menu_return_view)
	menu_return_view = {}
	menu_preview = null
	rig.update_camera()
	world.last_revision = -1
	world.fog_enabled = true
	fog.sync(model, true)
	world.sync(model, 0.0, selected)
	menu.visible = false
	hud.visible = true

func _delete_slot(slot: int) -> void:
	if operation_busy: return
	operation_busy = true
	await _wait_for_autosave()
	_delete_saved_slot(slot)
	_finish_operation()

func _delete_saved_slot(slot: int) -> void:
	if not saves.delete_slot(slot):
		menu.refresh_entries(saves.entries())
		menu.status.text = tr("settlement_slot_delete_failed_text")
		return
	if active_slot == slot:
		# End the in-memory session without autosaving the deleted settlement.
		session_started = false
		active_slot = -1
		selected = -1
		selected_workers.clear()
		selected_object = {}
		accumulator = 0.0
		autosave_elapsed = 0.0
		menu_return_view = {}
		menu.has_session = false
		menu.active_slot = -1
	menu.status.text = ""
	menu.refresh_entries(saves.entries())

func _choose_slot(slot: int, create: bool) -> void:
	if operation_busy or slot < 0 or slot >= SaveSlots.SLOT_COUNT:
		return
	# Check before saving or generating anything; a stale click cannot overwrite.
	if create and saves.occupied(slot):
		menu.status.text = tr("settlement_slot_exists_text")
		return
	operation_busy = true
	if session_started and active_slot >= 0 and not await _save_during_operation(active_slot, model, _save_view()):
		menu.status.text = tr("settlement_autosave_failed_text")
		_finish_operation()
		return
	var next_model = Model.new()
	var data := {}
	if create:
		await _loading_stage("Creating world…")
		if menu_preview == null:
			await _background(_prepare_slot_model.bind(next_model, saves, slot, true, randi(), menu.selected_difficulty))
		elif menu.selected_difficulty == menu_preview.difficulty:
			next_model = menu_preview
		else:
			var landscape_seed:=randi()
			while landscape_seed==menu_preview.world_seed: landscape_seed=randi()
			await _background(_prepare_slot_model.bind(next_model, saves, slot, true, landscape_seed, menu.selected_difficulty))
		if not await _save_during_operation(slot, next_model):
			menu.status.text = tr("settlement_autosave_failed_text")
			_finish_operation()
			return
	else:
		await _loading_stage("Loading world…")
		var prepared: Dictionary = await _background(_prepare_slot_model.bind(next_model, saves, slot, false, 0, "normal"))
		if prepared.is_empty():
			menu.status.text = tr("settlement_slot_damaged_text")
			_finish_operation()
			return
		data = prepared.data
	await _loading_stage("Preparing view…")
	# Budget scene construction across frames. All Node/GPU work stays on main.
	while not world.scenery.sync(next_model, 1):
		await get_tree().process_frame
	model = next_model
	model.set_debug_mode(bool(preferences.get("debug_mode", false)))
	last_idle_citizen = -1
	active_slot = slot
	session_started = true
	world.last_revision = -1
	accumulator = 0.0
	autosave_elapsed = 0.0
	selected = -1
	selected_workers.clear()
	selected_object = {}
	rig.focus = Vector3(-1, 1, 0)
	rig.yaw = -0.65
	rig.pitch = 0.68
	rig.zoom = 23.0
	speed = 1.0
	world.cutaway = false
	hud.set_level(1)
	menu_return_view = {}
	_restore_view(data.get("view", {}))
	rig.update_camera()
	_resume_game()
	if data.get("recovered", false):
		_message(tr("settlement_slot_recovered_text"))
	_finish_operation()

func _restore_view(view: Variant) -> void:
	if not view is Dictionary:
		return
	var focus: Variant = view.get("focus")
	if focus is Array and focus.size() == 3 and focus.all(func(v): return (v is float or v is int) and is_finite(v)):
		rig.focus = Vector3(clampf(focus[0], -Model.Catalog.WORLD_LIMIT * Navigation.CELL_SIZE, Model.Catalog.WORLD_LIMIT * Navigation.CELL_SIZE), clampf(focus[1], 0, 44), clampf(focus[2], -Model.Catalog.WORLD_LIMIT * Navigation.CELL_SIZE, Model.Catalog.WORLD_LIMIT * Navigation.CELL_SIZE))
	for key in ["yaw", "pitch", "zoom", "level", "speed"]:
		var value: Variant = view.get(key)
		if not (value is int or value is float) or not is_finite(value):
			continue
		match key:
			"yaw": rig.yaw = fmod(float(value), TAU)
			"pitch": rig.pitch = clampf(value, 0.4, 1.15)
			"zoom": rig.zoom = clampf(value, 10, 110)
			"level": hud.set_level(int(value))
			"speed": speed = float(value) if value in [1, 2, 4] else 1.0
	world.cutaway = bool(view.get("cutaway", false))

func _change_settings(values: Dictionary) -> void:
	if not saves.write_settings(values):
		menu.status.text = tr("settlement_settings_failed_text")
		return
	preferences = values
	_apply_settings()

func _apply_settings() -> void:
	model.set_debug_mode(bool(preferences.get("debug_mode", false)))
	soundscape.set_volume_percent(float(preferences.get("sound_effects", 100.0)))
	hotkeys.load_values(preferences.get("hotkeys", {}))
	menu.refresh_hotkeys()
	hud.refresh_hotkeys()
	world.show_routes = false
	if not capture and DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if preferences.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)

func _quit_game() -> void:
	if operation_busy:
		close_requested = true
		return
	operation_busy = true
	if session_started and active_slot >= 0 and not await _save_during_operation(active_slot, model, _save_view()):
		close_requested = false
		_finish_operation()
		_open_menu(false)
		menu.status.text = tr("settlement_autosave_failed_text")
		return
	await _loading_stage("Closing…")
	# A terrain worker can still be finishing. Wait with the window responsive.
	while chunk_loader.task_id >= 0 and not WorkerThreadPool.is_task_completed(chunk_loader.task_id):
		await get_tree().process_frame
	chunk_loader.finish()
	get_tree().quit()

func _notification(what: int) -> void:
	if not is_instance_valid(menu):
		return
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_quit_game()

func _show_gallery() -> void:
	world.visible = false
	hud.visible = false
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("d6c9af")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 0.7
	environment.environment = env
	viewport.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50, -30, 0)
	light.shadow_enabled = true
	viewport.add_child(light)
	var kinds := ["citizen_0", "citizen_1", "citizen_2", "tree", "palm", "well", "garden", "stockpile", "house", "sawmill", "table", "bed"]
	for index in kinds.size():
		var asset := Assets.create(kinds[index])
		asset.position = Vector3((index % 4) * 3.4 - 5.1, 0, floori(index / 4.0) * 5.2 - 5.2)
		if kinds[index].begins_with("citizen"):
			asset.scale = Vector3.ONE * 1.8
			asset.rotation.y = PI
		viewport.add_child(asset)
	var gallery_hud := CanvasLayer.new()
	add_child(gallery_hud)
	var title := Label.new()
	title.position = Vector2(28, 24)
	title.text = tr("settlement_gallery_title_text")
	title.add_theme_font_size_override("font_size", VisualTokens.UI_FONT_SIZE)
	gallery_hud.add_child(title)
	var subtitle := Label.new()
	subtitle.position = Vector2(28, 64)
	subtitle.text = tr("settlement_gallery_subtitle_text")
	gallery_hud.add_child(subtitle)
	for index in kinds.size():
		var caption := Label.new()
		caption.text = tr("settlement_asset_" + kinds[index] + "_text")
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.custom_minimum_size.x = 170
		caption.add_theme_font_size_override("font_size", VisualTokens.UI_FONT_SIZE)
		gallery_hud.add_child(caption)
		gallery_labels.append({"label": caption, "anchor": Vector3((index % 4) * 3.4 - 5.1, 0, floori(index / 4.0) * 5.2 - 5.2 + 1.15)})

	rig.focus = Vector3(0, 0.5, 0)
	rig.yaw = 0.05
	rig.pitch = 0.9
	rig.zoom = 20
	rig.update_camera()

func _capture() -> void:
	await RenderingServer.frame_post_draw
	var output := "res://artifacts/main-menu.png" if OS.get_cmdline_user_args().has("--capture-menu") else ("res://artifacts/asset-gallery.png" if gallery else ("res://artifacts/terraces-expanded.png" if showcase else "res://artifacts/terraces-prototype.png"))
	var image := get_viewport().get_texture().get_image()
	image.save_png(output)
	print("CAPTURE: " + output)
	get_tree().quit()

func _build_showcase() -> void:
	# Exercise the same construction API as player placement; no instant buildings.
	for cell in [Vector3i(0, 2, 0), Vector3i(1, 2, 0), Vector3i(0, 2, 1), Vector3i(1, 2, 1), Vector3i(2, 2, 0)]:
		model.request_build("platform", cell)
	model.request_build("stairs", Vector3i(-1, 0, 0), 0)
	model.request_build("well", model.well)
	for step in 6000:
		model.tick(0.05)
	model.request_build("garden", Vector3i(1, 2, 1))
	for step in 1600:
		model.tick(0.05)
	model.request_build("platform", Vector3i(0, 2, 2))
	model.request_build("platform", Vector3i(0, 4, 0))
	model.request_build("platform", Vector3i(1, 4, 0))
	for step in 2400:
		model.tick(0.05)
	model.request_build("stairs", Vector3i(0, 2, 1), 3)
	model.request_build("stockpile", Vector3i(2, 2, 0))
	for step in 2400:
		model.tick(0.05)
	model.request_build("garden", Vector3i(1, 4, 0))
	for step in 2400:
		model.tick(0.05)
	for spec in [{"kind": "house", "cell": Vector3i(3, 0, 0)},
		{"kind": "log_shed", "cell": Vector3i(-3, 0, 3)},
		{"kind": "hay_field", "cell": Vector3i(-1, 0, 3)},
		{"kind": "windmill", "cell": Vector3i(-4, 0, -3)}]:
		model.request_build(spec.kind, spec.cell)
	for step in 6000:
		model.tick(0.05)
	model.request_build("house", Vector3i(3, 2, 0))
	for step in 2400:
		model.tick(0.05)
	print("SHOWCASE: %d completed catalogue buildings, %d remaining plans" % [model.buildings.size(), model.plans.size()])
	rig.focus = Vector3(1.5, 1.7, 0.4)
	rig.zoom = 24.0
	rig.update_camera()

func _open_structure_workshop() -> void:
	if room_editor!=null: room_editor.set_active(false)
	if not is_instance_valid(structure_workshop):
		structure_workshop = preload("res://scenes/settlement/StructureWorkshop.tscn").instantiate()
		add_child(structure_workshop)
		structure_workshop.closed.connect(func():
			hud.visible = not menu.visible
			world_container.visible = true)
	else:
		structure_workshop.open()
	rig.rotating = false
	left_selecting = false
	hud.selection_drag = Rect2()
	hud.visible = false
	world_container.visible = false

func _exit_tree() -> void:
	autosave_worker.finish()
	if operation_thread != null and operation_thread.is_started():
		operation_thread.wait_to_finish()
	chunk_loader.finish()

func terrain_floor_at(point: Vector3) -> Vector3i:
	if model.SolidIslands.enabled(model): return Vector3i(roundi(point.x),roundi(point.y),roundi(point.z))
	return model.surface_at(roundi(point.x / Navigation.CELL_SIZE),roundi(point.z / Navigation.CELL_SIZE))
