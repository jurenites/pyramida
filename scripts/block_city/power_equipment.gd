extends RefCounted
const Cable=preload("res://scripts/block_city/cable.gd")

static func pole(game, parent: Node3D, cell: Vector3i, normal: Vector3i) -> void:
	var root:=Node3D.new(); root.name="SmallPole"; parent.add_child(root)
	var base:=Vector3(cell)+Vector3(0.5,0,0.5)
	game.box(root,base+Vector3.UP*0.06,Vector3(0.46,0.12,0.46),game.model.CONCRETE_FLOOR)
	game.beam(root,base,base+Vector3.UP*2.25,game.model.CONCRETE_COLUMN,0.07)
	var side:=Vector3(-normal.z,0,normal.x)
	game.beam(root,base+Vector3.UP*2.25-side*0.38,base+Vector3.UP*2.25+side*0.38,game.INK,0.045)
	for slot in 3:
		var point:=Cable.equipment_socket(cell,normal,slot,"pole")
		game.beam(root,point-Vector3.UP*0.10-Vector3(normal)*0.16,point-Vector3.UP*0.10,game.INK,0.025)
		var terminal: MeshInstance3D=game.box(root,point,Vector3(0.085,0.15,0.085),game.POWER)
		terminal.name="Terminal%d" % slot

static func transformer(game, parent: Node3D, at := Vector3i(100,100,100)) -> void:
	if at.x==100: at=game.model.transformer_cell
	var root:=Node3D.new(); root.name="StarterTransformer"; parent.add_child(root)
	root.position=Vector3(at)
	game.box(root,Vector3(0.5,0.06,0.5),Vector3(1,0.12,1),game.model.CONCRETE_FLOOR)
	game.box(root,Vector3(0.5,0.49,0.5),Vector3(0.80,0.74,0.80),Color("687e79"))
	game.box(root,Vector3(0.5,0.90,0.5),Vector3(0.98,0.08,0.98),game.model.CONCRETE_COLUMN)
	for x in [0.045,0.955]:
		for z in [0.20,0.32,0.44,0.56,0.68,0.80]: game.box(root,Vector3(x,0.48,z),Vector3(0.09,0.60,0.045),Color("566b66"))
	game.box(root,Vector3(0.5,0.46,0.085),Vector3(0.54,0.56,0.04),game.model.CONCRETE_WALL)
	for segment in [[Vector3(0.55,0.64,0.055),Vector3(0.43,0.46,0.055)],[Vector3(0.43,0.46,0.055),Vector3(0.56,0.46,0.055)],[Vector3(0.56,0.46,0.055),Vector3(0.45,0.28,0.055)]]:
		game.beam(root,segment[0],segment[1],game.ACCESS,0.018)
	var input: MeshInstance3D=game.box(root,Vector3(0.5,0.78,-0.025),Vector3(0.14,0.14,0.15),game.ACCESS)
	input.name="Input"
	for slot in 3:
		var point:=Cable.equipment_socket(at,Vector3i.FORWARD,slot,"transformer")-root.position
		var output: MeshInstance3D=game.box(root,point,Vector3(0.12,0.16,0.12),game.POWER)
		output.name="Output%d" % slot
	var feed:=Node3D.new(); feed.name="ServiceFeed"; parent.add_child(feed)
	var points: PackedVector3Array=game.model.transformer_feed(at)
	for i in range(1,points.size()): game.beam(feed,points[i-1],points[i],game.INK,0.026)
