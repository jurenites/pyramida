extends "res://scripts/block_city/game.gd"
const Economy=preload("res://scripts/block_city/economy_lab_model.gd")
const LabIcon=preload("res://scripts/block_city/lab_icon.gd")
const WATER:=Color("57b7db")
const SEWER:=Color("b78461")
var economy=Economy.new()
var focused_floor:=0
var tool_kind:="home"
var pipe_source:=-99
var pipe_kind:=""
var hover_slot:=Vector2i(-1,-1)
var pulses:=0.0
var flash:=0.0
var hud_money: Label
var hud_people: Label
var hud_month: Label
var hud_net: Label
var tool_buttons: Dictionary={}
var floor_buttons: VBoxContainer
var add_level_button: Button
var month_button: Button
var capacity_button: Button
var lift_button: Button
var lesson_complete:=false

func _ready() -> void:
	auto_save=false; restore_last=false; holding=false
	get_window().title="Block City · Economy & Plumbing Lab"
	setup_world()
	setup_lab_ui()
	refresh_lab()
	get_viewport().size_changed.connect(update_camera)
	get_window().focus_exited.connect(stop_camera_motion)
func lab_icon(symbol: String, parent: Node, callback: Callable, tip: String) -> Button:
	var control:=LabIcon.new()
	control.symbol=symbol; control.tooltip_text=tip
	control.custom_minimum_size=Vector2(48,48)*UI.POINT
	control.focus_mode=Control.FOCUS_NONE
	control.add_theme_stylebox_override("normal",style(PAPER))
	control.add_theme_stylebox_override("hover",style(Color.WHITE))
	control.add_theme_stylebox_override("pressed",style(Color("d7e9e2")))
	control.pressed.connect(callback); parent.add_child(control)
	return control
func setup_lab_ui() -> void:
	var layer:=CanvasLayer.new(); add_child(layer)
	canvas=Control.new(); layer.add_child(canvas)
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.mouse_filter=Control.MOUSE_FILTER_IGNORE
	overlay=Control.new(); canvas.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE; overlay.draw.connect(draw_lab_overlay)
	var hud:=HBoxContainer.new(); canvas.add_child(hud)
	hud.position=Vector2(24,24)*UI.POINT
	hud.add_theme_constant_override("separation",8*UI.GAP_UNIT)
	var coin:=lab_icon("coin",hud,func():pass,"Money"); coin.mouse_filter=Control.MOUSE_FILTER_IGNORE
	hud_money=label("",hud)
	var people:=lab_icon("people",hud,func():pass,"Residents"); people.mouse_filter=Control.MOUSE_FILTER_IGNORE
	hud_people=label("",hud)
	hud_net=label("",canvas); hud_net.position=Vector2(34,78)*UI.POINT
	cards_box=VBoxContainer.new(); canvas.add_child(cards_box)
	cards_box.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	cards_box.offset_left=-72*UI.POINT; cards_box.offset_right=-24*UI.POINT; cards_box.offset_top=24*UI.POINT
	cards_box.add_theme_constant_override("separation",8*UI.GAP_UNIT)
	for kind in ["home","garden","bath","remove"]:
		tool_buttons[kind]=lab_icon(kind,cards_box,func(): tool_kind=kind; pipe_source=-99; refresh_lab(),{"home":"Home · 24","garden":"Garden · 12","bath":"Move bathroom · route cost difference","remove":"Remove · full prototype refund"}[kind])
	floor_buttons=VBoxContainer.new(); canvas.add_child(floor_buttons)
	floor_buttons.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	floor_buttons.offset_left=-72*UI.POINT; floor_buttons.offset_right=-24*UI.POINT
	var bottom:=HBoxContainer.new(); canvas.add_child(bottom)
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	bottom.offset_left=-152*UI.POINT; bottom.offset_right=-24*UI.POINT; bottom.offset_top=-72*UI.POINT; bottom.offset_bottom=-24*UI.POINT
	month_button=lab_icon("month",bottom,advance_month,"Next month · Enter")
	hud_month=label("0",bottom)
	capacity_button=lab_icon("capacity",canvas,func():buy_lab_upgrade("capacity"),"Street capacity · 16 → 24 · cost 24")
	lift_button=lab_icon("lift",canvas,func():buy_lab_upgrade("lift"),"Lift · cost 36 · upkeep 3/month")
	menu=ColorRect.new(); canvas.add_child(menu)
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); menu.color=Color(0.1,0.15,0.15,0.4)
	var center:=CenterContainer.new(); menu.add_child(center); center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var options:=VBoxContainer.new(); center.add_child(options)
	options.custom_minimum_size.x=240*UI.POINT
	button("Resume",options,func():menu.hide())
	button("New experiment",options,func(): economy.reset(); lesson_complete=false; focused_floor=0; tool_kind="home"; pipe_source=-99; hover_slot=Vector2i(-1,-1); menu.hide(); refresh_lab())
	button("Construction Demo",options,func():get_tree().change_scene_to_file("res://scenes/block_city/BlockCity.tscn"))
	button("Quit",options,func():get_tree().quit())
	menu.hide()
