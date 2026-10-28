extends Node3D
const AnalysisWorker=preload("res://scripts/block_city/analysis_worker.gd")
const SurfacePicker=preload("res://scripts/block_city/surface_picker.gd")
const Utilities=preload("res://scripts/block_city/utility_network.gd")
const UtilityView=preload("res://scripts/block_city/utility_view.gd")
const UtilityButton=preload("res://scripts/block_city/utility_button.gd")
const TerrainView=preload("res://scripts/block_city/terrain_view.gd")
const Land = preload("res://scripts/block_city/land.gd")
const Editor = preload("res://scripts/block_city/editor_selection.gd")
const Model = preload("res://scripts/block_city/model.gd")
const PowerView = preload("res://scripts/block_city/power_view.gd")
const Cable = preload("res://scripts/block_city/cable.gd")
const Neighbourhood = preload("res://scripts/block_city/neighbourhood.gd")
const RoomView = preload("res://scripts/block_city/room_view.gd")
const ViewButton = preload("res://scripts/block_city/view_button.gd")
const MenuIcon = preload("res://scripts/block_city/menu_button.gd")
const FloorButton = preload("res://scripts/block_city/floor_button.gd")
const ShapeCard = preload("res://scripts/block_city/shape_card.gd")
const DebugPalette = preload("res://scripts/block_city/debug_palette.gd")
const Feedback = preload("res://scripts/block_city/placement_feedback.gd")
const ShapeOutline = preload("res://scripts/block_city/shape_outline.gd")
const UI = preload("res://scripts/ui_visual_tokens.gd")
const DemoVersion = preload("res://scripts/block_city/demo_version.gd")
const SAVE_PATH := "user://block_city_v2.json"
const INK := Color("293b42")
const PAPER := Color("f4f3ed")
const MUTED := Color("7a8b8b")
const ACCESS := Color("edbd59")
const ENTRY_CONNECTED := Color("65b879")
const ENTRY_PENDING := Color("efc85b")
const POWER := Color("65cbd0")
const MIN_ZOOM := 0.82
const MAX_ZOOM := 1.30
const ZOOM_STEP := 0.04
const POLE_TARGET_RADIUS := 10 * UI.POINT
var utility_kind := ""
var utility_bar: HBoxContainer
var utility_hover: Dictionary={}
var utility_path: Array=[]
var utility_dragging:=false
var utility_blocked:=false
var utility_graph: Dictionary={}
var utility_graph_key:=0
var utility_ghost: Node3D
var utility_audio: AudioStreamPlayer
var utility_notes: Array=[]
var utility_note_index:=0
var utility_note_time:=0
var manual_orientation:=false
var entry_override: Dictionary={}
var analysis_thread: Thread
var analysis_revision:=0
var analysis_signature:=0
var analysis_pending: Dictionary={}
var analysis_powered: Dictionary={}
var analysis_reached: Dictionary={}
var world_signature:=0
var room_signatures: Dictionary={}
var room_redraw_queue: Array=[]
var cable_signature:=0
var utility_signature:=0
var render_deferred:=false
var model = Model.new()
var camera: Camera3D
var geometry: Node3D
var ghost: Node3D
var canvas: Control
var overlay: Control
var cards_box: VBoxContainer
var debug_palette: ScrollContainer
var debug_shape := ""
var issue_hint: Label
var route_cost: Label
var selected_route: Dictionary = {}
var view_mode := 0
var view_button: Button
var menu_button: Button
var fps_label: Label
var version_label: Label
var fps_refresh := 0.0
var floor_up: Button
var floor_down: Button
var forced_floor := -100
var menu: ColorRect
var note: Label
var selection_ids: Array=[]
var selection_kind := ""
var selection_path: Array=[]
var edit_ids: Array=[]
var edit_action := ""
var edit_card: Dictionary={}
var purchase_button: Button
var hovered_plot := -1
var editor_bar: HBoxContainer
var editor_crumbs: HBoxContainer
var selected := -1
var moving_id := -1
var moving_card: Dictionary = {}
var move_context = null
var underground := false
var anchor := Vector2i.ZERO
var cut_hall_held := false
var carve_hall := false
var snap_y := -100
var placement_plane := -100
var retarget_floor_held := false
var cursor_offset := Vector2i.ZERO
var surface_offset := Vector2i.ZERO
var rotation_center := Vector2.INF
var holding := false
var wire_source: Dictionary = {}
var wire_drag: Dictionary = {}
var wire_drag_start := Vector2.ZERO
var wire_dragging := false
var neighbours: Array = []
var yaw := 0
var orbit := -2.4
var elevation := 0.55
var zoom := 1.0
var fitted_camera_size := 1.0
var framing_points: Array[Vector3] = []
var framing_center := Vector3.ZERO
var orbiting := false
var orbit_button := MOUSE_BUTTON_NONE
var orbit_drag_distance := 0.0
var orbit_target := -2.4
var orbit_tween: Tween
var preview: Dictionary = {}
var wire_target: Dictionary = {}
var wiring := false
var auto_save := true
var restore_last := true
var toast_time := 0.0
var animating := false
var drop_tween: Tween

func _ready() -> void:
	get_window().title = "Block City · Construction Lab"
	if restore_last:
		if FileAccess.file_exists(SAVE_PATH): model.load_game(SAVE_PATH)
		else: model.load_legacy("user://block_city_v1.json")
	setup_world()
	setup_ui()
	setup_purchase_ui()
	setup_utility_ui()
	route_cost=Label.new()
	route_cost.add_theme_font_size_override("font_size",UI.UI_FONT_SIZE)
	route_cost.add_theme_color_override("font_color",INK)
	route_cost.add_theme_stylebox_override("normal",style(PAPER))
	route_cost.mouse_filter=Control.MOUSE_FILTER_IGNORE
	canvas.add_child(route_cost)
	route_cost.hide()
	refresh()
	model.defer_analysis=true
	get_viewport().size_changed.connect(update_camera)
	get_window().focus_exited.connect(stop_camera_motion)
	get_window().focus_exited.connect(cancel_utility_stroke)
	get_window().focus_exited.connect(func(): cut_hall_held=false; retarget_floor_held=false)

func setup_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	canvas = Control.new()
	layer.add_child(canvas)
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cards_box = VBoxContainer.new()
	canvas.add_child(cards_box)
	cards_box.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	cards_box.offset_left = -136 * UI.POINT
	cards_box.offset_right = -24 * UI.POINT
	cards_box.offset_top = 80 * UI.POINT
	cards_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cards_box.add_theme_constant_override("separation", 4 * UI.GAP_UNIT)
	debug_palette=DebugPalette.new()
	canvas.add_child(debug_palette)
	debug_palette.anchor_left=1.0; debug_palette.anchor_right=1.0; debug_palette.anchor_bottom=1.0
	debug_palette.offset_left=-192*UI.POINT; debug_palette.offset_right=-24*UI.POINT
	debug_palette.offset_top=192*UI.POINT; debug_palette.offset_bottom=-80*UI.POINT
	debug_palette.setup(model)
	debug_palette.chosen.connect(select_debug_shape)
	note = label("", canvas)
	note.position = Vector2(24,24) * UI.POINT
	overlay = Control.new()
	canvas.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.draw.connect(draw_overlay)
	issue_hint=label("",canvas)
	issue_hint.mouse_filter=Control.MOUSE_FILTER_IGNORE
	issue_hint.add_theme_stylebox_override("normal",style(PAPER))
	issue_hint.hide()
	view_button = ViewButton.new()
	canvas.add_child(view_button)
	view_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	view_button.offset_left = -72 * UI.POINT
	view_button.offset_right = -24 * UI.POINT
	view_button.offset_top = -72 * UI.POINT
	view_button.offset_bottom = -24 * UI.POINT
	view_button.focus_mode = Control.FOCUS_NONE
	view_button.add_theme_stylebox_override("normal",style(PAPER))
	view_button.add_theme_stylebox_override("hover",style(Color.WHITE))
	view_button.add_theme_stylebox_override("pressed",style(Color("d7e9e2")))
	view_button.pressed.connect(cycle_view)
	menu_button=MenuIcon.new()
	canvas.add_child(menu_button)
	menu_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	menu_button.offset_left=-72*UI.POINT; menu_button.offset_right=-24*UI.POINT
	menu_button.offset_top=24*UI.POINT; menu_button.offset_bottom=72*UI.POINT
	menu_button.focus_mode=Control.FOCUS_NONE
	menu_button.tooltip_text="Menu"
	menu_button.add_theme_stylebox_override("normal",style(PAPER))
	menu_button.add_theme_stylebox_override("hover",style(Color.WHITE))
	menu_button.add_theme_stylebox_override("pressed",style(Color("d7e9e2")))
	menu_button.pressed.connect(toggle_menu)
	fps_label=label("— FPS",canvas)
	fps_label.name="FPS"
	fps_label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	fps_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	fps_label.offset_left=-232*UI.POINT; fps_label.offset_right=-88*UI.POINT
	fps_label.offset_top=24*UI.POINT; fps_label.offset_bottom=72*UI.POINT
	fps_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	fps_label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	version_label=label("v"+DemoVersion.VERSION,canvas)
	version_label.name="DemoVersion"
	version_label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	version_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	version_label.offset_left=-248*UI.POINT; version_label.offset_right=-88*UI.POINT
	version_label.offset_top=-72*UI.POINT; version_label.offset_bottom=-24*UI.POINT
	version_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	version_label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	for direction in [1,-1]:
		var control:=FloorButton.new()
		control.direction=direction
		canvas.add_child(control)
		control.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
		control.offset_left=24*UI.POINT; control.offset_right=72*UI.POINT
		control.offset_top=(-128 if direction==1 else -72)*UI.POINT
		control.offset_bottom=(-80 if direction==1 else -24)*UI.POINT
		control.focus_mode=Control.FOCUS_NONE
		control.add_theme_stylebox_override("normal",style(PAPER))
		control.add_theme_stylebox_override("hover",style(Color.WHITE))
		control.add_theme_stylebox_override("pressed",style(Color("d7e9e2")))
		control.add_theme_stylebox_override("disabled",style(PAPER))
		control.pressed.connect(func(): change_floor(direction))
		if direction==1: floor_up=control
		else: floor_down=control
	menu = ColorRect.new()
	canvas.add_child(menu)
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu.color = Color(0.1,0.15,0.15,0.35)
	var center := CenterContainer.new()
	menu.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", style(PAPER))
	center.add_child(panel)
	var choices := VBoxContainer.new()
	choices.custom_minimum_size.x = 224 * UI.POINT
	choices.add_theme_constant_override("separation", 12 * UI.GAP_UNIT)
	panel.add_child(choices)
	button("Resume", choices, toggle_menu)
	button("New Game", choices, new_game)
	button("Quit", choices, func(): persist(); get_tree().quit())
	menu.hide()
	setup_editor_ui()

func setup_editor_ui() -> void:
	editor_bar=HBoxContainer.new()
	canvas.add_child(editor_bar)
	editor_bar.position=Vector2(24,24)*UI.POINT
	editor_bar.add_theme_constant_override("separation",8*UI.GAP_UNIT)
	for action in ["Move","Copy","Delete"]:
		var control:=Button.new()
		control.text=action; control.custom_minimum_size=Vector2(88,48)*UI.POINT
		control.focus_mode=Control.FOCUS_NONE
		control.add_theme_font_size_override("font_size",UI.UI_FONT_SIZE)
		for state in ["font_color","font_hover_color","font_pressed_color"]: control.add_theme_color_override(state,INK)
		control.add_theme_stylebox_override("normal",style(PAPER))
		control.add_theme_stylebox_override("hover",style(Color.WHITE))
		control.pressed.connect(func(): editor_action(action.to_lower()))
		if action=="Copy": control.tooltip_text="Copy rooms above this selection; utility feeds stay with the original"
		editor_bar.add_child(control)
	editor_crumbs=HBoxContainer.new()
	canvas.add_child(editor_crumbs)
	editor_crumbs.position=Vector2(24,80)*UI.POINT
	editor_crumbs.add_theme_constant_override("separation",4*UI.GAP_UNIT)
	refresh_editor_ui()

