extends SceneTree
const Navigation = preload("res://scripts/settlement/navigation.gd")
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
		var surfaces := {}; var shapes := {}
		var rise := 1 if index == 1 else 2
		for x in range(-3,4):
			for z in range(-1,2):
				var cell := Vector3i(x,0,z); surfaces[cell]=true
				if index == 0: shapes[cell]=[(x-0.5)*0.35+1.1,(x+0.5)*0.35+1.1,(x+0.5)*0.35+1.1,(x-0.5)*0.35+1.1]
		if index == 0:
			ground.mesh = BoxMesh.new(); ground.mesh.size=Vector3(6,0.12,1.4)
			ground.rotation.z = atan(0.35); ground.position.y=1.1-0.06/cos(atan(0.35))
			for stripe in range(-10,11):
				var mark := MeshInstance3D.new(); mark.mesh=BoxMesh.new(); mark.mesh.size=Vector3(0.008,0.002,1.4)
				mark.position=Vector3(stripe*0.25,1.102+stripe*0.25*0.35,0)
				var ink:=StandardMaterial3D.new(); ink.albedo_color=Color("b5a891"); mark.material_override=ink; view.add_child(mark)
		else:
			var ladder := Worker.Assets.create("stairs")
			preload("res://scripts/settlement/construction_variants.gd").stairs(ladder,rise)
			view.add_child(ladder)
			var deck := MeshInstance3D.new(); deck.mesh=BoxMesh.new(); deck.mesh.size=Vector3(2,0.1,2)
			deck.position=Vector3(2,rise-0.05,0); deck.material_override=paint; view.add_child(deck)
		surfaces[Vector3i(2,rise,0)]=true
		nav.rebuild(surfaces,{Vector3i.ZERO:0} if index>0 else {},{},shapes)
		var traveller := Node3D.new(); view.add_child(traveller)
		var actor := Worker.new(); traveller.add_child(actor)
		actor.setup(1)
		var worker := {"position":Vector3.ZERO,"cell":Vector3i(2,rise,0) if index==3 else Vector3i(-2,0,0),"route":[Vector3i(-2,0,0) if index==3 else Vector3i(2,rise,0)],"route_index":0,"appearance":1 if index==1 else 0,"cloth_color":1 if index==1 else 2 if index==2 else 0,"life_stage":"child" if index==2 else "adult","cargo":"","status":"walking"}
		var camera := Camera3D.new()
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = 2.5
		view.add_child(camera)
		var offset := Vector3(-1.8, 3.5, 4.6)
		entries.append({"traveller": traveller, "actor": actor, "camera": camera, "offset": offset, "worker": worker, "index": index, "nav":nav, "rise":rise})
	caption(canvas, "RAMP AND LADDER CONTACT", Vector2(42, 25), 25)
	caption(canvas, "Terrain contact and steps on the actual ladder rungs", Vector2(42, 65), 18)
	for index in 4:
		caption(canvas, ["RAMP", "1 m LADDER", "CHILD / 2 m LADDER", "DESCENDING"][index], Vector2(index * 400 + 65, 688), 16)
	DirAccess.make_dir_recursive_absolute("/tmp/pyramida-foot-contact")
	for frame in 180:
		for entry in entries:
			var x := lerpf(-1.25,1.25,frame/179.0)
			if entry.index==3: x=-x
			entry.worker.position=Vector3(x,x*0.35+1.1 if entry.index==0 else clampf((x+1)/2,0,1)*entry.rise,0)
			entry.actor.sync(entry.worker,1.0/30.0,false,entry.camera,entry.nav)
			entry.camera.position = entry.actor.position + entry.offset
			entry.camera.look_at(entry.actor.position + Vector3(0, 0.50, 0))
		await process_frame
		RenderingServer.force_draw()
		var image := canvas.get_texture().get_image()
		image.save_png("/tmp/pyramida-foot-contact/%03d.png" % frame)
		if frame == 82: image.save_png("res://artifacts/settlement/foot-contact.png")
	print("PASS: captured ramp and ladder contact")
	quit()
func caption(parent: Node, text_: String, at: Vector2, size_: int) -> void:
	var label := Label.new(); label.text = text_; label.position = at
	label.add_theme_font_size_override("font_size", size_)
	label.add_theme_color_override("font_color", Color("4b4037"))
	parent.add_child(label)
