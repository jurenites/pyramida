extends Node3D
const Shell=preload("res://scripts/block_city/room_view.gd")
const Palette=preload("res://scripts/game_palette.gd")
const Illustration=preload("res://scripts/settlement/illustration_style.gd")
const Rooms=preload("res://scripts/settlement/room_construction.gd")
const ACCESS=Palette.GRASS
const INK=Palette.HOME_DOORWAY
var model
var town
var ghost: Node3D
var view_mode:=1
func entry_color(reached: bool) -> Color: return ACCESS if reached else Palette.PEACH_SHADOW
func material(color: Color,transparent:=false) -> StandardMaterial3D:
	var result:=StandardMaterial3D.new()
	if color==Rooms.Layout.CONCRETE_COLUMN: color=Palette.HOME_DOORWAY
	elif color==Rooms.Layout.CONCRETE_FLOOR: color=Palette.LIMESTONE_SIDE
	elif color==Rooms.Layout.CONCRETE_WALL: color=Palette.SAND_SURFACE
	result.albedo_color=color; result.roughness=0.95
	if Illustration.enabled: result.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	if transparent:
		result.albedo_color.a=1.0
		result.no_depth_test=false
	return result
func box(parent: Node3D,at: Vector3,size: Vector3,color: Color,transparent:=false) -> MeshInstance3D:
	var node:=MeshInstance3D.new(); var mesh:=BoxMesh.new(); mesh.size=size
	node.mesh=mesh; node.position=at; node.material_override=material(color,transparent)
	parent.add_child(node); return node
func draw_room(room: Dictionary,network: Array,future:=false) -> Node3D:
	var node: Node3D
	if room.has("generated") and room.shape != "stairs":
		node=preload("res://scripts/settlement/generated_building_view.gd").draw(self,room,model,network,town)
	else:
		node=Node3D.new(); add_child(node); Shell.draw(self,node,room,view_mode,{},false,network)
		if room.has("generated") and room.shape == "stairs": preload("res://scripts/settlement/generated_building_view.gd").stair_supports(node,room)
	node.name="Room%d" % int(room.id)
	for brace in room.braces:
		var cell:=Vector3(Rooms.Layout.vec(brace[0])); var anchor:=Vector3(Rooms.Layout.vec(brace[1]))
		var toward:=Vector3(anchor.x-cell.x,0,anchor.z-cell.z).normalized()
		var side:=Vector3(-toward.z,0,toward.x)
		for offset in [-0.34,0.34]:
			var a: Vector3=cell+Vector3(0.5,-0.035,0.5)-toward*0.37+side*offset
			var b: Vector3=anchor+Vector3(0.5,0.22,0.5)-toward*0.48+side*offset
			var beam:=box(node,(a+b)/2,Vector3(0.05,a.distance_to(b),0.05),Rooms.Layout.CONCRETE_COLUMN)
			beam.quaternion=Quaternion(Vector3.UP,(b-a).normalized())
	if future:
		for batch in node.find_children("*","MultiMeshInstance3D",true,false): batch.transparency=0.0
		for mesh in node.find_children("*","MeshInstance3D",true,false):
			mesh.transparency=0.0; mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node
func bed(world,entry: Dictionary,future:=false,parent: Node3D=null) -> void:
	var base:=Vector3(Rooms.Layout.vec(entry.cell))
	var access:=Rooms.bed_access(world,entry)
	var right:=access.x==Rooms.base(world,Rooms.Layout.vec(entry.cell)).x
	var center:=base+Vector3(0.75 if right else 0.25,0.16,0.5)
	var node:=Node3D.new(); (self if parent==null else parent).add_child(node)
	box(node,center,Vector3(0.42,0.16,0.85),Palette.TIMBER_SIDE)
	box(node,center+Vector3(0,0.105,0),Vector3(0.40,0.09,0.81),Palette.PEACH_SHADOW)
	box(node,center+Vector3(0,0.16,-0.27),Vector3(0.34,0.06,0.19),Palette.SAND_SURFACE)
	box(node,center+Vector3(0,0.16,0.11),Vector3(0.40,0.04,0.55),Palette.WATER_BLUE)
	if future:
		for mesh in node.get_children():
			mesh.transparency=0.0
			if parent==ghost: mesh.material_override.no_depth_test=false
func rebuild(world,mode:=1,level:=100) -> void:
	town=world
	if has_meta("exemplar_detail"): remove_meta("exemplar_detail")
	for child in get_children(): child.free()
	view_mode=mode; ghost=null
	if world.room_site.is_empty(): return
	position=Vector3(world.room_site.origin)-Vector3(0.5,0,0.5); scale=Vector3.ONE*2
	model=Rooms.layout(world,true)
	for room in model.rooms:
		var node:=draw_room(room,model.rooms)
		if room.cells.all(func(raw):return int(raw[1])>level):
			node.hide()
	var design=Rooms.layout(world)
	model=design
	for room in design.rooms:
		if not Rooms.constructed(world,room): draw_room(room,design.rooms,true)
	for entry in world.room_site.beds: bed(world,entry)
	for plan in world.plans.values():
		if plan.kind=="room_bed": bed(world,{"cell":plan.bed_cell},true)
	ghost=Node3D.new(); ghost.name="HeldRoom"; add_child(ghost)
	preload("res://scripts/settlement/material_exemplars.gd").consolidate(self)
