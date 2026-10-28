extends SceneTree
## --headless for CPU work; omit it and add -- --rendered for actual frame timing.
## Fixed seed, three starting citizens, no user saves.
const Perf = preload("res://scripts/settlement/performance_log.gd")
const Model = preload("res://scripts/settlement/world_model.gd")

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var rendered := OS.get_cmdline_user_args().has("--rendered")
	var game = load("res://scenes/settlement/Terraces.tscn").instantiate()
	game.launch_to_menu = false
	game.slot_directory = "/tmp/pyramida-frame-benchmark"
	root.add_child(game)
	game.set_process(false)
	RenderingServer.viewport_set_measure_render_time(game.viewport.get_viewport_rid(), rendered)
	for landscape in ["easy", "normal"]:
		var model = Model.new()
		model.setup(1409, landscape)
		game.model = model
		game.world.last_revision = -1
		# Stable workload: measure streaming separately, without racing generation.
		model.streaming_enabled = false
		for location in [Vector3.ZERO, Vector3(-18, 0, -12), Vector3(17, 0, 0)]:
			game.rig.focus = location
			game.rig.update_camera()
			model.exploration.reveal(location)
			Perf.enabled = false
			for index in 10:
				game._process(1.0 / 60.0)
				if rendered: await process_frame
			Perf.reset()
			Perf.enabled = true
			var start := Time.get_ticks_usec()
			var measured_frames: Array[float] = []
			for index in 180:
				var frame_start := Time.get_ticks_usec()
				game._process(1.0 / 60.0)
				if rendered: await process_frame
				measured_frames.append((Time.get_ticks_usec() - frame_start) / 1000.0)
			var report := Perf.summary()
			report.erase("frames") # Input delta is fixed; wall_ms measures real elapsed time.
			report.landscape = landscape
			report.location = str(location)
			report.citizens = model.workers.size()
			report.wall_ms = (Time.get_ticks_usec() - start) / 1000.0
			measured_frames.sort()
			report.measured_frames = {"p95_ms": measured_frames[171], "max_ms": measured_frames.back(), "mean_ms": report.wall_ms / 180.0}
			report.rendered = rendered
			report.viewport_gpu_ms = RenderingServer.viewport_get_measured_render_time_gpu(game.viewport.get_viewport_rid())
			report.draw_calls = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
			Perf.enabled = false
			print(JSON.stringify(report))
			if rendered and landscape == "easy" and location == Vector3.ZERO:
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("/tmp/pyramida-performance-grass.png")
	game.chunk_loader.finish()
	quit()