func setup_utility_ui() -> void:
	utility_bar=HBoxContainer.new(); canvas.add_child(utility_bar)
	utility_bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	utility_bar.offset_left=96*UI.POINT; utility_bar.offset_top=-72*UI.POINT
	utility_bar.offset_bottom=-24*UI.POINT
	utility_bar.add_theme_constant_override("separation",8*UI.GAP_UNIT)
	for kind in Utilities.KINDS:
		var button:=UtilityButton.new(); button.kind=kind
		button.custom_minimum_size=Vector2(48,48)*UI.POINT; button.focus_mode=Control.FOCUS_NONE
		button.tooltip_text={"power":"Electricity","pipe":"Pipe","vent":"Vent"}[kind]
		button.add_theme_stylebox_override("normal",style(PAPER)); button.add_theme_stylebox_override("hover",style(Color.WHITE))
		button.pressed.connect(func(): select_utility(kind)); utility_bar.add_child(button)
	utility_ghost=Node3D.new(); add_child(utility_ghost)
	utility_audio=AudioStreamPlayer.new(); utility_audio.volume_db=-24; add_child(utility_audio)
	for frequency in [261.63,293.66,329.63,392.0,440.0]:
		var sample:=AudioStreamWAV.new(); sample.format=AudioStreamWAV.FORMAT_16_BITS; sample.mix_rate=22050
		var bytes:=PackedByteArray(); bytes.resize(4410*2)
		for i in 4410:
			var t:=float(i)/22050.0
			var envelope:=minf(1.0,t/0.008)*exp(-t*24.0)
			bytes.encode_s16(i*2,int(sin(TAU*frequency*t)*envelope*18000))
		sample.data=bytes; utility_notes.append(sample)

func refresh_utility_ui() -> void:
	if utility_bar==null: return
	utility_bar.visible=not holding and not menu.visible and not wiring
	for button in utility_bar.get_children(): button.active=button.kind==utility_kind; button.queue_redraw()

func select_utility(kind: String) -> void:
	if menu.visible: return
	var previous:=utility_kind
	set_holding(false)
	utility_kind="" if previous==kind else kind
	utility_graph_key=0
	refresh_ui(); refresh_preview()

func utility_over_ui(screen: Vector2) -> bool:
	for control in [utility_bar,debug_palette,cards_box,menu_button,view_button,floor_up,floor_down,editor_bar,editor_crumbs,purchase_button]:
		if control!=null and control.visible and control.get_global_rect().has_point(screen): return true
	return false

func utility_hit(screen: Vector2) -> Dictionary:
	if menu.visible or orbiting or utility_over_ui(screen): return {}
	return SurfacePicker.cast(model,camera.project_ray_origin(screen),camera.project_ray_normal(screen),view_mode,forced_floor if forced_floor!=-100 else 100,underground,[],true)

func update_utility_hover(screen: Vector2) -> void:
	if utility_kind.is_empty(): return
	var hit:=utility_hit(screen)
	var next: Dictionary={} if hit.is_empty() else Utilities.from_hit(hit)
	if next==utility_hover: return
	utility_hover=next
	if utility_dragging: extend_utility_stroke()
	overlay.queue_redraw()

func begin_utility_stroke(screen: Vector2) -> void:
	update_utility_hover(screen)
	if utility_hover.is_empty(): return
	var signature:=hash([model.rooms,model.owned_plots,view_mode,forced_floor,underground])
	if utility_graph_key!=signature:
		utility_graph_key=signature
		utility_graph=Utilities.graph(model,view_mode,forced_floor if forced_floor!=-100 else 100,underground)
	if not utility_graph.nodes.has(Utilities.key(utility_hover)): return
	utility_dragging=true; utility_blocked=false; utility_path=[utility_hover.duplicate(true)]
	play_utility_note(); preview_utilities()

func extend_utility_stroke() -> void:
	utility_blocked=utility_hover.is_empty()
	if utility_hover.is_empty(): preview_utilities(); return
	var old:=utility_path.find(utility_hover)
	if old>=0:
		utility_path=utility_path.slice(0,old+1)
	else:
		var path:=Utilities.route(utility_graph,utility_path[-1],utility_hover)
		utility_blocked=path.is_empty()
		if not utility_blocked:
			utility_path.append_array(path.slice(1)); play_utility_note()
	preview_utilities()

func preview_utilities() -> void:
	clear_nodes(utility_ghost)
	UtilityView.draw(self,utility_ghost,Utilities.links(utility_kind,utility_path),true)
	overlay.queue_redraw()

func finish_utility_stroke(screen: Vector2) -> void:
	update_utility_hover(screen)
	if not utility_blocked and not utility_over_ui(screen) and not menu.visible and Utilities.add(model,utility_kind,utility_path):
		refresh(); persist()
	cancel_utility_stroke()

func cancel_utility_stroke() -> void:
	utility_dragging=false; utility_blocked=false; utility_path=[]; utility_hover={}
	if utility_ghost!=null: clear_nodes(utility_ghost)
	if overlay!=null: overlay.queue_redraw()

func play_utility_note() -> void:
	if utility_audio==null or Time.get_ticks_msec()-utility_note_time<50: return
	utility_note_time=Time.get_ticks_msec()
	utility_audio.stream=utility_notes[utility_note_index%utility_notes.size()]
	utility_note_index+=1; utility_audio.play()

func draw_utilities() -> void:
	var signature:=hash([model.utility_links,analysis_powered,underground,view_mode,forced_floor])
	if signature==utility_signature: return
	utility_signature=signature
	var old:=geometry.get_node_or_null("Utilities")
	if old!=null: old.free()
	var parent:=Node3D.new(); parent.name="Utilities"; geometry.add_child(parent)
	var visible: Array=model.utility_links.filter(func(link):return (Utilities.vec(link.a.cell).y<0)==underground and (forced_floor==-100 or Utilities.vec(link.a.cell).y<=forced_floor))
	UtilityView.draw(self,parent,visible)

func draw_utility_overlay() -> void:
	if utility_kind.is_empty() or utility_hover.is_empty(): return
	var points:=PackedVector2Array()
	var normal:=Vector3(Utilities.vec(utility_hover.normal))
	for corner in Utilities.corners(utility_hover):
		var at:=Vector3(corner)+normal*0.015
		if utility_hover.surface=="floor": at.y+=0.08
		points.append(camera.unproject_position(at))
	points.append(points[0])
	overlay.draw_polyline(points,Color("d56e60") if utility_blocked else UI.SELECTION_COLOR,UI.LINE_WIDTH,true)

func select_floor(level: int) -> void:
	if (not holding and utility_kind.is_empty()) or menu.visible: return
	forced_floor=clampi(level,0,int(model.rules().ceiling)-1)
	snap_y=forced_floor; placement_plane=forced_floor; surface_offset=Vector2i.ZERO
	cancel_utility_stroke(); refresh_preview(); draw_utilities()

func cycle_entry() -> void:
	if not holding or menu.visible or edit_action=="transformer_move": return
	var card: Dictionary=held_card()
	if not edit_action.is_empty():
		if edit_ids.size()!=1 or model.room_role(model.rooms[edit_ids[0]]) in ["hall","pole"]: return
		card=model.relocation_card(edit_ids[0])
		if not entry_override.is_empty(): card.merge(entry_override,true)
	elif model.room_role(card) in ["hall","pole"]: return
	var form: Dictionary=model.oriented(card,0)
	var extent:=Vector3i.ZERO
	for cell in form.cells: extent=extent.max(cell+Vector3i.ONE)
	var choices: Array=[]
	var long_side: bool=model.shape_for(card.shape).get("long_side_door",false)
	for cell in form.cells:
		for normal in Model.DIRECTIONS:
			if form.cells.has(cell+normal): continue
			if long_side and ((extent.z>extent.x and normal.z!=0) or (extent.x>extent.z and normal.x!=0)): continue
			choices.append({"door":Model.arr(cell),"normal":Model.arr(normal)})
	if choices.is_empty(): return
	var at:=choices.find({"door":Model.arr(form.door),"normal":Model.arr(form.normal)})
	var choice: Dictionary=choices[(at+1)%choices.size()]
	if not edit_action.is_empty(): entry_override=choice
	else: card.merge(choice,true)
	manual_orientation=true
	refresh_preview()

func align_vertical_room() -> void:
	if manual_orientation or moving_id>=0 or not edit_action.is_empty() or not holding: return
	var role: String=model.room_role(held_card())
	if role not in ["stairs","elevator"]: return
	var occ: Dictionary=model.occupied()
	var level:=snap_y
	if level==-100:
		var landing: Dictionary=model.landing(held_card(),anchor.x,anchor.y,yaw,underground,snap_y)
		if not landing.is_empty() and landing.has("origin"): level=landing.origin.y
	var below:=Vector3i(anchor.x,level-1,anchor.y)
	if not occ.has(below): return
	var lower: Dictionary=model.rooms[int(occ[below])]
	if model.room_role(lower)!=role: return
	for rotation in 4:
		if model.oriented(held_card(),rotation).normal==Model.vec(lower.normal): yaw=rotation; return

func xray_preview(root: Node) -> void:
	for mesh in root.find_children("*","MeshInstance3D",true,false):
		if str(mesh.get_path()).contains("EditContext"): continue
		var material=mesh.material_override
		if not material is StandardMaterial3D: continue
		material=material.duplicate()
		material.no_depth_test=true
		material.render_priority=10 if str(mesh.name).begins_with("Doormat") or str(mesh.name)=="UpperDoormat" else 1
		if str(mesh.name).contains("Doormat") and not preview.get("ok",true): material.albedo_color=Color("d56e60")
		if not str(mesh.name).contains("Doormat"):
			material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
			material.albedo_color.a=0.55
		mesh.material_override=material; mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func setup_purchase_ui() -> void:
	purchase_button=Button.new()
	purchase_button.text="Purchase"
	purchase_button.focus_mode=Control.FOCUS_NONE
	purchase_button.custom_minimum_size=Vector2(168,48)*UI.POINT
	purchase_button.add_theme_font_size_override("font_size",UI.UI_FONT_SIZE)
	for state in ["font_color","font_hover_color","font_pressed_color"]: purchase_button.add_theme_color_override(state,INK)
	for state in ["normal","hover","pressed"]:
		var panel:=style(Color.WHITE if state=="hover" else PAPER)
		panel.content_margin_left=40*UI.POINT
		panel.content_margin_right=12*UI.POINT
		purchase_button.add_theme_stylebox_override(state,panel)
	purchase_button.draw.connect(func():
		var center:=Vector2(20*UI.POINT,purchase_button.size.y*0.5)
		purchase_button.draw_line(center-Vector2(8,0)*UI.POINT,center+Vector2(8,0)*UI.POINT,INK,UI.LINE_WIDTH,true)
		purchase_button.draw_line(center-Vector2(0,8)*UI.POINT,center+Vector2(0,8)*UI.POINT,INK,UI.LINE_WIDTH,true))
	purchase_button.pressed.connect(purchase_hovered_plot)
	canvas.add_child(purchase_button)
	purchase_button.hide()

func can_purchase_land() -> bool:
	return not (holding or menu.visible or wiring or not utility_kind.is_empty() or underground or orbiting or animating)

func purchase_hovered_plot() -> void:
	if not can_purchase_land() or not model.purchase_plot(hovered_plot): return
	hovered_plot=-1; purchase_button.hide()
	refresh(); persist()

