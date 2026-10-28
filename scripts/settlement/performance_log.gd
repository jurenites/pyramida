extends RefCounted
## Opt-in, aggregated CPU scopes. Nested scopes are inclusive, not additive.
static var enabled := OS.get_cmdline_user_args().has("--profile-performance")
static var scopes: Dictionary = {}
static var frames: Array[float] = []
static var elapsed := 0.0
static var output: FileAccess
static var output_path := ""

static func begin() -> int:
	return Time.get_ticks_usec() if enabled else 0

static func end(label: String, started: int) -> void:
	if not enabled: return
	var us := Time.get_ticks_usec() - started
	var sample: Array = scopes.get(label, [0, 0, 0])
	sample[0] += 1
	sample[1] += us
	sample[2] = maxi(sample[2], us)
	scopes[label] = sample

static func reset() -> void:
	scopes.clear()
	frames.clear()
	elapsed = 0.0

static func summary() -> Dictionary:
	var rows := []
	for label: String in scopes:
		var sample: Array = scopes[label]
		rows.append({"scope": label, "calls": sample[0], "total_ms": sample[1] / 1000.0,
			"mean_ms": sample[1] / (1000.0 * sample[0]), "max_ms": sample[2] / 1000.0})
	rows.sort_custom(func(a, b): return a.total_ms > b.total_ms)
	var result := {"cpu_scopes_inclusive": rows}
	if not frames.is_empty():
		var sorted := frames.duplicate()
		sorted.sort()
		result.frames = {"count": sorted.size(), "mean_ms": elapsed * 1000.0 / sorted.size(),
			"p95_ms": sorted[mini(sorted.size() - 1, int(sorted.size() * 0.95))], "max_ms": sorted.back()}
	return result

static func frame(delta: float, model, viewport: Viewport, debt: float) -> void:
	if not enabled: return
	frames.append(delta * 1000.0)
	elapsed += delta
	if elapsed < 5.0: return
	var report := summary()
	report.context = {"landscape": model.difficulty, "citizens": model.workers.size(),
		"chunks": model.loaded_chunks.size(), "ground_cells": model.ground.size(),
		"simulation_backlog_ms": debt * 1000.0, "headless": DisplayServer.get_name() == "headless"}
	report.engine = {"process_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		"physics_ms": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0}
	report.render = {"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		"objects": Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		"viewport_cpu_ms": RenderingServer.viewport_get_measured_render_time_cpu(viewport.get_viewport_rid()),
		"viewport_gpu_ms": RenderingServer.viewport_get_measured_render_time_gpu(viewport.get_viewport_rid())}
	if output == null:
		output_path = "user://performance-%s.jsonl" % Time.get_datetime_string_from_system().replace(":", "-")
		output = FileAccess.open(output_path, FileAccess.WRITE)
		print("Performance log: " + ProjectSettings.globalize_path(output_path))
	var line := JSON.stringify(report)
	print("[performance] " + line)
	if output != null:
		output.store_line(line)
		output.flush()
	reset()
