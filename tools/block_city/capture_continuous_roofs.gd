extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size=Vector2i(1100,760)
	var game=load("res://scripts/block_city/game.gd").new()
	game.auto_save=false; game.restore_last=false; root.add_child(game)
	game.set_process_unhandled_input(false)
	for item in [["small_square",0,0],["domino",2,0],["cube",0,2]]:
		game.model.queue[0]={"shape":item[0],"color":1}
		assert(game.model.drop(item[1],item[2],0,false,0))
	game.set_holding(false); game.view_mode=0; game.refresh()
	var occupied: Dictionary=game.model.occupied()
	var edges:=0
	var corners:=0
	for i in 3:
		var room=game.geometry.get_node("Room%d" % i)
		for slab in room.get_node("Roofs").get_children():
			assert(slab.mesh.size==Vector3(1,0.07,1))
			assert(slab.material_override.albedo_color==game.model.STAIR_COLOR)
		for edge in room.get_node("RoofRim").get_children():
			if edge.has_meta("inset_corner"):
				corners+=1
				continue
			assert(not occupied.has(edge.get_meta("cell")+edge.get_meta("normal")))
			edges+=1
	assert(edges==12 and corners==1)
	game.camera.position=Vector3(-3,5.5,-5)
	game.camera.look_at(Vector3(1.5,0.4,1.5)); game.camera.size=5.0
	for neighbour in game.neighbours: neighbour.node.hide()
	for child in game.canvas.get_children(): child.hide()
	for i in 8: await process_frame
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://artifacts/block_city/continuous-roofs.png")
	for mode in [1,2]:
		game.view_mode=mode; game.refresh()
		for i in 3:
			assert(game.geometry.get_node("Room%d/RoofRim" % i).get_child_count()==0)
			assert(game.geometry.get_node("Room%d/Roofs" % i).get_child_count()==0)
	game.model.queue[0]={"shape":"cube","color":0}
	assert(game.model.drop(0,0,0,false,1))
	game.view_mode=0; game.refresh()
	for edge in game.geometry.get_node("Room0/RoofRim").get_children():
		assert(edge.get_meta("cell")!=Vector3i.ZERO)
	print("Continuous roofs: perimeter, materials, covered cells and cutaway checks passed")
	game.free(); quit()