func update_land_hover(screen: Vector2) -> void:
	var previous:=hovered_plot
	if not can_purchase_land():
		hovered_plot=-1
	elif purchase_button.visible and purchase_button.get_global_rect().has_point(screen):
		pass
	else:
		hovered_plot=-1
		var blocked:=false
		for control in [debug_palette,cards_box,menu_button,view_button,floor_up,floor_down,editor_bar,editor_crumbs]:
			if control.visible and control.get_global_rect().has_point(screen): blocked=true
		if transformer_hit(screen): blocked=true
		if not blocked and pick(screen).is_empty():
			var from:=camera.project_ray_origin(screen); var direction:=camera.project_ray_normal(screen)
			var nearest:=INF
			# The grey building itself is also a purchase target.
			for neighbour in neighbours:
				var hit=neighbour.bounds.intersects_ray(from,direction)
				if hit!=null and from.distance_squared_to(hit)<nearest:
					nearest=from.distance_squared_to(hit); hovered_plot=int(neighbour.plot_id)
			if hovered_plot<0:
				var ground=Plane(Vector3.UP,0).intersects_ray(from,direction)
				if ground!=null: hovered_plot=Land.at(model.config,Vector2(ground.x,ground.z),model.owned_plots)
			if model.owned_plots.has(hovered_plot): hovered_plot=-1
	purchase_button.visible=hovered_plot>=0
	if hovered_plot>=0:
		var plot: Rect2i=Land.plots(model.config)[hovered_plot]
		var center:=Vector2(plot.position)+Vector2(plot.size)*0.5
		var at:=camera.unproject_position(Vector3(center.x,0.05,center.y))-purchase_button.size*0.5
		var viewport:=get_viewport().get_visible_rect().size
		purchase_button.position=at.clamp(Vector2.ONE*8,viewport-purchase_button.size-Vector2.ONE*8)
	if previous!=hovered_plot: overlay.queue_redraw()

func refresh_editor_ui() -> void:
	if editor_bar==null: return
	var active:=(not selection_ids.is_empty() or selection_kind=="transformer") and not holding and not wiring and utility_kind.is_empty() and not menu.visible
	editor_bar.visible=active; editor_crumbs.visible=active
	for button in editor_bar.get_children(): button.visible=selection_kind!="transformer" or button.text=="Move"
	for child in editor_crumbs.get_children(): child.free()
	if not active: return
	if selection_kind=="transformer":
		label("Transformer",editor_crumbs); return
	if selection_kind=="multi":
		label("%d rooms" % selection_ids.size(),editor_crumbs)
	else:
		for index in selection_path.size():
			var item:=Button.new()
			item.text=selection_path[index].label
			item.focus_mode=Control.FOCUS_NONE
			item.add_theme_font_size_override("font_size",UI.UI_FONT_SIZE)
			for state in ["font_color","font_hover_color","font_pressed_color"]: item.add_theme_color_override(state,INK)
			item.add_theme_stylebox_override("normal",style(PAPER,UI.SELECTION_COLOR if index==selection_path.size()-1 else Color.TRANSPARENT))
			item.pressed.connect(func(): choose_scope(index))
			editor_crumbs.add_child(item)

func choose_scope(index: int) -> void:
	if index<0 or index>=selection_path.size(): return
	var scope: Dictionary=selection_path[index]
	selection_path=selection_path.slice(0,index+1)
	selection_ids=scope.ids.duplicate(); selection_kind=scope.kind
	selected=int(selection_ids[0]) if selection_kind=="room" else -1
	preview={}; refresh_editor_ui(); refresh_route(); overlay.queue_redraw()

func select_hit(id: int, additive := false) -> void:
	if id<0 or id>=model.rooms.size(): return
	if additive:
		if selection_kind not in ["multi","room"]: selection_ids=[]
		if selection_ids.has(id): selection_ids.erase(id)
		else: selection_ids.append(id)
		selection_ids.sort(); selection_kind="multi"; selection_path=[]; selected=-1
	else:
		var path: Array=Editor.path(model,id)
		var depth:=0
		if selection_ids.has(id) and selection_kind!="multi":
			for i in path.size():
				if path[i].kind==selection_kind and path[i].ids==selection_ids and (selection_kind!="group" or path[i].get("group")==selection_path[-1].get("group")):
					depth=mini(i+1,path.size()-1); break
		selection_path=path.slice(0,depth+1)
		selection_ids=path[depth].ids.duplicate(); selection_kind=path[depth].kind
		selected=id if selection_kind=="room" else -1
	preview={}; refresh_editor_ui(); refresh_route(); overlay.queue_redraw()

func group_selection() -> void:
	if holding or wiring or menu.visible or selection_ids.size()<2: return
	var group: int=Editor.group_rooms(model,selection_ids)
	if group<0: return
	var path: Array=Editor.path(model,int(selection_ids[0]))
	for index in path.size():
		if path[index].get("group",-1)==group:
			selection_path=path.slice(0,index+1); selection_kind="group"; break
	selected=-1; refresh_editor_ui(); persist(); overlay.queue_redraw()

func editor_action(action: String) -> void:
	if selection_kind=="transformer" and not menu.visible and not animating:
		if action!="move": return
		clear_move(); reset_placement_aim()
		edit_action="transformer_move"
		edit_card={"shape":"cube","color":0,"origin":model.transformer_cell}
		anchor=Vector2i(model.transformer_cell.x,model.transformer_cell.z)
		snap_y=model.transformer_cell.y; forced_floor=snap_y; placement_plane=snap_y
		holding=true; wiring=false; wire_source={}; wire_target={}; selected=-1
		refresh_ui(); refresh_preview(); return
	if selection_ids.is_empty() or menu.visible or animating: return
	if action=="delete":
		var result: Dictionary=Editor.removal(model,selection_ids)
		if not Editor.commit(model,result):
			preview={"cells":Editor.cells(model,selection_ids),"ok":false,"issues":result.issues}
			overlay.queue_redraw(); return
		set_holding(false); refresh(); persist(); return
	clear_move()
	edit_ids=selection_ids.duplicate(); edit_action=action
	edit_card=Editor.card(model,edit_ids)
	yaw=0; reset_placement_aim()
	var origin: Vector3i=edit_card.origin
	if action=="copy":
		var height:=1
		for raw in edit_card.cells: height=maxi(height,int(raw[1])+1)
		origin.y+=height
	anchor=Vector2i(origin.x,origin.z); snap_y=origin.y; placement_plane=origin.y; forced_floor=origin.y
	underground=origin.y<0
	cursor_offset=-Vector2i(Vector2(footprint_extent())*0.5)
	holding=true; wiring=false; wire_source={}; wire_target={}; selected=-1
	refresh_ui(); refresh_preview()

func refresh_edit_preview() -> void:
	if edit_action=="transformer_move":
		var at:=Vector3i(anchor.x,snap_y,anchor.y)
		preview=model.transformer_plan(at)
		RoomView.Equipment.transformer(self,ghost,at)
		for cable in model.cables:
			var moved: Dictionary=cable.duplicate(true)
			if cable.get("source_device","")=="transformer": moved.source_cell=Model.arr(at)
			PowerView.draw(self,ghost,moved)
		xray_preview(ghost); refresh_floor_tools(); overlay.queue_redraw(); return
	preview=Editor.plan(model,edit_ids,Vector3i(anchor.x,snap_y,anchor.y),yaw,edit_action=="copy")
	if edit_ids.size()==1 and not entry_override.is_empty():
		var card: Dictionary=model.relocation_card(edit_ids[0]); card.merge(entry_override,true)
		var form: Dictionary=model.oriented(card,yaw)
		var room: Dictionary=preview.edited[0]
		room.door=Model.arr(preview.origin+form.door); room.normal=Model.arr(form.normal)
		preview.proposed_rooms[int(room.id)]=room
	var reached: Dictionary=model.accessible_rooms(preview.proposed_rooms)
	for room in preview.edited:
		var node:=Node3D.new(); node.name="EditRoom%d" % int(room.id); ghost.add_child(node)
		RoomView.draw(self,node,room,view_mode,{},reached.has(int(room.id)),preview.proposed_rooms)
		for brace in room.braces: draw_brace(node,brace,model.room_role(room))
	# Refresh adjoining shells against the proposed occupancy, so their roof
	# rims and rooftop housings do not intersect the held floor above them.
	var affected: Dictionary={}
	var existing: Dictionary=model.occupied()
	var changed: Array=preview.cells.duplicate()
	if edit_action=="move": changed.append_array(Editor.cells(model,edit_ids))
	for cell in changed:
		for direction in Model.DIRECTIONS+[Vector3i.ZERO,Vector3i.UP,Vector3i.DOWN]:
			if existing.has(cell+direction): affected[int(existing[cell+direction])]=true
	var context:=Node3D.new(); context.name="EditContext"; ghost.add_child(context)
	for id in affected:
		if preview.ids.has(id): continue
		var original:=geometry.get_node_or_null("Room%d" % id)
		if original!=null: original.hide()
		var room: Dictionary=preview.proposed_rooms[id]
		if not room_visible(room): continue
		var node:=Node3D.new(); context.add_child(node)
		RoomView.draw(self,node,room,view_mode,model.powered_cells(),reached.has(id),preview.proposed_rooms)
		for brace in room.braces: draw_brace(node,brace,model.room_role(room))
		if forced_floor!=-100 and room.cells.all(func(raw):return int(raw[1])>forced_floor):
			for mesh in node.find_children("*","MeshInstance3D",true,false):
				mesh.transparency=0.92; mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if not underground:
		var occ: Dictionary={}
		for room in preview.proposed_rooms:
			for raw in room.cells: occ[Model.vec(raw)]=int(room.id)
		for cable in preview.proposed_cables: PowerView.draw(self,ghost,cable,occ)
	xray_preview(ghost)
	refresh_floor_tools(); refresh_editor_ui(); refresh_route(); overlay.queue_redraw()

func refresh_ui() -> void:
	if purchase_button!=null and not can_purchase_land():
		hovered_plot=-1
		purchase_button.hide()
		overlay.queue_redraw()
	refresh_utility_ui()
	refresh_editor_ui()
	layout_supply()
	if debug_palette!=null: debug_palette.refresh(model,debug_shape,underground,holding and moving_id<0 and edit_action.is_empty())
	for c in cards_box.get_children():
		cards_box.remove_child(c); c.queue_free()
	var view := ShapeCard.new()
	view.custom_minimum_size = Vector2(112, 96) * UI.POINT
	view.cells = model.oriented(held_card(), yaw).cells
	view.tint = model.tint(held_card())
	view.role = model.room_role(held_card())
	view.modulate.a = 1.0 if holding else 0.4
	view.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT and not menu.visible:
			set_holding(not holding)
	)
	cards_box.add_child(view)
	view.mouse_filter = Control.MOUSE_FILTER_STOP

func select_debug_shape(id: String) -> void:
	manual_orientation=false
	if menu.visible or animating or model.shape_for(id).is_empty() or model.shape_for(id).get("palette_hidden",false): return
	clear_move()
	debug_shape=id
	apply_debug_shape(true)
	reset_placement_aim(true)
	note.text=""
	set_holding(true)

func apply_debug_shape(new_piece := false) -> void:
	if not debug_shape.is_empty():
		var cards: Array=model.basement_queue if underground else model.queue
		if new_piece or cards[0].shape!=debug_shape:
			cards[0]=model.make_card(debug_shape,int(cards[0].color))

func update_issue_hint(screen: Vector2) -> void:
	if issue_hint==null: return
	var text := "" if menu.visible or (not holding and selection_ids.is_empty()) or orbiting else Feedback.hint(self,screen)
	issue_hint.text=text
	issue_hint.visible=not text.is_empty()
	if issue_hint.visible:
		var size:=get_viewport().get_visible_rect().size
		issue_hint.position=Vector2(clampf(screen.x+20,8,maxf(8,size.x-issue_hint.get_minimum_size().x-8)),clampf(screen.y+20,8,size.y-48))

func held_card() -> Dictionary:
	if not edit_action.is_empty(): return edit_card
	return moving_card if moving_id>=0 else model.current(underground)

func placement_model():
	return move_context if moving_id>=0 else model

func begin_move(id: int, screen: Vector2) -> void:
	if id<0 or id>=model.rooms.size() or animating: return
	reset_placement_aim()
	moving_id=id
	selected=id
	moving_card=model.relocation_card(id)
	move_context=model.relocation_context(id)
	yaw=0
	anchor=Vector2i(moving_card.origin.x,moving_card.origin.z)
	snap_y=moving_card.origin.y
	placement_plane=snap_y
	var point=Plane(Vector3.UP,snap_y).intersects_ray(camera.project_ray_origin(screen),camera.project_ray_normal(screen))
	if point!=null: cursor_offset=anchor-Vector2i(floori(point.x),floori(point.z))
	holding=true; wiring=false; wire_source={}; wire_target={}
	refresh_ui(); refresh_preview()

func clear_move() -> void:
	entry_override={}
	edit_ids=[]; edit_action=""; edit_card={}
	moving_id=-1
	moving_card={}
	move_context=null

