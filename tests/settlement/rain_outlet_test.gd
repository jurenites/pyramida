extends SceneTree
const Model=preload("res://scripts/settlement/world_model.gd")
const Rain=preload("res://scripts/settlement/roof_rain.gd")
const Fixture=preload("res://tests/settlement/reviewed_balance_test.gd")
var failures: Array[String]=[]
func check(ok: bool,message: String) -> void:
	if not ok: failures.append(message); printerr("FAIL: "+message)
func _initialize() -> void: call_deferred("run")
func fit(world,spec: Dictionary) -> int:
	if not Rain.request(world,spec): check(false,world.last_message); return -1
	check(world.debug_finish_plan(world.next_plan_id-1),"Complete fitting")
	return world.roof_rain.next_id-1
func run() -> void:
	var fixture:=Fixture.new(); var world=fixture.fixture(); world.generator_version=4; world.roof_rain=Rain.fresh(true)
	fixture.finish(world,"house",Vector3i.ZERO)
	var gutter: int=-1
	for key in Rain.roof_lanes(world,true):
		var id:=fit(world,{"kind":"gutter","lane":key})
		if key.ends_with(":s7"): gutter=id
	var cell:=Vector3i(0,0,4)
	var start: Vector3=Rain.start_point(world,{"gutter":gutter}); var end: Vector3=Rain.end_point(world,{"outfall":cell})
	var id:=fit(world,{"kind":"pipe","gutter":gutter,"outfall":cell,"path":[start,Vector3(start.x,start.y-0.02,3),Vector3(0,1.1,3),end]})
	world.weather.raining=true
	for i in 16: Rain.rain_second(world)
	check(Rain.receiver(world,world.roof_rain.pipes[id])==null,"Uncaught outlet has no receiver")
	check(world.roof_rain.wet.get(cell,0)>0 and not world.water_sources.has(cell),"Ground discharge wets its landing without creating free stored water")
	fit(world,{"kind":"vase","cell":cell,"offset":Vector3.ZERO})
	for i in 8: Rain.rain_second(world)
	var restored:=Model.new(); check(restored.restore(JSON.parse_string(JSON.stringify(world.snapshot()))),"Ground outlet and newly placed receiver survive save/load")
	for i in 8: Rain.rain_second(restored)
	check(restored.water_sources[cell].inventory.count("water")==1,"A vase placed below the existing drain collects one roof's full rain event")
	check(Rain.move_tank(restored,cell,Vector3i(2,0,4),Vector3.ZERO),"Move the full vase away")
	check(restored.roof_rain.pipes[id].outfall==cell and Rain.receiver(restored,restored.roof_rain.pipes[id])==null,"Moving a vase leaves the fixed ground outlet in place")
	fit(restored,{"kind":"barrel","cell":cell,"offset":Vector3.ZERO})
	for i in 16: Rain.rain_second(restored)
	check(restored.water_sources[cell].inventory.count("water")==1,"A replacement barrel catches the same outlet without rerouting")
	check(Rain.move_tank(restored,cell,cell,Vector3(0.45,0,0)),"Offset the barrel away from the stream")
	check(Rain.receiver(restored,restored.roof_rain.pipes[id])==null,"A vessel must actually be under the spout")
	check(world.restore(JSON.parse_string(JSON.stringify(restored.snapshot()))),"Moved receivers and outfall pipes preserve their saved state")
	fixture.free()
	if failures.is_empty(): print("PASS: ground discharge, receiver replacement, exact catchment and persistence")
	quit(0 if failures.is_empty() else 1)
