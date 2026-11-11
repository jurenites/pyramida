extends SceneTree
## -- --save=/absolute/slot.json [--baseline-navigation=/absolute/navigation.gd]
## Read-only, 400 simulation ticks; optional comparison preserves journey outcomes.
const Model = preload("res://scripts/settlement/world_model.gd")
const Perf = preload("res://scripts/settlement/performance_log.gd")
const Saver = preload("res://scripts/settlement/background_save.gd")
const TICKS := 400
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var path := ""
	var baseline := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--save="): path = argument.trim_prefix("--save=")
		if argument.begins_with("--baseline-navigation="): baseline = argument.trim_prefix("--baseline-navigation=")
	if path.is_empty() or not FileAccess.file_exists(path):
		printerr("Pass --save=/absolute/slot.json after --")
		quit(1)
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	var model = Model.new()
	if not baseline.is_empty(): model.navigation = load(baseline).new()
	if not data is Dictionary or not data.get("world") is Dictionary or not model.restore(data.world):
		printerr("Cannot restore benchmark save")
		quit(1)
		return
	Perf.reset()
	Perf.enabled = true
	var samples: Array[float] = []
	for index in TICKS:
		var started := Time.get_ticks_usec()
		model.tick(0.05)
		samples.append((Time.get_ticks_usec() - started) / 1000.0)
	var report := Perf.summary()
	Perf.enabled = false
	samples.sort()
	report.ticks = TICKS
	report.wall = {"max_ms": samples.back(), "p95_ms": samples[int(TICKS * 0.95)], "total_ms": samples.reduce(func(a, b): return a + b, 0.0)}
	report.searches = model.navigation.searches_built
	report.expanded = model.navigation.nodes_expanded
	report.state_sha256 = JSON.stringify(model.snapshot()).sha256_text()
	print(JSON.stringify(report))
	if OS.get_cmdline_user_args().has("--measure-save"):
		var saver = Saver.new()
		var directory := "/tmp/pyramida-background-benchmark-%d" % Time.get_ticks_usec()
		for index in 2:
			var started := Time.get_ticks_usec()
			var record := {"format": 1, "difficulty": model.difficulty, "saved_at": Time.get_unix_time_from_system(),
				"elapsed": model.time, "view": data.get("view", {}).duplicate(true), "world": Model.SaveCodec.capture(model)}
			var captured_ms := (Time.get_ticks_usec() - started) / 1000.0
			if not saver.start(directory, 0, record): quit(1); return
			var frames := 0
			var result := {}
			while result.is_empty():
				await process_frame
				frames += 1
				result = saver.poll()
			print(JSON.stringify({"save_capture_ms": captured_ms, "save_total_ms": (Time.get_ticks_usec() - started) / 1000.0,
				"frames_while_saving": frames, "backup": index > 0, "success": result.success}))
		for suffix in ["", ".bak", ".tmp", ".bak.tmp"]:
			DirAccess.remove_absolute(directory.path_join("slot_1.json") + suffix)
		DirAccess.remove_absolute(directory)
	quit()
