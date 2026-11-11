extends SceneTree
const Navigation = preload("res://scripts/settlement/navigation.gd")
const Indoor = preload("res://scripts/settlement/indoor_stair_contact.gd")
const Worker = preload("res://scripts/settlement/worker_view.gd")
func _initialize() -> void: call_deferred("capture")
func capture() -> void:
	var canvas := SubViewport.new()
	canvas.size = Vector2i(1600, 730)
	canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(canvas)
	var background := ColorRect.new()
	background.color = Color("eee3cc"); background.size = Vector2(1600, 730)
	canvas.add_child(background)
	var entries := []
	for index in 4:
		var holder := SubViewportContainer.new()
		holder.position = Vector2(index * 400, 105)
		holder.size = Vector2(400, 570)
		canvas.add_child(holder)
		var view := SubViewport.new()
		view.size = Vector2i(400, 570); view.own_world_3d = true
		view.msaa_3d = Viewport.MSAA_4X
		view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		holder.add_child(view)
		var environment := WorldEnvironment.new()
		environment.environment = Environment.new()
		environment.environment.background_mode = Environment.BG_COLOR
		environment.environment.background_color = Color("eee3cc")
		environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		environment.environment.ambient_light_color = Color.WHITE
		environment.environment.ambient_light_energy = 0.8
		view.add_child(environment)
		var light := DirectionalLight3D.new()
		light.rotation_degrees = Vector3(-65, -25, 0)
		light.light_energy = 0.6; light.shadow_enabled = true
		light.shadow_bias = 0.05
		light.shadow_normal_bias = 0.05
		light.directional_shadow_max_distance = 12.0
		view.add_child(light)
		var ground := MeshInstance3D.new()
		var plane := PlaneMesh.new(); plane.size = Vector2(20, 20)
		ground.mesh = plane
		ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var paint := StandardMaterial3D.new(); paint.albedo_color = Color("e6dcc5")
		paint.roughness = 1
		ground.material_override = paint
		view.add_child(ground)
		var nav := Navigation.new()
		var center := Vector3(0.5,0,0.5)
		var lower := Vector3i(0,0,-1); var upper := Vector3i(1,2,-1)
		var path: Array = [Vector3(lower)+Vector3.UP*0.16]
		for p: Vector3 in Indoor.Geometry.route(): path.append(center+p*2)
		path.append(Vector3(upper)+Vector3.UP*0.16)
		nav.room_nodes={lower:1,upper:2}; nav.room_heights={lower:0.16,upper:2.16}
		nav.rebuild({lower:true,upper:true},{})
		preload("res://scripts/settlement/room_navigation.gd").add_path(nav,lower,upper,path)
		Indoor.register(nav,lower,upper,center,0,path)
		var geometry: Dictionary=nav.room_stair_contacts[lower][upper]
		for box: AABB in geometry.boxes+geometry.trim:
			var step := MeshInstance3D.new(); step.mesh=BoxMesh.new(); step.mesh.size=box.size
			step.position=center+box.get_center()
			var color:=StandardMaterial3D.new(); color.albedo_color=Color("858b85") if box.size.y>0.03 else Color("d9ae6f")
			step.material_override=color; view.add_child(step)
		if index==1 or index==3: path.reverse()
		var traveller := Node3D.new(); view.add_child(traveller)
		var actor := Worker.new(); traveller.add_child(actor)
		actor.setup(1)
		var worker := {"position":path[0],"cell":upper if index in [1,3] else lower,"route":[lower if index in [1,3] else upper],"route_index":0,"appearance":1 if index==1 else 0,"cloth_color":1 if index==1 else 2 if index==2 else 0,"life_stage":"child" if index==2 else "adult","cargo":"log" if index==3 else "","status":"walking"}
		var camera := Camera3D.new()
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = 4.5
		view.add_child(camera)
		var offset := Vector3(-4.0, 3.8, -5.6) if index!=1 else Vector3(4.0,3.8,-5.6)
		entries.append({"traveller": traveller, "actor": actor, "camera": camera, "offset": offset, "worker": worker, "index": index, "nav":nav, "path":path,"next":1})
	caption(canvas, "INDOOR STAIRS / LARGER CITIZENS", Vector2(42, 25), 25)
	caption(canvas, "Actual tread contact · 2 m storey · adults approximately 1.4 m tall", Vector2(42, 65), 18)
	for index in 4:
		caption(canvas, ["ASCENDING", "DESCENDING", "CHILD", "CARRYING DOWN"][index], Vector2(index * 400 + 65, 688), 16)
	DirAccess.make_dir_recursive_absolute("/tmp/pyramida-indoor-stairs")
	for frame in 300:
		for entry in entries:
			if entry.next<entry.path.size():
				entry.worker.position=entry.worker.position.move_toward(entry.path[entry.next],0.022)
				if entry.worker.position.distance_to(entry.path[entry.next])<0.0001: entry.next+=1
			entry.actor.sync(entry.worker,1.0/30.0,false,entry.camera,entry.nav)
			entry.camera.position = Vector3(0.5,1.4,-0.1)+entry.offset
			entry.camera.look_at(Vector3(0.5,1.4,-0.1))
		await process_frame
		RenderingServer.force_draw()
		var image := canvas.get_texture().get_image()
		image.save_png("/tmp/pyramida-indoor-stairs/%03d.png" % frame)
		if frame == 82: image.save_png("res://artifacts/settlement/indoor-stairs.png")
	print("PASS: captured indoor stairs")
	quit()
func caption(parent: Node, text_: String, at: Vector2, size_: int) -> void:
	var label := Label.new(); label.text = text_; label.position = at
	label.add_theme_font_size_override("font_size", size_)
	label.add_theme_color_override("font_color", Color("4b4037"))
	parent.add_child(label)