func level_y(level: int) -> float: return float(level)
func displayed(point: Vector3) -> Vector3: return point
func port_position(level: int, kind: String) -> Vector3:
	var offset:=Vector3(-0.16,0.12,0) if kind=="water" else Vector3(0.16,0.12,0)
	return (Economy.ROAD if level<0 else displayed(economy.bathroom(level)))+offset
func visual_route(level: int, kind: String) -> Array[Vector3]:
	var result: Array[Vector3]=[]
	var offset:=Vector3(-0.08,0,0) if kind=="water" else Vector3(0.08,0,0)
	for point in economy.route(level): result.append(displayed(point)+offset)
	result[0]=port_position(level,kind)
	result[-1]=port_position(level-1,kind)
	return result
func update_camera() -> void:
	if camera==null: return
	var target:=Vector3(1.0,level_y(economy.floors.size()-1)*0.5+0.1,0.5)
	camera.position=target+Vector3(sin(orbit)*cos(elevation),sin(elevation),cos(orbit)*cos(elevation))*30
	camera.look_at(target); camera.keep_aspect=Camera3D.KEEP_HEIGHT
	var size:=get_viewport().get_visible_rect().size
	camera.size=maxf(8.5+economy.floors.size()*0.85,9.0*size.y/maxf(size.x-160,1))*zoom
	if capacity_button!=null:
		capacity_button.position=camera.unproject_position(Economy.ROAD+Vector3(1.0,0.3,0))-Vector2(24,24)
		lift_button.position=camera.unproject_position(lift_position())-Vector2(24,24)
	if overlay!=null: overlay.queue_redraw()
