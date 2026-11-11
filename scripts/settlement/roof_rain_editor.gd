extends Node
const Rain = preload("res://scripts/settlement/roof_rain.gd")
const View = preload("res://scripts/settlement/roof_rain_view.gd")
const Geometry = preload("res://scripts/settlement/rain_fitting_geometry.gd")
const UI = preload("res://scripts/ui_visual_tokens.gd")
var game
var active := false
var mode := "vase"
var anchor := Vector3i.ZERO
var toolbar := HBoxContainer.new()
var label := Label.new()
var ghost := Node3D.new()
var spec := {}
var gutter := -1
var source_joint := -1
var editing := -1
var route_height := 0.0
var height_label := Label.new()
var ground_button := Button.new()
var path: Array = []
var hovered := {}
var moving: Variant = null
func reset_path() -> void:
	gutter=-1; source_joint=-1; editing=-1; path=[]; spec={}
	ground_button.set_pressed_no_signal(false)
func setup(host) -> void:
	game=host; game.viewport.add_child(ghost)
	var canvas:=CanvasLayer.new(); add_child(canvas); canvas.add_child(toolbar); canvas.add_child(label)
	toolbar.theme=game.hud.root.theme; toolbar.position=Vector2(16,100)*UI.POINT; toolbar.add_theme_constant_override("separation",4*UI.POINT)
	for entry in [["Vase","vase"],["Barrel","barrel"],["Gutter","gutter"],["Pipe","pipe"],["Move","move"],["Remove","remove"],["Basin","basin"],["Junction","junction"],["Edit","edit"]]:
		var button:=Button.new(); button.text=entry[0]; button.focus_mode=Control.FOCUS_NONE; button.add_theme_font_size_override("font_size",UI.UI_FONT_SIZE)
		button.tooltip_text={"vase":"2 Clay, 1 droplet","barrel":"6 Planks, 2 droplets","basin":"24 Clay + 12 Stone, 24 droplets","gutter":"0.25 m clay section, 1 Clay","pipe":"Click bends, then a receiver. Shift uses the selected height. Backspace undoes a bend.","junction":"Join several drains. Adjust height with the arrows.","edit":"Redraw a pipe route, keeping its existing Clay","move":"Move container","remove":"Recover fitting materials"}[entry[1]]
		toolbar.add_child(button); button.pressed.connect(func():mode=entry[1]; reset_path(); moving=null)
	for direction in [-1,1]:
		var button:=Button.new(); button.text="↓" if direction<0 else "↑"; button.focus_mode=Control.FOCUS_NONE; button.add_theme_font_size_override("font_size",UI.UI_FONT_SIZE)
		button.pressed.connect(func():route_height+=direction*0.25)
		toolbar.add_child(button)
	height_label.add_theme_font_size_override("font_size",UI.UI_FONT_SIZE); toolbar.add_child(height_label)
	ground_button.text="Ground"; ground_button.toggle_mode=true; ground_button.focus_mode=Control.FOCUS_NONE
	ground_button.tooltip_text="End the drain here. Place a container underneath to catch the water."
	ground_button.add_theme_font_size_override("font_size",UI.UI_FONT_SIZE); toolbar.add_child(ground_button); ground_button.hide()
	var done:=Button.new(); done.text="Done"; done.pressed.connect(cancel); done.add_theme_font_size_override("font_size",UI.UI_FONT_SIZE); toolbar.add_child(done)
	label.mouse_filter=Control.MOUSE_FILTER_IGNORE; label.add_theme_font_size_override("font_size",UI.UI_FONT_SIZE)
	label.add_theme_color_override("font_color",Color("fff0c9")); label.add_theme_color_override("font_shadow_color",Color("4d342d")); label.add_theme_constant_override("shadow_offset_x",2); label.add_theme_constant_override("shadow_offset_y",2)
	toolbar.hide(); label.hide()
func begin(cell: Vector3i) -> void:
	game._set_tool("inspect"); game.room_editor.set_active(false)
	anchor=cell; active=true; mode="vase"; route_height=Rain.floor_position(game.model,cell).y+1.5; toolbar.show(); game.hud.build_panel.hide()
func cancel() -> void:
	active=false; toolbar.hide(); label.hide(); reset_path(); moving=null
	for child in ghost.get_children(): child.free()
