extends SceneTree
const Model = preload("res://scripts/settlement/world_model.gd")
const Tooltip = preload("res://scripts/settlement/object_tooltip.gd")

func _initialize() -> void:
	var world := Model.new()
	world.setup()
	var home: Vector3i = Model.STARTING_HOUSE
	assert(world.Houses.ROOM_RESIDENTS == 1 and world.Houses.ROOM_FOOD == 4)
	assert(world.Economy.resource_capacity(world,home,"food") == 4)
	assert(world.stores[home].count("food") == 4)
	assert(world.Economy.storage_space(world,home,"food") == 0)
	# Overfull legacy saves retain goods, but cannot expand the configured limit.
	world.stores[home].amounts.food = 12
	var restored := Model.new()
	assert(restored.restore(JSON.parse_string(JSON.stringify(world.snapshot()))))
	assert(restored.stores[home].count("food") == 12)
	assert(restored.Economy.storage_capacity(restored,"food") == 4)
	assert(restored.Economy.storage_space(restored,home,"food") == 0)
	assert(restored.workers.size() == 3 and restored.Houses.room_occupancy(restored,home) == 1)
	var info := Tooltip.describe(restored,{"kind":"house","cell":home})
	assert(info.rows[0].value == "1/1" and info.rows[1].value == "12/4")
	print("PASS: single-person room, four-food cap, bounded delivery and lossless legacy loading")
	quit()
