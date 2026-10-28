extends Node
## A blunt macOS-style arrow on the same two-logical-pixel grid as the world.
## Keep this a native cursor so pointer motion stays responsive at low FPS.
const PIXEL_SIZE := 2
const HOTSPOT := Vector2(2, 1)
const PIXELS := [
	"................",
	"..WW............",
	".WBBWW..........",
	".WBBBBW.........",
	".WBBBBBW........",
	".WBBBBBBW.......",
	".WBBBBBBBW......",
	".WBBBBBBBBW.....",
	".WBBBBBBBBBW....",
	".WBBBBBBBBBBW...",
	".WBBBBBBBBBBBW..",
	".WBBBBBBWWWWW...",
	".WBBBWBBBW......",
	".WBBW.WBBBW.....",
	"..WW..WBBBW.....",
	".......WBBBW....",
	".......WBBBW....",
	"........WWW.....",
	"................",
	"................",
]
var texture: ImageTexture

func _ready() -> void:
	get_window().dpi_changed.connect(_apply_cursor)
	_apply_cursor()

static func create_image(pixel_scale: int = PIXEL_SIZE) -> Image:
	var image := Image.create(PIXELS[0].length(), PIXELS.size(), false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	for y in PIXELS.size():
		for x in PIXELS[y].length():
			match PIXELS[y][x]:
				"W": image.set_pixel(x, y, Color.WHITE)
				"B": image.set_pixel(x, y, Color.BLACK)
	image.resize(image.get_width() * pixel_scale, image.get_height() * pixel_scale, Image.INTERPOLATE_NEAREST)
	return image

func _apply_cursor() -> void:
	if DisplayServer.get_name() == "headless":
		return
	# macOS native cursor dimensions are already in logical screen points.
	# Other backends use physical pixels, so include the game's display scale.
	var density := 1.0 if OS.get_name() == "macOS" else get_window().content_scale_factor
	var pixel_scale := maxi(1, roundi(PIXEL_SIZE * density))
	texture = ImageTexture.create_from_image(create_image(pixel_scale))
	# Controls may request hand, text or resize shapes; keep our cursor everywhere.
	for shape in range(Input.CURSOR_ARROW, Input.CURSOR_HELP + 1):
		Input.set_custom_mouse_cursor(texture, shape, HOTSPOT * pixel_scale)

func _exit_tree() -> void:
	if DisplayServer.get_name() != "headless":
		for shape in range(Input.CURSOR_ARROW, Input.CURSOR_HELP + 1):
			Input.set_custom_mouse_cursor(null, shape)
