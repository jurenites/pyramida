extends Node
const Rooms=preload("res://scripts/settlement/room_construction.gd")
const View=preload("res://scripts/settlement/room_editor_view.gd")
const Card=preload("res://scripts/block_city/shape_card.gd")
const Outline=preload("res://scripts/block_city/shape_outline.gd")
const Picker=preload("res://scripts/block_city/surface_picker.gd")
const UI=preload("res://scripts/ui_visual_tokens.gd")
var game
var active:=false
var shape:=""
var yaw:=0
var entry_index:=0
var floor_level:=0
var mode:=1
var anchor:=Vector3i.ZERO
var ids: Array=[]
var scope:=""
var path: Array=[]
var edit_action:=""
var preview: Dictionary={}
var history: Array=[]
var revision:=-1
var model_instance:=0
var rendered_state: Array=[]
var last_mouse:=Vector2.INF
var view: Node3D
var canvas: CanvasLayer
var palette: VBoxContainer
var actions: HBoxContainer
var crumbs: HBoxContainer
var overlay: Control
var selector: HBoxContainer
func setup(host) -> void:
	game=host; view=View.new(); game.viewport.add_child(view)
	canvas=CanvasLayer.new(); game.add_child(canvas)
	palette=VBoxContainer.new(); palette.theme=game.hud.root.theme; canvas.add_child(palette)
	palette.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	palette.offset_left=-132*UI.POINT; palette.offset_top=100*UI.POINT; palette.offset_right=-16*UI.POINT
	palette.add_theme_constant_override("separation",4*UI.POINT)
	var grid:=GridContainer.new(); grid.columns=2; palette.add_child(grid)
	var sample=Rooms.layout(game.model)
	for kind in ["cube","domino","room_domino","bar","small_square","stairs"]:
		var button:=Button.new(); button.custom_minimum_size=Vector2(54,60)*UI.POINT
		button.tooltip_text={"cube":"Hall · 2×2×2 m","domino":"Hall · 2×4×2 m","room_domino":"Room · 2×4×2 m","bar":"Room · 2×6×2 m","small_square":"Room · 4×4×2 m","stairs":"Stairs · 180° · 2 m rise"}[kind]
		button.focus_mode=Control.FOCUS_NONE; grid.add_child(button)
		var icon:=Card.new(); icon.cells=sample.oriented({"shape":kind,"color":0},0).cells
		icon.role=sample.room_role({"shape":kind}); icon.tint=View.Palette.LIMESTONE_SIDE
		icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); icon.mouse_filter=Control.MOUSE_FILTER_IGNORE
		button.add_child(icon); button.pressed.connect(func():pick_shape(kind))
	button(palette,"Bed",func():pick_shape("bed"))
	button(palette,"Rain",func():game.rain_editor.begin(anchor+Vector3i.UP*floor_level*2))
	selector=HBoxContainer.new(); palette.add_child(selector)
	button(selector,"↓",func():set_floor(floor_level-1)); button(selector,"↑",func():set_floor(floor_level+1))
	button(palette,"◫",func():mode=(mode+1)%3; revision=-1)
	actions=HBoxContainer.new(); actions.theme=game.hud.root.theme; canvas.add_child(actions); actions.position=Vector2(24,100)*UI.POINT
	button(actions,"Move",func():begin_edit("move")); button(actions,"Copy",func():begin_edit("copy")); button(actions,"Delete",remove_selection)
	crumbs=HBoxContainer.new(); crumbs.theme=game.hud.root.theme; canvas.add_child(crumbs); crumbs.position=Vector2(24,148)*UI.POINT
	overlay=Control.new(); canvas.add_child(overlay); overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE; overlay.draw.connect(draw_outline)
	set_active(false)
func button(parent: Node,title: String,callback: Callable) -> Button:
	var b:=Button.new(); b.text=title; b.focus_mode=Control.FOCUS_NONE
	b.custom_minimum_size=Vector2(48,40)*UI.POINT; b.add_theme_font_size_override("font_size",UI.UI_FONT_SIZE)
	parent.add_child(b); b.pressed.connect(callback); return b