func start_route(source: Dictionary) -> void:
	reset_path(); gutter=source.get("gutter",-1); source_joint=source.get("source_joint",-1); editing=source.get("replace",-1)
	var start: Variant=Rain.start_point(game.model,source)
	if start==null: reset_path(); return
	path=[start]; route_height=start.y-0.05
	ground_button.set_pressed_no_signal(source.has("outfall"))
func routed(points: Array, target: Dictionary) -> Dictionary:
	var result: Dictionary={"kind":"pipe","path":points}
	if source_joint>=0: result.source_joint=source_joint
	else: result.gutter=gutter
	result.merge(target)
	if editing>=0: result.replace=editing
	return result
func _process(_delta: float) -> void:
	if game==null or not game.setup_complete: return
	if game.menu.visible or game.operation_busy: cancel(); return
	if game.get_viewport().gui_get_hovered_control()!=null: label.hide(); return
	var mouse: Vector2=game._viewport_mouse()
	var origin: Vector3=game.rig.camera.project_ray_origin(mouse); var ray: Vector3=game.rig.camera.project_ray_normal(mouse)
	hovered=game.world.roof_rain_view.hit(origin,ray)
	label.position=game.get_viewport().get_mouse_position()+Vector2(16,16)*UI.POINT
	if not active:
		label.visible=not hovered.is_empty() and hovered.kind=="tank" and game.tool=="inspect"
		if label.visible:
			var inventory=game.model.Hydrology.inventory_at(game.model,hovered.cell)
			label.text="Water %d / %d" % [inventory.count("water"),inventory.capacity]
		return
	height_label.visible=mode in ["pipe","junction","edit"]; height_label.text="%.2f m" % (route_height-Rain.floor_position(game.model,anchor).y)
	ground_button.visible=mode in ["pipe","edit"] and not path.is_empty()
	for child in ghost.get_children(): child.free()
	spec={}; label.show()
	if mode in Rain.CAPACITY or (mode=="move" and moving!=null):
		var y:=Rain.floor_position(game.model,anchor).y
		var point: Variant=Plane(Vector3.UP,y).intersects_ray(origin,ray)
		if point==null: return
		var cell:=Vector3i(roundi(point.x),anchor.y,roundi(point.z))
		var offset:=Vector3(snappedf(point.x-cell.x,0.1),0,snappedf(point.z-cell.z,0.1))
		var kind: String=game.model.roof_rain.tanks[moving].kind if mode=="move" else mode
		spec={"kind":kind,"cell":cell,"offset":offset}
		if mode=="move": spec.moving_from=moving
		var holder:=Node3D.new(); ghost.add_child(holder); holder.position=Rain.floor_position(game.model,cell,offset); View.vessel(holder,kind,true).hide()
	elif mode=="junction":
		var point: Variant=Plane(Vector3.UP,route_height).intersects_ray(origin,ray)
		if point!=null:
			point=Vector3(snappedf(point.x,0.25),route_height,snappedf(point.z,0.25))
			spec={"kind":"junction","cell":Vector3i(roundi(point.x),anchor.y,roundi(point.z)),"position":point}; View.junction(ghost,point,true)
	elif mode=="gutter":
		var lanes:=Rain.roof_lanes(game.model,true); var distance:=INF
		for key in lanes:
			var lane: Dictionary=lanes[key]
			var point: Variant=AABB(lane.a,Vector3.ZERO).expand(lane.b).grow(0.15).intersects_ray(origin,ray)
			if point is Vector3 and origin.distance_to(point)<distance: distance=origin.distance_to(point); spec={"kind":"gutter","lane":key}
		if not spec.is_empty():
			var lane: Dictionary=lanes[spec.lane]; Geometry.gutter(ghost,lane.a,lane.b,lane.mount,true)
			Geometry.stream(ghost,lane.ridge,(lane.a+lane.b)*0.5)
	elif mode in ["pipe","edit"] and not path.is_empty():
		var points:=path.duplicate(); var destination: Dictionary={}
		if ground_button.button_pressed:
			var point: Variant=Plane(Vector3.UP,Rain.floor_position(game.model,anchor).y).intersects_ray(origin,ray)
			if point!=null: destination.outfall=Vector3i(roundi(point.x),anchor.y,roundi(point.z))
		elif hovered.get("kind")=="tank": destination.target=hovered.cell
		elif hovered.get("kind")=="junction": destination.target_joint=hovered.id
		var query:=PhysicsRayQueryParameters3D.create(origin,origin+ray*300)
		var hit: Dictionary=game.viewport.world_3d.direct_space_state.intersect_ray(query)
		if destination.is_empty() and not hit.is_empty() and game.model.wells.has(hit.collider.get_meta("cell",Vector3i(-999,0,0))): destination.target=hit.collider.get_meta("cell")
		if not destination.is_empty():
			var end: Variant=Rain.end_point(game.model,destination)
			if end!=null:
				# The last elbow turns into a vertical spout over the receiver.
				if (destination.has("target") or destination.has("outfall")) and path.back().y>end.y+0.45:
					var neck: Vector3=end+Vector3.UP*0.45
					if points.back().distance_to(neck)>0.05: points.append(neck)
				points.append(end); spec=routed(points,destination)
		else:
			var point: Variant=null
			if not hit.is_empty() and not Input.is_key_pressed(KEY_SHIFT): point=(hit.position+hit.normal*0.20).snapped(Vector3.ONE*0.25)
			else:
				point=Plane(Vector3.UP,route_height).intersects_ray(origin,ray)
				if point!=null: point=Vector3(snappedf(point.x,0.25),route_height,snappedf(point.z,0.25))
			if point!=null and point.distance_to(points.back())>=0.20: points.append(point); spec={"waypoint":point}
		if points.size()>1: Geometry.pipe(ghost,points,true)
		for i in range(1,points.size()):
			var delta: Vector3=(points[i]-points[i-1]).normalized(); var centre: Vector3=(points[i]+points[i-1])*0.5
			var side:=delta.cross(Vector3.UP).normalized()*0.08
			Geometry.stream(ghost,centre-delta*0.14+side,centre+delta*0.12,0.035); Geometry.stream(ghost,centre-delta*0.14-side,centre+delta*0.12,0.035)
	var error: String=Rain.error(game.model,spec) if spec.has("kind") else ""
	label.text=error if not error.is_empty() else (Rain.U.cost_text(Rain.charged_recipe(game.model.roof_rain,spec)) if spec.has("kind") else ("Choose gutter or junction" if mode=="pipe" and path.is_empty() else "Choose receiver or bend"))
	if spec.has("waypoint") and spec.waypoint.y>path.back().y+0.001: label.text="Water needs a downhill route"
	if mode=="edit" and path.is_empty(): label.text="Choose pipe"
	if mode=="remove": label.text="Remove fitting" if not hovered.is_empty() else "Choose fitting"
	if mode=="move" and error.is_empty(): label.text="Place container" if moving!=null else "Choose container"
