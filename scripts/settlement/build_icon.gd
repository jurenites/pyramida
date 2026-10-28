extends Control
const VisualTokens = preload("res://scripts/ui_visual_tokens.gd")
## Small original line icons drawn in the reference's warm, square-button style.
var kind := "house"
var framed := false
const BUILDING_ICONS := {
	"goods_rack": preload("res://assets/ui/buildings/small_warehouse.svg"),
	"small_warehouse": preload("res://assets/ui/buildings/small_warehouse.svg"),
	"stone_storage": preload("res://assets/ui/buildings/stockpile.svg"),
	"house": preload("res://assets/ui/buildings/house.svg"),
	"hay_field": preload("res://assets/ui/buildings/hay_field.svg"),
	"windmill": preload("res://assets/ui/buildings/windmill.svg"),
	"road": preload("res://assets/ui/buildings/road.svg"),
	"well": preload("res://assets/ui/buildings/well.svg"),
	"school": preload("res://assets/ui/buildings/school.svg"),
	"pantry": preload("res://assets/ui/buildings/pantry.svg"),
	"log_shed": preload("res://assets/ui/buildings/log_shed.svg"),
	"hay_barn": preload("res://assets/ui/buildings/hay_barn.svg"),
	"sawmill": preload("res://assets/ui/buildings/sawmill.svg"),
	"mine_camp": preload("res://assets/ui/buildings/mine_camp.svg"),
	"masonry": preload("res://assets/ui/buildings/masonry.svg"),
	"workshop": preload("res://assets/ui/buildings/workshop.svg"),
	"platform": preload("res://assets/ui/buildings/platform.svg"),
	"stairs": preload("res://assets/ui/buildings/stairs.svg"),
	"stockpile": preload("res://assets/ui/buildings/stockpile.svg"),
	"soil_bed": preload("res://assets/ui/buildings/garden.svg"),
	"garden": preload("res://assets/ui/buildings/garden.svg"),
}
var ink := Color("64452f")

func _ready() -> void:
	custom_minimum_size = Vector2.ONE * VisualTokens.GAME_ICON_SIZE
	size = Vector2.ONE * VisualTokens.GAME_ICON_SIZE
	z_index = 1
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func line(points: Array) -> void:
	var packed := PackedVector2Array()
	for point: Vector2 in points:
		packed.append(point * VisualTokens.GAME_ICON_SCALE)
	draw_polyline(packed, ink, VisualTokens.LINE_WIDTH, true)

func circle(center: Vector2, radius: float) -> void:
	draw_circle(center * VisualTokens.GAME_ICON_SCALE, radius * VisualTokens.GAME_ICON_SCALE, ink, false, VisualTokens.LINE_WIDTH, true)

func icon_rect(rect: Rect2) -> Rect2:
	return Rect2(rect.position * VisualTokens.GAME_ICON_SCALE, rect.size * VisualTokens.GAME_ICON_SCALE)

