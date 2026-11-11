extends SceneTree
## Editable solid miniatures, rasterizable without a window or GPU.
const Palette = preload("res://scripts/game_palette.gd")
const Resources = preload("res://scripts/settlement/resource_palette.gd")
const Tokens = preload("res://scripts/ui_visual_tokens.gd")
const OUT := "res://assets/ui/buildings/"
var shapes := ""
var wood := Resources.colour("log")
var board := Resources.colour("plank")
var hay := Resources.colour("grain")
var stone := Resources.colour("stone")
var brick := Resources.colour("brick")
var ink := Palette.HOME_DOORWAY.darkened(0.30)

func poly(points: String, color: Color) -> void:
	shapes += '<polygon points="%s" fill="#%s"/>' % [points, color.to_html(false)]

func rect(x: float, y: float, w: float, h: float, color: Color) -> void:
	shapes += '<rect x="%s" y="%s" width="%s" height="%s" fill="#%s"/>' % [x,y,w,h,color.to_html(false)]

func circle(x: float, y: float, radius: float, color: Color) -> void:
	shapes += '<circle cx="%s" cy="%s" r="%s" fill="#%s"/>' % [x,y,radius,color.to_html(false)]

func line(points: String, color: Color) -> void:
	shapes += '<polyline points="%s" fill="none" stroke="#%s" stroke-width="%s" stroke-linejoin="round" stroke-linecap="round"/>' % [points,color.to_html(false),Tokens.LINE_WIDTH]

func roof(color: Color, lean := false) -> void:
	if lean:
		poly("2,12 24,7 32,12 10,19",color)
		poly("10,19 32,12 32,15 10,22",color.darkened(0.24))
	else:
		poly("2,15 11,5 23,8 32,19 18,23",color.darkened(0.20))
		poly("2,15 11,5 23,8 14,18",color)

func posts() -> void:
	rect(6,14,4,16,wood)
	rect(25,15,4,14,wood.darkened(0.2))

func room(color: Color) -> void:
	poly("6,15 18,18 18,31 6,27",color)
	poly("18,18 29,14 29,27 18,31",color.darkened(0.18))
	rect(10,21,5,8,ink)
	poly("22,20 26,19 26,23 22,24",Palette.SAND_SURFACE)

func slab(x: int, y: int, color: Color) -> void:
	shapes += '<g transform="translate(%d %d)">' % [x,y]
	poly("0,3 7,0 12,3 5,6",color.lightened(0.12))
	poly("0,3 5,6 5,9 0,6",color)
	poly("5,6 12,3 12,6 5,9",color.darkened(0.22))
	shapes += '</g>'

func log_stack() -> void:
	for p in [Vector2(13,24),Vector2(20,25),Vector2(16,19)]:
		poly('%s,%s %s,%s %s,%s %s,%s' % [p.x,p.y-3,p.x+8,p.y-6,p.x+8,p.y,p.x,p.y+3],wood)
		circle(p.x,p.y,3,board)
		circle(p.x,p.y,1,wood)

func oven(roof_color: Color) -> void:
	room(Palette.PEACH_SHADOW)
	roof(roof_color)
	poly("23,13 23,3 28,2 28,13",brick.darkened(0.15))
	rect(22,2,7,4,brick)
	poly("9,28 9,23 11,20 15,21 17,24 17,30",ink)

