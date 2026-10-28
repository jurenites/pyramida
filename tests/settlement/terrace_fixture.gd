extends RefCounted
## Explicit built settlement for tests of upper-floor hauling, not new-game defaults.
static func add_to(model) -> void:
	# Isolate vertical logistics from the new foraging economy.
	model.deposits.clear()
	for cell in [Vector3i(0, 1, 0), Vector3i(2, 1, 0), Vector3i(0, 1, 2), Vector3i(2, 1, 2)]:
		model.platforms[cell] = true
	model.stairs[Vector3i(-2, 0, 0)] = 0
	# Keep this long hauling fixture supplied; weather/source depletion is tested separately.
	model.well_inventory.capacity = 24
	model.well_inventory.store("water", 24)
	model.wells[model.well] = model.well_inventory
	model.gardens[Vector3i(2, 1, 2)] = {"water": 0, "growth": 0.0, "food": 0, "reserved": -1}
	for citizen in model.workers:
		citizen.life_stage = "adult"
	model.rebuild_navigation()
	model.request_build("platform", Vector3i(4, 1, 0))