func _draw() -> void:
	if framed:
		draw_rect(icon_rect(Rect2(1, 1, 32, 32)), Color("f3c78f"), false, VisualTokens.LINE_WIDTH)
		draw_rect(icon_rect(Rect2(4, 4, 26, 26)), Color("fff0c8"), false, VisualTokens.LINE_WIDTH)
	if BUILDING_ICONS.has(kind):
		draw_texture_rect(BUILDING_ICONS[kind], icon_rect(Rect2(5, 5, 24, 24)), false)
		return
	match kind:
		"terrain_dig", "terrain_fill":
			line([Vector2(5, 15), Vector2(15, 10), Vector2(25, 15), Vector2(15, 20), Vector2(5, 15), Vector2(5, 26), Vector2(15, 31), Vector2(25, 26), Vector2(25, 15)])
			line([Vector2(15, 20), Vector2(15, 31)])
			line([Vector2(21, 5), Vector2(31, 5)])
			if kind == "terrain_fill": line([Vector2(26, 0), Vector2(26, 10)])
		"debug_finish":
			line([Vector2(6, 28), Vector2(22, 12)])
			line([Vector2(18, 8), Vector2(26, 16)])
			line([Vector2(26, 2), Vector2(26, 8)])
			line([Vector2(23, 5), Vector2(29, 5)])
			line([Vector2(8, 5), Vector2(8, 13)])
			line([Vector2(4, 9), Vector2(12, 9)])
			line([Vector2(26, 23), Vector2(26, 29)])
			line([Vector2(23, 26), Vector2(29, 26)])
		"nature", "seed_vegetables":
			line([Vector2(17, 29), Vector2(17, 15)])
			line([Vector2(17, 22), Vector2(7, 16), Vector2(8, 9), Vector2(17, 15), Vector2(26, 7), Vector2(28, 15), Vector2(17, 22)])
		"seed_vine":
			line([Vector2(10, 29), Vector2(10, 21), Vector2(22, 17), Vector2(22, 6)])
			line([Vector2(10, 21), Vector2(4, 15), Vector2(10, 13)])
			line([Vector2(22, 14), Vector2(29, 9), Vector2(28, 5)])
		"seed_tree":
			line([Vector2(17, 29), Vector2(17, 21)])
			line([Vector2(6, 21), Vector2(10, 10), Vector2(17, 5), Vector2(24, 10), Vector2(28, 21), Vector2(6, 21)])
		"seed_palm":
			line([Vector2(15, 29), Vector2(17, 11), Vector2(7, 8), Vector2(3, 16)])
			line([Vector2(17, 11), Vector2(26, 8), Vector2(31, 16)])
			line([Vector2(9, 20), Vector2(17, 11), Vector2(25, 20)])
		"seed_bush":
			line([Vector2(6, 26), Vector2(4, 19), Vector2(9, 10), Vector2(18, 7), Vector2(27, 14), Vector2(29, 26), Vector2(6, 26)])
		"seed_grass":
			line([Vector2(9, 28), Vector2(5, 12), Vector2(16, 26), Vector2(17, 6), Vector2(21, 26), Vector2(29, 11), Vector2(25, 28)])
		"copy":
			line([Vector2(12, 10), Vector2(12, 5), Vector2(29, 5), Vector2(29, 23), Vector2(24, 23)])
			line([Vector2(5, 12), Vector2(22, 12), Vector2(22, 29), Vector2(5, 29), Vector2(5, 12)])
		"deconstruct":
			line([Vector2(7, 10), Vector2(27, 10)])
			line([Vector2(12, 10), Vector2(12, 5), Vector2(22, 5), Vector2(22, 10)])
			line([Vector2(9, 14), Vector2(10, 29), Vector2(24, 29), Vector2(25, 14)])
			line([Vector2(14, 15), Vector2(14, 24)])
			line([Vector2(20, 15), Vector2(20, 24)])
		"relocate":
			line([Vector2(21, 10), Vector2(21, 6), Vector2(5, 6), Vector2(5, 28), Vector2(21, 28), Vector2(21, 24)])
			line([Vector2(13, 17), Vector2(30, 17)])
			line([Vector2(24, 11), Vector2(30, 17), Vector2(24, 23)])
		"log":
			line([Vector2(10, 22), Vector2(22, 10), Vector2(27, 15), Vector2(15, 27)])
			circle(Vector2(12, 24), 4)
			line([Vector2(15, 20), Vector2(23, 12)])
		"berry":
			for centre in [Vector2(12, 20), Vector2(22, 20), Vector2(17, 26)]:
				circle(centre, 4)
			line([Vector2(17, 17), Vector2(17, 8), Vector2(24, 10)])
		"food":
			line([Vector2(7, 24), Vector2(7, 17), Vector2(11, 11), Vector2(24, 10), Vector2(28, 15), Vector2(28, 23), Vector2(7, 24)])
			line([Vector2(12, 12), Vector2(16, 17)])
			line([Vector2(18, 11), Vector2(22, 16)])
		"grain":
			line([Vector2(17, 27), Vector2(17, 8)])
			for y in [13, 18, 23]:
				line([Vector2(17, y), Vector2(11, y - 4), Vector2(11, y), Vector2(17, y + 3)])
				line([Vector2(17, y), Vector2(23, y - 4), Vector2(23, y), Vector2(17, y + 3)])
		"plank":
			line([Vector2(7, 20), Vector2(22, 7), Vector2(27, 13), Vector2(12, 27), Vector2(7, 20)])
			line([Vector2(11, 20), Vector2(23, 10)])
		"stone":
			line([Vector2(7, 23), Vector2(10, 12), Vector2(15, 8), Vector2(24, 10), Vector2(28, 23), Vector2(19, 27), Vector2(7, 23)])
			line([Vector2(10, 12), Vector2(17, 15), Vector2(19, 27)])
		"pottery":
			line([Vector2(12, 8), Vector2(22, 8)])
			line([Vector2(13, 9), Vector2(13, 13), Vector2(8, 18), Vector2(10, 26), Vector2(24, 26), Vector2(26, 18), Vector2(21, 13), Vector2(21, 9)])
		"block":
			line([Vector2(8, 24), Vector2(9, 13), Vector2(19, 8), Vector2(26, 14), Vector2(25, 25), Vector2(8, 24)])
			line([Vector2(9, 13), Vector2(17, 18), Vector2(26, 14)])
			line([Vector2(17, 18), Vector2(17, 25)])
		"water":
			line([Vector2(17, 6), Vector2(9, 18), Vector2(9, 24), Vector2(13, 28), Vector2(21, 28), Vector2(25, 24), Vector2(25, 18), Vector2(17, 6)])
		"citizens":
			circle(Vector2(17, 11), 4)
			line([Vector2(9, 27), Vector2(10, 21), Vector2(14, 18), Vector2(20, 18), Vector2(24, 21), Vector2(25, 27), Vector2(9, 27)])
		"house", "school", "pantry", "housing":
			line([Vector2(8, 16), Vector2(17, 8), Vector2(26, 16)])
			line([Vector2(11, 15), Vector2(11, 26), Vector2(24, 26), Vector2(24, 15)])
			line([Vector2(15, 25), Vector2(15, 19), Vector2(20, 19), Vector2(20, 25)])
			if kind == "school": line([Vector2(17, 8), Vector2(17, 5), Vector2(24, 5)])
			if kind == "pantry": line([Vector2(10, 21), Vector2(25, 21)])
		"log_shed":
			line([Vector2(8, 13), Vector2(26, 8)])
			line([Vector2(11, 19), Vector2(11, 25)])
			line([Vector2(23, 16), Vector2(23, 25)])
		"hay_barn":
			line([Vector2(8, 18), Vector2(17, 8), Vector2(26, 18), Vector2(8, 18)])
			line([Vector2(10, 18), Vector2(10, 26)])
			line([Vector2(24, 18), Vector2(24, 26)])
		"platform", "structure", "stockpile":
			line([Vector2(8, 11), Vector2(26, 11)])
			line([Vector2(11, 12), Vector2(11, 26)])
			line([Vector2(23, 12), Vector2(23, 26)])
			if kind == "stockpile":
				line([Vector2(14, 22), Vector2(21, 22)])
				line([Vector2(14, 18), Vector2(21, 18)])
		"stairs":
			line([Vector2(8, 26), Vector2(8, 21), Vector2(14, 21), Vector2(14, 15), Vector2(20, 15), Vector2(20, 9), Vector2(26, 9)])
		"garden", "hay_field", "soil_bed":
			line([Vector2(7, 25), Vector2(27, 25)])
			for x in [11, 17, 23]:
				line([Vector2(x, 24), Vector2(x, 11)])
				line([Vector2(x - 3, 14), Vector2(x, 17), Vector2(x + 3, 12)])
		"windmill":
			line([Vector2(11, 26), Vector2(14, 17), Vector2(20, 17), Vector2(23, 26), Vector2(11, 26)])
			line([Vector2(9, 8), Vector2(25, 22)])
			line([Vector2(25, 8), Vector2(9, 22)])
		"road":
			for x in [10, 16, 22]:
				line([Vector2(x, 25), Vector2(x + 3, 10)])
		"well":
			line([Vector2(9, 10), Vector2(25, 10), Vector2(22, 15), Vector2(12, 15), Vector2(9, 10)])
			line([Vector2(11, 16), Vector2(11, 25), Vector2(24, 25), Vector2(24, 17), Vector2(11, 17)])
		"inspect":
			circle(Vector2(15, 14), 6)
			line([Vector2(20, 19), Vector2(26, 26)])
		"remove":
			line([Vector2(10, 9), Vector2(25, 25)])
			line([Vector2(25, 9), Vector2(10, 25)])
		"sawmill":
			line([Vector2(8, 11), Vector2(8, 24)])
			line([Vector2(26, 11), Vector2(26, 24)])
			line([Vector2(8, 14), Vector2(26, 14)])
			line([Vector2(8, 21), Vector2(11, 24), Vector2(14, 21), Vector2(17, 24), Vector2(20, 21), Vector2(23, 24), Vector2(26, 21)])
		_:
			line([Vector2(10, 26), Vector2(23, 10)])
			line([Vector2(11, 10), Vector2(17, 8), Vector2(26, 17)])