func handle(event: InputEvent) -> bool:
	if active and event is InputEventKey and event.pressed:
		if event.keycode==KEY_ESCAPE:
			if not path.is_empty(): reset_path()
			else: cancel()
			return true
		if event.keycode==KEY_BACKSPACE and not path.is_empty():
			if path.size()>1: path.pop_back(); route_height=path.back().y
			else: reset_path()
			return true
	if not event is InputEventMouseButton or not event.pressed or event.button_index!=MOUSE_BUTTON_LEFT: return active
	if not active:
		if game.tool=="inspect" and hovered.get("kind")=="tank": game.model.request_collect_water(hovered.cell); return true
		return false
	if mode=="remove" and not hovered.is_empty(): Rain.remove(game.model,hovered)
	elif mode=="move" and moving==null and hovered.get("kind")=="tank": moving=hovered.cell; anchor.y=moving.y
	elif mode=="move" and spec.has("cell"):
		if Rain.move_tank(game.model,moving,spec.cell,spec.offset): moving=null
	elif mode=="edit" and path.is_empty() and hovered.get("kind")=="pipe":
		var old: Dictionary=game.model.roof_rain.pipes[hovered.id].duplicate(); old.replace=hovered.id; start_route(old)
	elif mode=="pipe" and path.is_empty() and hovered.get("kind") in ["gutter","junction"]:
		start_route({"gutter":hovered.id} if hovered.kind=="gutter" else {"source_joint":hovered.id})
	elif spec.has("waypoint"):
		if spec.waypoint.y<=path.back().y+0.001 and path.size()<126: path.append(spec.waypoint); route_height=spec.waypoint.y
	elif spec.has("kind") and Rain.request(game.model,spec): reset_path()
	return true