func reset_placement_aim(keep_floor := false) -> void:
	if not keep_floor: forced_floor=-100
	placement_plane=-100
	snap_y=forced_floor
	carve_hall=false
	cursor_offset=Vector2i.ZERO
	surface_offset=Vector2i.ZERO
	rotation_center=Vector2.INF

func current_floor() -> int:
	if forced_floor!=-100: return forced_floor
	return int(preview.origin.y) if not preview.is_empty() else (-1 if underground else 0)

func floor_limits() -> Vector2i:
	if edit_action=="transformer_move": return Vector2i(0,int(model.rules().ceiling)-1)
	if not edit_action.is_empty():
		var height:=1
		for id in edit_ids:
			for raw in model.rooms[id].cells:
				height=maxi(height,int(raw[1])-edit_card.origin.y+(2 if model.room_role(model.rooms[id])=="stairs" else 1))
		return Vector2i(-int(model.rules().bedrock),int(model.rules().ceiling)-height)
	return Vector2i(-int(model.rules().bedrock),-1) if underground else Vector2i(0,int(model.rules().ceiling)-(2 if model.room_role(held_card())=="stairs" else 1))

func change_floor(direction: int) -> void:
	if (not holding and utility_kind.is_empty()) or menu.visible or wiring or animating: return
	if not utility_kind.is_empty(): select_floor((0 if forced_floor==-100 else forced_floor)+direction); return
	var limits:=floor_limits()
	forced_floor=clampi(current_floor()+direction,limits.x,limits.y)
	snap_y=forced_floor; placement_plane=forced_floor
	carve_hall=false; surface_offset=Vector2i.ZERO
	refresh_preview()

func refresh_floor_tools() -> void:
	if floor_up==null: return
	var enabled:=(holding or not utility_kind.is_empty()) and not menu.visible and not wiring
	var limits:=floor_limits()
	var level:=current_floor()
	for control in [floor_up,floor_down]:
		control.visible=enabled
		control.locked=forced_floor!=-100
		control.tooltip_text="Floor %d" % (level+1 if level>=0 else level)
		control.queue_redraw()
	floor_up.disabled=level>=limits.y
	floor_down.disabled=level<=limits.x

func update_floor_visibility() -> void:
	var active:=(holding or not utility_kind.is_empty()) and forced_floor!=-100 and not menu.visible and not wiring
	for room in model.rooms:
		var node:=geometry.get_node_or_null("Room%d" % int(room.id))
		if node==null: continue
		var faded: bool=active and room.cells.all(func(raw):return int(raw[1])>forced_floor)
		for mesh in node.find_children("*","MeshInstance3D",true,false):
			mesh.transparency=0.92 if faded else 0.0
			mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if faded else GeometryInstance3D.SHADOW_CASTING_SETTING_ON

func footprint_extent() -> Vector2i:
	var extent := Vector3i.ONE
	for cell in model.oriented(held_card(),yaw).cells: extent=extent.max(cell+Vector3i.ONE)
	return Vector2i(extent.x,extent.z)

func set_holding(value: bool) -> void:
	utility_kind=""; cancel_utility_stroke()
	selection_ids=[]; selection_path=[]; selection_kind=""
	wire_drag={}; wire_dragging=false
	holding = value
	if not value:
		selected=-1
		clear_move()
		reset_placement_aim()
	wiring = false
	wire_source = {}
	wire_target = {}
	refresh_ui()
	refresh_preview()

func begin_wire(source: Dictionary = {}) -> void:
	utility_kind=""; cancel_utility_stroke()
	selection_ids=[]; selection_path=[]; selection_kind=""
	clear_move()
	selected=-1
	reset_placement_aim()
	holding = false
	wiring = true
	wire_source = source.duplicate(true)
	wire_target = {}
	refresh_ui()
	refresh_preview()

func cycle_view() -> void:
	if menu.visible: return
	view_mode = (view_mode+1)%3
	view_button.mode = view_mode
	view_button.queue_redraw()
	refresh()

func cancel_construction() -> void:
	menu.hide()
	selected=-1
	cut_hall_held=false; retarget_floor_held=false
	reset_placement_aim()
	stop_camera_motion()
	orbit_button=MOUSE_BUTTON_NONE
	set_holding(false)

func toggle_menu() -> void:
	cancel_utility_stroke()
	menu.visible = not menu.visible
	refresh_editor_ui()
	wire_drag={}; wire_dragging=false
	wiring = false
	wire_target = {}
	stop_camera_motion()
	refresh_preview()

func new_game() -> void:
	utility_kind=""; cancel_utility_stroke()
	analysis_powered={}; analysis_reached={}
	clear_move()
	stop_camera_motion()
	model.reset()
	debug_shape=""
	selected = -1
	holding = false
	selection_ids=[]; selection_path=[]; selection_kind=""
	reset_placement_aim()
	wire_source = {}
	underground = false
	anchor = Vector2i.ZERO
	yaw = 0
	menu.hide()
	wiring = false
	refresh()
	persist()

func add_frame_box(bounds: AABB) -> void:
	for i in 8:
		framing_points.append(bounds.position+Vector3(bounds.size.x*(i&1),bounds.size.y*((i>>1)&1),bounds.size.z*((i>>2)&1)))

func rebuild_camera_frame() -> void:
	framing_points.clear()
	var plan := Neighbourhood.layout(model.config)
	add_frame_box(TerrainView.bounds(plan.bounds))
	for road in plan.roads:
		add_frame_box(AABB(Vector3(road.position.x,-0.2,road.position.y),Vector3(road.size.x,0.2,road.size.y)))
	for building in plan.neighbours:
		var bounds := AABB(Vector3(building.cells[0]),Vector3.ONE)
		for cell in building.cells: bounds = bounds.merge(AABB(Vector3(cell),Vector3.ONE))
		add_frame_box(bounds)
	for room in model.rooms:
		if not room_visible(room): continue
		for raw in room.cells: add_frame_box(AABB(Vector3(Model.vec(raw)),Vector3.ONE))
	if underground:
		for id in model.owned_plots:
			var plot: Rect2i=Land.plots(model.config)[int(id)]
			add_frame_box(AABB(Vector3(plot.position.x,-int(model.rules().bedrock),plot.position.y),Vector3(plot.size.x,0,plot.size.y)))
	else:
		add_frame_box(AABB(Cable.POLE-Vector3(0.4,0,0.15),Vector3(0.8,0.25,0.3)))
		add_frame_box(AABB(Vector3(model.transformer_cell),Vector3.ONE))
	var bounds := AABB(framing_points[0],Vector3.ZERO)
	for point in framing_points: bounds = bounds.expand(point)
	framing_center = bounds.get_center()

func layout_supply() -> void:
	if debug_palette==null: return
	var viewport:=get_viewport().get_visible_rect().size
	cards_box.visible=holding and edit_action.is_empty() and viewport.y>=560*UI.POINT
	debug_palette.offset_top=(192 if cards_box.visible else 80)*UI.POINT
	var palette_width: float=debug_palette.fit_height(viewport.y+debug_palette.offset_bottom-debug_palette.offset_top)
	debug_palette.offset_left=debug_palette.offset_right-palette_width

func update_camera() -> void:
	if camera == null: return
	if framing_points.is_empty(): rebuild_camera_frame()
	camera.position = framing_center + Vector3(sin(orbit)*cos(elevation), sin(elevation), cos(orbit)*cos(elevation)) * 40
	camera.look_at(framing_center)
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	var viewport := get_viewport().get_visible_rect().size
	if viewport.x<=0 or viewport.y<=0: return
	layout_supply()
	# Fit projected world extents to the logical viewport, with room for corner UI.
	var usable := Vector2(maxf(1,viewport.x-160*UI.POINT),maxf(1,viewport.y-96*UI.POINT))
	var projected_min := Vector2(INF,INF)
	var projected_max := Vector2(-INF,-INF)
	for point in framing_points:
		var relative := point-framing_center
		var projected := Vector2(camera.basis.x.dot(relative),camera.basis.y.dot(relative))
		projected_min = projected_min.min(projected)
		projected_max = projected_max.max(projected)
	var center := (projected_min+projected_max)*0.5
	camera.position += camera.basis.x*center.x+camera.basis.y*center.y
	var span := projected_max-projected_min
	fitted_camera_size = maxf(span.y*viewport.y/usable.y,span.x*viewport.y/usable.x)
	zoom = clampf(zoom,MIN_ZOOM,MAX_ZOOM)
	camera.size = fitted_camera_size*zoom
	camera.h_offset = 0
	update_neighbour_visibility()
	overlay.queue_redraw()

func stop_camera_motion() -> void:
	if orbit_tween != null and orbit_tween.is_valid(): orbit_tween.kill()
	orbit_target = orbit
	orbiting = false
	orbit_button = MOUSE_BUTTON_NONE

func turn_camera(direction: float) -> void:
	if orbiting: return
	if orbit_tween != null and orbit_tween.is_valid(): orbit_tween.kill()
	orbit_target += direction * PI / 2
	orbit_tween = create_tween()
	orbit_tween.tween_method(func(value: float): orbit = value; update_camera(), orbit, orbit_target, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)

func refresh() -> void:
	if drop_tween != null and drop_tween.is_valid(): drop_tween.kill()
	animating = false
	if model.owned_plots.has(hovered_plot): hovered_plot=-1
	var signature:=hash([model.owned_plots,underground,model.config.plot,model.transformer_cell])
	if signature!=world_signature or geometry.get_node_or_null("Neighbourhood")==null:
		world_signature=signature
		var old:=geometry.get_node_or_null("Neighbourhood")
		if old!=null: old.free()
		neighbours.clear()
		var root:=geometry
		geometry=Node3D.new(); geometry.name="Neighbourhood"; root.add_child(geometry)
		draw_neighbourhood()
		geometry=root
	request_analysis()
	draw_rooms()
	draw_utilities()
	rebuild_camera_frame()
	refresh_ui()
	update_camera()
	refresh_preview()

func request_analysis() -> void:
	var state: Dictionary=model.snapshot()
	var signature:=hash([state.rooms,state.cables,state.utility_links])
	if signature==analysis_signature: return
	analysis_signature=signature; analysis_revision+=1
	var paths: Dictionary={}
	for cable in model.cables: paths[Cable.key(cable)]=model.cable_points(cable)
	analysis_pending={"config":model.config.duplicate(true),"state":state,"paths":paths,"revision":analysis_revision}
	start_analysis()

func start_analysis() -> void:
	if analysis_pending.is_empty() or analysis_thread!=null: return
	var job:=analysis_pending; analysis_pending={}
	analysis_thread=Thread.new()
	analysis_thread.start(AnalysisWorker.calculate.bind(job.config,job.state,job.paths,job.revision))

func poll_analysis() -> void:
	if analysis_thread==null or analysis_thread.is_alive(): return
	var result: Dictionary=analysis_thread.wait_to_finish(); analysis_thread=null
	if result.revision==analysis_revision:
		analysis_powered=result.powered; analysis_reached=result.reached
		model.queue[1]=result.supply[0]; model.basement_queue[1]=result.supply[1]
		for room in model.rooms: room.color=result.colors.get(int(room.id),room.color)
		analysis_signature=hash([model.rooms,model.cables,model.utility_links])
		render_deferred=true; draw_rooms(); render_deferred=false
		draw_utilities(); refresh_route(); persist()
	start_analysis()

func _exit_tree() -> void:
	if analysis_thread!=null: analysis_thread.wait_to_finish(); analysis_thread=null

func render_room(room: Dictionary,powered: Dictionary,reached: Dictionary) -> void:
	var old:=geometry.get_node_or_null("Room%d" % int(room.id))
	if old!=null: old.free()
	if not room_visible(room): return
	var container:=Node3D.new(); container.name="Room%d" % int(room.id); geometry.add_child(container)
	container.visible=int(room.id)!=moving_id and not (edit_action=="move" and edit_ids.has(int(room.id)))
	RoomView.draw(self,container,room,view_mode,powered,reached.has(int(room.id)))
	for brace in room.braces: draw_brace(container,brace,model.room_role(room))
	var path: Array=room.access_path
	for i in path.size():
		var p:=Model.vec(path[i])
		box(container,Vector3(p)+Vector3(0.5,0.025,0.5),Vector3(0.38,0.06,0.38),ACCESS)
		if i>0: beam(container,Vector3(Model.vec(path[i-1]))+Vector3(0.5,0.1,0.5),Vector3(p)+Vector3(0.5,0.1,0.5),ACCESS,0.05)

