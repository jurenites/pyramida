extends RefCounted
## Hover uses the completed assembly renderer on a private prospective world.
static func sync(node: Node3D,world,cell: Vector3i,direction: int,offset: Vector3,tier:=1) -> bool:
	var signature:=hash([world.world_seed,cell,direction,offset,tier,world.buildings,world.plans,world.platforms,world.stairs,world.bridges])
	if node.get_meta("home_preview_signature",-1)==signature: return false
	var preview_world=load("res://scripts/settlement/world_model.gd").new()
	for field in ["world_seed","generator_version","difficulty","terrain_revision","soil_enabled"]: preview_world.set(field,world.get(field))
	for field in ["buildings","plans","platforms","stairs","bridges","home_utilities","volume_edits","terrain_excavations"]: preview_world.set(field,world.get(field).duplicate(true))
	for field in ["ground","terrain_shapes"]: preview_world.set(field,world.get(field))
	var data: Dictionary=preview_world.buildings.get(cell,{}).duplicate(true)
	data.merge({"kind":"house","direction":direction,"placement_offset":offset,"house_tier":tier},true)
	preview_world.buildings[cell]=data
	node.set_meta("cell",cell); node.set_meta("asset","house")
	load("res://scripts/settlement/building_assembly.gd").sync(preview_world,{"hover":node})
	node.set_meta("home_preview_signature",signature)
	node.set_meta("support_preview",load("res://scripts/settlement/home_stack.gd").plan(preview_world,cell,offset))
	return true
