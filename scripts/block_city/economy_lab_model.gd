extends RefCounted
## Separate, deterministic economy experiment. Does not read or write the construction save.
const CONFIG := "res://data/block_city/economy_lab.json"
const NETWORKS := ["water","sewer"]
const ROAD := Vector3(-0.5,-0.22,-2.5)
var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CONFIG))
var floors: Array = []
var cash := 0.0
var month := 0
var mode := "builder"
var lift := false
var upgraded := false
var next_id := 0
var earned := 0.0
var expenses := 0.0
var spent := 0.0
var history: Array = []
var error := ""
var finished_month := -1
var last_income := 0.0
var last_expense := 0.0

func _init() -> void: reset()
func reset(new_mode := "builder") -> void:
	mode=new_mode if new_mode in ["builder","creative","sprint"] else "builder"
	floors=[empty_floor()]
	cash=float(config.starting_cash)
	month=0; lift=false; upgraded=false; next_id=0
	earned=0; expenses=0; spent=0; finished_month=-1; last_income=0; last_expense=0
	history.clear(); error=""
func empty_floor() -> Dictionary:
	return {"bath":[0,0],"water":false,"sewer":false,"rooms":[]}
func snapshot() -> Dictionary:
	return {"version":1,"floors":floors.duplicate(true),"cash":cash,"month":month,"mode":mode,"lift":lift,
		"upgraded":upgraded,"next_id":next_id,"earned":earned,"expenses":expenses,"spent":spent,
		"finished_month":finished_month,"last_income":last_income,"last_expense":last_expense}
func restore(state: Dictionary) -> void:
	floors=state.floors.duplicate(true); cash=float(state.cash); month=int(state.month); mode=state.mode
	lift=state.lift; upgraded=state.upgraded; next_id=int(state.next_id)
	earned=float(state.earned); expenses=float(state.expenses); spent=float(state.spent)
	finished_month=int(state.finished_month); last_income=float(state.last_income); last_expense=float(state.last_expense)
func remember() -> void:
	history.append(snapshot())
	if history.size()>200: history.pop_front()
func undo() -> bool:
	if history.is_empty(): return false
	restore(history.pop_back()); error=""; return true
func reject(reason: String) -> bool:
	error=reason; return false
func valid_slot(level: int, slot: Vector2i) -> bool:
	return level>=0 and level<floors.size() and slot.x>=0 and slot.x<3 and slot.y in [0,2]
func room_at(level: int, slot: Vector2i) -> Dictionary:
	if level<0 or level>=floors.size(): return {}
	for room in floors[level].rooms:
		if Vector2i(room.at[0],room.at[1])==slot: return room
	return {}
func bath_slot(level: int) -> Vector2i:
	return Vector2i(floors[level].bath[0],floors[level].bath[1])
func bathroom(level: int) -> Vector3:
	var slot := bath_slot(level)
	return Vector3(slot.x+0.5,level+0.16,slot.y+0.5)
func route(level: int) -> Array[Vector3]:
	# Paired supply/drain occupy a reserved service plenum. Sewage never climbs.
	var start := bathroom(level)
	var end := ROAD if level==0 else bathroom(level-1)
	var points: Array[Vector3] = [start]
	if level==0:
		points.append(Vector3(start.x,-0.04,start.z))
		points.append(Vector3(end.x,-0.10,start.z))
		points.append(end)
	else:
		if not is_equal_approx(start.x,end.x): points.append(Vector3(end.x,start.y-0.04,start.z))
		if not is_equal_approx(start.z,end.z): points.append(Vector3(end.x,start.y-0.08,end.z))
		points.append(end)
	return points
func route_length(level: int) -> float:
	var points := route(level)
	var length := 0.0
	for i in range(1,points.size()): length+=points[i-1].distance_to(points[i])
	return length
func bends(level: int) -> int: return maxi(0,route(level).size()-2)
func link_cost(level: int) -> float:
	return snappedf(float(config.pipe_connection_cost)+route_length(level)*float(config.pipe_unit_cost)+bends(level)*float(config.pipe_bend_cost),0.1)
func asset_value() -> float:
	var total := (floors.size()-1)*float(config.floor_cost)
	if lift: total+=float(config.lift_cost)
	if upgraded: total+=float(config.capacity_upgrade_cost)
	for level in floors.size():
		for kind in NETWORKS:
			if floors[level][kind]: total+=link_cost(level)
		for room in floors[level].rooms: total+=float(config.home_cost if room.kind=="home" else config.garden_cost)
	return snappedf(total,0.1)
func commit_change(before: Dictionary, old_value: float) -> bool:
	var delta := snappedf(asset_value()-old_value,0.1)
	if mode!="creative" and cash+0.001<delta:
		restore(before); return reject("cash")
	history.append(before)
	if history.size()>200: history.pop_front()
	if mode!="creative": cash=snappedf(cash-delta,0.1); spent=snappedf(spent+delta,0.1)
	error=""; return true
func build(level: int, slot: Vector2i, kind := "home") -> bool:
	if not valid_slot(level,slot) or not kind in ["home","garden"]: return reject("slot")
	if slot==bath_slot(level) or not room_at(level,slot).is_empty(): return reject("occupied")
	var before := snapshot(); var value := asset_value()
	floors[level].rooms.append({"id":next_id,"at":[slot.x,slot.y],"kind":kind,"people":0,"missed":0})
	next_id+=1
	return commit_change(before,value)
func remove(level: int, slot: Vector2i) -> bool:
	var room := room_at(level,slot)
	if room.is_empty(): return reject("empty")
	var before := snapshot(); var value := asset_value()
	floors[level].rooms.erase(room)
	return commit_change(before,value)