func set_active(value: bool) -> void:
	active=value; last_mouse=Vector2.INF; shape=""; ids=[]; path=[]; scope=""; edit_action=""; preview={}
	palette.visible=value; actions.hide(); crumbs.hide(); revision=-1
	if not value and view.ghost!=null:
		for child in view.ghost.get_children(): child.free()
	if overlay!=null: overlay.queue_redraw()
func sync() -> void:
	for control in [palette,actions,crumbs]: control.modulate=game.hud.root.modulate
	var visible: bool=not game.menu.visible and not (is_instance_valid(game.structure_workshop) and game.structure_workshop.is_open())
	canvas.visible=visible; view.visible=visible
	if model_instance!=game.model.get_instance_id():
		model_instance=game.model.get_instance_id(); history=[]; set_active(false)
	if revision!=game.model.revision:
		var shell_state: Dictionary=game.model.room_site.duplicate(); shell_state.erase("utilities")
		var state: Array=[shell_state,mode,floor_level if active else 100,
			game.model.plans.values().filter(func(plan):return plan.kind=="room_bed").map(func(plan):return plan.bed_cell)]
		revision=game.model.revision
		if state!=rendered_state:
			rendered_state=state.duplicate(true)
			view.rebuild(game.model,mode,floor_level if active else 100)
		update_preview()
	overlay.queue_redraw()
func pick_shape(value: String) -> void:
	last_mouse=Vector2.INF; shape=value; edit_action=""; ids=[]; path=[]; scope=""; yaw=0; entry_index=0
	actions.hide(); crumbs.hide(); update_preview()
func hand(design) -> Dictionary:
	var card: Dictionary=design.make_card(shape,0,1)
	if design.room_role(card)=="room":
		var choices: Array=design.entrance_options(shape)
		card.merge(choices[entry_index%choices.size()],true)
	return card
func set_floor(value: int) -> void:
	if game.model.room_site.is_empty(): floor_level=0; update_preview(); return
	floor_level=clampi(value,0,8); anchor.y=floor_level; revision=-1; update_preview()
func cancel() -> void:
	if shape.is_empty() and ids.is_empty() and edit_action.is_empty(): set_active(false)
	else: shape=""; ids=[]; path=[]; edit_action=""; actions.hide(); crumbs.hide(); update_preview()
func local_ray() -> Array:
	var origin: Vector3=game.rig.camera.project_ray_origin(game._viewport_mouse())
	var direction: Vector3=game.rig.camera.project_ray_normal(game._viewport_mouse())
	return [(origin-view.position)/2,direction]
func update_hover() -> void:
	if not active or game.get_viewport().gui_get_hovered_control()!=null or game.rig.rotating: return
	var mouse: Vector2=game._viewport_mouse()
	if mouse==last_mouse: return
	last_mouse=mouse
	if game.model.room_site.is_empty():
		var terrain: Dictionary=game.terrain_placement_at(mouse)
		if not terrain.is_empty(): anchor=terrain.cell; update_preview()
		return
	if shape.is_empty() and edit_action.is_empty(): return
	var ray:=local_ray(); var point=Plane(Vector3.UP,floor_level).intersects_ray(ray[0],ray[1])
	if point==null: return
	var next:=Vector3i(floori(point.x),floor_level,floori(point.z))
	if next!=anchor: anchor=next; update_preview()
