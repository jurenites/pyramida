extends SceneTree
const Generator=preload("res://scripts/block_city/building_generator.gd")
const Model=preload("res://scripts/block_city/model.gd")
var failures:=0
func check(ok: bool,message: String) -> void:
	if not ok: failures+=1; push_error(message)
func _initialize() -> void:
	var config: Dictionary=Model.new().config
	for size in [Vector2i(2,3),Vector2i(3,2),Vector2i(3,3),Vector2i(4,4),Vector2i(5,3)]:
		for seed_value in 6:
			var options: Dictionary={"width":size.x,"depth":size.y,"floors":3,"seed":seed_value,"top_setback":seed_value%2==0}
			var result: Dictionary=Generator.new().generate(config,options)
			check(result.ok,"Connected generation %s seed %d: %s" % [size,seed_value,result.get("error","")])
			if not result.ok: continue
			check(result.rooms==Generator.new().generate(config,options).rooms,"Same conditions and seed reproduce the same rooms and doors")
			check(result.cells.all(func(cell):return cell.x>=0 and cell.x<size.x and cell.z>=0 and cell.z<size.y and cell.y<3),"Generated cells obey footprint and height")
			var test_model=Model.new("",result.config); test_model.rooms=result.rooms.duplicate(true)
			test_model.rooms[-1].door=[99,0,99]
			check(not Generator.validate(test_model).ok,"Validator rejects a broken doorway")
	for floors in [1,9]:
		check(Generator.new().generate(config,{"floors":floors}).ok,"Single-floor and maximum-height buildings connect")
	var broken: Dictionary=Generator.new().generate(config,{})
	var disconnected=Model.new("",broken.config); disconnected.rooms=broken.rooms
	for room in disconnected.rooms:
		if disconnected.room_role(room)=="stairs": room.normal=[0,0,1]
	check(not Generator.validate(disconnected).ok,"Disconnected stair entrances fail reachability validation")
	for invalid in [{"floors":0},{"width":1},{"allowed_shapes":["flat_l"]},{"allowed_shapes":[]},{"max_room_cells":1},{"min_rooms":999}]:
		check(not Generator.new().generate(config,invalid).ok,"Impossible conditions return an error")
	print("Block City generator: ",failures," failures")
	quit(1 if failures else 0)
