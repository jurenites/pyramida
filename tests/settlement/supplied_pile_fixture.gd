extends RefCounted
## Explicit legacy opening for logistics tests that require pre-stocked materials.
static func add_to(model) -> void:
	var cell: Vector3i = model.STARTING_HOUSE
	model.buildings.erase(cell)
	model.construction_materials.erase(cell)
	model.stores.erase(cell)
	model.add_store(cell, {"log": 18, "food": 5})
	for worker in model.workers: worker.erase("home_cell")
	model.rebuild_navigation()