func build(kind: String) -> String:
	shapes = ""
	match kind:
		"house":
			room(Palette.PEACH_SHADOW)
			roof(Palette.WOODEN_ROOF)
		"well":
			poly("3,19 17,12 31,19 31,25 17,32 3,25",stone.darkened(0.18))
			poly("3,19 17,12 31,19 17,26",stone.lightened(0.2))
			poly("8,19 17,15 26,19 17,23",ink)
			poly("10,20 17,17 24,20 17,23",Palette.WATER_BLUE)
		"sawmill":
			posts()
			slab(10,21,board)
			log_stack()
			poly("17,13 22,13 22,18 20,20 22,22 20,24 18,25",Palette.TOOL_METAL)
			roof(board,true)
		"log_shed":
			posts()
			log_stack()
			roof(board,true)
		"hay_barn":
			posts()
			poly("11,22 13,18 20,19 23,27 11,29",hay)
			rect(11,23,11,4,Resources.colour("rope").darkened(0.2))
			roof(board)
		"stone_storage", "brickyard", "stockpile":
			posts()
			line("6,13 17,8 28,13",wood)
			var cargo := brick if kind == "brickyard" else Resources.colour("block")
			slab(9,22,cargo)
			slab(18,18,cargo)
			if kind == "brickyard": slab(9,17,Resources.colour("clay"))
		"claypit":
			poly("3,19 17,11 31,18 31,25 18,31 3,24",Resources.colour("clay"))
			poly("6,19 17,14 28,19 18,25",wood.darkened(0.35))
			poly("9,20 17,16 25,20 18,24",Palette.WATER_BLUE)
			slab(18,23,Resources.colour("clay"))
		"pottery_workshop":
			posts()
			roof(board,true)
			slab(10,24,board)
			poly("14,15 20,15 19,19 23,23 21,28 13,28 11,23 15,19",Resources.colour("pottery"))
			rect(14,14,6,4,Resources.colour("pottery").darkened(0.25))
		"kiln":
			oven(Palette.WOODEN_ROOF)
			rect(11,25,4,4,Palette.SUN)
		"bakery":
			oven(hay)
			poly("20,27 21,24 26,23 29,25 29,28 22,30",Resources.colour("food"))
		"tilery":
			room(brick)
			roof(Resources.colour("imbrex"),true)
			for x in [20,25]:
				poly('%d,28 %d,23 %d,21 %d,24 %d,29' % [x,x+1,x+3,x+5,x+4],Resources.colour("imbrex"))
		"mill":
			poly("12,15 21,13 26,30 10,31",Palette.PEACH_SHADOW)
			poly("21,13 26,30 21,31 18,17",wood)
			poly("10,15 15,7 22,9 25,15",Palette.WOODEN_ROOF)
			line("7,3 26,25",Palette.MARBLE)
			line("5,22 27,4",Palette.MARBLE)
			circle(16,14,3,wood)
		"hay_field":
			poly("2,23 17,15 32,22 17,31",Resources.colour("clay"))
			for p in [Vector2(9,22),Vector2(16,26),Vector2(17,18),Vector2(24,22)]:
				poly('%s,%s %s,%s %s,%s %s,%s %s,%s' % [p.x-3,p.y,p.x-4,p.y-10,p.x,p.y-5,p.x+3,p.y-12,p.x+3,p.y],hay)
		"rope_maker":
			posts()
			roof(board,true)
			slab(10,23,board)
			line("12,22 23,18",Resources.colour("rope"))
			circle(24,26,5,Resources.colour("rope"))
			circle(24,26,2,wood)
		"quarry":
			poly("3,28 5,19 11,15 17,22 16,31",stone)
			poly("14,29 18,16 25,18 31,27 25,31",stone.lightened(0.18))
			line("20,8 13,24",wood)
			line("15,8 20,7 25,11",Palette.TOOL_METAL)
		"masonry":
			posts()
			slab(10,23,stone)
			slab(13,18,Resources.colour("block"))
			poly("2,12 14,6 32,12 26,17 17,16 9,18",Palette.MARBLE)
		"mine":
			poly("3,24 18,17 31,24 18,31",wood)
			poly("7,24 18,20 27,24 18,29",ink)
			line("7,22 7,9 26,9 26,24",wood)
			line("17,11 17,21",Resources.colour("rope"))
			circle(17,10,4,board)
		"platform":
			posts()
			poly("2,12 18,5 32,12 16,20",board)
			poly("2,12 16,20 32,12 32,16 16,24 2,16",wood)
		"stairs":
			for i in 4:
				slab(3+i*4,23-i*6,board)
				poly('%d,%d %d,%d %d,30 %d,30' % [15+i*4,26-i*6,15+i*4,29-i*6,15+i*4,12+i*4],wood)
		"road":
			for p in [Vector2i(4,19),Vector2i(17,13),Vector2i(16,23)]: slab(p.x,p.y,stone)
		"rope_bridge":
			line("4,13 10,20 19,22 30,15",Resources.colour("rope"))
			poly("3,23 12,28 22,28 31,23 31,27 22,32 12,32 3,27",board)
			line("4,9 4,27",wood)
			line("30,10 30,28",wood)
			line("12,21 12,28",Resources.colour("rope"))
			line("22,21 22,28",Resources.colour("rope"))
		"small_warehouse":
			posts()
			for y in [15,23]:
				slab(10,y,board)
				circle(16,y,3,Resources.colour("pottery"))
			roof(board,true)
		"school", "pantry", "workshop":
			room(Palette.PEACH_SHADOW)
			roof(board if kind == "workshop" else Palette.WOODEN_ROOF)
			if kind == "school": line("21,3 21,9",wood)
			if kind == "pantry": slab(18,23,Resources.colour("food"))
			if kind == "workshop": line("21,25 27,19",Palette.TOOL_METAL)
		_:
			push_error("Missing building icon: " + kind)
	return shapes

func _initialize() -> void:
	var kinds := ["house","well","sawmill","log_shed","hay_barn","stone_storage","brickyard","claypit","pottery_workshop","kiln","tilery","mill","bakery","hay_field","rope_maker","quarry","masonry","mine","platform","stairs","road","rope_bridge","stockpile","small_warehouse","school","pantry","workshop"]
	var aliases := {"windmill":"mill", "mine_camp":"mine", "garden":"hay_field"}
	var bodies := {}
	for kind: String in kinds: bodies[kind] = build(kind)
	for alias: String in aliases: bodies[alias] = bodies[aliases[alias]]
	for kind: String in bodies:
		var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="34" height="34" viewBox="0 0 34 34">%s</svg>\n' % bodies[kind]
		FileAccess.open(OUT + kind + ".svg",FileAccess.WRITE).store_string(svg)
	# Headless preview uses the same SVG rasterizer as imported game textures.
	var sheet := Image.create(6*112,5*88,false,Image.FORMAT_RGBA8)
	sheet.fill(Palette.SAND_SURFACE)
	for index in kinds.size():
		var kind: String = kinds[index]
		var preview := Image.new()
		var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="68" height="68" viewBox="0 0 34 34">%s</svg>' % bodies[kind]
		assert(preview.load_svg_from_string(svg) == OK)
		sheet.blend_rect(preview,Rect2i(0,0,68,68),Vector2i((index%6)*112+22,(index/6)*88+10))
	assert(sheet.save_png("res://artifacts/settlement/building-icon-sheet.png") == OK)
	print("PASS: generated %d coloured building icons and headless preview" % bodies.size())
	quit()