func flush_room_redraws() -> void:
	var started:=Time.get_ticks_usec()
	while not room_redraw_queue.is_empty() and Time.get_ticks_usec()-started<3000:
		var id: int=room_redraw_queue.pop_front()
		if id<model.rooms.size(): render_room(model.rooms[id],analysis_powered,analysis_reached)
	update_floor_visibility()

func slab(rect: Rect2, height: float, color: Color) -> void:
	box(geometry, Vector3(rect.get_center().x, height - 0.06, rect.get_center().y), Vector3(rect.size.x,0.12,rect.size.y), color)

func draw_neighbourhood(include_power_pole := true) -> void:
	var plan := Neighbourhood.layout(model.config)
	TerrainView.draw(self,geometry,plan.bounds)
	# Surface and excavation openings stop exactly at the floating block's edge.
	var area: Rect2i=plan.bounds
	for z in range(area.position.y,area.end.y):
		var run_start:=area.position.x
		for x in range(area.position.x,area.end.x+1):
			if x==area.end.x or model.owns_cell(Vector3i(x,0,z)):
				if x>run_start: slab(Rect2(run_start,z,x-run_start,1),-0.20,Color("dce3df"))
				run_start=x+1
	for rect in plan.passages:
		if model.owns_cell(Vector3i(int(rect.position.x),0,int(rect.position.y))): continue
		slab(rect,-0.025,Color("c1cbbf"))
		for x in range(int(rect.position.x),int(rect.end.x)):
			for z in range(int(rect.position.y),int(rect.end.y)):
				box(geometry,Vector3(x+0.5,-0.025,z+0.5),Vector3(0.96,0.035,0.96),Color("d2d8cd"))
	for rect in plan.roads: slab(rect,-0.14,Color("7f918c"))
	for crossing in plan.crossings:
		var rect: Rect2=crossing.rect
		for stripe in 4:
			var center:=rect.get_center()
			var dimensions:=Vector3(0.90,0.012,0.09)
			if crossing.axis=="x": center.y=rect.position.y+0.08+stripe*0.16
			else:
				center.x=rect.position.x+0.08+stripe*0.16
				dimensions=Vector3(0.09,0.012,0.90)
			var marking:=box(geometry,Vector3(center.x,-0.132,center.y),dimensions,Color("e2e6d9"))
			marking.name="Crosswalk"
	var front: Rect2 = plan.roads[0]
	for x in range(int(front.position.x),int(front.end.x)):
		if x in plan.cross_streets: continue
		box(geometry,Vector3(x+0.5,-0.072,front.get_center().y),Vector3(0.4,0.015,0.045),Color("c4cec4"))
	var drawn_ground: Dictionary={}
	for id in model.owned_plots:
		var plot: Rect2i=Land.plots(model.config)[int(id)]
		for x in range(plot.position.x,plot.end.x):
			for z in range(plot.position.y,plot.end.y):
				if drawn_ground.has(Vector2i(x,z)): continue
				drawn_ground[Vector2i(x,z)]=true
				var y := -float(model.rules().bedrock) if underground else -0.015
				box(geometry,Vector3(x+0.5,y-0.06,z+0.5),Vector3(0.96,0.12,0.96),Color("8b9692") if underground else Color("b4c2aa"))
	for building in plan.neighbours:
		if not building.cells.any(func(cell):return model.owns_cell(cell)): draw_neighbour(building)
	if not underground and include_power_pole:
		beam(geometry,Vector3(Cable.POLE.x,0,Cable.POLE.z),Cable.POLE+Vector3.UP*0.15,INK,0.07)
		beam(geometry,Cable.POLE-Vector3(0.35,0,0),Cable.POLE+Vector3(0.35,0,0),INK,0.045)
		for x in [-0.25,0.0,0.25]: box(geometry,Cable.POLE+Vector3(x,0.08,0),Vector3(0.09,0.18,0.09),POWER)
		RoomView.Equipment.transformer(self,geometry)

func draw_neighbour(building: Dictionary) -> void:
	var cells: Array = building.cells
	var container := Node3D.new()
	geometry.add_child(container)
	var bounds := AABB(Vector3(cells[0]),Vector3.ONE)
	for cell in cells: bounds = bounds.merge(AABB(Vector3(cell),Vector3.ONE))
	neighbours.append({"node":container,"bounds":bounds,"plot_id":building.plot_id})
	var tint := Color("c2ceca").darkened(float(building.variant % 3)*0.025)
	var entrance: Vector3i=building.origin+Model.vec(building.validation.entry)
	for p in cells:
		box(container,Vector3(p)+Vector3(0.5,0.035,0.5),Vector3(0.96,0.07,0.96),Model.CONCRETE_FLOOR)
		for normal in Model.DIRECTIONS:
			if cells.has(p+normal): continue
			var door: bool=p==entrance and normal==Vector3i.FORWARD
			RoomView.wall(self,container,p,normal,tint,door,not door,0,tint.darkened(0.18),tint.darkened(0.22),true,not cells.has(p+Vector3i.UP))
			# Close the facade above the lintel without filling the stair core.
			RoomView.wall_box(self,container,p,normal,0,0.95,0.96,0.10,0.10,tint)
		if not cells.has(p+Vector3i.UP):
			box(container,Vector3(p)+Vector3(0.5,0.965,0.5),Vector3(0.96,0.07,0.96),Model.CONCRETE_FLOOR)

func update_neighbour_visibility() -> void:
	# Sample the playable volume, including empty ground and the next roof level.
	var top := 1
	for room in model.rooms:
		for raw in room.cells: top = maxi(top,int(raw[1])+2)
	for neighbour in neighbours:
		var obstructs := false
		for id in model.owned_plots:
			var plot: Rect2i=Land.plots(model.config)[int(id)].grow(1)
			for x in range(plot.position.x,plot.end.x):
				if obstructs: break
				for z in range(plot.position.y,plot.end.y):
					if obstructs: break
					for y in range(-int(model.rules().bedrock) if underground else 0,top+1):
						var target := Vector3(x+0.5,y+0.25,z+0.5)
						var screen := camera.unproject_position(target)
						if neighbour.bounds.intersects_segment(camera.project_ray_origin(screen),target)!=null:
							obstructs = true; break
			if obstructs: break
		for mesh in neighbour.node.get_children():
			mesh.transparency = 0.92 if obstructs else 0.0
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if obstructs else GeometryInstance3D.SHADOW_CASTING_SETTING_ON

func room_visible(r: Dictionary) -> bool:
	return int(r.cells[0][1]) < 0 if underground else int(r.cells[0][1]) >= 0

func draw_cable(parent: Node3D, end: Vector3, color: Color, start: Vector3 = Cable.POLE) -> void:
	var points := Cable.curve(end,start)
	for i in range(1,points.size()): beam(parent,points[i-1],points[i],color,0.014)

func draw_brace(parent: Node3D, brace: Array, role: String) -> void:
	var cell:=Vector3(Model.vec(brace[0]))
	var anchor_cell:=Vector3(Model.vec(brace[1]))
	if role!="hall":
		beam(parent,cell+Vector3(0.5,0.07,0.5),anchor_cell+Vector3(0.5,0.8,0.5),INK,0.04)
		return
	var toward:=Vector3(anchor_cell.x-cell.x,0,anchor_cell.z-cell.z).normalized()
	var side:=Vector3(-toward.z,0,toward.x)
	# Twin brackets reach the outside floor edge and a lower wall attachment.
	# Keep them at the cell's sides so they do not run across a doorway.
	for offset in [-0.34,0.34]:
		var outer: Vector3=cell+Vector3(0.5,-0.035,0.5)-toward*0.37+side*offset
		var wall: Vector3=anchor_cell+Vector3(0.5,0.22,0.5)-toward*0.48+side*offset
		beam(parent,outer,wall,INK,0.035)

func draw_rooms() -> void:
	var powered: Dictionary=analysis_powered if model.defer_analysis else model.powered_cells()
	var reached: Dictionary=analysis_reached if model.defer_analysis else model.accessible_rooms()
	var occ: Dictionary=model.occupied()
	for child in geometry.get_children():
		if str(child.name).begins_with("Room") and int(str(child.name).trim_prefix("Room"))>=model.rooms.size(): child.free()
	for room in model.rooms:
		var id:=int(room.id); var neighbors: Dictionary={}
		for raw in room.cells:
			var cell:=Model.vec(raw)
			for direction in Model.DIRECTIONS+[Vector3i.UP,Vector3i.DOWN]:
				if occ.has(cell+direction): neighbors[occ[cell+direction]]=model.rooms[int(occ[cell+direction])]
		var signature:=hash([room,neighbors,view_mode,underground,reached.has(id),room.cells.any(func(raw):return powered.has(Model.vec(raw)))])
		var existing:=geometry.get_node_or_null("Room%d" % id)
		if room_signatures.get(id,0)==signature and existing!=null: continue
		room_signatures[id]=signature
		if render_deferred and existing!=null:
			if not room_redraw_queue.has(id): room_redraw_queue.append(id)
		else: render_room(room,powered,reached)
	var signature:=hash([model.cables,occ.keys(),underground])
	if signature!=cable_signature:
		cable_signature=signature
		var old:=geometry.get_node_or_null("Cables")
		if old!=null: old.free()
		if not underground:
			var root:=Node3D.new(); root.name="Cables"; geometry.add_child(root)
			for cable in model.cables: PowerView.draw(self,root,cable,occ)

func entry_color(reached: bool) -> Color:
	return ENTRY_CONNECTED if reached else ENTRY_PENDING

func constrain_first_room() -> void:
	# There is no supporting storey yet: keep the entire first footprint on the lot.
	if model.rooms.any(func(room): return room_visible(room)): return
	var extent := Vector3i.ONE
	for cell in model.oriented(held_card(),yaw).cells:
		extent=extent.max(cell+Vector3i.ONE)
	var plots:=Land.plots(model.config)
	var closest: Rect2i=plots[Land.START]
	var distance:=INF
	for id in model.owned_plots:
		var plot: Rect2i=plots[int(id)]
		var clamped:=anchor.clamp(plot.position,plot.end-Vector2i(extent.x,extent.z))
		var score:=Vector2(anchor-clamped).length_squared()
		if score<distance: distance=score; closest=plot
	anchor=anchor.clamp(closest.position,closest.end-Vector2i(extent.x,extent.z))
	snap_y=forced_floor
	carve_hall=false

