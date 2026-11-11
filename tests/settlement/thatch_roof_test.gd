extends SceneTree
const Thatch=preload("res://scripts/settlement/thatch_roof.gd")
var failures:=0
func check(ok: bool,message: String) -> void:
	if not ok: failures+=1; printerr("FAIL: "+message)
func _initialize() -> void:
	var hole:=Rect2(0.97,-0.03,0.76,0.76)
	for seed_ in [0,42,1409]:
		for slope in [-0.2,0.04,0.18]:
			var rect:=Rect2(-0.15,-0.15,2.3,2.3)
			var mesh:=Thatch.mesh(rect,2.16,slope,seed_,hole)
			check(mesh==Thatch.mesh(rect,2.16,slope,seed_,hole),"Stable thatch reuses its cached mesh")
			var vertices: PackedVector3Array=mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			var high:=-INF; var low:=INF
			for v in vertices:
				var relief: float=v.y-2.16-slope*(v.x-1)
				high=maxf(high,relief); low=minf(low,relief)
			check(high-low>0.15,"Roof has visible raised bundles above its closed straw bed")
			var opening:=PackedVector2Array([hole.position,Vector2(hole.end.x,hole.position.y),hole.end,Vector2(hole.position.x,hole.end.y)])
			for i in range(0,vertices.size(),3):
				var triangle:=PackedVector2Array()
				for j in 3: triangle.append(Vector2(vertices[i+j].x,vertices[i+j].z))
				if absf((triangle[1]-triangle[0]).cross(triangle[2]-triangle[0]))<0.000001: continue
				for clipped in Geometry2D.intersect_polygons(triangle,opening):
					var area:=0.0
					for j in clipped.size(): area+=clipped[j].cross(clipped[(j+1)%clipped.size()])
					check(absf(area)<0.00001,"Thatched roof leaves the chimney aperture clear")
	print("PASS: seeded thatch relief, mesh caching and clear chimney openings" if failures==0 else "FAIL: thatch geometry")
	quit(int(failures>0))
