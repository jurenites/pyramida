extends RefCounted
## Deterministic islands with independent coastlines, flat shelves and rocky ridges.
const Vegetation = preload("res://scripts/settlement/vegetation_patches.gd")
const Random = preload("res://scripts/deterministic_random.gd")
const CORNERS := [Vector2(-0.5,-0.5),Vector2(0.5,-0.5),Vector2(0.5,0.5),Vector2(-0.5,0.5)]

static func islands(point: Vector2, seed_: int) -> Array[Dictionary]:
	var phase := float(posmod(seed_,97))*0.064
	var result: Array[Dictionary] = [
		{"at":Vector2(-7,0),"size":Vector2(35,30),"angle":0.12,"phase":phase},
		{"at":Vector2(38,8),"size":Vector2(7,11),"angle":-0.4,"phase":phase+1},
		{"at":Vector2(28,-32),"size":Vector2(12,9),"angle":0.5,"phase":phase+2},
		{"at":Vector2(-30,39),"size":Vector2(11,8),"angle":-0.2,"phase":phase+3},
		{"at":Vector2(39,37),"size":Vector2(6,8),"angle":0.8,"phase":phase+4}]
	var tile := Vector2i(floori(point.x/80),floori(point.y/80))
	for x in range(tile.x-1,tile.x+2):
		for z in range(tile.y-1,tile.y+2):
			var at := Vector2(x*80+40,z*80+40)
			if at.length()<100: continue
			var roll := Random.world_fraction(x,z,seed_,1801)
			if roll<0.35: continue
			result.append({"at":at,"size":Vector2(12+roll*9,10+roll*7),"angle":roll*3,"phase":phase+roll*6})
	return result

static func distance_to_island(point: Vector2, island: Dictionary) -> float:
	var local: Vector2 = (point-island.at).rotated(-island.angle)
	var unit: Vector2 = local/island.size
	var angle := atan2(unit.y,unit.x)
	var outline := 1.0+0.07*sin(angle*3+island.phase)+0.035*sin(angle*5-island.phase)
	return (unit.length()-outline)*minf(island.size.x,island.size.y)

static func shore_distance(point: Vector2, seed_: int) -> float:
	var distance := INF
	for island in islands(point,seed_): distance = minf(distance,distance_to_island(point,island))
	# Preserve the supplied family clearing, including its water sources.
	var opening := maxf(absf(point.x)-17.5,absf(point.y)-17.5)
	return minf(distance,opening)

static func height(point: Vector2, seed_: int) -> float:
	if maxf(absf(point.x),absf(point.y))<=17.5: return 0.0
	var inland := -shore_distance(point,seed_)
	if inland<2: return 0.0
	var h := 0.0
	for island in islands(point,seed_):
		var local: Vector2 = (point-island.at).rotated(-island.angle)
		if distance_to_island(point,island)>-2: continue
		var mainland: bool = island.size.x>30
		var peak: Vector2 = Vector2(-16,-16) if mainland else Vector2(-2,-1)
		var p := local-peak
		var edge := maxf(absf(p.x)*0.75,absf(p.y)*1.1)+0.7*sin(p.y*0.3+island.phase)
		# Wide bench on one flank, narrow steep faces on the other.
		var shelf := 9.0 if p.x>0 else 6.0
		var rise := 2.0*clampf((shelf-edge)/1.2,0,1)
		rise += 3.0*clampf((5.0-edge)/0.9,0,1)
		rise += 3.0*clampf((2.0-edge)/0.8,0,1)
		h = maxf(h,rise*clampf((inland-2)/3,0,1))
	return h

static func ground_color(point: Vector2, seed_: int) -> Color:
	var inland := -shore_distance(point,seed_)
	var green := Color("91aa73")
	var base := Color("ead9ad").lerp(green,smoothstep(1.5,6,inland))
	return base.lerp(Color("c4b68f"),smoothstep(1,5,height(point,seed_)))

static func generate(seed_: int,bounds: Rect2i) -> Dictionary:
	var result := {"seed":seed_,"version":6,"heights":{},"ground":{},"shapes":{},"ramps":{},"water":{},"nature":{},"grass":{},"border":{},"border_shapes":{}}
	var bushes := Vegetation.bushes_in(bounds.grow(1),seed_)
	var trees := Vegetation.trees_in(bounds.grow(1),seed_,true)
	for x in range(bounds.position.x-1,bounds.end.x+1):
		for z in range(bounds.position.y-1,bounds.end.y+1):
			var point := Vector2(x,z)
			var inland := -shore_distance(point,seed_)
			if inland<0: continue
			var values: Array[float] = []
			for offset in CORNERS: values.append(height(point+offset,seed_))
			var level := floori(values.min())
			var cell := Vector3i(x,level,z); var column := Vector2i(x,z)
			var shaped: bool = values.max()-values.min()>0.0001 or absf(values[0]-level)>0.0001
			result.border[column]=level
			if shaped: result.border_shapes[cell]=values
			if not bounds.has_point(column): continue
			result.heights[column]=level; result.ground[cell]=true
			if shaped: result.shapes[cell]=values
			if cell in [Vector3i(-8,0,0),Vector3i(8,0,-8),Vector3i(-10,0,8)]: result.water[cell]="puddle"; continue
			if inland>2.5 and level<2: result.grass[cell]=true
			if maxi(absi(x),absi(z))<=16 or shaped or inland<4: continue
			if level>0:
				if Random.world_fraction(x,z,seed_,304)<0.025: result.nature[cell]="limestone"
			elif bushes.has(column): result.nature[cell]="berry"
			elif trees.has(column): result.nature[cell]=trees[column]
			elif Random.world_fraction(x,z,seed_,302)<0.015: result.nature[cell]="limestone"
			if result.nature.has(cell): result.grass.erase(cell)
	return result

static func shoreline_vertex(point: Vector2,seed_: int) -> Vector2:
	# Shared boundary vertices follow the continuous coast instead of cell steps.
	var land := 0
	for corner in CORNERS:
		if shore_distance(point+corner,seed_)<=0: land+=1
	if land==0 or land==4: return point
	var distance := shore_distance(point,seed_)
	var gradient := Vector2(shore_distance(point+Vector2(0.05,0),seed_)-shore_distance(point-Vector2(0.05,0),seed_),shore_distance(point+Vector2(0,0.05),seed_)-shore_distance(point-Vector2(0,0.05),seed_)).normalized()
	return point-gradient*clampf(distance,-0.75,0.75)