func refresh_preview() -> void:
	refresh_utility_ui()
	for name in ["StarterTransformer","ServiceFeed"]:
		var fixture:=geometry.get_node_or_null("Neighbourhood/"+name)
		if fixture!=null: fixture.visible=edit_action!="transformer_move" or menu.visible
	if forced_floor!=-100: snap_y=forced_floor
	update_floor_visibility()
	for room in model.rooms:
		var node := geometry.get_node_or_null("Room%d" % int(room.id))
		if node!=null: node.visible=(int(room.id)!=moving_id and not (edit_action=="move" and edit_ids.has(int(room.id)))) or menu.visible
	var cable_root := geometry.get_node_or_null("Cables")
	if cable_root!=null: cable_root.visible=(moving_id<0 and edit_action.is_empty()) or menu.visible
	clear_nodes(ghost)
	refresh_editor_ui()
	preview = {}
	if issue_hint!=null: issue_hint.hide()
	if menu.visible:
		refresh_floor_tools()
		refresh_route()
		overlay.queue_redraw(); return
	if not edit_action.is_empty() and holding:
		refresh_edit_preview(); return
	if wiring:
		if not wire_target.is_empty():
			PowerView.line(self,ghost,wire_target.get("points",PackedVector3Array()),POWER if wire_target.ok else Color("d56e60"),0.026 if wire_source.is_empty() else 0.011)
	elif holding:
		constrain_first_room()
		align_vertical_room()
		preview = model.relocation_plan(moving_id,anchor.x,anchor.y,yaw,snap_y) if moving_id>=0 else model.landing(held_card(),anchor.x,anchor.y,yaw,underground,snap_y,carve_hall)
		if preview.get("carve",false) and preview.ok:
			for id in preview.affected:
				var node := geometry.get_node_or_null("Room%d" % id)
				if node!=null: node.visible=false
			for part in preview.remnants:
				var remnant := Node3D.new()
				ghost.add_child(remnant)
				RoomView.draw(self,remnant,part,view_mode,model.powered_cells(),model.accessible_rooms(preview.proposed_rooms).has(int(part.id)),preview.proposed_rooms)
		if not preview.cells.is_empty():
			var room := {"shape":held_card().shape,"color":held_card().color,
				"cells":preview.cells.map(func(p): return Model.arr(p)),"door":Model.arr(preview.door),"normal":Model.arr(preview.normal)}
			if moving_id>=0:
				room.id=moving_id
				room.access_path=preview.get("proposed_rooms",model.rooms)[moving_id].access_path
			RoomView.draw(self,ghost,room,view_mode,{},preview_has_access(room),preview.get("proposed_rooms",[]))
			xray_preview(ghost)
			if moving_id>=0 and not underground:
				var old_cells: Array=model.rooms[moving_id].cells
				var stationary_cables: Array=model.cables.filter(func(cable):return not old_cells.has(cable.cell) and not old_cells.has(cable.get("source_cell",[])))
				var proposed_occupancy: Dictionary={}
				for member in preview.get("proposed_rooms",model.rooms):
					for raw in member.cells: proposed_occupancy[Model.vec(raw)]=int(member.id)
				for cable in preview.get("proposed_cables",stationary_cables):
					PowerView.draw(self,ghost,cable,proposed_occupancy)
			for brace in preview.braces:
				draw_brace(ghost,brace,model.room_role(held_card()))

	refresh_floor_tools()
	refresh_route()
	overlay.queue_redraw()

func refresh_route() -> void:
	selected_route={}
	if route_cost!=null: route_cost.hide()
	if menu.visible or wiring: return
	var destination := moving_id if moving_id>=0 else (selected if not holding else -1)
	if destination<0: return
	if moving_id>=0:
		if not preview.get("ok",false): return
		selected_route=model.route_to_room(destination,preview.proposed_rooms)
	else:
		selected_route=model.route_to_room(destination)
	if selected_route.get("reachable",false) and route_cost!=null:
		route_cost.text=str(selected_route.cost)
		route_cost.reset_size()
		position_route_cost()

func position_route_cost() -> void:
	if route_cost==null or not selected_route.get("reachable",false): return
	var finish: Vector3i=selected_route.path[-1]
	var point:=Vector3(finish)+Vector3(0.5,1.18,0.5)
	route_cost.visible=not menu.visible and not camera.is_position_behind(point)
	if route_cost.visible: route_cost.position=camera.unproject_position(point)-Vector2(route_cost.size.x*0.5,route_cost.size.y)

func draw_route() -> void:
	if not selected_route.get("reachable",false): return
	var points:=PackedVector2Array()
	var entry: Dictionary=selected_route.entry
	points.append(camera.unproject_position(Vector3(entry.cell)+Vector3(0.5,0.12,0.5)+Vector3(entry.normal)*0.55))
	for cell in selected_route.path: points.append(camera.unproject_position(Vector3(cell)+Vector3(0.5,0.12,0.5)))
	if points.size()>1: overlay.draw_polyline(points,POWER,UI.LINE_WIDTH,true)
	for point in points: overlay.draw_circle(point,4*UI.POINT,POWER)

func preview_has_access(room: Dictionary) -> bool:
	if not preview.get("ok",false): return false
	if moving_id>=0: return model.accessible_rooms(preview.proposed_rooms).has(moving_id)
	if preview.get("carve",false) and preview.ok:
		return model.accessible_rooms(preview.proposed_rooms).has(preview.proposed_rooms.size()-1)
	var network: Array=model.rooms.duplicate()
	var candidate: Dictionary=room.duplicate(true)
	candidate.id=network.size(); candidate.access_path=[]
	network.append(candidate)
	return model.accessible_rooms(network).has(int(candidate.id))

func launch_offset(cells: Array) -> float:
	var highest := -100
	var lowest := 100
	for p in cells:
		highest = maxi(highest,p.y)
		lowest = mini(lowest,p.y)
	return -float(model.rules().bedrock)-lowest if underground else float(model.rules().ceiling)-highest-1

func draw_overlay() -> void:
	if camera == null or menu.visible: return
	draw_utility_overlay()
	if hovered_plot>=0:
		var plot: Rect2i=Land.plots(model.config)[hovered_plot]
		var points:=PackedVector2Array()
		for corner in [plot.position,Vector2i(plot.end.x,plot.position.y),plot.end,Vector2i(plot.position.x,plot.end.y),plot.position]:
			points.append(camera.unproject_position(Vector3(corner.x,0.03,corner.y)))
		overlay.draw_polyline(points,UI.SELECTION_COLOR,UI.LINE_WIDTH,true)
	if not holding and not underground:
		for terminal in equipment_terminals():
			var point:=Cable.endpoint(terminal)
			if not socket_visible(point): continue
			var active:=wiring and not wire_source.is_empty() and Cable.key(terminal)==Cable.key(wire_source)
			var used: bool=model.terminal_used(terminal)
			overlay.draw_rect(Rect2(camera.unproject_position(point)-Vector2.ONE*5,Vector2.ONE*10),UI.SELECTION_COLOR if active or used else POWER,used,-1.0 if used else UI.LINE_WIDTH)
		for cable in model.cables:
			if cable.get("device","")=="pole": continue
			var point := Cable.endpoint(cable)
			var chosen: bool=wiring and not wire_source.is_empty() and Cable.key(cable)==Cable.key(wire_source)
			if socket_visible(point): overlay.draw_rect(Rect2(camera.unproject_position(point)-Vector2.ONE*6,Vector2.ONE*12),UI.SELECTION_COLOR if chosen else POWER,false,UI.LINE_WIDTH)
	if not underground and not camera.is_position_behind(Cable.POLE):
		overlay.draw_circle(camera.unproject_position(Cable.POLE),POLE_TARGET_RADIUS,POWER,false,UI.LINE_WIDTH,true)
		if wiring:
			var feeds: int=1+model.cables.filter(func(c):return not c.has("source_cell")).size()
			for index in 3:
				var center:=camera.unproject_position(Cable.POLE)+Vector2((index-1)*10,POLE_TARGET_RADIUS+10)
				overlay.draw_rect(Rect2(center-Vector2.ONE*3,Vector2.ONE*6),UI.SELECTION_COLOR if index<feeds else POWER,index<feeds,-1.0 if index<feeds else UI.LINE_WIDTH)
	if wiring:
		if not wire_target.is_empty():
			for slot in (3 if wire_target.get("device","")=="pole" else 4):
				var target: Dictionary=wire_target.duplicate(); target.slot=slot
				var point:=Cable.endpoint(target)
				if socket_visible(point): overlay.draw_rect(Rect2(camera.unproject_position(point)-Vector2.ONE*4,Vector2.ONE*8),POWER,false,UI.LINE_WIDTH)
			overlay.draw_rect(Rect2(camera.unproject_position(wire_target.end)-Vector2.ONE*7,Vector2.ONE*14),POWER if wire_target.ok else Color("d56e60"),false,UI.LINE_WIDTH)
		return
	draw_route()
	if preview.is_empty():
		if selection_kind=="transformer" and not holding:
			for contour in ShapeOutline.silhouette([model.transformer_cell],camera):
				var closed: PackedVector2Array=contour.duplicate(); closed.append(closed[0])
				overlay.draw_polyline(closed,UI.SELECTION_COLOR,UI.LINE_WIDTH,true)
		if not holding and (not selection_ids.is_empty() or (selected>=0 and selected<model.rooms.size())):
			var ids: Array=selection_ids if not selection_ids.is_empty() else [selected]
			for contour in ShapeOutline.silhouette(Editor.cells(model,ids),camera):
				var closed: PackedVector2Array=contour.duplicate()
				closed.append(closed[0]); overlay.draw_polyline(closed,UI.SELECTION_COLOR,UI.LINE_WIDTH,true)
		return
	var color := UI.SELECTION_COLOR
	for contour in ShapeOutline.silhouette(preview.cells,camera):
		var closed: PackedVector2Array=contour.duplicate()
		if not closed.is_empty():
			closed.append(closed[0])
			overlay.draw_polyline(closed,color,UI.LINE_WIDTH,true)
	# Error outlines remain local to the exact cells causing the rejection.
	var bad_cells := {}
	for issue in preview.get("issues",[]): bad_cells[issue.cell]=true
	for cell in bad_cells:
		for edge in ShapeOutline.edges([cell]):
			overlay.draw_line(camera.unproject_position(Vector3(edge[0])),camera.unproject_position(Vector3(edge[1])),Feedback.BAD,UI.LINE_WIDTH,true)
	Feedback.draw(self)
	if preview.cells.is_empty():
		var at := camera.unproject_position(Vector3(anchor.x+0.5,0,anchor.y+0.5))
		overlay.draw_line(at-Vector2(8,8),at+Vector2(8,8),color,UI.LINE_WIDTH,true)
		overlay.draw_line(at+Vector2(-8,8),at+Vector2(8,-8),color,UI.LINE_WIDTH,true)

func persist() -> void:
	if auto_save and not model.save_game(SAVE_PATH): toast("Save failed")

func toast(text: String) -> void:
	note.text = text
	toast_time = 2.0

func _process(delta: float) -> void:
	poll_analysis()
	flush_room_redraws()
	update_utility_hover(get_viewport().get_mouse_position())
	fps_refresh+=delta
	if fps_refresh>=0.5:
		fps_refresh=0.0
		fps_label.text="%d FPS" % Engine.get_frames_per_second()
	var cable_root:=geometry.get_node_or_null("Cables")
	if cable_root!=null: PowerView.animate(cable_root,Time.get_ticks_msec()/1000.0)
	update_land_hover(get_viewport().get_mouse_position())
	update_issue_hint(get_viewport().get_mouse_position())
	if not selected_route.is_empty(): position_route_cost()
	if toast_time > 0:
		toast_time -= delta
		if toast_time <= 0: note.text = ""

func drop() -> void:
	if menu.visible or wiring or animating or not holding: return
	if edit_action=="transformer_move":
		if not model.move_transformer(Vector3i(anchor.x,snap_y,anchor.y)): refresh_preview(); return
		set_holding(false); selection_kind="transformer"; refresh(); persist(); return
	if not edit_action.is_empty():
		if not Editor.commit(model,preview): refresh_preview(); return
		var placed: Array=preview.ids.duplicate()
		var previous_kind:=selection_kind
		set_holding(false)
		selection_ids=placed; selection_kind="multi" if placed.size()>1 else "room"
		var path: Array=Editor.path(model,int(placed[0]))
		for i in path.size():
			if path[i].kind==previous_kind and path[i].ids==placed:
				selection_kind=previous_kind; selection_path=path.slice(0,i+1); break
		if placed.size()==1 and selection_kind=="room":
			selection_path=path; selected=int(placed[0])
		refresh(); persist(); return
	if moving_id>=0:
		if not model.relocate(moving_id,anchor.x,anchor.y,yaw,snap_y):
			refresh_preview()
			return
		clear_move()
		holding=false
		reset_placement_aim()
		refresh()
		persist()
		return
	constrain_first_room()
	if not model.drop(anchor.x,anchor.y,yaw,underground,snap_y,carve_hall):
		note.text=""
		refresh_preview()
		return
	apply_debug_shape(true)
	manual_orientation=false
	var was_carving := carve_hall
	selected = model.rooms.size()-1
	reset_placement_aim(true)
	refresh()
	persist()

func rotate_shape() -> void:
	if not holding or edit_action=="transformer_move": return
	manual_orientation=true
	# Preserve the footprint center. Mixed odd/even extents need a half-cell
	# rounding choice, so keep the original pivot across consecutive turns.
	var current_center := Vector2(anchor)+Vector2(footprint_extent())*0.5
	if rotation_center==Vector2.INF or (current_center-rotation_center).abs().x>0.51 or (current_center-rotation_center).abs().y>0.51:
		rotation_center=current_center
	var before := anchor
	yaw = (yaw+1)%4
	var corner := rotation_center-Vector2(footprint_extent())*0.5
	anchor=Vector2i(floori(corner.x),floori(corner.y))
	refresh_ui()
	refresh_preview()
	cursor_offset+=anchor-before