func refresh_lab() -> void:
	focused_floor=clampi(focused_floor,0,economy.floors.size()-1)
	if economy.residents()>0: lesson_complete=true
	clear_nodes(geometry); clear_nodes(ghost); neighbours.clear()
	draw_neighbourhood(false)
	for neighbour in neighbours:
		for mesh in neighbour.node.get_children():
			mesh.transparency=0.94; mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The circular street manhole has separate supply and drain ports.
	var cover:=MeshInstance3D.new(); var mesh:=CylinderMesh.new()
	mesh.top_radius=0.33; mesh.bottom_radius=0.33; mesh.height=0.04; mesh.radial_segments=32
	cover.mesh=mesh; cover.position=Vector3(Economy.ROAD.x,-0.05,Economy.ROAD.z); cover.material_override=material(INK); geometry.add_child(cover)
	var allocated: Dictionary=economy.allocations()
	for level in economy.floors.size(): draw_lab_floor(level,allocated)
	for level in economy.floors.size():
		for kind in Economy.NETWORKS:
			if not economy.floors[level][kind]: continue
			var route: Array[Vector3]=visual_route(level,kind)
			var tint:=WATER if kind=="water" else SEWER
			if not economy.linked(level,kind): tint=ENTRY_PENDING
			for i in range(1,route.size()): beam(geometry,route[i-1],route[i],tint,0.025)
	capacity_button.visible=lesson_complete and (not economy.upgraded or tool_kind=="remove")
	lift_button.visible=lesson_complete and (economy.floors.size()>1 or economy.lift) and (not economy.lift or tool_kind=="remove")
	hud_money.text="∞" if economy.mode=="creative" else "%.1f" % economy.cash
	hud_people.text=str(economy.residents())
	hud_month.text=str(economy.finished_month if economy.mode=="sprint" and economy.finished_month>=0 else economy.month)
	hud_month.modulate=ENTRY_CONNECTED if economy.mode=="sprint" and economy.finished_month>=0 else INK
	var net: float=economy.forecast().net
	hud_net.text="%+.1f" % net if lesson_complete else ""
	hud_net.tooltip_text="Next month · income %.1f − upkeep %.1f" % [economy.forecast().income,economy.forecast().upkeep]
	tool_buttons.home.tooltip_text="Home · %.0f" % economy.config.home_cost
	tool_buttons.garden.tooltip_text="Garden · %.0f" % economy.config.garden_cost
	capacity_button.tooltip_text="Street capacity · %d → %d · cost %.0f" % [economy.config.street_capacity,int(economy.config.street_capacity)+int(economy.config.upgrade_capacity),economy.config.capacity_upgrade_cost]
	lift_button.tooltip_text="Lift · cost %.0f · upkeep %.0f/month" % [economy.config.lift_cost,economy.config.lift_upkeep]
	if tool_kind=="remove":
		capacity_button.tooltip_text="Remove street upgrade · refund %.0f" % economy.config.capacity_upgrade_cost
		lift_button.tooltip_text="Remove lift · refund %.0f" % economy.config.lift_cost
	for kind in tool_buttons:
		tool_buttons[kind].visible=lesson_complete or kind=="home"
		tool_buttons[kind].modulate=Color.WHITE if kind==tool_kind else Color(0.72,0.72,0.72)
	for child in floor_buttons.get_children():
		floor_buttons.remove_child(child); child.queue_free()
	for level in range(economy.floors.size()-1,-1,-1):
		var b:=button(str(level+1),floor_buttons,func():focused_floor=level; pipe_source=-99; refresh_lab(),"Floor "+str(level+1))
		b.modulate=Color.WHITE if level==focused_floor else Color(0.65,0.65,0.65)
	add_level_button=null
	if lesson_complete and tool_kind=="remove" and economy.floors.size()>1:
		add_level_button=button("−",floor_buttons,remove_lab_floor,"Remove top floor and contents · full refund")
	elif lesson_complete and economy.floors.size()<int(economy.config.max_floors):
		add_level_button=button("+",floor_buttons,add_lab_floor,"New floor · %.0f" % economy.config.floor_cost)
	if add_level_button!=null: floor_buttons.move_child(add_level_button,0)
	update_camera()
func add_lab_floor() -> void:
	if menu.visible: return
	if economy.add_floor(): focused_floor=economy.floors.size()-1; pipe_source=-99; refresh_lab()
	else: fail_flash()
func remove_lab_floor() -> void:
	if menu.visible: return
	if economy.remove_floor(): focused_floor=mini(focused_floor,economy.floors.size()-1); pipe_source=-99; refresh_lab()
func buy_lab_upgrade(kind: String) -> void:
	if menu.visible: return
	var ok: bool=economy.remove_upgrade(kind) if tool_kind=="remove" else economy.buy_upgrade(kind)
	if ok: refresh_lab()
	else: fail_flash()
