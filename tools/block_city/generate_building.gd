extends SceneTree
const Generator=preload("res://scripts/block_city/building_generator.gd")
const Model=preload("res://scripts/block_city/model.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var conditions: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/block_city/building_presets.json")).defaults.duplicate(true)
	var output:="res://artifacts/block_city/generated-building.json"
	var preview:=false
	for argument in OS.get_cmdline_user_args():
		if argument=="--preview": preview=true; continue
		var parts: PackedStringArray=argument.trim_prefix("--").split("=",true,1)
		if parts.size()!=2: printerr("Use --seed=42 --width=3 --depth=3 --floors=3 --out=path --preview"); quit(2); return
		match parts[0]:
			"seed","width","depth","floors","max_room_cells","min_rooms":
				if not parts[1].is_valid_int(): printerr("Expected integer: ",parts[0]); quit(2); return
				conditions[parts[0]]=int(parts[1])
			"top_setback": conditions.top_setback=parts[1]=="true"
			"allowed_shapes": conditions.allowed_shapes=Array(parts[1].split(","))
			"out": output=parts[1]
			_: printerr("Unknown condition: ",parts[0]); quit(2); return
	var generated: Dictionary=Generator.new().generate(Model.new().config,conditions)
	if not generated.ok: printerr(generated.error); quit(1); return
	var export: Dictionary={"version":1,"conditions":generated.conditions,"rooms":generated.rooms,"validation":generated.validation}
	var file:=FileAccess.open(output,FileAccess.WRITE)
	if file==null: printerr("Cannot write ",output); quit(1); return
	file.store_string(JSON.stringify(export,"\t")); file.close()
	print("Generated %d connected modules / %d reachable cells → %s" % [generated.rooms.size(),generated.validation.reachable_cells,output])
	if not preview: quit(); return
	var game=load("res://scripts/block_city/game.gd").new()
	game.auto_save=false; game.restore_last=false; root.add_child(game)
	game.model=Model.new("",generated.config); game.model.reset()
	game.model.rooms=generated.rooms; game.view_mode=1; game.set_holding(false); game.refresh()
	root.title="Block City · Generated building preview"
