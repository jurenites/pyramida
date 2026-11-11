extends SceneTree
const Islands=preload("res://scripts/settlement/solid_islands.gd")
const Shape=preload("res://scripts/settlement/island_shape_generator.gd")
const Deposits=preload("res://scripts/settlement/geological_deposits.gd")
const Stone=preload("res://scripts/settlement/eroded_stone.gd")
const Model=preload("res://scripts/settlement/world_model.gd")
var failures: Array[String]=[]
var checks:=0
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures.append(message); printerr("FAIL: ",message)
func _initialize() -> void: call_deferred("run")
func closed(faces: PackedVector3Array, label: String) -> void:
	var edges: Dictionary={}
	for i in range(0,faces.size(),3):
		for j in 3:
			var a:=faces[i+j].snapped(Vector3.ONE*0.0001); var b:=faces[i+(j+1)%3].snapped(Vector3.ONE*0.0001)
			var key: Array=[a,b] if a<b else [b,a]
			edges[key]=int(edges.get(key,0))+1
	var bad:=0
	for edge in edges:
		if edges[edge]!=2: bad+=1
	check(bad==0,"Closed solid %s (%d open edges)"%[label,bad])
func run() -> void:
	var signatures: Array=[]
	for version in [10,12,13]:
		for seed_value in [1409,42,9182,101,0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31]:
			var main: Dictionary=Islands.definitions(seed_value,version)[0]
			if version>=13:
				var hull:=Geometry2D.convex_hull(main.coast)
				var filled:=Shape.polygon_area(main.coast)/Shape.polygon_area(hull)
				var previous: Dictionary=Islands.definitions(seed_value,12)[0]
				var old_filled:=Shape.polygon_area(previous.coast)/Shape.polygon_area(Geometry2D.convex_hull(previous.coast))
				check(filled>0.78 and filled>old_filled+0.15,"Broad connected coast replaces thin radial arms")
				for a in main.shelves.size():
					for b in range(a+1,main.shelves.size()):
						if main.shelves[a].height!=main.shelves[b].height: continue
						var merged:=Geometry2D.merge_polygons(main.shelves[a].outline,main.shelves[b].outline)
						check(merged.size()!=1,"Touching equal-height shelves share one continuous solid")
			var current: Array=[]
			for i in main.parts.size():
				closed(main.parts[i].faces,"seed %d part %d"%[seed_value,i]); current.append(hash(main.parts[i].faces))
			check(current!=signatures,"Seed changes the landforms"); signatures=current
			var repeat:=Islands.make_islands(seed_value,version)[0]
			for i in main.parts.size(): check(main.parts[i].faces==repeat.parts[i].faces,"Regeneration matches")
			var peak:=0.0; var cliff:=0.0; var concave:=0
			for item in main.parts: peak=maxf(peak,item.bounds.end.y)
			check(peak>12,"Narrow rocky summit rises above broad plateaus")
			var widest:=0.0; var narrowest:=INF
			for shelf in main.shelves:
				widest=maxf(widest,Shape.polygon_area(shelf.outline)); narrowest=minf(narrowest,Shape.polygon_area(shelf.outline))
			check(widest>narrowest*2.5,"Unequal shelf areas")
			for i in main.coast.size():
				var a: Vector2=main.coast[i]; var b: Vector2=main.coast[(i+1)%main.coast.size()]; var c: Vector2=main.coast[(i+2)%main.coast.size()]
				if (b-a).cross(c-b)<-0.2: concave+=1
				var inward:=Vector2(-(b-a).y,(b-a).x).normalized()
				var at: Vector2=(a+b)*0.5+inward*0.1
				if Islands.native_solid(seed_value,Vector3(at.x,2,at.y),version): cliff+=(b-a).length()
			check(concave>=5 and cliff>15,"Deep coves alternate with sea cliffs")
			if version<12:
				check(main.shoals.size()>=2,"Eroded rocks emerge beside coastal cliffs")
			else:
				# Deeper coves need not leave room for a rock group at every seed.
				check(main.shoals.size()<=2,"Compact coast retains at most one sparse outcrop group")
	for seed_value in [1409,42,9182,101,7,25]:
		var world:=Model.new(); world.setup(seed_value,"easy")
		var rocks: Array[Vector3i]=[]
		for cell: Vector3i in world.deposits:
			if world.deposits[cell].kind!="limestone": continue
			rocks.append(cell)
			var distance:=Deposits.cliff_distance(world,Vector2(cell.x,cell.z))
			check(distance>=2.2 and distance<=5.0,"Quarry stone follows cliff-foot erosion")
			check(not world.navigation.route(world.workers[0].cell,cell).is_empty(),"Deposit has an actual citizen route")
			check(Deposits.quarry_site(world,cell,world.workers[0].cell)!=Vector3i.ZERO,"Quarry fits nearby with access")
			for section in Stone.sections(cell,seed_value): closed(Stone.mesh(section.faces).get_faces(),"quarry fragment")
		print("Seed ",seed_value," reachable quarries ",rocks)
		check(rocks.size()>=2,"At least two reachable quarry sites per starting island")
		check(Model.new().restore(JSON.parse_string(JSON.stringify(world.snapshot()))),"New island and resource save loads")
		if seed_value==1409 and not rocks.is_empty(): await mining(world,rocks[0])
	if failures.is_empty(): print("PASS: %d geological terrain, coastal rock, quarry access and mining checks"%checks)
	quit(int(not failures.is_empty()))
func mining(world, deposit: Vector3i) -> void:
	var site:=Deposits.quarry_site(world,deposit,world.workers[0].cell)
	check(world.request_build("quarry",site),"Quarry construction is valid")
	check(world.buildings.has(site) or world.debug_finish_plan(world.next_plan_id-1),"Quarry completes")
	world.exploration.reveal(Vector3(deposit)); world.exploration.reveal(Vector3(site))
	for worker in world.workers: world.set_role(worker.id,"idle")
	check(world.order_workplace(0,site),"Citizen takes quarry job")
	var before:=remaining_stone(world)
	var section: Dictionary=Stone.sections(deposit,world.world_seed)[0]
	var full:=Stone.Base.polygon_volume(section.faces)
	for remaining in range(1,9):
		var faces:=Stone.visual_faces(section,remaining)
		closed(Stone.mesh(faces).get_faces(),"partially mined boulder")
		check(absf(Stone.Base.polygon_volume(faces)/full-float(remaining)/9)<0.001,"Mined volume tracks finite stock")
	for tick in 5000:
		for worker in world.workers: worker.hunger=0
		world.tick(0.1)
		if world.stores[site].count("stone")>0: break
	check(world.stores[site].count("stone")>0,"Citizen mines and delivers stone to quarry")
	check(remaining_stone(world)<before,"Mining consumes finite outcrop")
	check(Model.new().restore(JSON.parse_string(JSON.stringify(world.snapshot()))),"Mined rock and quarry survive save/load")

func remaining_stone(world) -> int:
	var amount:=0
	for entry in world.deposits.values():
		if entry.kind=="limestone": amount+=entry.inventory.count("stone")
	return amount
