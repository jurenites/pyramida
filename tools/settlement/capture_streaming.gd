extends SceneTree
const Scene = preload("res://scenes/settlement/Terraces.tscn")
const Chunks = preload("res://scripts/settlement/chunk_stream.gd")
var game: Node
var directory := "/tmp/pyramida-stream-preview-%d" % Time.get_ticks_usec()
func _initialize() -> void: call_deferred("run")
func run() -> void:
	game = Scene.instantiate()
	game.slot_directory = directory
	root.add_child(game)
	game.set_process(false)
	await capture("streamed-home")
	game.menu.buttons.slot_0.pressed.emit()
	game.menu.buttons.normal.pressed.emit()
	game.hud.visible = false
	game.fog.visible = false
	game.world.fog_enabled = false
	game.rig.focus = Vector3(200, 1, -175)
	game.rig.zoom = 42.0
	game.rig.update_camera()
	Chunks.update(game.model, game.rig.focus, game._streaming_radius(), 256)
	game.world.sync(game.model, 0, -1)
	await capture("streamed-landscape")
	game.rig.focus += Vector3(16, 0, 0)
	game.rig.update_camera()
	Chunks.update(game.model, game.rig.focus, game._streaming_radius(), 256)
	game.world.sync(game.model, 0, -1)
	await capture("streamed-neighbour")
	game.queue_free()
	await process_frame
	for file in DirAccess.get_files_at(directory): DirAccess.remove_absolute(directory.path_join(file))
	DirAccess.remove_absolute(directory)
	print("PASS: captured generated home and adjacent streamed terrain with temporary saves")
	quit()
func capture(name_: String) -> void:
	for frame in 8: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/" + name_ + ".png")