func update_preview() -> void:
	preview={}
	if not active: return
	if view.ghost==null: view.ghost=Node3D.new(); view.add_child(view.ghost)
	for child in view.ghost.get_children(): child.free()
	if game.model.room_site.is_empty():
		if shape.is_empty() or shape=="bed": return
		view.position=Vector3(anchor)-Vector3(0.5,0,0.5); view.scale=Vector3.ONE*2
		var first=Rooms.layout(game.model); first.queue[0]=hand(first)
		preview=first.landing(first.queue[0],0,0,yaw,false,0)
		if first.drop(0,0,yaw,false,0):
			# Validate at the prospective origin without committing a world change.
			game.model.room_site=Rooms.fresh(anchor)
			preview.ok=Rooms.placement_error(game.model,first).is_empty()
			game.model.room_site={}
			view.model=first
			View.Shell.draw(view,view.ghost,first.rooms[0],mode,{},false,first.rooms)
			for mesh in view.ghost.find_children("*","MeshInstance3D",true,false): mesh.material_override.no_depth_test=true
		overlay.queue_redraw(); return
	var design=Rooms.layout(game.model)
	if not edit_action.is_empty():
		if ids.any(func(id):return id>=design.rooms.size()): cancel(); return
		preview=Rooms.Editor.plan(design,ids,anchor,yaw,edit_action=="copy",scope)
	elif shape=="bed":
		preview={"cells":[anchor],"ok":Rooms.can_add_bed(game.model,anchor)}
		view.bed(game.model,{"cell":Rooms.Layout.arr(anchor)},true,view.ghost)
		overlay.queue_redraw(); return
	elif not shape.is_empty():
		var card: Dictionary=hand(design)
		preview=design.landing(card,anchor.x,anchor.z,yaw,false,anchor.y)
	else: overlay.queue_redraw(); return
	var proposed: Array=preview.get("proposed_rooms",design.rooms)
	if preview.get("ok",false):
		var trial=Rooms.layout(game.model)
		if not edit_action.is_empty(): trial.rooms=proposed.duplicate(true)
		else:
			trial.queue[0]=hand(trial)
			trial.drop(anchor.x,anchor.z,yaw,false,anchor.y)
		var error:=Rooms.placement_error(game.model,trial)
		if not error.is_empty(): preview.ok=false; preview.reason=error
	var rooms: Array=preview.get("edited",[])
	if rooms.is_empty() and preview.has("door"):
		rooms=[{"id":proposed.size()-1 if preview.get("infill",false) else proposed.size(),"shape":shape,"color":0,
			"cells":preview.cells.map(func(p):return Rooms.Layout.arr(p)),"door":Rooms.Layout.arr(preview.door),"normal":Rooms.Layout.arr(preview.normal),"access_path":[]}]
	view.model=design
	for room in rooms:
		var node:=Node3D.new(); view.ghost.add_child(node)
		View.Shell.draw(view,node,room,mode,{},false,proposed)
		for mesh in node.find_children("*","MeshInstance3D",true,false):
			mesh.material_override=mesh.material_override.duplicate()
			mesh.material_override.no_depth_test=true; mesh.transparency=0.3
	overlay.queue_redraw()
func commit() -> bool:
	if shape.is_empty() and edit_action.is_empty(): return false
	if game.model.room_site.is_empty():
		game.model.room_site=Rooms.fresh(anchor); anchor=Vector3i.ZERO; floor_level=0
	var design=Rooms.layout(game.model); var before: Array=design.rooms.duplicate(true)
	var ok:=false
	if shape=="bed": ok=Rooms.add_bed(game.model,anchor)
	else:
		if not edit_action.is_empty():
			var plan:=Rooms.Editor.plan(design,ids,anchor,yaw,edit_action=="copy",scope)
			ok=Rooms.Editor.commit(design,plan)
		else:
			design.queue[0]=hand(design)
			ok=design.drop(anchor.x,anchor.z,yaw,false,anchor.y)
		if ok: ok=Rooms.commit(game.model,design)
		if ok: history.append(before)
	if ok:
		if not edit_action.is_empty(): cancel()
		revision=-1
	elif game.model.room_site.design.is_empty(): game.model.room_site={}
	if not ok: game._message(game.model.last_message)
	update_preview(); return ok
func select(id: int,additive:=false) -> void:
	var design=Rooms.layout(game.model)
	if additive:
		if scope!="multi": ids=[]
		if ids.has(id): ids.erase(id)
		else: ids.append(id)
		scope="multi"; path=[]
	else:
		var next: Array=Rooms.Editor.path(design,id); var depth:=0
		if ids.has(id):
			for i in next.size():
				if next[i].kind==scope and next[i].ids==ids: depth=mini(i+1,next.size()-1); break
		elif not path.is_empty():
			for i in mini(path.size(),next.size()):
				if path[i].kind!=next[i].kind or path[i].ids!=next[i].ids: break
				depth=mini(i+1,next.size()-1)
		path=next.slice(0,depth+1); ids=next[depth].ids.duplicate(); scope=next[depth].kind
	actions.visible=not ids.is_empty(); crumbs.visible=not path.is_empty()
	var locked: bool=ids.any(func(i):return Rooms.constructed(game.model,design.rooms[i]) or game.model.plans.values().any(func(plan):return plan.get("room_uid",-1)==design.rooms[i].uid and (plan.installed>0 or plan.reserved>0)))
	actions.get_child(0).disabled=locked; actions.get_child(2).disabled=locked
	for child in crumbs.get_children(): child.free()
	for i in path.size():
		button(crumbs,path[i].label,func():ids=path[i].ids.duplicate(); scope=path[i].kind; path=path.slice(0,i+1); overlay.queue_redraw())
	overlay.queue_redraw()
