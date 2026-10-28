extends Node
## Keep the first scene independent of game assets so sand can render immediately.
const GAME_SCENE := "res://scenes/settlement/Terraces.tscn"
var loading := false
var cover: ColorRect

func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	cover = ColorRect.new()
	cover.color = ProjectSettings.get_setting("application/boot_splash/bg_color")
	cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(cover)
	# Present the empty background before starting any expensive scene loading.
	await get_tree().process_frame
	await get_tree().process_frame
	if ResourceLoader.load_threaded_request(GAME_SCENE) != OK:
		_load_failed()
		return
	loading = true

func _process(_delta: float) -> void:
	if not loading:
		return
	match ResourceLoader.load_threaded_get_status(GAME_SCENE):
		ResourceLoader.THREAD_LOAD_LOADED:
			loading = false
			_show_game()
		ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			loading = false
			_load_failed()

func _show_game() -> void:
	var scene := ResourceLoader.load_threaded_get(GAME_SCENE) as PackedScene
	if scene == null:
		_load_failed()
		return
	var game := scene.instantiate()
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	# The opaque cover stays above the world through setup and menu layout.
	await get_tree().process_frame
	await get_tree().process_frame
	queue_free()

func _load_failed() -> void:
	push_error("Unable to load the settlement scene")
	var message := Label.new()
	message.text = "Unable to load game."
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	message.add_theme_color_override("font_color", Color("64452f"))
	cover.add_child(message)
