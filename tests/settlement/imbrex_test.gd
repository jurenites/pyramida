extends SceneTree
const Fixture = preload("res://tests/settlement/reviewed_balance_test.gd")
const Tiers = preload("res://scripts/settlement/house_tiers.gd")
const Assets = preload("res://scripts/settlement/asset_library.gd")
const Roof = preload("res://scripts/settlement/house_roofs.gd")
const Boards = preload("res://scripts/settlement/roof_boards.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var fixture := Fixture.new(); var model = fixture.fixture()
	fixture.finish(model, "house", Vector3i.ZERO)
	model.buildings[Vector3i.ZERO].house_tier = 2; model.rebuild_navigation()
	fixture.finish(model, "tilery", Vector3i(5,0,0))
	fixture.finish(model, "log_shed", Vector3i(-4,0,0))
	model.stores[Vector3i(5,0,0)].store("clay",4)
	model.stores[Vector3i(-4,0,0)].store("plank",2)
	assert(model.request_build("house",Vector3i.ZERO))
	assert(model.plans.values()[0].materials == {"plank":2,"imbrex":4})
	model.workers[0].cell = Vector3i(0,0,2); model.workers[0].position = Vector3(0,0,2)
	assert(model.order_workplace(0,Vector3i(5,0,0)))
	assert(model.workers[0].role == "tiler")
	fixture.step(model,1800)
	assert(model.resource_total("clay") == 0, "Four clay inputs fired")
	model.set_role(0,"builder")
	for step in 2500:
		fixture.step(model)
		if Tiers.tier(model.buildings[Vector3i.ZERO]) == 3: break
	assert(Tiers.tier(model.buildings[Vector3i.ZERO]) == 3, "Worker-made Imbrex installs into Tier 3")
	fixture.save_roundtrip(model)
	var cargo := Assets.create("imbrex")
	assert(cargo.get_node("Imbrex").mesh.get_aabb().size.y > 0.10, "Cargo is curved physical stock")
	cargo.free()
	# Sampling both roof coverings across a T junction catches holes at valleys.
	var tiles := {}; var rooms: Array = []
	for at: Vector2 in [Vector2.ZERO, Vector2(2,0), Vector2(0,2)]:
		rooms.append({"at":at,"axis":0 if at.x == 2 else 1})
		for x in 2:
			for z in 2: tiles[Vector2i(at)+Vector2i(x-1,z-1)] = true
	var shape := Roof.profile(tiles,rooms)
	for kind in ["hay","imbrex"]:
		var triangles := PackedVector3Array()
		for tile: Vector2i in tiles:
			var mesh_ := Boards.mesh(Roof.tile_mesh(tile,shape),tile,shape,17,kind)
			var second := Boards.mesh(Roof.tile_mesh(tile,shape),tile,shape,17,kind)
			assert(mesh_.get_faces() == second.get_faces(), "Stable seeded covering")
			triangles.append_array(mesh_.get_faces())
			var caps := Node3D.new()
			for segment: Array in Roof.ridge_segments(tile,shape):
				preload("res://scripts/settlement/roof_covering.gd").ridge(caps,segment[0],segment[1],Roof.EAVE+1,kind,null)
			for cap: MeshInstance3D in caps.get_children():
				for vertex: Vector3 in cap.mesh.get_faces(): triangles.append(cap.transform * vertex)
			caps.free()
		for tile: Vector2i in tiles:
			for offset: Vector2 in [Vector2(.17,.19),Vector2(.5,.5),Vector2(.82,.81)]:
				var at := Vector2(tile)+offset; var covered := false
				for i in range(0,triangles.size(),3):
					if Geometry3D.ray_intersects_triangle(Vector3(at.x+0.00001,5,at.y-0.00001),Vector3.DOWN,triangles[i],triangles[i+1],triangles[i+2]) != null: covered = true; break
				assert(covered,"%s junction hole at %s" % [kind,at])
	assert(fixture.failures.is_empty()); fixture.free()
	print("PASS: assigned Tilery production, Imbrex delivery/upgrade/save, physical cargo and seeded T-junction coverage")
	quit()
