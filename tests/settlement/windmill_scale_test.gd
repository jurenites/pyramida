extends SceneTree
const Catalog = preload("res://data/settlement/catalog.gd")
const Farming = preload("res://scripts/settlement/farming.gd")
const Model = preload("res://scripts/settlement/world_model.gd")
func _initialize() -> void:
	var mill = load("res://data/settlement/windmill.tscn").instantiate()
	assert(Catalog.DEFINITIONS.windmill.size == Vector3(2, 6, 2))
	assert(mill.get_node("RoofSocket").position.y == 6)
	assert(is_equal_approx(mill.get_node("WindTower/Ridge").position.y + 0.04, 3.64))
	assert(mill.get_node("WindTower/Rotor").position.y > 3.0)
	assert(mill.get_node("WindTower/Rotor").scale == Vector3(3, 3, 1))
	for height in range(1, 6):
		assert(Farming.overlaps("house", Vector3i(0, height, 0), "windmill", Vector3i.ZERO))
	assert(not Farming.overlaps("house", Vector3i(0, 6, 0), "windmill", Vector3i.ZERO))
	var world = Model.new()
	world.buildings[Vector3i.ZERO] = {"kind": "windmill", "direction": 0}
	for height in [2, 4, 5]:
		assert(world.occupied(Vector3i(0, height, 0), "house"))
		assert(not world.supports_build_cell(Vector3i(0, height, 0)))
	assert(world.supports_build_cell(Vector3i(0, 6, 0)))
	assert(world.snap_cell("house", "windmill", Vector3i.ZERO) == Vector3i(0, 6, 0))
	world.buildings.clear()
	world.buildings[Vector3i(0, 4, 0)] = {"kind": "house", "direction": 0}
	assert(world.occupied(Vector3i.ZERO, "windmill"))
	mill.free()
	print("PASS: short tower and six-metre sail clearance, selection bounds, upper socket and three-storey placement clearance")
	quit()
