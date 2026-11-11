extends SceneTree
const Model=preload("res://scripts/settlement/world_model.gd")
const Homes=preload("res://scripts/settlement/home_assembly.gd")
var failures: Array[String]=[]
func check(value: bool,message: String) -> void:
	if not value: failures.append(message); printerr("FAIL: ",message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var world:=Model.new(); world.setup(1409,"easy")
	var view=preload("res://scripts/settlement/world_view.gd").new()
	view.set_meta("detailed",false) # Dummy renderer cannot read back MultiMesh transforms.
	root.add_child(view); view.setup(world)
	var home: Node3D=view.entity_views["building:%s"%world.STARTING_HOUSE]
	var count:=0; var covered:=AABB()
	for mesh: MeshInstance3D in home.find_children("*","MeshInstance3D",true,false):
		if not mesh.is_visible_in_tree() or mesh.mesh==null: continue
		var local:=home.global_transform.affine_inverse()*mesh.global_transform
		var bounds: AABB=local*mesh.mesh.get_aabb()
		if bounds.end.y>0.2 or bounds.size.x<1.8 or bounds.size.z<1.8: continue
		count+=1; covered=bounds if count==1 else covered.merge(bounds)
		check(is_equal_approx(bounds.end.y,Homes.FLOOR_HEIGHT),"Floor meets the existing walking height")
		check(bounds.position.y>=0,"Floor is above opaque natural ground")
	check(count>0 and covered.size.x>1.8 and covered.size.z>1.8,"Visible boards cover the house interior")
	check(is_equal_approx(world.navigation.surface_height(world.STARTING_HOUSE,Vector3(world.STARTING_HOUSE)),world.STARTING_HOUSE.y+covered.end.y),"Citizens stand on the visible floor")
	view.free()
	# Raised houses use the same room floor, without changing their metre address.
	world.buildings[Vector3i(0,2,0)]={"kind":"house","direction":0,"house_tier":1}
	Homes.ensure(world)
	var profile:=Homes.profile(world,Vector3i(0,2,0),[Vector3i(0,2,0)])
	check(profile.floor_height==Homes.FLOOR_HEIGHT,"Upper house keeps the same floor offset")
	if failures.is_empty(): print("PASS: visible house floorboards, full coverage and walking-height alignment")
	quit(int(not failures.is_empty()))
