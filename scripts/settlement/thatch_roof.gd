extends RefCounted
## Closed straw bed with broad, uneven overlapping sheaves, not a grid of tiles.
const Kit=preload("res://scripts/settlement/roof_kit.gd")
const Cuts=preload("res://scripts/settlement/walkable_planks.gd")
const Palette=preload("res://scripts/game_palette.gd")
static var meshes: Dictionary={}
static var material: StandardMaterial3D
static func vertex(x: float,y: float,z: float,base: float,slope: float,center: float) -> Vector3:
	return Vector3(x,base+slope*(x-center)+y,z)
static func mesh(rect: Rect2,base: float,slope: float,seed_: int,hole:=Rect2()) -> ArrayMesh:
	var key:=str([rect,base,slope,seed_,hole])
	if meshes.has(key): return meshes[key]
	var st:=SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var center:=rect.get_center().x
	# The bed closes every gap between bundles and is cut around the real flue.
	for piece in Cuts.subtract(rect,hole):
		var lower: Array=[]; var upper: Array=[]
		for p in [piece.position,Vector2(piece.end.x,piece.position.y),piece.end,Vector2(piece.position.x,piece.end.y)]:
			lower.append(vertex(p.x,-0.045,p.y,base,slope,center)); upper.append(vertex(p.x,0,p.y,base,slope,center))
		var inside: Vector3=(lower[0]+upper[2])/2
		Kit.polygon(st,upper,inside); Kit.polygon(st,lower,inside)
		for i in 4: Kit.polygon(st,[lower[i],lower[(i+1)%4],upper[(i+1)%4],upper[i]],inside)
	var rng:=RandomNumberGenerator.new(); rng.seed=hash([seed_,"thatch-v2"])
	var columns:=maxi(1,ceili(rect.size.y/0.20)); var rows:=maxi(1,ceili(rect.size.x/0.65))
	for column in columns:
		var z:=lerpf(rect.position.y+0.08,rect.end.y-0.08,float(column)/maxi(1,columns-1))
		for row in rows:
			var x:=lerpf(rect.position.x+0.32,rect.end.x-0.32,float(row)/maxi(1,rows-1))+rng.randf_range(-0.08,0.08)
			var left:=maxf(rect.position.x-rng.randf_range(0.01,0.065),x-rng.randf_range(0.46,0.62))
			var right:=minf(rect.end.x+rng.randf_range(0.01,0.065),x+rng.randf_range(0.46,0.62))
			var width:=rng.randf_range(0.105,0.14)
			var bounds:=Rect2(left,z-width,right-left,width*2)
			if hole.has_area() and bounds.intersects(hole.grow(0.015)): continue
			var lift:=rng.randf_range(0.015,0.055)
			var crest:=rng.randf_range(0.09,0.18)
			var rings: Array=[]
			for station in 3:
				var along:=lerpf(left,right,float(station)/2)
				var w:=width*rng.randf_range(0.78,1.0)
				var y:=lift+(0.025 if station==1 else 0.0)
				var peak:=crest*(1.0 if station==1 else rng.randf_range(0.35,0.70))
				rings.append([vertex(along,y-0.04,z-w,base,slope,center),vertex(along,y-0.04,z+w,base,slope,center),vertex(along,y,z+w,base,slope,center),vertex(along,y+peak,z+rng.randf_range(-0.03,0.03),base,slope,center),vertex(along,y,z-w,base,slope,center)])
			var inside:=vertex(x,lift+0.025,z,base,slope,center)
			Kit.polygon(st,rings[0],inside); Kit.polygon(st,rings[2],inside)
			for station in 2:
				for i in 5: Kit.polygon(st,[rings[station][i],rings[station][(i+1)%5],rings[station+1][(i+1)%5],rings[station+1][i]],inside)
	if material==null:
		material=StandardMaterial3D.new(); material.albedo_color=Palette.HAY_FIELD
		material.vertex_color_use_as_albedo=true; material.roughness=1.0
	st.set_material(material)
	var result:=st.commit()
	if meshes.size()>=64: meshes.clear()
	meshes[key]=result
	return result
static func build(root: Node3D,rect: Rect2,base: float,slope: float,seed_: int,hole:=Rect2()) -> void:
	var node:=MeshInstance3D.new(); node.name="UnevenThatch"
	node.mesh=mesh(rect,base,slope,seed_,hole); node.set_meta("shaped_surface",true)
	node.set_meta("source_component","ThatchSheaf"); root.add_child(node)
