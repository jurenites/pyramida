extends SceneTree
const Model=preload("res://scripts/block_city/model.gd")
const Land=preload("res://scripts/block_city/land.gd")
const Neighborhood=preload("res://scripts/block_city/neighbourhood.gd")
var failures:=0
func check(ok: bool,message: String):
	if not ok: failures+=1; push_error(message)
func _initialize(): call_deferred("run")
func run():
	var model=Model.new()
	var plans:=Land.plots(model.config); var area:=Land.bounds(model.config)
	check(area==Rect2i(-7,-9,17,19),"Outer road ring removed by one tile on each edge")
	var plan:=Neighborhood.layout(model.config)
	for road in plan.roads:
		check(Rect2(area).encloses(road),"Every retained road is inside the smaller city block")
		check(road!=Rect2(area.position.x,area.position.y,area.size.x,1),"No front perimeter road")
	for path in plan.passages:
		var center: Vector2=path.get_center()
		check(Land.at(model.config,center,model.owned_plots)>=0,"Every unowned sidewalk tile has a 3×3 purchase option")
	for id in range(9,plans.size()):
		check(plans[id].size==Vector2i(3,3) and area.encloses(plans[id]),"Paving purchase is a full in-bounds 3×3 section")
		check(not Land.roads(model.config).any(func(road):return road.intersects(plans[id])),"Paving purchases never consume retained roads")
	var id:=Land.at(model.config,Vector2(3.5,1.5),model.owned_plots)
	check(id>=9 and model.purchase_plot(id),"Purchase sidewalk beside the starting plot")
	check(model.owns_cell(Vector3i(3,0,1)),"Purchased sidewalk becomes buildable")
	model.queue[0]={"shape":"cube","color":0}
	check(model.drop(3,1,0,false,0),"Room places on former pavement")
	var loaded=Model.new()
	check(loaded.load_state(JSON.parse_string(JSON.stringify(model.snapshot()))) and loaded.owns_cell(Vector3i(3,0,1)),"New ownership IDs and infill construction survive save/load")
	model.undo(); model.undo()
	check(not model.owns_cell(Vector3i(3,0,1)),"Undo construction and purchase restores public pavement")
	check(Land.at(model.config,Vector2(20,20),model.owned_plots)==-1,"Space beyond the floating ground cannot be purchased")
	var game=load("res://scripts/block_city/game.gd").new()
	game.auto_save=false; game.restore_last=false; root.add_child(game)
	check(game.geometry.has_node("Neighbourhood/GroundSection/MetroCutaway/MetroCar"),"Floating ground has a visible metro cutaway")
	check(game.geometry.get_node("Neighbourhood/GroundSection").find_children("FoundationPile*","MeshInstance3D",true,false).size()>0,"Cutaway exposes foundation piles")
	for mesh in game.geometry.get_node("Neighbourhood/GroundSection").find_children("*","MeshInstance3D",true,false):
		if mesh.mesh is BoxMesh: check(mesh.mesh.size.x<=area.size.x+0.1 and mesh.mesh.size.z<=area.size.y+0.1,"No infinite ground plane remains")
	print("Block City floating land: ",failures," failures")
	game.free(); quit(1 if failures else 0)