func mirror_shape() -> void:
	var current: Dictionary=held_card()
	if current.shape not in ["flat_l","flat_l_mirror"]: return
	current.shape="flat_l_mirror" if current.shape=="flat_l" else "flat_l"
	if not debug_shape.is_empty(): debug_shape=current.shape
	refresh_ui(); refresh_preview()

func switch_depth() -> void:
	utility_kind=""; cancel_utility_stroke()
	selection_ids=[]; selection_path=[]; selection_kind=""; selected=-1
	clear_move()
	underground = not underground
	apply_debug_shape()
	reset_placement_aim()
	wiring = false
	wire_target = {}
	refresh()

func remove_selected_room() -> void:
	if menu.visible or animating: return
	if not utility_kind.is_empty():
		if not utility_hover.is_empty() and Utilities.remove_at(model,utility_kind,utility_hover): refresh(); persist()
		return
	if not wiring and not selection_ids.is_empty() and edit_action.is_empty():
		editor_action("delete"); return
	if wiring:
		if wire_source.is_empty(): return
		if (model.remove_equipment_branch(wire_source) if wire_source.has("device") else model.remove_power_node(Model.vec(wire_source.cell),Model.vec(wire_source.normal),int(wire_source.get("slot",-1)))):
			set_holding(false)
			refresh()
			persist()
		return
	var id := moving_id if moving_id>=0 else (selected if not holding else -1)
	if id<0 or id>=model.rooms.size(): return
	var plan: Dictionary=model.removal_plan(id)
	if not plan.ok:
		if preview.is_empty(): preview={"cells":model.rooms[id].cells.map(func(raw):return Model.vec(raw))}
		preview.ok=false
		preview.issues=plan.issues
		refresh_route()
		overlay.queue_redraw()
		return
	if not model.remove_room(id): return
	clear_move()
	selected=-1
	holding=false
	reset_placement_aim()
	refresh()
	persist()

func undo() -> void:
	if utility_dragging: cancel_utility_stroke(); return
	if not edit_action.is_empty():
		set_holding(false); refresh(); return
	selection_ids=[]; selection_path=[]; selection_kind=""
	if moving_id>=0:
		set_holding(false)
		return
	if model.undo():
		reset_placement_aim()
		apply_debug_shape()
		wiring = false
		wire_target = {}
		refresh()
		persist()

func pick(screen: Vector2) -> Dictionary:
	var excluded: Array=edit_ids if edit_action=="move" else ([moving_id] if moving_id>=0 else [])
	var level:=forced_floor if (holding or not utility_kind.is_empty()) and forced_floor!=-100 else 100
	return SurfacePicker.cast(model,camera.project_ray_origin(screen),camera.project_ray_normal(screen),view_mode,level,underground,excluded)

func hit_face(cell: Vector3i, point: Vector3) -> Vector3i:
	var local:=point-Vector3(cell)-Vector3.ONE*0.5
	var normal:=Vector3i.ZERO
	var axis:=local.abs().max_axis_index()
	normal[axis]=1 if local[axis]>0 else -1
	return normal

func pole_hit(screen: Vector2) -> bool:
	if underground or camera.is_position_behind(Cable.POLE): return false
	# Only the visible top-circle target captures a click; the shaft is click-through.
	return screen.distance_to(camera.unproject_position(Cable.POLE)) <= POLE_TARGET_RADIUS + UI.LINE_WIDTH * 0.5

func transformer_hit(screen: Vector2) -> bool:
	if underground: return false
	var origin:=camera.project_ray_origin(screen); var direction:=camera.project_ray_normal(screen)
	var point=AABB(Vector3(model.transformer_cell),Vector3.ONE).intersects_ray(origin,direction)
	if point==null: return false
	var other:=pick(screen)
	return other.is_empty() or origin.distance_squared_to(point)<origin.distance_squared_to(other.point)

func equipment_terminals() -> Array:
	var result: Array=[]
	if underground: return result
	for slot in 3: result.append(model.transformer_source(slot))
	for room in model.rooms:
		if model.room_role(room)!="pole": continue
		for slot in 3: result.append({"device":"pole","cell":room.cells[0],"normal":room.normal,"slot":slot})
	return result

func equipment_at(screen: Vector2) -> Dictionary:
	var nearest:=14.0*UI.POINT; var result: Dictionary={}
	for terminal in equipment_terminals():
		var point:=Cable.endpoint(terminal)
		var distance:=screen.distance_to(camera.unproject_position(point))
		if distance<nearest and socket_visible(point): nearest=distance; result=terminal
	return result

func target_at(screen: Vector2) -> Dictionary:
	var equipment:=equipment_at(screen)
	if not equipment.is_empty():
		if equipment.device=="transformer": return {}
		if wire_source.get("device","")=="transformer" and model.terminal_used(equipment):
			for slot in 3:
				equipment.slot=slot
				if not model.terminal_used(equipment): break
		return model.connection(Model.vec(equipment.cell),Model.vec(equipment.normal),wire_source,int(equipment.slot))
	var best:=Vector3i.ZERO; var cell:=Vector3i.ZERO; var slot: int=0
	var distance:=14.0*14.0
	var occ: Dictionary=model.occupied()
	# Socket centers sit just outside the wall: their projected ray can miss
	# the room at a corner. Pick the visible targets themselves first.
	for candidate in occ:
		if candidate.y<0 or model.room_role(model.rooms[int(occ[candidate])])=="pole": continue
		for normal in Model.DIRECTIONS:
			if occ.has(candidate+normal): continue
			for index in 4:
				var point:=Cable.socket(candidate,normal,index)
				var score:=screen.distance_squared_to(camera.unproject_position(point))
				if score<distance and socket_visible(point):
					distance=score; best=normal; cell=candidate; slot=index
	if best==Vector3i.ZERO:
		var hit:=pick(screen)
		if hit.is_empty() or hit.surface=="equipment": return {}
		cell=hit.cell; distance=INF
		for normal in Model.DIRECTIONS:
			if occ.has(cell+normal): continue
			for index in 4:
				var point:=Cable.socket(cell,normal,index)
				var score: float=hit.point.distance_squared_to(point)
				if score<distance and socket_visible(point): distance=score; best=normal; slot=index
	if best==Vector3i.ZERO: return {}
	var result: Dictionary=model.connection(cell,best,wire_source,slot)
	if wire_dragging:
		result.ok=model.move_power_node(wire_drag,cell,best,slot,false)
		for cable in model.cables:
			if Cable.key(cable)==Cable.key(wire_drag):
				var moved: Dictionary=cable.duplicate(true)
				moved.cell=result.cell; moved.normal=result.normal; moved.slot=slot
				result.points=model.cable_points(moved)
				break
	return result

func socket_visible(point: Vector3) -> bool:
	if camera.is_position_behind(point): return false
	var start := camera.project_ray_origin(camera.unproject_position(point))
	for cell in model.occupied():
		if model.solid_bounds(cell).intersects_segment(start,point)!=null: return false
	if Cable.bounds(model.transformer_cell).intersects_segment(start,point)!=null: return false
	return true

func socket_at(screen: Vector2) -> Dictionary:
	if underground: return {}
	var equipment:=equipment_at(screen)
	if not equipment.is_empty(): return equipment
	var closest := 9.0*UI.POINT
	var result := {}
	for cable in model.cables:
		var point := Cable.endpoint(cable)
		var distance := screen.distance_to(camera.unproject_position(point))
		if distance<closest and socket_visible(point):
			closest=distance
			result={"cell":cable.cell,"normal":cable.normal,"slot":int(cable.get("slot",-1))}
	return result

func click_world(screen: Vector2, additive := false) -> void:
	if menu.visible: return
	if menu_button.get_global_rect().has_point(screen):
		toggle_menu()
		return
	if animating or orbiting: return
	if purchase_button.visible and purchase_button.get_global_rect().has_point(screen):
		purchase_hovered_plot(); return
	for control in [floor_up,floor_down]:
		if control.visible and control.get_global_rect().has_point(screen):
			if not control.disabled: change_floor(control.direction)
			return
	if debug_palette!=null and debug_palette.get_global_rect().has_point(screen):
		select_debug_shape(debug_palette.shape_at(screen))
		return
	if cards_box.visible and cards_box.get_global_rect().has_point(screen):
		set_holding(not holding)
		return
	if view_button.get_global_rect().has_point(screen): return
	if pole_hit(screen):
		if wiring: set_holding(false)
		else: begin_wire()
		return
	if wiring:
		var terminal:=equipment_at(screen)
		if terminal.get("device","")=="transformer": begin_wire(terminal); return
		wire_target = target_at(screen)
		if not wire_target.is_empty() and wire_target.ok:
			if model.connect_power(Model.vec(wire_target.cell),Model.vec(wire_target.normal),wire_source,int(wire_target.get("slot",-1))):
				var from_transformer: bool=wire_source.get("device","")=="transformer"
				wire_source={"cell":wire_target.cell,"normal":wire_target.normal,"slot":wire_target.slot}
				if wire_target.get("device","")=="pole":
					wire_source.device="pole"
					for slot in 3:
						wire_source.slot=slot
						if not model.terminal_used(wire_source): break
				if from_transformer:
					for slot in 3:
						var next: Dictionary=model.transformer_source(slot)
						if not model.terminal_used(next): wire_source=next; break
				wire_target = {}
				refresh()
				persist()
		refresh_preview()
		return
	if not holding and not additive:
		var source := socket_at(screen)
		if not source.is_empty():
			begin_wire(source)
			return
	if not holding and not additive and transformer_hit(screen):
		selection_ids=[]; selection_path=[]; selection_kind="transformer"; selected=-1
		preview={}; refresh_editor_ui(); refresh_route(); overlay.queue_redraw(); return
	# Selection drills down the hierarchy; editing is an explicit action.
	var hit := pick(screen)
	if not holding and not hit.is_empty():
		select_hit(int(hit.id),additive); return
	if not holding and hit.is_empty(): set_holding(false); return
	if holding and position_anchor(screen): drop()

