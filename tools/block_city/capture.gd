extends SceneTree
const Solver=preload("res://tools/block_city/solver.gd")
func _initialize() -> void: call_deferred("run")
func capture(name: String) -> void:
	print("CAPTURE ", name)
	for i in 8: await process_frame
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://artifacts/block_city/"+name+".png")
func run() -> void:
	root.size=Vector2i(1440,900)
	var game=load("res://scripts/block_city/game.gd").new()
	game.auto_save=false; game.restore_last=false
	root.add_child(game)
	game.set_process_unhandled_input(false)
	game.anchor=Vector2i.ZERO
	game.refresh()
	await capture("flat-opening")
	game.zoom=1.15
	game.update_camera()
	await capture("road-grid")
	game.zoom=1.0
	game.update_camera()
	game.model.drop(0,0)
	game.model.queue[0]={"shape":"rectangle","color":2}
	game.model.drop(-1,0)
	for i in 4:
		print("BUILD ", i)
		Solver.build(game.model)
	print("WIRE")
	for room in game.model.rooms:
		for raw in room.cells:
			var cell=game.model.vec(raw)
			if game.model.powered_cells().has(cell): continue
			for normal in game.Model.DIRECTIONS:
				if game.model.connect_power(cell,normal): break
	game.refresh()
	await capture("flat-cables")
	game.toggle_menu()
	await capture("flat-menu")
	game.free()
	quit()
