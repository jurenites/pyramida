extends RefCounted
const Perf = preload("res://scripts/settlement/performance_log.gd")
## Generate values off-thread; touch simulation and scene objects only on main.
const Chunks = preload("res://scripts/settlement/chunk_stream.gd")
const Generator = preload("res://scripts/settlement/world_generator.gd")
const Nav = preload("res://scripts/settlement/navigation.gd")
var task_id := -1
var task: Dictionary = {}

func advance(world, focus: Vector3, radius: int) -> void:
	if not world.streaming_enabled: return
	var started := Perf.begin()
	var wanted := Chunks.required(world, focus, radius)
	Perf.end("stream.required", started)
	if task_id >= 0 and WorkerThreadPool.is_task_completed(task_id):
		WorkerThreadPool.wait_for_task_completion(task_id)
		task_id = -1
		if task.model_id == world.get_instance_id() and wanted.has(task.chunk):
			started = Perf.begin()
			Chunks.integrate(world, task.chunk, task.generated)
			Perf.end("stream.integrate", started)
		task = {}
	started = Perf.begin()
	Chunks.update(world, focus, radius, 0, wanted)
	Perf.end("stream.unload", started)
	if task_id >= 0: return
	var centre := Generator.chunk_at(Vector2i(roundi(focus.x / Nav.CELL_SIZE), roundi(focus.z / Nav.CELL_SIZE)))
	var nearest := Vector2i.ZERO
	var distance := INF
	for chunk: Vector2i in wanted:
		if world.loaded_chunks.has(chunk): continue
		var next := float((chunk - centre).length_squared())
		if next < distance:
			nearest = chunk
			distance = next
	if is_inf(distance): return
	task = {"model_id": world.get_instance_id(), "seed": world.world_seed, "difficulty": world.difficulty, "chunk": nearest, "generated": {}}
	# The worker receives its own record; no model, node, inventory or scene ref.
	task_id = WorkerThreadPool.add_task(_generate.bind(task), false, "Terrain chunk")

static func _generate(record: Dictionary) -> void:
	record.generated = Generator.generate_chunk(record.seed, record.chunk, record.difficulty)

func finish() -> void:
	if task_id >= 0:
		WorkerThreadPool.wait_for_task_completion(task_id)
		task_id = -1
	task = {}
