extends RefCounted
## Complete sidewalk rings, narrow-street crossings, and connected prefab neighbors.
const Land=preload("res://scripts/block_city/land.gd")
const Generator=preload("res://scripts/block_city/building_generator.gd")
static var cached: Dictionary={}
static func layout(config: Dictionary) -> Dictionary:
	var key:=JSON.stringify(config)
	if cached.has(key): return cached[key]
	var w:=int(config.plot.width); var d:=int(config.plot.depth)
	var f:=int(config.street.front_road_width)
	var left:=-8; var right:=w+7
	var front:=-7-f; var back:=d+7
	var roads: Array=Land.roads(config).map(func(rect):return Rect2(rect))
	var cross_streets: Array=[-2,w+1]
	var rows: Array=[Vector2i(front+1,-1-f),Vector2i(-1,d+1),Vector2i(d+2,back)]
	var columns: Array=[Vector2i(left+1,-2),Vector2i(-1,w+1),Vector2i(w+2,right)]
	var passages: Array=[]
	for x in [-2,w+1]:
		for z in range(-1,d+1): passages.append(Rect2(x,z,1,1))
	var neighbours: Array=[]
	var blocks: Array=[]
	var presets: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/block_city/building_presets.json"))
	var variant:=0
	for row_index in rows.size():
		for col_index in columns.size():
			var col: Vector2i=columns[col_index]; var row: Vector2i=rows[row_index]
			var block:=Rect2(col.x,row.x,col.y-col.x,row.y-row.x)
			blocks.append(block)
			var occupied: Dictionary={}
			if row_index==1 and col_index==1:
				for x in w:
					for z in d: occupied[Vector2i(x,z)]=true
			else:
				var options: Dictionary=presets.defaults.duplicate(true)
				var footprint: Array=presets.neighbour_footprints[variant%presets.neighbour_footprints.size()]
				options.width=clampi(int(footprint[0]),2,3); options.depth=clampi(int(footprint[1]),2,3)
				options.floors=int(config.street.neighbour_height)
				options.seed=int(options.seed)+variant
				options.top_setback=variant%3==2
				var generated: Dictionary=Generator.new().generate(config,options)
				if not generated.ok:
					push_warning("Neighbor preset rejected: %s. Using a connected 3×3 fallback." % generated.error)
					generated=Generator.new().generate(config,{"seed":2026+variant,"floors":clampi(int(config.street.neighbour_height),1,9)})
				var origin:=Vector3i(col.x+1,0,row.x+1)
				var cells: Array=generated.cells.map(func(cell):return cell+origin)
				for cell in cells: occupied[Vector2i(cell.x,cell.z)]=true
				neighbours.append({"plot_id":row_index*3+col_index,"cells":cells,"variant":variant,"origin":origin,"rooms":generated.rooms,"conditions":generated.conditions,"validation":generated.validation})
				variant+=1
			# Every unbuilt ground cell becomes a paved pedestrian route.
			for x in range(col.x,col.y):
				for z in range(row.x,row.y):
					if not occupied.has(Vector2i(x,z)): passages.append(Rect2(x,z,1,1))
	var crossings: Array=[]
	for x in [-2,w+1]:
		for row in rows:
			if row.x==-1: continue
			for z in [row.x+0.5,row.y-0.5]: crossings.append({"rect":Rect2(x,z-0.32,1,0.64),"axis":"x","from":Vector2i(x-1,floori(z)),"to":Vector2i(x+1,floori(z))})
	for col in columns:
		for x in [col.x+0.5,col.y-0.5]: crossings.append({"rect":Rect2(x-0.32,d+1,0.64,1),"axis":"z","from":Vector2i(floori(x),d),"to":Vector2i(floori(x),d+2)})
	var result: Dictionary={"bounds":Land.bounds(config),"plot":Rect2(0,0,w,d),"passages":passages,"roads":roads,"cross_streets":cross_streets,"crossings":crossings,"blocks":blocks,"neighbours":neighbours}
	cached[key]=result
	return result
