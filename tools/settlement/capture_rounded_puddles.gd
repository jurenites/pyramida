extends SceneTree
const Model=preload("res://scripts/settlement/world_model.gd")
const Water=preload("res://scripts/settlement/water_view.gd")
const Palette=preload("res://scripts/game_palette.gd")
func _initialize() -> void:
	root.unfocusable=true; root.hide(); call_deferred("run")
func run() -> void:
	var viewport=SubViewport.new(); viewport.size=Vector2i(1200,800); viewport.own_world_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(viewport)
	var ground=MeshInstance3D.new(); var plane=PlaneMesh.new(); plane.size=Vector2(20,20)
	ground.mesh=plane; var sand=StandardMaterial3D.new(); sand.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	sand.albedo_color=Palette.SAND_SURFACE; ground.material_override=sand; viewport.add_child(ground)
	for soil in [false,true]:
		var world=Model.new(); world.soil_enabled=soil
		for i in 3:
			var cell=Vector3i((i-1)*2,0,2 if soil else 0)
			var inventory=world.Inventory.new(); inventory.capacity=3; inventory.store("water",3-i)
			world.water_sources[cell]={"kind":"puddle","inventory":inventory}
			if soil:
				world.soil_shapes[cell]=[0.22,0.29,0.24,0.31,0.02]
				world.navigation.terrain_shapes[cell]=world.soil_shapes[cell]
		var view=Water.new(); viewport.add_child(view); view.sync(world)
		for cell in world.water_sources:
			var surface: MeshInstance3D=view.sources[cell].get_node("Water")
			assert(surface.material_override.get_shader_parameter("shallow_colour")==Palette.WATER_BLUE)
			if soil:
				var vertices=surface.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
				for i in range(0,vertices.size(),3):
					assert((vertices[i+1]-vertices[i]).cross(vertices[i+2]-vertices[i]).y<0,"Upward water faces")
				for vertex in vertices:
					var point: Vector3=Vector3(cell)+vertex
					assert(point.y+0.0001>=world.navigation.surface_height(cell,point),"Rounded edge stays in the hollow")
			var id: int=surface.get_instance_id()
			var amount: int=world.water_sources[cell].inventory.count("water")
			world.water_sources[cell].inventory.amounts.water=0; view.sync(world)
			assert(not surface.visible and surface.get_instance_id()==id,"Empty pool hides without replacing inventory/view")
			world.water_sources[cell].inventory.amounts.water=amount; view.sync(world)
	var camera=Camera3D.new(); camera.projection=Camera3D.PROJECTION_ORTHOGONAL; camera.size=6.2
	viewport.add_child(camera); camera.position=Vector3(0,7,6); camera.look_at(Vector3(0,0,1)); camera.current=true
	if DisplayServer.get_name()!="headless":
		for i in 8: await process_frame
		await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_png("res://artifacts/settlement/rounded-puddles.png")
	print("PASS: rounded puddles, shared water swatch, waterline containment and depletion")
	viewport.free(); quit()
