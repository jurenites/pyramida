extends SceneTree
const Model = preload("res://scripts/settlement/world_model.gd")
const View = preload("res://scripts/settlement/world_view.gd")
const Stone = preload("res://scripts/settlement/stone_view.gd")
const Chunks = preload("res://scripts/settlement/chunk_stream.gd")
var failures: Array[String] = []
var checks := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

func visible_stones(node: Node3D) -> int:
	var count := 0
	for child in node.get_children():
		if child is MeshInstance3D and child.visible: count += 1
	return count

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var model = Model.new()
	model.setup()
	var cell := Vector3i.ZERO
	for candidate: Vector3i in model.deposits:
		if model.deposits[candidate].kind == "limestone":
			cell = candidate
			check(model.deposits[cell].inventory.capacity == Stone.Volume.capacity(cell, model.world_seed) and model.deposits[cell].inventory.count("stone") == model.deposits[cell].inventory.capacity, "New deposits derive capacity from physical volume")
	var view = View.new()
	root.add_child(view)
	view.setup(model)
	var node: Node3D = view.entity_views["deposit:%s" % cell]
	var inventory = model.deposits[cell].inventory
	var original_count: int = inventory.count("stone")
	check(visible_stones(node) == Stone.Volume.sections(cell, model.world_seed).size(), "Broad joined sections contain many smaller stones")
	check(node.get_meta("collider").get_child(0).shape is ConcavePolygonShape3D, "Picking follows the actual remaining rock")
	inventory.reserve(99, "stone")
	inventory.pickup(99)
	model.revision += 1
	view.sync(model, 0, -1)
	check(inventory.count("stone") == original_count - 1 and visible_stones(node) == Stone.Volume.sections(cell, model.world_seed).size(), "Pickup carves a small piece without deleting a large section")
	var restored = Model.new()
	check(restored.restore(JSON.parse_string(JSON.stringify(model.snapshot()))), "Partly mined deposit saves")
	check(restored.deposits[cell].inventory.count("stone") == original_count - 1, "Save preserves exact mined quantity")
	inventory.amounts.stone = 0
	model.revision += 1
	view.sync(model, 0, -1)
	check(visible_stones(node) == 0 and node.get_meta("collider").get_child(0).disabled, "Exhausted rock leaves no geometry or collider")
	var remote := Vector3i(900, 0, 900)
	Chunks.populate(model, {"water": {}, "nature": {remote: "limestone"}, "ground": {}, "shapes": {}})
	check(model.deposits[remote].inventory.capacity == Stone.Volume.capacity(remote, model.world_seed), "Streamed deposits use the same volume rule")
	model.deposits.erase(remote)
	# Old saves retain physical goods and reservations rather than losing stone.
	inventory.capacity = 30
	inventory.store("stone", 27)
	inventory.reserve(0, "stone")
	var legacy = Model.new()
	check(legacy.restore(JSON.parse_string(JSON.stringify(model.snapshot()))), "Legacy deposit saves with a pending pickup")
	check(legacy.deposits.has(cell) and legacy.deposits[cell].inventory.count("stone") == 27 and legacy.deposits[cell].inventory.capacity == 30, "Legacy stone stock is preserved")
	node.get_meta("collider").get_child(0).shape = BoxShape3D.new()
	Stone.sync(node, cell, model.world_seed, inventory)
	check(visible_stones(node) == 27, "Legacy stock also has one block per stone")
	check(node.get_meta("collider").get_child(0).shape.size.y < 4.0, "Legacy piles form a broad stepped mound rather than a tall column")
	var dressed: PackedVector3Array = Stone.block_mesh(1409).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var store_cell: Vector3i = model.stores.keys()[0]
	var store = model.stores[store_cell]
	store.amounts.clear()
	store.store("block", 9)
	store.store("stone", 2)
	model.revision += 1
	view.sync(model, 0, -1)
	var stock: Node3D = view.store_views[store_cell].get_node("EconomyStock")
	var blocks: Array[Node3D] = []
	var raw: Array[Node3D] = []
	for cargo: Node3D in stock.get_children():
		if cargo.get_meta("resource") == "block": blocks.append(cargo)
		if cargo.get_meta("resource") == "stone": raw.append(cargo)
	check(blocks.size() == 9 and raw.size() == 2, "Stored blocks and raw stone each show every physical unit")
	check(blocks[0].get_node("Stone").mesh.get_faces().size() == dressed.size(), "Only finished storage blocks use carved geometry")
	check(raw[0].get_node("Stone").mesh.get_faces().size() > dressed.size(), "Stored raw stone remains visibly rough")
	check(blocks[0].get_node("Stone").mesh.get_faces() != blocks[1].get_node("Stone").mesh.get_faces(), "Stored carved blocks have individual variation")
	var carried_raw := View.Assets.create(View.WorkerView.CARGO_ASSETS.stone)
	var carried_block := View.Assets.create(View.WorkerView.CARGO_ASSETS.block)
	check(carried_raw.get_node("Stone").mesh.get_faces().size() > carried_block.get_node("Stone").mesh.get_faces().size(), "Hauling distinguishes raw stone from the mason's finished output")
	carried_raw.free()
	carried_block.free()
	view.free()
	for failure in failures: printerr("FAIL: " + failure)
	if failures.is_empty(): print("PASS: %d stone shape, pickup, generation and persistence checks" % checks)
	quit(int(not failures.is_empty()))