func position_anchor(screen: Vector2) -> bool:
	if not holding: return false
	if purchase_button.visible and purchase_button.get_global_rect().has_point(screen): return false
	if not edit_action.is_empty():
		for control in [floor_up,floor_down,menu_button,view_button,debug_palette]:
			if control.visible and control.get_global_rect().has_point(screen): return false
		var point=Plane(Vector3.UP,snap_y).intersects_ray(camera.project_ray_origin(screen),camera.project_ray_normal(screen))
		if point==null: return false
		var next:=Vector2i(floori(point.x),floori(point.z))+cursor_offset
		if next!=anchor: anchor=next; rotation_center=Vector2.INF; refresh_preview()
		return true
	if debug_palette!=null and debug_palette.get_global_rect().has_point(screen): return false
	for control in [floor_up,floor_down]:
		if control.visible and control.get_global_rect().has_point(screen): return false
	if forced_floor!=-100:
		# Manual floor selection is authoritative, including beneath higher rooms.
		# Intersect the chosen plane directly; roofs cannot steal the pointer.
		var point=Plane(Vector3.UP,forced_floor).intersects_ray(camera.project_ray_origin(screen),camera.project_ray_normal(screen))
		if point==null: return false
		var next:=Vector2i(floori(point.x),floori(point.z))+cursor_offset
		if not model.land_bounds().grow(1).has_point(next): return false
		var cutting: bool=moving_id<0 and cut_hall_held and model.room_role(held_card())=="hall"
		if next!=anchor or snap_y!=forced_floor or carve_hall!=cutting:
			anchor=next; snap_y=forced_floor; placement_plane=forced_floor
			carve_hall=cutting; rotation_center=Vector2.INF
			refresh_preview()
		return true
	var hit := pick(screen)
	var hall_surface: bool=not hit.is_empty() and model.room_role(model.rooms[hit.id])=="hall"
	var direct_surface: bool=not hit.is_empty() and (hit.normal==Vector3i.UP or hall_surface)
	# Real build surfaces take priority over an old error badge under the cursor.
	if not direct_surface and not retarget_floor_held and not Feedback.hint(self,screen).is_empty(): return true
	var ray_origin := camera.project_ray_origin(screen)
	var ray_direction := camera.project_ray_normal(screen)
	var next_y := placement_plane if not underground else -100
	var next_carve := false
	var side_anchor = null
	var basement_hit = null
	# The pointed surface chooses its own level, even below a taller tower.
	# Only gaps and ordinary sidewalls retain the previous placement plane.
	var acquire := underground or placement_plane==-100 or retarget_floor_held or cut_hall_held or direct_surface
	if acquire:
		next_y=-100 if underground else 0
		if not hit.is_empty():
			if underground: basement_hit=hit.point
			next_carve=moving_id<0 and model.room_role(held_card())=="hall" and model.room_role(model.rooms[hit.id])=="room" and cut_hall_held
			if next_carve:
				next_y=int(hit.cell.y)
				side_anchor=Vector2i(hit.cell.x,hit.cell.z)
			elif not underground and hall_surface:
				# Halls have no roof mesh. Their floor/interior still identifies
				# the cell to stack on, not a sidewall for bracket attachment.
				next_y=int(hit.cell.y)+1
				side_anchor=Vector2i(hit.cell.x,hit.cell.z)
			elif not underground and hit.normal==Vector3i.UP:
				next_y=int(hit.cell.y)+1
			elif model.room_role(held_card())=="hall" and not underground and hit.normal.y==0:
				var neighbour: Vector3i=hit.cell+hit.normal
				next_y=hit.cell.y
				if not model.owns_cell(neighbour): next_y=maxi(1,next_y)
				var extent := footprint_extent()
				if hit.normal.x<0: neighbour.x-=extent.x-1
				if hit.normal.z<0: neighbour.z-=extent.y-1
				side_anchor=Vector2i(neighbour.x,neighbour.z)
			if not underground and not next_carve and (hit.normal==Vector3i.UP or side_anchor!=null): placement_plane=next_y
		if next_carve: placement_plane=-100
		elif retarget_floor_held and not underground: placement_plane=next_y
	var height := next_y if next_y!=-100 else 0
	var point = Plane(Vector3.UP,height).intersects_ray(ray_origin,ray_direction)
	if basement_hit!=null and not next_carve: point=basement_hit
	if point==null: return false
	var projected := Vector2i(floori(point.x),floori(point.z))
	# Surface projection and deliberate rotation/nudge offsets are independent.
	# Re-aiming at a hall must not undo a rotation around the room's center.
	if acquire: surface_offset=side_anchor-projected if side_anchor!=null else Vector2i.ZERO
	var next := projected+surface_offset+cursor_offset
	# Retain the selected storey while the footprint still belongs to the
	# structure. Once completely detached over bare ground, release the plane
	# and project onto that ground rather than leaving a floating preview.
	if not underground and not next_carve and not retarget_floor_held and next_y>0:
		var cells: Array=model.oriented(held_card(),yaw).cells.map(func(cell):return cell+Vector3i(next.x,next_y,next.y))
		var occupied: Dictionary=placement_model().occupied()
		var touching_support: bool=cells.any(func(cell):return occupied.has(cell+Vector3i.DOWN))
		var supported: bool=placement_model().support(cells,occupied,false,model.room_role(held_card())).ok
		if not touching_support and not supported and hit.is_empty():
			var ground = Plane(Vector3.UP,0).intersects_ray(ray_origin,ray_direction)
			if ground!=null:
				var ground_anchor := Vector2i(floori(ground.x),floori(ground.z))+cursor_offset
				var ground_plan: Dictionary=model.relocation_plan(moving_id,ground_anchor.x,ground_anchor.y,yaw,0) if moving_id>=0 else model.landing(held_card(),ground_anchor.x,ground_anchor.y,yaw,false,0)
				if ground_plan.ok:
					next=ground_anchor
					next_y=0
					placement_plane=-100
					surface_offset=Vector2i.ZERO
	if not model.land_bounds().grow(1).has_point(next): return false
	if next != anchor or next_y != snap_y or next_carve != carve_hall:
		anchor=next
		snap_y=next_y
		carve_hall=next_carve
		rotation_center=Vector2.INF
		refresh_preview()
	return true

func nudge_room(delta: Vector2i) -> void:
	if not holding or menu.visible: return
	var before := anchor
	var bounds: Rect2i=Land.bounds(model.config) if edit_action=="transformer_move" else model.land_bounds().grow(1)
	anchor=(anchor+delta).clamp(bounds.position,bounds.end-Vector2i.ONE)
	cursor_offset+=anchor-before
	rotation_center=Vector2.INF
	if not underground and not preview.is_empty():
		snap_y=preview.origin.y
		placement_plane=snap_y
	refresh_preview()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed and utility_dragging:
		finish_utility_stroke(event.position); get_viewport().set_input_as_handled(); return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_G and (event.meta_pressed or event.ctrl_pressed):
		group_selection(); get_viewport().set_input_as_handled(); return
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed and not wire_drag.is_empty():
		if wire_dragging and not menu.visible:
			var target:=target_at(event.position)
			if not target.is_empty() and model.move_power_node(wire_drag,Model.vec(target.cell),Model.vec(target.normal),int(target.slot)):
				wire_source={"cell":target.cell,"normal":target.normal,"slot":target.slot}
				refresh(); persist()
		wire_drag={}; wire_dragging=false; wire_target={}; refresh_preview()
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_ESCAPE:
		cancel_construction()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_BACKSPACE and not menu.visible:
		remove_selected_room()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.keycode==KEY_ALT:
		retarget_floor_held=event.pressed
		if event.pressed:
			cursor_offset=Vector2i.ZERO
			rotation_center=Vector2.INF
		if holding and not menu.visible: position_anchor(get_viewport().get_mouse_position())
	if event is InputEventKey and event.keycode==KEY_SHIFT:
		cut_hall_held=event.pressed
		if holding and not menu.visible: position_anchor(get_viewport().get_mouse_position())
	# Release even over UI, so a drag can never remain latched.
	if event is InputEventMouseButton and not event.pressed and event.button_index == orbit_button:
		var cancel_wire := orbit_button == MOUSE_BUTTON_RIGHT and orbit_drag_distance < 4.0
		orbiting = false
		orbit_button = MOUSE_BUTTON_NONE
		if cancel_wire: set_holding(false)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		cancel_construction()
		return
	if menu.visible: return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_Q: turn_camera(-1); return
		if event.keycode == KEY_E: turn_camera(1); return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index in [MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			stop_camera_motion()
			orbiting = true
			orbit_button = event.button_index
			orbit_drag_distance = 0.0
			return
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			zoom = clampf(zoom + (-ZOOM_STEP if event.button_index == MOUSE_BUTTON_WHEEL_UP else ZOOM_STEP) * event.factor, MIN_ZOOM, MAX_ZOOM)
			update_camera()
			return
	if event is InputEventMouseMotion and orbiting:
		orbit_drag_distance += event.relative.length()
		orbit -= event.relative.x*0.008
		orbit_target = orbit
		elevation = clampf(elevation+event.relative.y*0.004,0.25,1.1)
		update_camera()
		return
	if animating: return
	if not utility_kind.is_empty():
		if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
			begin_utility_stroke(event.position); return
		if event is InputEventMouseMotion:
			update_utility_hover(event.position); return
	if event is InputEventKey and event.pressed and not event.echo:
		if holding or not utility_kind.is_empty():
			if event.keycode>=KEY_1 and event.keycode<=KEY_9: select_floor(int(event.keycode)-KEY_1); return
			if event.keycode in [KEY_COMMA,KEY_LESS]: select_floor(maxi(0,current_floor()-1)); return
			if event.keycode in [KEY_PERIOD,KEY_GREATER]: select_floor(current_floor()+1); return
		match event.keycode:
			KEY_F: cycle_entry()
			KEY_SPACE: drop()
			KEY_R: rotate_shape()
			KEY_M: mirror_shape()
			KEY_B: switch_depth()
			KEY_Z: undo()
			KEY_BACKSPACE: remove_selected_room()
			KEY_LEFT, KEY_A: nudge_room(Vector2i.LEFT)
			KEY_RIGHT, KEY_D: nudge_room(Vector2i.RIGHT)
			KEY_UP, KEY_W: nudge_room(Vector2i.UP)
			KEY_DOWN, KEY_S: nudge_room(Vector2i.DOWN)
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if not holding and not event.shift_pressed:
				var socket:=socket_at(event.position)
				if not socket.is_empty() and not wiring:
					if socket.has("device"):
						begin_wire(socket); return
					wire_drag=socket; wire_drag_start=event.position; wire_dragging=false
					begin_wire(socket)
					return
			click_world(event.position,event.shift_pressed)
	if event is InputEventMouseMotion:
		if not wire_drag.is_empty() and event.position.distance_to(wire_drag_start)>6: wire_dragging=true
		if wiring:
			wire_target = target_at(event.position)
			refresh_preview()
		else:
			position_anchor(event.position)

func setup_world() -> void:
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("e8edeb")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 0.72
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.glow_enabled=true
	env.glow_intensity=0.45
	env.glow_bloom=0.05
	environment.environment = env
	add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-48, -35, 0)
	light.light_energy = 0.75
	light.shadow_enabled = true
	add_child(light)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	add_child(camera)
	camera.make_current()
	get_viewport().msaa_3d = Viewport.MSAA_4X
	geometry = Node3D.new()
	add_child(geometry)
	ghost = Node3D.new()
	add_child(ghost)

func style(background: Color, border := Color.TRANSPARENT) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = background
	box.border_color = border
	box.set_border_width_all(int(UI.LINE_WIDTH) if border.a > 0 else 0)
	box.set_corner_radius_all(8 * UI.POINT)
	box.content_margin_left = 12 * UI.PADDING_UNIT
	box.content_margin_right = 12 * UI.PADDING_UNIT
	box.content_margin_top = 8 * UI.PADDING_UNIT
	box.content_margin_bottom = 8 * UI.PADDING_UNIT
	return box

func label(text: String, parent: Node, tint := INK) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", tint)
	l.add_theme_font_size_override("font_size", UI.UI_FONT_SIZE)
	parent.add_child(l)
	return l

func button(text: String, parent: Node, callback: Callable, tooltip := "") -> Button:
	var b := Button.new()
	b.text = text
	b.tooltip_text = tooltip
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size.y = 44 * UI.POINT
	b.add_theme_stylebox_override("normal", style(PAPER))
	b.add_theme_stylebox_override("hover", style(Color("ffffff")))
	b.add_theme_stylebox_override("pressed", style(Color("d7e9e2")))
	b.add_theme_stylebox_override("disabled", style(Color("dce1dd")))
	b.add_theme_color_override("font_color", INK)
	b.add_theme_color_override("font_hover_color", INK)
	b.add_theme_color_override("font_pressed_color", INK)
	b.add_theme_color_override("font_disabled_color", MUTED)
	b.add_theme_font_size_override("font_size", UI.UI_FONT_SIZE)
	b.pressed.connect(callback)
	parent.add_child(b)
	return b

func material(color: Color, transparent := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.9
	if transparent:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.no_depth_test = true
	return m

func box(parent: Node3D, at: Vector3, size: Vector3, color: Color, transparent := false) -> MeshInstance3D:
	var item := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	item.mesh = mesh
	item.material_override = material(color, transparent)
	item.position = at
	if transparent: item.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(item)
	return item

func beam(parent: Node3D, from: Vector3, to: Vector3, color: Color, radius := 0.035) -> void:
	if from.distance_to(to) < 0.001: return
	var node := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = from.distance_to(to)
	mesh.radial_segments = 6
	node.mesh = mesh
	node.material_override = material(color)
	parent.add_child(node)
	node.position = (from + to) * 0.5
	var up := (to - from).normalized()
	var right := up.cross(Vector3.FORWARD).normalized()
	if right.length_squared() < 0.1: right = up.cross(Vector3.RIGHT).normalized()
	node.basis = Basis(right, up, right.cross(up).normalized())

func clear_nodes(parent: Node) -> void:
	for child in parent.get_children(): child.free()

