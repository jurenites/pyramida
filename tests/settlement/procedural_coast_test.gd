extends SceneTree
const Islands=preload("res://scripts/settlement/solid_islands.gd")
const Shape=preload("res://scripts/settlement/island_shape_generator.gd")
const VERSION=preload("res://scripts/settlement/world_generator.gd").VERSION
var failures: Array[String]=[]
func check(ok: bool,message: String) -> void:
	if not ok: failures.append(message); printerr("FAIL: ",message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var footprints: Array=[]; var headings: Array=[]; var heights: Dictionary={}
	for seed_value in [1409,42,9182,101,627861481,0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26]:
		var main:=Islands.definitions(seed_value,VERSION)[0]
		var definitions:=Islands.definitions(seed_value,VERSION)
		if VERSION>=21: check(main.ledge_count>=2,"Rocky slopes include small embedded ledges across seeds")
		if VERSION>=20:
			check(not main.shoulders.is_empty(),"A broad rock shoulder replaces the peak props")
			var rocky_slope_area:=0.0
			for item in main.parts:
				if item.get("decorative",false): continue
				check(item.bounds.position.y<=-4.0,"Mountains continue into the cliff foot instead of sitting on top as fins")
				var faces: PackedVector3Array=item.faces
				for i in range(0,faces.size(),3):
					var cross: Vector3=(faces[i+2]-faces[i]).cross(faces[i+1]-faces[i])
					var normal:=cross.normalized()
					if normal.y>0.65 and normal.y<0.99 and (faces[i].y+faces[i+1].y+faces[i+2].y)/3.0>3.9: rocky_slope_area+=cross.length()*0.5
			check(rocky_slope_area>40,"The mountain includes substantial sloping rock, not just flat steps")
			for shoulder in main.shoulders:
				var crown:=PackedVector2Array()
				for p: Vector3 in shoulder.crown: crown.append(Vector2(p.x,p.z))
				check(Shape.polygon_area(crown)>Shape.polygon_area(shoulder.foot)*0.25,"Mountain crowns stay broad instead of narrowing to blades")
		for a in definitions.size():
			for b in range(a+1,definitions.size()): check(Geometry2D.intersect_polygons(definitions[a].coast,definitions[b].coast).is_empty(),"Independently generated islands stay separate")
			if a > 0:
				var island: Dictionary=definitions[a]
				# Coast boulders retain their own eroded shape. Inspect terrace solids.
				for i in range(island.parts.size()-island.shoals.size()) if VERSION<19 else range(island.parts.size()):
					if island.parts[i].get("decorative",false): continue
					var faces: PackedVector3Array=island.parts[i].faces
					var edges: Dictionary={}
					for f in range(0,faces.size(),3):
						var p:=faces[f]; var q:=faces[f+1]; var r:=faces[f+2]
						if maxf(p.y,maxf(q.y,r.y))>maxf(0,island.parts[i].bounds.position.y+0.001):
							check((r-p).cross(q-p).normalized().y>=-0.001,"Small-island shelves do not grow overhanging caps")
							if VERSION>=17 and maxf(p.y,maxf(q.y,r.y))-minf(p.y,minf(q.y,r.y))>0.1:
								check((r-p).cross(q-p).normalized().y>0.001,"Small-island cliff faces lean")
						for j in 3:
							p=faces[f+j].snapped(Vector3.ONE*0.0001); q=faces[f+(j+1)%3].snapped(Vector3.ONE*0.0001)
							var key: Array=[p,q] if p<q else [q,p]
							edges[key]=int(edges.get(key,0))+1
					check(edges.values().all(func(value): return value==2),"Small-island tapered solids remain closed")
		for at in [Vector3(-6,0.5,2),Vector3(-8,0.5,-4),Vector3(6,0.5,-4),Vector3(8,0.5,4),Vector3(-4,0.5,4),Vector3(-2,0.5,4),Vector3(0,0.5,4)]:
			check(not Islands.native_solid(seed_value,at,VERSION) and Islands.native_solid(seed_value,at-Vector3.UP*0.6,VERSION),"Initial village and timber have safe ground seed %d"%seed_value)
		var repeat:=Islands.make_islands(seed_value,VERSION)[0]
		var cliff:=0.0; var perimeter:=0.0
		for i in main.parts.size():
			check(main.parts[i].faces==repeat.parts[i].faces,"Same seed preserves exact geometry")
			var edges: Dictionary={}; var faces: PackedVector3Array=main.parts[i].faces
			for f in range(0,faces.size(),3):
				for j in 3:
					var a:=faces[f+j].snapped(Vector3.ONE*0.0001); var b:=faces[f+(j+1)%3].snapped(Vector3.ONE*0.0001)
					var key: Array=[a,b] if a<b else [b,a]
					edges[key]=int(edges.get(key,0))+1
			check(edges.values().all(func(value): return value==2),"Closed solid seed %d part %d"%[seed_value,i])
			if i > 0 and i <= main.shelves.size():
				for f in range(0,faces.size(),3):
					var a:=faces[f]; var b:=faces[f+1]; var c:=faces[f+2]
					if maxf(a.y,maxf(b.y,c.y)) <= 0: continue
					check((c-a).cross(b-a).normalized().y>=-0.001,"Terrace walls taper inward without overhanging caps seed %d"%seed_value)
					if VERSION>=17 and maxf(a.y,maxf(b.y,c.y))-minf(a.y,minf(b.y,c.y))>0.1:
						check((c-a).cross(b-a).normalized().y>0.001,"Cliff faces lean instead of forming vertical walls seed %d"%seed_value)
		for i in main.coast.size():
			var a: Vector2=main.coast[i]; var b: Vector2=main.coast[(i+1)%main.coast.size()]
			var inward:=Vector2(-(b-a).y,(b-a).x).normalized()
			var p: Vector2=(a+b)*0.5+inward*0.04
			var length: float=a.distance_to(b); perimeter+=length
			var tall:=false
			for step in [0.0,0.25,0.5,1.0,1.5]:
				var sample_point: Vector2=p+inward*step
				if Islands.native_solid(seed_value,Vector3(sample_point.x,3.9,sample_point.y),VERSION) and Islands.native_solid(seed_value,Vector3(sample_point.x,-0.5,sample_point.y),VERSION): tall=true
			if tall: cliff+=length
		check(cliff/perimeter>0.28,"Substantial uninterrupted sea cliff seed %d ratio %.2f"%[seed_value,cliff/perimeter])
		check(cliff/perimeter<0.80,"Sheltered low shore remains seed %d"%seed_value)
		var fill:=Shape.polygon_area(main.coast)/Shape.polygon_area(Geometry2D.convex_hull(main.coast))
		check(fill>0.68,"Island remains a connected broad landmass")
		var occupied: Dictionary={}
		for x in range(-44,36,2):
			for z in range(-40,40,2):
				if Geometry2D.is_point_in_polygon(Vector2(x,z),main.coast): occupied[Vector2i(x,z)]=true
		footprints.append(occupied); headings.append(main.cliff_heading); heights[main.crest_height]=true
		print("Seed ",seed_value," coast cliff fraction=",snappedf(cliff/perimeter,0.01)," ridge=",snappedf(main.cliff_heading,0.01)," height=",main.crest_height," area=",Shape.polygon_area(main.coast))
	var difference:=0.0; var pairs:=0
	for a in footprints.size():
		for b in range(a+1,footprints.size()):
			var union: Dictionary=footprints[a].duplicate(); union.merge(footprints[b]); var common:=0
			for point in footprints[a]:
				if footprints[b].has(point): common+=1
			difference+=1.0-float(common)/union.size(); pairs+=1
	check(difference/pairs>0.18,"Seeds change the silhouette substantially, not just small edge noise")
	check(headings.max()-headings.min()>1.2 and heights.size()==3,"Cliff orientation and plateau levels genuinely vary")
	print("Mean silhouette difference=",difference/pairs)
	if failures.is_empty(): print("PASS: distinct seeded coastlines, tall sea cliffs, closed solids and determinism")
	quit(int(not failures.is_empty()))