func draw_lab_floor(level: int, allocated: Dictionary) -> void:
	var parent:=Node3D.new(); geometry.add_child(parent); parent.name="LabFloor%d" % level
	parent.position.y=level_y(level)
	for x in 3:
		for z in 3:
			box(parent,Vector3(x+0.5,0.015,z+0.5),Vector3(0.96,0.06,0.96),Color("d4d4ce") if z==1 else Color("c3ccc0"))
	for x in [0.08,2.92]:
		for z in [0.08,2.92]: box(parent,Vector3(x,0.5,z),Vector3(0.10,1,0.10),Color("b8bcb8"))
	RoomView.stairs(self,parent,Vector3i(2,0,1),Vector3i.FORWARD,Color("c5c8c3"))
	var bath: Vector2i=economy.bath_slot(level)
	box(parent,Vector3(bath.x+0.5,0.08,bath.y+0.5),Vector3(0.88,0.06,0.88),Color("b4d4d8"))
	box(parent,Vector3(bath.x+0.5,0.32,bath.y+0.65),Vector3(0.36,0.46,0.18),Color("f4f3ed"))
	box(parent,Vector3(bath.x+0.5,0.25,bath.y+0.4),Vector3(0.4,0.18,0.43),Color("f4f3ed"))
	box(parent,Vector3(bath.x+0.5,0.35,bath.y+0.38),Vector3(0.23,0.025,0.24),Color("759998"))
	for room in economy.floors[level].rooms:
		var x:=int(room.at[0]); var z:=int(room.at[1])
		if room.kind=="garden":
			box(parent,Vector3(x+0.5,0.12,z+0.5),Vector3(0.80,0.14,0.80),Color("879974"))
			for at in [Vector3(0.3,0.25,0.3),Vector3(0.7,0.34,0.65),Vector3(0.3,0.42,0.7)]: box(parent,Vector3(x,0,z)+at,Vector3(0.28,0.36,0.28),Color("79ad88"))
		else:
			var inside:=Vector3i.BACK if z==0 else Vector3i.FORWARD
			var shell:={"shape":"bar","color":0,"cells":[[x,0,z]],"door":[x,0,z],"normal":Model.arr(inside)}
			RoomView.draw(self,parent,shell,1,{},allocated.has(int(room.id)))
			box(parent,Vector3(x+0.30,0.18,z+0.5),Vector3(0.35,0.22,0.65),Color("cfaa91"))
			box(parent,Vector3(x+0.30,0.31,z+0.3),Vector3(0.32,0.06,0.18),PAPER)
			if int(room.people)>0:
				var color:=Color("e8c267") if allocated.has(int(room.id)) else ENTRY_PENDING
				for shift in [0.0,0.23]:
					box(parent,Vector3(x+0.63,0.24,z+0.38+shift),Vector3(0.11,0.25,0.11),color)
					box(parent,Vector3(x+0.63,0.41,z+0.38+shift),Vector3.ONE*0.14,INK)
	if economy.lift:
		box(parent,Vector3(0.5,0.52,1.5),Vector3(0.65,0.94,0.65),Color("9fb6bf"))
		box(parent,Vector3(0.5,0.48,1.15),Vector3(0.46,0.76,0.04),PAPER)
	if level!=focused_floor:
		for node in parent.find_children("*","MeshInstance3D",true,false): node.transparency=0.93
func draw_plus(at: Vector3, color: Color, radius:=12.0) -> void:
	var p:=camera.unproject_position(at)
	overlay.draw_circle(p,radius,color,false,UI.LINE_WIDTH,true)
	overlay.draw_line(p-Vector2(6,0),p+Vector2(6,0),color,UI.LINE_WIDTH,true)
	overlay.draw_line(p-Vector2(0,6),p+Vector2(0,6),color,UI.LINE_WIDTH,true)
