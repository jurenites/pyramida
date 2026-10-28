extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size=Vector2i(1100,760)
	var game=load("res://scripts/block_city/game.gd").new()
	game.auto_save=false; game.restore_last=false; root.add_child(game)
	game.set_process_unhandled_input(false)
	for y in 2:
		for x in [0,1]:
			game.model.queue[0]={"shape":"elevator" if x==1 else "cube","color":0}
			assert(game.model.drop(x,1,0,false,y))
	game.set_holding(false)
	for mode in [0,2]:
		game.view_mode=mode; game.refresh()
		game.camera.position=Vector3(-2,4.5,-5)
		game.camera.look_at(Vector3(1,1.45,1.5)); game.camera.size=4.2
		for neighbour in game.neighbours: neighbour.node.hide()
		for child in game.canvas.get_children(): child.hide()
		assert(not game.geometry.get_node("Room1/ElevatorShaft").has_node("MachineRoom"))
		var housing=game.geometry.get_node("Room3/ElevatorShaft/MachineRoom")
		assert(housing.has_node("Motor") and housing.has_node("CableDrum"))
		assert(housing.has_node("WeatherCap")== (mode==0))
		assert(game.geometry.get_node("Room0/Roofs").get_child_count()==0)
		assert(game.geometry.get_node("Room2/Roofs").get_child_count()==(1 if mode==0 else 0))
		for i in 8: await process_frame
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png("res://artifacts/block_city/rooftop-machinery-%d.png" % mode)
	game.model.queue[0]={"shape":"cube","color":0}
	assert(game.model.drop(1,1,0,false,2))
	game.refresh()
	assert(not game.geometry.get_node("Room3/ElevatorShaft").has_node("MachineRoom"))
	print("CAPTURE rooftop machinery and hall roofs: checks passed")
	game.free(); quit()
