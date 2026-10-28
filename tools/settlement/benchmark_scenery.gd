extends SceneTree
const Model = preload("res://scripts/settlement/world_model.gd")
const View = preload("res://scripts/settlement/world_view.gd")
const Perf = preload("res://scripts/settlement/performance_log.gd")

func _initialize() -> void: call_deferred("run")

func run() -> void:
	for landscape in ["easy", "normal"]:
		var model = Model.new()
		model.setup(1409, landscape)
		var view := View.new()
		root.add_child(view)
		view.setup(model)
		Perf.enabled = true
		Perf.reset()
		for index in 20:
			model.revision += 1 # Inventory-only changes must not rebuild terrain/grass.
			view.sync(model, 0.0, -1)
		var inventory := Perf.summary()
		Perf.reset()
		for chunk in [Vector2i(-4, 0), Vector2i(-4, -1), Vector2i(3, 0)]:
			var started := Perf.begin()
			var generated: Dictionary = model.Generator.generate_chunk(model.world_seed, chunk, landscape)
			Perf.end("stream.generate", started)
			started = Perf.begin()
			model.Chunks.integrate(model, chunk, generated)
			Perf.end("stream.integrate", started)
			started = Perf.begin()
			view.sync(model, 0.0, -1)
			Perf.end("stream.view", started)
		print(JSON.stringify({"landscape": landscape, "inventory_updates": inventory, "streaming": Perf.summary()}))
		Perf.enabled = false
		view.free()
	quit()
