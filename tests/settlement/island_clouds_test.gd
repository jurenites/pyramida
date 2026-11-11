extends SceneTree
const Model = preload("res://scripts/settlement/world_model.gd")
const Fog = preload("res://scripts/settlement/fog_view.gd")
var failures: Array[String] = []
var checks := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message); printerr("FAIL: ",message)
func interior(coast: PackedVector2Array) -> Vector2:
	var triangles := Geometry2D.triangulate_polygon(coast)
	return (coast[triangles[0]]+coast[triangles[1]]+coast[triangles[2]])/3.0
func run() -> void:
	var world := Model.new(); world.setup(1409,"easy")
	check(world.exploration.islands.size() >= 2,"Island discovery uses actual generated coastlines")
	var occupied := -1
	var start: Vector3 = world.workers[0].position
	for index in world.exploration.islands.size():
		if Geometry2D.is_point_in_polygon(Vector2(start.x,start.z),world.exploration.islands[index]): occupied = index
	check(occupied >= 0,"Starting citizen occupies an island")
	for vertex in world.exploration.islands[occupied]:
		check(world.exploration.contains(Vector3(vertex.x,0,vertex.y)),"The whole occupied coastline is revealed")
	var other := 1 if occupied == 0 else 0
	var landing := interior(world.exploration.islands[other])
	check(not world.exploration.contains(Vector3(landing.x,0,landing.y)),"Unvisited island stays undiscovered")
	var revision: int = world.exploration.revision
	world.exploration.update(world.workers)
	check(world.exploration.revision == revision,"Stationary citizens do not repaint an island")
	world.exploration.reveal(Vector3(landing.x,0,landing.y))
	for vertex in world.exploration.islands[other]:
		check(world.exploration.contains(Vector3(vertex.x,0,vertex.y)),"One landing reveals the complete next island")
	var restored := Model.new()
	check(restored.restore(JSON.parse_string(JSON.stringify(world.snapshot()))),"Island discovery survives JSON save/load")
	check(restored.exploration.cells == world.exploration.cells,"Saved discovery footprint is preserved exactly")
	var shape_bounds := []
	for kind in 4:
		var mesh = Fog.Shape.mesh(kind)
		check(mesh == Fog.Shape.mesh(kind),"Merged cloud geometry is cached and shared")
		shape_bounds.append(mesh.get_aabb())
		var arrays: Array = mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		check(vertices.size() > 500,"Cloud outlines have enough geometry to remain smooth")
		var smooth_faces := 0
		for face in range(0,indices.size(),3):
			var a := indices[face]; var b := indices[face+1]; var c := indices[face+2]
			if not normals[a].is_equal_approx(normals[b]): smooth_faces += 1
			check((vertices[b]-vertices[a]).cross(vertices[c]-vertices[a]).dot(normals[a]+normals[b]+normals[c]) <= 0.000001,"Merged cloud surface faces outwards")
		check(smooth_faces > indices.size()/6,"Surface normals blend across the merged lobes")
	check(shape_bounds[0] != shape_bounds[1] and shape_bounds[1] != shape_bounds[2],"Cloud families have different irregular silhouettes")
	var viewport := SubViewport.new(); viewport.size = Vector2i(800,600); root.add_child(viewport)
	var camera := Camera3D.new(); camera.projection = Camera3D.PROJECTION_ORTHOGONAL; camera.size = 80
	viewport.add_child(camera); camera.position = Vector3(0,60,60); camera.look_at(Vector3.ZERO)
	var fog := Fog.new(); camera.add_child(fog); fog.sync(world,true)
	var smallest := INF; var largest := 0.0
	var fringe := 0; var opaque := 0
	var groups := {}
	for sphere in fog.spheres:
		smallest = minf(smallest,sphere.radius.x)
		largest = maxf(largest,sphere.radius.x)
		var group := Vector2i(sphere.key.x,sphere.key.y)
		groups[group] = int(groups.get(group,0)) + 1
		if sphere.target > 0 and sphere.opacity < 0.8: fringe += 1
		if sphere.target > 0 and sphere.opacity > 0.99: opaque += 1
	check(largest > smallest * 5.0,"Cloud groups mix large bodies with much smaller puffs")
	check(groups.values().max() > groups.values().min(),"Cloud groups have different numbers of lobes")
	check(fringe > 0 and opaque > 0,"The transparent fringe leads into opaque distant clouds")
	var discovery_before: Dictionary = world.exploration.cells.duplicate()
	var states := {}
	for sphere in fog.spheres: states[sphere.key] = [sphere.at,sphere.radius,sphere.remaining]
	camera.position.x += 35; fog.sync(world,true)
	camera.position.x -= 35; fog.sync(world,true)
	for sphere in fog.spheres:
		check(states[sphere.key][0] == sphere.at and states[sphere.key][1] == sphere.radius,"Camera streaming preserves cloud shape and position")
	check(fog.global_transform == Transform3D.IDENTITY,"Clouds stay in world space when their owning camera moves")
	check(world.exploration.cells == discovery_before,"Cloud clearance and camera movement never reveal additional resources")
	fog.sync(world,false); check(not fog.visible,"Menu previews hide cloud cover")
	viewport.free()
	var rig = preload("res://scripts/settlement/camera_rig.gd").new()
	root.add_child(rig); rig.setup(); rig.zoom = 110; rig.pitch = 0.4; rig.update_camera()
	var screen := Vector2(root.size)
	for corner in [Vector2.ZERO,Vector2(screen.x,0),screen,Vector2(0,screen.y)]:
		check(rig.camera.project_ray_origin(corner).y > 24,"Wide low-angle camera keeps its near plane above cloud geometry")
	rig.free()
	if failures.is_empty(): print("PASS: %d island discovery, save, sphere geometry and cloud streaming checks" % checks)
	quit(int(not failures.is_empty()))
