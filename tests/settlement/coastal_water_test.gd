extends SceneTree
const Coast = preload("res://scripts/settlement/coastal_water.gd")
var failures: Array[String]=[]
func check(value: bool,message: String) -> void:
	if not value: failures.append(message); printerr("FAIL: ",message)
func sample(field: Dictionary,point: Vector2) -> Color:
	return field.image.get_pixelv(Vector2i((point-field.bounds.position)/Coast.CELL))
func _initialize() -> void:
	# A U-shaped island, bay open east. Wind travels east from behind its headland.
	var polygon:=PackedVector2Array([Vector2(-10,-12),Vector2(12,-12),Vector2(12,-7),Vector2(-5,-7),Vector2(-5,7),Vector2(12,7),Vector2(12,12),Vector2(-10,12)])
	var rock:=PackedVector2Array([Vector2(16,-1),Vector2(18,-1),Vector2(18,1),Vector2(16,1)])
	var start:=Time.get_ticks_msec()
	var field:=Coast.bake([{"coast":polygon,"shoals":[rock]}],Vector2.RIGHT)
	var bay:=sample(field,Vector2(0,0)); var exposed:=sample(field,Vector2(-14,0))
	check(bay.r>0,"The bay is water, not a convex hull of the coast")
	check(bay.g<exposed.g*0.5,"The bay attenuates incoming wind waves")
	check(sample(field,Vector2(-7,0)).r<0,"Land blocks fetch")
	check(sample(field,Vector2(17,0)).r<0,"Emergent rock is included in contact field")
	check(sample(field,Vector2(19,0)).r<2,"Foam can follow offshore rocks")
	check(sample(field,Vector2(-32,0)).g>0.9,"Open upwind water keeps its wave energy")
	var reversed:=Coast.bake([{"coast":polygon,"shoals":[rock]}],Vector2.LEFT)
	check(sample(reversed,Vector2(-14,0)).g<exposed.g*0.6,"Reversing wind swaps the lee shore")
	var mesh:=Coast.seabed(field)
	for vertex in mesh.get_faces(): check(vertex.y<=-1,"Visual seabed remains below water and walking floors")
	print("Coastal fixture ms=",Time.get_ticks_msec()-start," bay exposure=",bay.g," exposed=",exposed.g)
	start=Time.get_ticks_msec()
	var islands:=preload("res://scripts/settlement/solid_islands.gd").definitions(1409,10)
	var generated:=Coast.bake(islands)
	for island in islands:
		for shoal in island.shoals:
			var centre:=Vector2.ZERO
			for point in shoal: centre+=point
			centre/=shoal.size()
			check(sample(generated,centre).r<0,"Generated rock waterlines reach the shader field")
	print("Generated archipelago bake ms=",Time.get_ticks_msec()-start," resolution=",generated.image.get_size())
	if failures.is_empty(): print("PASS: bay shelter, wind reversal, rock contact and submerged bed")
	quit(int(not failures.is_empty()))