func begin_edit(action: String) -> void:
	if ids.is_empty(): return
	edit_action=action; shape=""; yaw=0
	var card: Dictionary=Rooms.Editor.card(Rooms.layout(game.model),ids)
	anchor=card.origin
	if action=="copy": anchor.y+=1
	set_floor(anchor.y); update_preview()
func remove_selection() -> void:
	if ids.is_empty(): return
	var design=Rooms.layout(game.model); var before: Array=design.rooms.duplicate(true)
	if Rooms.Editor.commit(design,Rooms.Editor.removal(design,ids)) and Rooms.commit(game.model,design):
		history.append(before); cancel(); revision=-1
func handle(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key: int=event.physical_keycode if event.physical_keycode else event.keycode
		if key==KEY_ESCAPE: cancel(); return
		if key==KEY_G and (event.meta_pressed or event.ctrl_pressed) and ids.size()>1:
			var design=Rooms.layout(game.model); Rooms.Editor.group_rooms(design,ids)
			if Rooms.commit(game.model,design): revision=-1
		elif key==KEY_Z and not history.is_empty():
			var design=Rooms.layout(game.model); design.rooms=history[-1].duplicate(true)
			if Rooms.commit(game.model,design): history.pop_back(); cancel(); revision=-1
		elif key==KEY_BACKSPACE: remove_selection()
		elif key>=KEY_1 and key<=KEY_9: set_floor(key-KEY_1)
		elif key==KEY_COMMA: set_floor(floor_level-1)
		elif key==KEY_PERIOD: set_floor(floor_level+1)
		elif key==KEY_SPACE: commit()
		elif key==KEY_R: yaw=(yaw+1)%4; update_preview()
		elif key==KEY_F and not shape.is_empty() and shape!="bed": entry_index+=1; update_preview()
		elif key in [KEY_LEFT,KEY_RIGHT,KEY_UP,KEY_DOWN] and (not shape.is_empty() or not edit_action.is_empty()):
			anchor+={KEY_LEFT:Vector3i.LEFT,KEY_RIGHT:Vector3i.RIGHT,KEY_UP:Vector3i.FORWARD,KEY_DOWN:Vector3i.BACK}[key]*(2 if game.model.room_site.is_empty() else 1); update_preview()
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed:
		if not shape.is_empty() or not edit_action.is_empty(): commit(); return
		if game.model.room_site.is_empty(): return
		var ray:=local_ray(); var hit: Dictionary=Picker.cast(Rooms.layout(game.model),ray[0],ray[1],mode,floor_level)
		if not hit.is_empty(): select(hit.id,event.shift_pressed)
func draw_outline() -> void:
	if not active: return
	var cells: Array=preview.get("cells",[])
	if cells.is_empty() and not ids.is_empty(): cells=Rooms.Editor.cells(Rooms.layout(game.model),ids)
	var screen_scale:=Vector2(game.get_viewport().get_visible_rect().size)/Vector2(game.viewport.size)
	for edge in Outline.edges(cells):
		var a: Vector3=view.position+Vector3(edge[0])*2; var b: Vector3=view.position+Vector3(edge[1])*2
		if not preview.is_empty() and not preview.get("ok",false):
			overlay.draw_dashed_line(game.rig.camera.unproject_position(a)*screen_scale,game.rig.camera.unproject_position(b)*screen_scale,UI.SELECTION_COLOR,UI.LINE_WIDTH,8*UI.POINT,true)
		else: overlay.draw_line(game.rig.camera.unproject_position(a)*screen_scale,game.rig.camera.unproject_position(b)*screen_scale,UI.SELECTION_COLOR,UI.LINE_WIDTH,true)
