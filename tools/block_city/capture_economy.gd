extends SceneTree
func _initialize() -> void: call_deferred("run")
func capture(name: String) -> void:
	for i in 12: await process_frame
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://artifacts/block_city/"+name+".png")
func run() -> void:
	var game=load("res://scripts/block_city/economy_lab.gd").new()
	root.add_child(game); game.set_process_unhandled_input(false)
	await capture("economy-first-step")
	game.economy.reset("creative")
	for level in 3:
		if level>0: game.economy.add_floor()
		if level==1: game.economy.move_bath(level,Vector2i(2,2))
		for kind in ["water","sewer"]: game.economy.connect_pipe(level-1,level,kind)
		for slot in [Vector2i(1,0),Vector2i(2,0),Vector2i(0,2),Vector2i(1,2)]: game.economy.build(level,slot)
		game.economy.build(level,Vector2i(2,2) if level!=1 else Vector2i(0,0),"garden")
	game.economy.buy_upgrade("capacity"); game.economy.advance()
	game.focused_floor=1; game.refresh_lab()
	await capture("economy-dollhouse")
	game.free(); quit()
