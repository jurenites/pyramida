extends RefCounted
## Finite quarry stone accumulates below exposed cliff faces, on accessible land.
const Inventory=preload("res://scripts/settlement/inventory.gd")
const Stone=preload("res://scripts/settlement/eroded_stone.gd")
const Islands=preload("res://scripts/settlement/solid_islands.gd")

static func cliff_distance(world, point: Vector2) -> float:
	var nearest:=INF
	for shelf in Islands.definitions(world.world_seed,world.generator_version)[0].get("shelves",[]):
		var outline: PackedVector2Array=shelf.outline
		if Geometry2D.is_point_in_polygon(point,outline): return 0.0
		for i in outline.size(): nearest=minf(nearest,point.distance_to(Geometry2D.get_closest_point_to_segment(point,outline[i],outline[(i+1)%outline.size()])))
	return nearest

static func seed(world, reachable: Array[Vector3i]) -> void:
	var candidates: Array[Vector3i]=[]
	for cell in reachable:
		if cell.y!=0 or world.terrain_shapes.has(cell): continue
		# On connected coasts the cliff feet can lie inside the old origin-centred
		# exclusion square. Protect the actual village, not an arbitrary map box.
		if world.generator_version>=13:
			if cell.distance_to(world.STARTING_HOUSE)<10: continue
		elif maxi(absi(cell.x),absi(cell.z))<12: continue
		var distance:=cliff_distance(world,Vector2(cell.x,cell.z))
		if distance<2.2 or distance>5.0: continue
		if Islands.shore_distance(Vector2(cell.x,cell.z),world.world_seed,world.generator_version)>-2.3: continue
		var clear:=true
		for dx in range(-2,3):
			for dz in range(-2,3):
				var foot:=cell+Vector3i(dx,0,dz)
				if not world.ground.has(foot) or world.terrain_shapes.has(foot) or world.buildings.has(foot) or world.water_sources.has(foot) or world.vines.has(foot) or world.gardens.has(foot): clear=false; break
			if not clear: break
		if clear: candidates.append(cell)
	candidates.sort_custom(func(a,b):
		var da:=absf(cliff_distance(world,Vector2(a.x,a.z))-3.0)
		var db:=absf(cliff_distance(world,Vector2(b.x,b.z))-3.0)
		return da<db if not is_equal_approx(da,db) else a<b)
	var placed: Array[Vector3i]=[]
	var origin: Vector3i=world.workers[0].cell
	for cell in candidates:
		if placed.any(func(other): return other.distance_to(cell)<8): continue
		# Exposed talus suppresses vegetation. Clear only this new erosion patch;
		# no saved world or player construction passes through this generator.
		var displaced_trees: Dictionary={}; var displaced_bushes: Dictionary={}
		for dx in range(-2,3):
			for dz in range(-2,3):
				var at:=cell+Vector3i(dx,0,dz)
				if world.trees.has(at): displaced_trees[at]=world.trees[at]; world.trees.erase(at)
				if world.deposits.has(at): displaced_bushes[at]=world.deposits[at]; world.deposits.erase(at)
		var inventory:=Inventory.new(); inventory.capacity=Stone.capacity(cell,world.world_seed); inventory.store("stone",inventory.capacity)
		world.deposits[cell]={"kind":"limestone","inventory":inventory,"regrowth":0.0}
		world.rebuild_navigation()
		if world.navigation.route(origin,cell).is_empty() or quarry_site(world,cell,origin)==Vector3i.ZERO:
			world.deposits.erase(cell); world.trees.merge(displaced_trees); world.deposits.merge(displaced_bushes); continue
		placed.append(cell)
		if placed.size()==(2 if world.generator_version>=11 else 4): break
	world.rebuild_navigation()
	# A later rubble patch must not cut off an earlier quarry's approach.
	for cell in placed:
		if world.navigation.route(origin,cell).is_empty() or quarry_site(world,cell,origin)==Vector3i.ZERO:
			world.deposits.erase(cell); world.rebuild_navigation()

static func quarry_site(world, deposit: Vector3i, origin: Vector3i) -> Vector3i:
	for radius in range(3,7):
		for dx in range(-radius,radius+1):
			for dz in range(-radius,radius+1):
				if maxi(absi(dx),absi(dz))!=radius or Vector2(dx,dz).length()>8: continue
				var cell:=deposit+Vector3i(dx,0,dz)
				if not world.build_error("quarry",cell).is_empty(): continue
				var route: Array=world.nearest_route(origin,world.work_cells("quarry",cell))
				if not route.is_empty() and not world.navigation.route(route.back(),deposit).is_empty(): return cell
	return Vector3i.ZERO
