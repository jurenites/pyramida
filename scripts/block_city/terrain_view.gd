extends RefCounted
## A bounded, floating ground section; the service bay is a visual cutaway only.
const Model=preload("res://scripts/block_city/model.gd")
const BOTTOM := -4.2
static func bounds(area: Rect2i) -> AABB:
	return AABB(Vector3(area.position.x,BOTTOM,area.position.y),Vector3(area.size.x,-BOTTOM,area.size.y))

static func subtract(box: AABB, cut: AABB) -> Array:
	if not box.intersects(cut): return [box]
	var lo:=box.position.max(cut.position); var hi:=box.end.min(cut.end)
	var result: Array=[]
	# Six non-overlapping slabs around the intersection.
	for pair in [[box.position,Vector3(lo.x,box.end.y,box.end.z)],
		[Vector3(hi.x,box.position.y,box.position.z),box.end],
		[Vector3(lo.x,box.position.y,box.position.z),Vector3(hi.x,lo.y,box.end.z)],
		[Vector3(lo.x,hi.y,box.position.z),Vector3(hi.x,box.end.y,box.end.z)],
		[Vector3(lo.x,lo.y,box.position.z),Vector3(hi.x,hi.y,lo.z)],
		[Vector3(lo.x,lo.y,hi.z),Vector3(hi.x,hi.y,box.end.z)]]:
		var size: Vector3=pair[1]-pair[0]
		if size.x>0.001 and size.y>0.001 and size.z>0.001: result.append(AABB(pair[0],size))
	return result

static func draw(game,parent: Node3D,area: Rect2i) -> void:
	var root:=Node3D.new(); root.name="GroundSection"; parent.add_child(root)
	var left:=float(area.position.x); var right:=float(area.end.x)
	var front:=float(area.position.y); var back:=float(area.end.y)
	var metro_z:=front+1.55
	var bay:=AABB(Vector3(left+2,-3.35,front-0.1),Vector3(area.size.x-4,2.80,2.75))
	var tunnel:=AABB(Vector3(left-0.1,-3.25,metro_z-0.90),Vector3(area.size.x+0.2,1.70,1.80))
	var cuts: Array=[bay,tunnel]
	if game.underground:
		var land=preload("res://scripts/block_city/land.gd")
		for id in game.model.owned_plots:
			var plot: Rect2i=land.plots(game.model.config)[int(id)]
			cuts.append(AABB(Vector3(plot.position.x,-3.0,plot.position.y),Vector3(plot.size.x,3.1,plot.size.y)))
	for layer in [[-0.55,-0.22,Color("8f9682")],[-1.55,-0.55,Color("a99a7d")],[-3.35,-1.55,Color("918775")],[BOTTOM,-3.35,Color("737c7b")]]:
		var pieces: Array=[AABB(Vector3(left,layer[0],front),Vector3(area.size.x,layer[1]-layer[0],area.size.y))]
		for cut in cuts:
			var remaining: Array=[]
			for piece in pieces: remaining.append_array(subtract(piece,cut))
			pieces=remaining
		for piece in pieces:
			var mesh: MeshInstance3D=game.box(root,piece.get_center(),piece.size,layer[2]); mesh.name="SoilStratum"
	# Concrete retaining slab and piles exposed by the front service bay.
	var concrete:=Model.CONCRETE_COLUMN
	game.box(root,Vector3((left+right)*0.5,-0.35,front+1.35),Vector3(area.size.x-3.8,0.16,2.65),Model.CONCRETE_FLOOR)
	for x in range(int(left)+3,int(right)-1,3):
		var pile: MeshInstance3D=game.box(root,Vector3(x+0.5,-2.0,front+0.24),Vector3(0.24,3.55,0.24),concrete)
		pile.name="FoundationPile"
		game.box(root,Vector3(x+0.5,-3.66,front+0.24),Vector3(0.62,0.20,0.58),Model.CONCRETE_FLOOR)
	metro(game,root,area,metro_z,bay)
	# Sparse block-sized inclusions reveal the voxel scale on the exposed ends.
	for side in [left,right]:
		for z in range(int(front)+3,int(back)-1,3):
			var detail: MeshInstance3D=game.box(root,Vector3(side+(-0.006 if side==left else 0.006),-2.25,z+0.45),Vector3(0.014,0.28,0.65),Color("9d947f"))
			detail.name="GroundInclusion"

static func metro(game,parent: Node3D,area: Rect2i,z: float,bay: AABB) -> void:
	var root:=Node3D.new(); root.name="MetroCutaway"; parent.add_child(root)
	var left:=float(area.position.x); var right:=float(area.end.x); var center:=(left+right)*0.5
	var concrete:=Model.CONCRETE_WALL
	game.box(root,Vector3(center,-3.30,z),Vector3(area.size.x,0.16,2.02),Model.CONCRETE_FLOOR)
	game.box(root,Vector3(center,-1.50,z),Vector3(area.size.x,0.16,2.02),Model.CONCRETE_FLOOR)
	game.box(root,Vector3(center,-2.4,z+0.94),Vector3(area.size.x,1.80,0.16),concrete)
	# The front tunnel wall is removed only inside the viewing bay.
	for span in [Vector2(left,bay.position.x),Vector2(bay.end.x,right)]:
		game.box(root,Vector3((span.x+span.y)*0.5,-2.4,z-0.94),Vector3(span.y-span.x,1.80,0.16),concrete)
	for x in range(int(left),int(right)):
		game.box(root,Vector3(x+0.5,-3.16,z),Vector3(0.16,0.09,1.35),Color("606966"))
	for side in [-1,1]:
		var rail: MeshInstance3D=game.box(root,Vector3(center,-3.07,z+side*0.46),Vector3(area.size.x,0.09,0.07),Color("46565a")); rail.name="Rail"
	# Cut ends show the tunnel section and continuing rails, without a road ring.
	for x in [left+0.02,right-0.02]:
		for side in [-1,1]: game.box(root,Vector3(x,-2.4,z+side*0.97),Vector3(0.15,1.90,0.20),Model.CONCRETE_COLUMN)
		for y in [-3.29,-1.50]: game.box(root,Vector3(x,y,z),Vector3(0.15,0.20,2.10),Model.CONCRETE_COLUMN)
	var train:=Node3D.new(); train.name="MetroCar"; root.add_child(train)
	var x:=center-0.5
	game.box(train,Vector3(x,-2.49,z),Vector3(3.5,0.87,1.16),Color("d3d9d3"))
	game.box(train,Vector3(x,-1.99,z),Vector3(3.36,0.15,1.10),Color("9caeaa"))
	game.box(train,Vector3(x,-2.78,z-0.591),Vector3(3.45,0.15,0.025),Color("668e8b"))
	for offset in [-1.25,-0.55,0.55,1.25]:
		game.box(train,Vector3(x+offset,-2.32,z-0.594),Vector3(0.48,0.39,0.026),Color("466168"))
	for offset in [-0.16,0.16]: game.box(train,Vector3(x+offset,-2.45,z-0.60),Vector3(0.27,0.67,0.035),Color("8fa6a5"))
	for offset in [-1.12,1.12]:
		for side in [-1,1]: game.box(train,Vector3(x+offset,-2.99,z+side*0.46),Vector3(0.40,0.20,0.14),Color("3f5053"))
	for lamp_x in [left+3,right-3]:
		var lamp: MeshInstance3D=game.box(root,Vector3(lamp_x,-1.61,z+0.80),Vector3(0.42,0.08,0.06),Color("ffd18a"))
		lamp.material_override.emission_enabled=true; lamp.material_override.emission=Color("ffd18a")
