extends Node
## Rounded vector arrow, rasterized at the native cursor's display size.
## Keep this a native cursor so pointer motion stays responsive at low FPS.
const VisualTokens = preload("res://scripts/ui_visual_tokens.gd")
const HOTSPOT := Vector2(4, 2) * VisualTokens.POINT
const SVG := """<svg xmlns="http://www.w3.org/2000/svg" width="32" height="40" viewBox="0 0 32 40">
<path d="M4 5 Q4 3 6 4.5 L25.5 20 Q28 22 25 22 H17.5 L22 31.5 Q23 33.5 21 34.3 L19.5 35 Q17.5 35.8 16.5 33.5 L12.5 24 L7 28 Q4 30 4 27 Z"
fill="black" stroke="white" stroke-width="%s" stroke-linejoin="round" stroke-linecap="round"/>
</svg>"""
var texture: ImageTexture

func _ready() -> void:
	get_window().dpi_changed.connect(_apply_cursor)
	_apply_cursor()

static func create_image(density: float = 1.0) -> Image:
	var image := Image.new()
	var error := image.load_svg_from_string(SVG % VisualTokens.LINE_WIDTH, maxf(1.0, density))
	assert(error == OK, "Cursor SVG must rasterize successfully")
	return image

func _apply_cursor() -> void:
	if DisplayServer.get_name() == "headless":
		return
	# macOS native cursor dimensions are already in logical screen points.
	# Other backends use physical pixels, so include the game's display scale.
	var density := 1.0 if OS.get_name() == "macOS" else get_window().content_scale_factor
	texture = ImageTexture.create_from_image(create_image(density))
	# Controls may request hand, text or resize shapes; keep our cursor everywhere.
	for shape in range(Input.CURSOR_ARROW, Input.CURSOR_HELP + 1):
		Input.set_custom_mouse_cursor(texture, shape, HOTSPOT * density)

func _exit_tree() -> void:
	if DisplayServer.get_name() != "headless":
		for shape in range(Input.CURSOR_ARROW, Input.CURSOR_HELP + 1):
			Input.set_custom_mouse_cursor(null, shape)
