extends Node
const Plans = preload("res://scripts/settlement/generated_building_plan.gd")
const RoomView = preload("res://scripts/settlement/room_editor_view.gd")
const UI = preload("res://scripts/ui_visual_tokens.gd")
var game
var active := false
var seed_ := 0
var yaw := 0
var anchor := Vector3i.ZERO
var proposal := {}
var ghost: Node3D
var toolbar := HBoxContainer.new()
var cost := Label.new()
var stamp: Array = []
var services: Node3D
var service_label := Label.new()
var service_hit := {}
var home_services := {}
var service_view: Node3D

func setup(host) -> void:
	game=host
	services=preload("res://scripts/settlement/town_utility_view.gd").new(); game.viewport.add_child(services)
	var canvas := CanvasLayer.new(); add_child(canvas); canvas.add_child(toolbar)
	canvas.add_child(service_label); service_label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	service_label.add_theme_font_size_override("font_size",UI.UI_FONT_SIZE)
	service_label.add_theme_color_override("font_color",Color("FFF0C9"))
	service_label.add_theme_color_override("font_shadow_color",Color("4D342D")); service_label.add_theme_constant_override("shadow_offset_x",2); service_label.add_theme_constant_override("shadow_offset_y",2)
	toolbar.position=Vector2(16,100)*UI.POINT; toolbar.add_theme_constant_override("separation",8*UI.GAP_UNIT)
	for entry in [["Generate",func():seed_+=1; stamp=[]],["Rotate",func():yaw=(yaw+1)%4; stamp=[]]]:
		var button := Button.new(); button.text=entry[0]; button.pressed.connect(entry[1]); button.add_theme_font_size_override("font_size",UI.UI_FONT_SIZE); toolbar.add_child(button)
	cost.add_theme_font_size_override("font_size",UI.UI_FONT_SIZE); toolbar.add_child(cost); toolbar.hide()

func begin() -> void:
	active=true; stamp=[]; yaw=0; toolbar.show(); game.hud.build_panel.hide()

func cancel() -> void:
	active=false; toolbar.hide(); proposal={}; stamp=[]
	if is_instance_valid(ghost): ghost.queue_free()

func _process(_delta: float) -> void:
	if game == null or not game.setup_complete: return
	if game.room_editor != null:
		Plans.Exemplars.detail(game.room_editor.view,game.viewport.get_visible_rect().size.y/game.rig.zoom)
	for asset in game.world.entity_views.values():
		var assembled=asset.get_node_or_null("AssembledHome")
		if assembled==null: assembled=asset.get_node_or_null("AssembledBuilding")
		if assembled!=null: Plans.Exemplars.detail(assembled,game.viewport.get_visible_rect().size.y/game.rig.zoom)
	services.visible=not game.menu.visible
	services.sync(game.model,game.viewport.get_visible_rect().size.y/game.rig.zoom)
	services.set_cutaway(game.room_editor.floor_level*2 if game.room_editor.active else (game.world.display_level if game.world.cutaway else INF),game.room_editor.active and game.room_editor.mode>0)
	service_hit={}; service_view=services; service_label.hide()
	var homes=preload("res://scripts/settlement/home_assembly.gd")
	var wanted := {}
	for context in homes.contexts(game.model):
		var owner: int=context.room_site.design[0].uid
		wanted[owner]=true
		if not home_services.has(owner):
			var view=preload("res://scripts/settlement/town_utility_view.gd").new(); game.viewport.add_child(view); home_services[owner]=view
		home_services[owner].visible=not game.menu.visible
		home_services[owner].sync(context,game.viewport.get_visible_rect().size.y/game.rig.zoom)
		home_services[owner].set_cutaway(game.world.display_level if game.world.cutaway else INF)
	for owner in home_services.keys():
		if not wanted.has(owner): home_services[owner].free(); home_services.erase(owner)
	if not active and game.tool=="inspect" and not game.menu.visible and not game.room_editor.active and game.get_viewport().gui_get_hovered_control()==null:
		var mouse: Vector2=game._viewport_mouse()
		service_hit=services.hit(game.rig.camera.project_ray_origin(mouse),game.rig.camera.project_ray_normal(mouse))
		for view in home_services.values():
			var hit: Dictionary=view.hit(game.rig.camera.project_ray_origin(mouse),game.rig.camera.project_ray_normal(mouse))
			if not hit.is_empty(): service_hit=hit; service_view=view; break
		if not service_hit.is_empty():
			service_label.text=service_view.label_for(service_hit); service_label.position=game.get_viewport().get_mouse_position()+Vector2(18,18)
			service_label.visible=not service_label.text.is_empty()
	if not active: return
	if game.menu.visible or game.operation_busy: cancel(); return
	if game.get_viewport().gui_get_hovered_control()!=null or game.rig.rotating: return
	var hit: Dictionary=game.terrain_placement_at(game._viewport_mouse())
	if hit.is_empty():
		proposal={}; stamp=[]
		if is_instance_valid(ghost): ghost.hide()
		return
	anchor=hit.cell
	if not game.model.room_site.is_empty():
		var origin: Vector3i=game.model.room_site.origin
		anchor.x=origin.x+roundi(float(anchor.x-origin.x)/2)*2; anchor.z=origin.z+roundi(float(anchor.z-origin.z)/2)*2
	var next: Array=[anchor,seed_,yaw,game.model.revision]
	if next==stamp: return
	stamp=next; proposal=Plans.prepare(game.model,anchor,seed_,yaw)
	if is_instance_valid(ghost): ghost.free()
	cost.text="" if proposal.error.is_empty() else proposal.error
	toolbar.tooltip_text=Plans.Utilities.cost_text(proposal.materials) if proposal.error.is_empty() else proposal.error
	if not proposal.has("design"): return
	ghost=RoomView.new(); game.viewport.add_child(ghost)
	ghost.position=Vector3(proposal.site.origin)-Vector3(0.5,0,0.5); ghost.scale=Vector3.ONE*2; ghost.model=proposal.design
	for room in proposal.added: ghost.draw_room(room,proposal.design.rooms,true)

func handle(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode==KEY_ESCAPE: cancel()
		elif event.keycode==KEY_R: yaw=(yaw+1)%4; stamp=[]
	elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed and not proposal.is_empty():
		var fresh := Plans.prepare(game.model,anchor,seed_,yaw)
		if Plans.commit(game.model,fresh): cancel()

func handle_fixture(event: InputEvent) -> bool:
	if service_hit.is_empty(): return false
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed:
		service_view.activate(service_hit); return true
	return false