func move_bath(level: int, slot: Vector2i) -> bool:
	if not valid_slot(level,slot) or not room_at(level,slot).is_empty(): return reject("occupied")
	if slot==bath_slot(level): return reject("same")
	var before := snapshot(); var value := asset_value()
	floors[level].bath=[slot.x,slot.y]
	# Requote both incoming and outgoing links; preserve genuine service continuity.
	return commit_change(before,value)
func connect_pipe(source: int, target: int, kind: String) -> bool:
	if not kind in NETWORKS or target<0 or target>=floors.size() or source!=target-1: return reject("route")
	if floors[target][kind]: return reject("connected")
	var before := snapshot(); var value := asset_value()
	floors[target][kind]=true
	return commit_change(before,value)
func disconnect_pipe(level: int, kind: String) -> bool:
	if not kind in NETWORKS or level<0 or level>=floors.size() or not floors[level][kind]: return reject("route")
	var before := snapshot(); var value := asset_value()
	floors[level][kind]=false
	return commit_change(before,value)
func add_floor() -> bool:
	if floors.size()>=int(config.max_floors): return reject("height")
	var before := snapshot(); var value := asset_value()
	var floor := empty_floor(); floor.bath=floors[-1].bath.duplicate()
	floors.append(floor)
	return commit_change(before,value)
func remove_floor() -> bool:
	if floors.size()<=1: return reject("foundation")
	var before := snapshot(); var value := asset_value()
	floors.pop_back()
	return commit_change(before,value)
func remove_upgrade(kind: String) -> bool:
	if kind not in ["lift","capacity"] or not (lift if kind=="lift" else upgraded): return reject("upgrade")
	var before := snapshot(); var value := asset_value()
	if kind=="lift": lift=false
	else: upgraded=false
	return commit_change(before,value)
func buy_upgrade(kind: String) -> bool:
	if kind not in ["lift","capacity"] or (lift if kind=="lift" else upgraded): return reject("upgrade")
	var before := snapshot(); var value := asset_value()
	if kind=="lift": lift=true
	else: upgraded=true
	return commit_change(before,value)
func linked(level: int, kind: String) -> bool:
	if not kind in NETWORKS or level<0 or level>=floors.size(): return false
	for i in range(level+1):
		if not floors[i][kind]: return false
	return true
func capacity() -> int:
	return int(config.street_capacity)+ (int(config.upgrade_capacity) if upgraded else 0)
func allocations() -> Dictionary:
	var remaining := mini(capacity(),int(config.district_demand))
	var result := {}
	for level in floors.size():
		if not linked(level,"water") or not linked(level,"sewer"): continue
		var local := int(config.bathroom_capacity)
		for room in floors[level].rooms:
			if room.kind!="home": continue
			var count := int(config.residents_per_home)
			if remaining<count or local<count: continue
			result[int(room.id)]=count; remaining-=count; local-=count
	return result
func residents() -> int:
	var count := 0
	for floor in floors:
		for room in floor.rooms: count+=int(room.people)
	return count
func garden_bonus(level: int, room: Dictionary) -> float:
	for other in floors[level].rooms:
		if other.kind=="garden" and absi(int(other.at[0])-int(room.at[0]))+absi(int(other.at[1])-int(room.at[1]))<=2:
			return float(config.garden_rent_bonus)
	return 0.0
func account(allocated: Dictionary) -> Dictionary:
	var income := 0.0; var upkeep := 0.0; var served := 0; var used_links := {}
	var lift_used := false
	for level in floors.size():
		for room in floors[level].rooms:
			if not allocated.has(int(room.id)): continue
			var people := int(allocated[int(room.id)])
			served+=people
			var bonus := garden_bonus(level,room)
			if lift and level>0:
				bonus+=float(config.lift_rent_bonus); lift_used=true
			income+=people*(float(config.rent_per_resident)+bonus)
			upkeep+=float(config.home_upkeep)+people*float(config.service_per_resident)
			for i in range(level+1): used_links[i]=true
	var length := 0.0
	for level in used_links: length+=2.0*route_length(level)
	upkeep+=minf(length*float(config.pipe_upkeep_per_unit),served*float(config.pipe_surcharge_cap_per_resident))
	if lift_used: upkeep+=float(config.lift_upkeep)
	return {"income":snappedf(income,0.1),"upkeep":snappedf(upkeep,0.1),"net":snappedf(income-upkeep,0.1),"served":served,"active_pipe_length":length}
func forecast() -> Dictionary: return account(allocations())
func advance() -> void:
	remember()
	var allocated := allocations()
	for floor in floors:
		for room in floor.rooms:
			if room.kind!="home": continue
			if allocated.has(int(room.id)):
				room.people=int(allocated[int(room.id)]); room.missed=0
			else:
				room.missed=int(room.missed)+1
				if room.missed>=int(config.outage_grace_months): room.people=0
	var books := account(allocated)
	last_income=books.income; last_expense=books.upkeep
	earned=snappedf(earned+last_income,0.1); expenses=snappedf(expenses+last_expense,0.1)
	if mode!="creative": cash=snappedf(cash+books.net,0.1)
	month+=1
	if finished_month<0 and books.served>=int(config.district_demand): finished_month=month
	error=""
func pipe_total() -> float:
	var length := 0.0
	for level in floors.size():
		for kind in NETWORKS:
			if floors[level][kind]: length+=route_length(level)
	return length
func teaching_step() -> int:
	if residents()>0: return 4
	if floors[0].rooms.is_empty(): return 0
	if not floors[0].water: return 1
	if not floors[0].sewer: return 2
	return 3
