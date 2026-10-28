extends SceneTree
const Model=preload("res://scripts/block_city/model.gd")
const Land=preload("res://scripts/block_city/land.gd")
const Editor=preload("res://scripts/block_city/editor_selection.gd")
const Neighbourhood=preload("res://scripts/block_city/neighbourhood.gd")
var failures:=0
func check(ok: bool,message: String) -> void:
	if not ok: failures+=1; push_error(message)
func _initialize() -> void:
	var model=Model.new()
	var plots:=Land.plots(model.config)
	check(plots.size()>9 and model.owned_plots==[4],"Start with the central parcel of a nine-plot grid")
	var original: Dictionary=model.snapshot()
	var card: Dictionary={"shape":"cube","color":0}
	for id in 9:
		var at: Vector2i=plots[id].position
		check(model.landing(card,at.x,at.y,0,false,0).ok==(id==4),"Unowned land cannot be built on")
		if id==4: continue
		check(model.purchase_plot(id),"Purchase any parcel, including across roads, for free")
		check(not model.purchase_plot(id),"Cannot purchase twice")
		model.queue[0]=card
		check(model.drop(at.x,at.y,0,false,0),"New parcel supports construction")
		check(model.has_access(model.rooms.back()),"New plot entrance reaches its sidewalk")
		check(model.route_to_room(model.rooms.size()-1).reachable,"Each new building has its own main entrance")
	check(not model.purchase_plot(-1) and not model.purchase_plot(plots.size()),"Invalid parcel IDs cannot be purchased")
	check(not model.landing(card,0,-3,0,false,0).ok,"Road remains unbuildable after all purchases")
	var loaded=Model.new()
	check(loaded.load_state(JSON.parse_string(JSON.stringify(model.snapshot()))),"Ownership and expanded construction survive save/load")
	check(loaded.owned_plots.size()==9 and loaded.rooms.size()==8,"Save keeps all purchased plots and rooms")
	var first: Vector3i=Model.vec(model.rooms[0].cells[0])
	check(model.relocation_plan(0,first.x+1,first.z,0,0).ok,"Legacy relocation honors ownership")
	check(Editor.plan(model,[0],first+Vector3i.UP,0,true).ok,"Editor copies on purchased land")
	check(model.removal_plan(0).ok,"Removal honors all purchased plots")
	var invalid: Dictionary=model.snapshot(); invalid.owned_plots=[4]
	check(not loaded.load_state(invalid),"Reject saved rooms on unowned plots")
	check(loaded.owned_plots.size()==9,"Invalid loads do not mutate ownership")
	var legacy: Dictionary=original.duplicate(true); legacy.erase("owned_plots")
	check(loaded.load_state(legacy) and loaded.owned_plots==[4],"Existing saves migrate to central ownership")
	model=Model.new(); model.purchase_plot(0); model.undo()
	check(model.snapshot()==original,"Purchase is one complete undo step")
	model.purchase_plot(8); model.reset()
	check(model.owned_plots==[4],"New game resets land")
	var plan:=Neighbourhood.layout(model.config)
	for x in [-2,4]:
		check(not plan.roads.any(func(road):return road.has_point(Vector2(x+0.5,1.5))),"Side roads beside the starting plot are removed")
		check(plan.passages.any(func(path):return path.has_point(Vector2(x+0.5,1.5))),"Removed side roads become pedestrian paving")
	check(plan.roads[0].has_point(Vector2(1,-2)),"Wide main road remains")
	for building in plan.neighbours:
		for cell in building.cells: check(plots[building.plot_id].has_point(Vector2i(cell.x,cell.z)),"Gray neighbor belongs entirely to its purchase footprint")
	print("Block City land: ",failures," failures")
	quit(1 if failures else 0)
