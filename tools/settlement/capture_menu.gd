extends SceneTree
## Render actual menu flows with isolated temporary saves, never player slots.
const Scene = preload("res://scenes/settlement/Terraces.tscn")
var directory := "/tmp/pyramida-menu-preview-%d" % Time.get_ticks_usec()
var game: Node

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	game = Scene.instantiate()
	game.slot_directory = directory
	root.add_child(game)
	await capture("settlement-slots")
	game.menu.buttons.slot_0.pressed.emit()
	await capture("settlement-difficulty")
	game.menu.buttons.normal.pressed.emit()
	game._open_menu()
	await capture("main-menu")
	game.menu.buttons.settings.pressed.emit()
	await capture("settlement-settings")
	game._resume_game()
	await capture("settlement-hud")
	game.queue_free()
	await process_frame
	for file in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(file))
	DirAccess.remove_absolute(directory)
	print("PASS: captured five menu states with isolated temporary saves")
	quit()

func capture(name_: String) -> void:
	for frame in 30:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/" + name_ + ".png")
