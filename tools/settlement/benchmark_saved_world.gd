extends SceneTree
## Read-only replay: -- --save=/absolute/slot.json [--rendered] [--measure-save] [--construction] [--motion] [--streaming]
## Stable saved terrain; streaming and automatic writes to player slots are disabled.
const Perf = preload("res://scripts/settlement/performance_log.gd")
const Model = preload("res://scripts/settlement/world_model.gd")
const FRAME_COUNT := 180

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var args := OS.get_cmdline_user_args()
	var path := ""
	for argument in args:
		if argument.begins_with("--save="): path = argument.trim_prefix("--save=")
	if path.is_empty() or not FileAccess.file_exists(path):
		printerr("Pass --save=/absolute/path/to/slot.json after --")
		quit(1)
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	var model = Model.new()
	var started := Time.get_ticks_usec()
	if not data is Dictionary or not data.get("world") is Dictionary or not model.restore(data.world):
		printerr("Cannot restore benchmark save")
		quit(1)
		return
	print(JSON.stringify({"restore_ms": (Time.get_ticks_usec() - started) / 1000.0,
		"citizens": model.workers.size(), "buildings": model.buildings.size(),
		"plans": model.plans.size(), "chunks": model.loaded_chunks.size(), "ground": model.ground.size()}))
	var game = load("res://scenes/settlement/Terraces.tscn").instantiate()
	game.launch_to_menu = false
	game.slot_directory = "/tmp/pyramida-saved-benchmark-%d" % Time.get_ticks_usec()
	root.add_child(game)
	game.set_process(false)
	game.set_process_input(false)
	game.set_process_unhandled_input(false)
	game.session_started = false
	game.model = model
	game.world.last_revision = -1
	game._restore_view(data.get("view", {}))
	game.rig.update_camera()
	# Capture mode suppresses streaming without changing terrain semantics.
	# Stay below the screenshot trigger throughout the benchmark.
	game.capture = not args.has("--streaming")
	game.capture_frames = -100000
	var rendered := args.has("--rendered")
	RenderingServer.viewport_set_measure_render_time(game.viewport.get_viewport_rid(), rendered)
	Perf.enabled = false
	for index in 20:
		game._process(1.0 / 60.0)
		if rendered: await process_frame
	if args.has("--construction"):
		game.speed = 0
		for tool in ["house", "inspect"]:
			Perf.reset()
			Perf.enabled = true
			started = Time.get_ticks_usec()
			game._set_tool(tool)
			game._process(1.0 / 60.0)
			if rendered: await process_frame
			var report := Perf.summary()
			Perf.enabled = false
			report.erase("frames")
			report.tool = tool
			report.switch_ms = (Time.get_ticks_usec() - started) / 1000.0
			print(JSON.stringify(report))
	for speed in ([0] if args.has("--motion") else [0, 1, 4]):
		game.speed = speed
		Perf.reset()
		Perf.enabled = true
		var samples: Array[float] = []
		for index in FRAME_COUNT:
			started = Time.get_ticks_usec()
			if args.has("--motion"):
				game.rig.yaw += 0.008
				game.rig.focus.x += 0.04 if index < FRAME_COUNT / 2 else -0.04
				game.rig.update_camera()
			game._process(1.0 / 60.0)
			if rendered: await process_frame
			samples.append((Time.get_ticks_usec() - started) / 1000.0)
		var report := Perf.summary()
		Perf.enabled = false
		report.erase("frames") # Fixed input delta is not observed frame time.
		samples.sort()
		report.speed = speed
		report.rendered = rendered
		report.motion = args.has("--motion")
		report.streaming = args.has("--streaming")
		report.wall = {"p95_ms": samples[int(FRAME_COUNT * 0.95)], "max_ms": samples.back(),
			"mean_ms": samples.reduce(func(a, b): return a + b, 0.0) / FRAME_COUNT}
		report.gpu_ms = RenderingServer.viewport_get_measured_render_time_gpu(game.viewport.get_viewport_rid())
		report.draw_calls = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		print(JSON.stringify(report))
	if args.has("--measure-save"):
		# Unique scratch slot: exercise both the first write and backup validation.
		for index in 2:
			started = Time.get_ticks_usec()
			var success: bool = game.saves.write_slot(0, model, data.get("view", {}))
			print(JSON.stringify({"save_ms": (Time.get_ticks_usec() - started) / 1000.0, "backup": index > 0, "success": success}))
		for suffix in ["", ".bak", ".tmp", ".bak.tmp"]:
			DirAccess.remove_absolute(game.saves.path_for(0) + suffix)
		DirAccess.remove_absolute(game.saves.directory)
	game.chunk_loader.finish()
	quit()