func draw_lab_overlay() -> void:
	if camera==null or menu.visible: return
	var pulse:=0.55+0.45*sin(pulses*3.0)
	var step: int=economy.teaching_step()
	for level in range(focused_floor+1):
		for kind in Economy.NETWORKS:
			if not economy.floors[level][kind]: continue
			var tint:=WATER if kind=="water" else SEWER
			if not economy.linked(level,kind): tint=ENTRY_PENDING
			var route: Array[Vector3]=visual_route(level,kind)
			for index in range(1,route.size()):
				var a:=camera.unproject_position(route[index-1])
				var b:=camera.unproject_position(route[index])
				overlay.draw_line(a,b,Color(tint,0.85),UI.LINE_WIDTH,true)
				if a.distance_to(b)<20: continue
				var direction: Vector2=(a-b).normalized() if kind=="water" else (b-a).normalized()
				var center: Vector2=a.lerp(b,0.5)
				var side:=Vector2(-direction.y,direction.x)
				overlay.draw_polyline(PackedVector2Array([center-direction*5+side*4,center+direction*3,center-direction*5-side*4]),tint,UI.LINE_WIDTH,true)
	for level in range(-1,economy.floors.size()):
		for kind in Economy.NETWORKS:
			var tint:=WATER if kind=="water" else SEWER
			var relevant: bool=lesson_complete or (step==1 and kind=="water") or (step==2 and kind=="sewer") or pipe_source!=-99
			if not relevant: continue
			var at:=camera.unproject_position(port_position(level,kind))
			var active:=level<0 or economy.linked(level,kind)
			if not active: tint=tint.darkened(0.3)
			if pipe_source==level and pipe_kind==kind: tint=UI.SELECTION_COLOR
			overlay.draw_circle(at,8.0,tint,false,UI.LINE_WIDTH,true)
			if not lesson_complete and level==-1: overlay.draw_arc(at,13.0,0,TAU*pulse,24,tint,UI.LINE_WIDTH,true)
	if pipe_source!=-99:
		var source:=camera.unproject_position(port_position(pipe_source,pipe_kind))
		var destination:=get_viewport().get_mouse_position()
		overlay.draw_line(source,destination,WATER if pipe_kind=="water" else SEWER,UI.LINE_WIDTH,true)
	if economy.valid_slot(focused_floor,hover_slot):
		var points:=PackedVector2Array()
		for corner in [Vector2(0.03,0.03),Vector2(0.97,0.03),Vector2(0.97,0.97),Vector2(0.03,0.97),Vector2(0.03,0.03)]:
			points.append(camera.unproject_position(Vector3(hover_slot.x+corner.x,level_y(focused_floor)+0.08,hover_slot.y+corner.y)))
		overlay.draw_polyline(points,UI.SELECTION_COLOR,UI.LINE_WIDTH,true)
	if not lesson_complete and step==0: draw_plus(Vector3(1.5,0.10,0.5),UI.SELECTION_COLOR.lightened(pulse*0.2))
	var allocated: Dictionary=economy.allocations()
	for room in economy.floors[focused_floor].rooms:
		if room.kind!="home" or allocated.has(int(room.id)): continue
		var at:=camera.unproject_position(Vector3(room.at[0]+0.5,level_y(focused_floor)+1.05,room.at[1]+0.5))
		var color:=WATER if not economy.linked(focused_floor,"water") else (SEWER if not economy.linked(focused_floor,"sewer") else ENTRY_PENDING)
		overlay.draw_circle(at,7,color,false,UI.LINE_WIDTH,true)
		overlay.draw_line(at-Vector2(4,4),at+Vector2(4,4),color,UI.LINE_WIDTH,true)
func add_floor_position() -> Vector3: return Vector3(1.5,level_y(economy.floors.size()-1)+1.4,1.5)
func lift_position() -> Vector3: return Vector3(3.6,level_y(focused_floor)+0.4,1.5)
func near(screen: Vector2, world: Vector3, radius:=14.0) -> bool: return screen.distance_to(camera.unproject_position(world))<=radius
func lab_slot(screen: Vector2) -> Vector2i:
	var at=Plane(Vector3.UP,level_y(focused_floor)+0.08).intersects_ray(camera.project_ray_origin(screen),camera.project_ray_normal(screen))
	if at==null: return Vector2i(-1,-1)
	return Vector2i(floori(at.x),floori(at.z))
