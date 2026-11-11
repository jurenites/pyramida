extends SceneTree
const Model = preload("res://scripts/settlement/world_model.gd")
const View = preload("res://scripts/settlement/world_view.gd")
const Inventory = preload("res://scripts/settlement/inventory.gd")
const Labour = preload("res://scripts/applied_labour.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.min_size = Vector2i(900, 600)
	root.size = Vector2i(900, 600)
	var model = Model.new()
	model.setup()
	model.streaming_enabled = false
	model.soil_enabled = false
	for collection in [model.ground, model.terrain_heights, model.terrain_shapes, model.terrain_ramps, model.loaded_chunks, model.chunk_details, model.trees, model.deposits, model.gardens, model.soil_beds, model.water_sources, model.plans, model.buildings, model.stores]: collection.clear()
	for x in range(-9, 10):
		for z in range(-7, 8): model.ground[Vector3i(x, 0, z)] = true
	var tree_cell := Vector3i(-2, 0, 0)
	var store_cell := Vector3i(1, 0, 0)
	var build_cell := Vector3i(4, 0, 0)
	model.buildings[store_cell] = {"kind": "log_shed", "direction": 0}
	model.add_store(store_cell, {"log": 2})
	var inventory := Inventory.new()
	inventory.store("log", 3)
	model.trees[tree_cell] = {"inventory": inventory, "kind": "living", "appearance_seed": 517, "regrowth": 0.0}
	model.workers.resize(1)
	var worker: Dictionary = model.workers[0]
	worker.cell = Vector3i(-2, 0, 1)
	worker.position = Vector3(-2, 0, 1)
	worker.life_stage = "adult"
	worker.job = {}
	worker.role = "idle"
	worker.status = "cutting timber"
	model.rebuild_navigation()
	assert(model.navigation.at_access(Vector3i(1, 0, 2), store_cell))
	var view := View.new()
	root.add_child(view)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 10.5
	camera.position = Vector3(7, 6, 12)
	root.add_child(camera)
	camera.look_at(Vector3(0.9, 0.9, 0.4))
	assert(model.request_build("log_shed", build_cell))
	var plan: Dictionary = model.plans.values()[0]
	view.setup(model)
	for chunk in view.scenery.chunks.values(): chunk.get_node("Grass").hide()
	root.msaa_3d = Viewport.MSAA_4X
	var directory := "/tmp/pyramida-timber-construction-frames"
	DirAccess.make_dir_recursive_absolute(directory)
	for initial in 5: await process_frame
	for frame in 220:
		if frame == 12:
			inventory.reserve(0, "log")
			worker.job = {"kind": "fell", "phase": "collect", "target": tree_cell, "source": inventory, "labour": Labour.new(0.01)}
			model.tick_citizen_job(worker, 0.1)
			worker.status = "carrying to storage"
		if frame >= 32 and frame <= 66:
			worker.position = Vector3(-2, 0, 1).lerp(Vector3(1, 0, 2), (frame - 32) / 34.0)
		if frame == 70:
			worker.cell = Vector3i(1, 0, 2)
			worker.position = model.Navigation.point(worker.cell)
			model.tick_citizen_job(worker, 0.1)
			worker.status = "idle"
		if frame == 104:
			model.stores[store_cell].reserve(0, "log")
			preload("res://scripts/settlement/job_system.gd").claim_material(plan, "log", 1)
			worker.route = []; worker.route_index = 0
			worker.job = {"kind": "build", "phase": "pickup", "source": model.stores[store_cell], "target": store_cell, "plan_id": plan.id, "labour": Labour.new(0.01)}
			model.tick_citizen_job(worker, 0.1)
			worker.status = "carrying timber"
		if frame >= 125 and frame <= 171:
			worker.position = Vector3(1, 0, 2).lerp(Vector3(4, 0, 2), (frame - 125) / 46.0)
		if frame == 176:
			worker.cell = Vector3i(4, 0, 2)
			worker.position = model.Navigation.point(worker.cell)
			worker.route = []; worker.route_index = 0
			worker.job.phase = "work"
			worker.job.target = build_cell
			model.tick_citizen_job(worker, 0.1)
		view.sync(model, 0.05, -1)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(directory + "/%03d.png" % frame)
	print("PASS: captured actual tree-to-hands-to-pile-to-frame object transfer")
	quit()