func fail_flash() -> void:
	flash=0.7
	if economy.error=="cash": hud_money.modulate=ENTRY_PENDING
func lab_click(screen: Vector2) -> void:
	if menu.visible or orbiting: return
	if cards_box.get_global_rect().has_point(screen) or floor_buttons.get_global_rect().has_point(screen): return
	for control in [capacity_button,lift_button]:
		if control.visible and control.get_global_rect().has_point(screen): return
	if month_button.get_global_rect().has_point(screen): return
	for level in range(-1,economy.floors.size()):
		for kind in Economy.NETWORKS:
			if not lesson_complete and not (economy.teaching_step()==1 and kind=="water") and not (economy.teaching_step()==2 and kind=="sewer"): continue
			if not near(screen,port_position(level,kind),11): continue
			if pipe_source==-99:
				pipe_source=level; pipe_kind=kind
			elif kind==pipe_kind and level!=pipe_source:
				var lower:=mini(level,pipe_source); var upper:=maxi(level,pipe_source)
				if economy.connect_pipe(lower,upper,kind): pipe_source=-99; refresh_lab()
				else: fail_flash()
			else: pipe_source=-99
			overlay.queue_redraw(); return
	if pipe_source!=-99: pipe_source=-99; overlay.queue_redraw(); return
	var slot:=lab_slot(screen)
	var ok:=false
	if tool_kind=="bath": ok=economy.move_bath(focused_floor,slot)
	elif tool_kind=="remove": ok=economy.remove(focused_floor,slot)
	else: ok=economy.build(focused_floor,slot,tool_kind)
	if ok: refresh_lab()
	else: fail_flash()
func advance_month() -> void:
	if menu.visible: return
	economy.advance(); refresh_lab()
func _process(delta: float) -> void:
	pulses+=delta
	if flash>0:
		flash-=delta
		if flash<=0: hud_money.modulate=Color.WHITE
	if month_button!=null:
		month_button.modulate=Color.WHITE.lerp(ENTRY_CONNECTED,0.3+0.2*sin(pulses*3)) if not lesson_complete and economy.teaching_step()==3 else Color.WHITE
	if overlay!=null: overlay.queue_redraw()
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and not event.pressed and event.button_index==orbit_button:
		if orbit_button==MOUSE_BUTTON_RIGHT and orbit_drag_distance<4: pipe_source=-99
		orbiting=false; orbit_button=MOUSE_BUTTON_NONE
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_ESCAPE: menu.visible=not menu.visible; stop_camera_motion(); return
	if menu.visible: return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_Q: turn_camera(-1)
			KEY_E: turn_camera(1)
			KEY_ENTER: advance_month()
			KEY_Z:
				if economy.undo(): pipe_source=-99; refresh_lab()
			KEY_PAGEUP: focused_floor=mini(economy.floors.size()-1,focused_floor+1); refresh_lab()
			KEY_PAGEDOWN: focused_floor=maxi(0,focused_floor-1); refresh_lab()
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index==MOUSE_BUTTON_LEFT: lab_click(event.position)
		elif event.button_index in [MOUSE_BUTTON_RIGHT,MOUSE_BUTTON_MIDDLE]:
			stop_camera_motion(); orbiting=true; orbit_button=event.button_index; orbit_drag_distance=0
		elif event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			zoom=clampf(zoom+(-0.04 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 0.04),0.82,1.3); update_camera()
	if event is InputEventMouseMotion:
		if orbiting:
			orbit_drag_distance+=event.relative.length(); orbit-=event.relative.x*0.008; orbit_target=orbit
			elevation=clampf(elevation+event.relative.y*0.004,0.25,1.1); update_camera()
		else: hover_slot=lab_slot(event.position)
