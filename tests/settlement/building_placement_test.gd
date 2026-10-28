extends SceneTree
const Model = preload("res://scripts/settlement/world_model.gd")
const Catalog = preload("res://data/settlement/catalog.gd")
const Assets = preload("res://scripts/settlement/asset_library.gd")
const Navigation = preload("res://scripts/settlement/navigation.gd")
const Labour = preload("res://scripts/applied_labour.gd")
var failures: Array[String] = []
var checks := 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)

func complete(model, kind: String, cell: Vector3i) -> void:
	if not model.request_build(kind, cell):
		check(false, "Cannot queue %s at %s: %s" % [kind, cell, model.last_message])
		return
	model._complete_plan(model.plans[model.next_plan_id - 1])

func _initialize() -> void:
	var model = Model.new()
	model.setup()
	model.deposits.clear()
	check(model.ground.size() == Model.Generator.INITIAL_BOUNDS.get_area(), "World has 41 by 41 playable ground cells")
	check(model.request_build("house", model.surface_at(40, 40)), "Expanded corner is buildable")
	check(not model.request_build("house", Vector3i(60, 0, 40)), "Placement beyond map edge is rejected")
	model.plans.clear()
	check(model.snap_cell("house", "platform", Vector3i(0, 2, 0)) == Vector3i(0, 2, 0), "Building bottom rests directly on the hovered deck")
	check(model.snap_cell("house", "house", Vector3i(0, 2, 0)) == Vector3i(0, 4, 0), "Building bottom snaps to hovered building roof")
	check(model.snap_cell("platform", "platform", Vector3i(0, 2, 0)) == Vector3i(0, 4, 0), "Platform posts start on hovered platform")
	check(model.snap_cell("platform", "house", Vector3i(0, 2, 0)) == Vector3i(0, 6, 0), "Platform posts start on house roof without intersecting its walls")
	check(not model.request_build("house", Vector3i(20, 6, 20)), "Free-floating building is rejected")
	check(not model.request_build("platform", Vector3i(20, 6, 20)), "Free-floating platform is rejected")
	model.platforms[Vector3i(2, 2, 0)] = true
	model.rebuild_navigation()
	check(not model.request_build("house", Vector3i(2, 0, 0)), "Cannot insert a building through existing platform posts")
	check(model.request_build("house", Vector3i(-4, 0, 0)), "House queues on clear ground")
	check(not model.request_build("platform", Vector3i(-4, 2, 0)), "Cannot plan a deck through an unfinished house")
	for step in 1600:
		model.tick(0.05)
	check(model.buildings.has(Vector3i(-4, 0, 0)), "Citizens actually haul materials to complete a house")
	check(model.navigation.surfaces.has(Vector3i(-4, 2, 0)), "Completed house contributes an exact roof surface")
	check(not model.request_build("house", Vector3i(-4, 0, 0)), "Cannot overlap completed buildings")
	check(model.request_build("house", Vector3i(-4, 2, 0)), "Second house can be queued directly on the first roof")
	model.plans.clear()
	for worker in model.workers:
		worker.job = {}
		worker.cargo = ""
		worker.route = []
		worker.route_index = 0
	# Isolate catalogue persistence from hauling and natural obstacles.
	model.trees.clear()
	model.water_sources.clear()
	var index := 0
	for category: String in ["housing", "industry"]:
		for kind: String in Catalog.CATEGORIES[category]:
			var cell := Vector3i(-9 + index % 6 * 4, 0, 5 + index / 6 * 4)
			complete(model, kind, cell)
			check(model.buildings.has(cell) and model.buildings[cell].kind == kind, "%s persists as its own building kind" % kind)
			var asset := Assets.create(kind)
			check(asset.get_child_count() > 1, "%s has an authored model" % kind)
			if kind in Catalog.ROOFS:
				check(asset.has_node("RoofSocket") and is_equal_approx(asset.get_node("RoofSocket").position.y, Catalog.building_height(kind)), "%s roof shares the stacking/navigation socket" % kind)
			asset.free()
			index += 1
	check(model.wells.size() == 1, "New well becomes a real water source")
	check(model.stores.size() == 5, "Three storage buildings and mine camp join hauling inventory")
	check(model.gardens.size() == 1, "Hay field joins crop simulation")
	var restored = Model.new()
	check(restored.restore(JSON.parse_string(JSON.stringify(model.snapshot()))), "Expanded building catalogue saves and loads")
	check(restored.buildings == model.buildings and restored.wells.size() == 1 and restored.ground.size() == model.ground.size(), "All buildings, wells and expanded bounds survive reload")
	check(restored.wells.values()[0].count("water") == model.wells.values()[0].count("water"), "Constructed well retains its inventory after restore")
	var legacy := model.snapshot()
	legacy.version = 1
	legacy.world.v = legacy.world.v.filter(func(pair): return pair[0] not in ["buildings", "wells"])
	check(Model.new().restore(legacy), "Previous save format remains readable")
	check_retired_buildings()
	check_platform_cover()
	if failures.is_empty():
		print("PASS: %d catalogue, support, hauling and migration checks" % checks)
		quit(0)
	else:
		for failure in failures:
			printerr("FAIL: " + failure)
		quit(1)

func cover_world(with_citizens := false):
	var model = Model.new()
	if with_citizens:
		model.setup()
	else:
		for x in range(-4, 5):
			for z in range(-4, 5): model.ground[Vector3i(x, 0, z)] = true
	model.streaming_enabled = false
	model.loaded_chunks.clear()
	model.trees.clear()
	model.deposits.clear()
	model.water_sources.clear()
	model.rebuild_navigation()
	return model

func check_platform_cover() -> void:
	var base := Vector3i.ZERO
	var deck := base + Navigation.Grid.STOREY
	for kind: String in Catalog.PLATFORM_COVERABLE:
		if not Model.BUILD_COSTS.has(kind) or kind == "seed_grass": continue
		var model = cover_world()
		complete(model, kind, base)
		check(model.build_error("platform", deck).is_empty(), "Platform can cover completed %s" % kind)
		check(model.build_error("platform", deck + Vector3i.RIGHT).is_empty(), "Offset platform can partially cover %s" % kind)
		complete(model, "platform", deck)
		check(model.navigation.walkable(base) and model.navigation.walkable(deck), "Covered %s retains separate lower and upper floors" % kind)
		check(model.navigation.route(base, deck).is_empty(), "Covering %s does not invent a ladder connection" % kind)
		var reverse = cover_world()
		complete(reverse, "platform", deck)
		check(reverse.request_build(kind, base), "%s can be built beneath a completed platform" % kind)
		for platform_first in [false, true]:
			var planned = cover_world()
			var first: String = "platform" if platform_first else kind
			var second: String = kind if platform_first else "platform"
			check(planned.request_build(first, deck if platform_first else base), "First %s plan queues" % first)
			check(planned.request_build(second, base if platform_first else deck), "%s and platform plans coexist in either order" % kind)
	var world = cover_world(true)
	var pile := Vector3i(-6, 0, 2)
	var pile_deck: Vector3i = world.snap_cell("platform", "stockpile", pile)
	check(pile_deck == pile + Navigation.Grid.STOREY, "Hovering a pile places the deck one floor above it")
	var inventory = world.stores[pile]
	var logs: int = inventory.count("log")
	check(world.request_build("platform", pile_deck), "Platform queues over the supplied starting pile")
	var restored = Model.new()
	check(restored.restore(JSON.parse_string(JSON.stringify(world.snapshot()))), "Covered-pile construction plan survives saving")
	for worker in restored.workers: restored.set_role(worker.id, "idle")
	restored.order_build(0, restored.next_plan_id - 1)
	for step in 1600:
		restored.tick(0.05)
		if restored.platforms.has(pile_deck): break
	check(restored.platforms.has(pile_deck), "Builder hauls from the pile and completes its covering platform")
	check(restored.stores[pile].count("log") == logs - 4, "Cover construction consumes only its four logs from the accessible pile")
	check(restored.request_build("stockpile", pile_deck), "The covering platform supports another building on top")
	var saved = Model.new()
	check(saved.restore(JSON.parse_string(JSON.stringify(restored.snapshot()))), "Pile, completed cover and upper construction reload together")
	check(saved.platforms.has(pile_deck) and saved.stores[pile].amounts == restored.stores[pile].amounts, "Reload retains the cover and lower inventory")
	for kind: String in ["house", "log_shed", "mine_camp", "well", "stairs"]:
		var blocked = cover_world()
		complete(blocked, kind, base)
		check(not blocked.build_error("platform", deck).is_empty(), "Platform cannot intersect full-height %s, including its inventories" % kind)
	var unsupported = cover_world()
	unsupported.add_store(Vector3i(0, 4, 0))
	check(not unsupported.build_error("platform", Vector3i(0, 6, 0)).is_empty(), "A pile does not provide structural support to floating posts")
	var duplicate = cover_world()
	complete(duplicate, "stockpile", base)
	complete(duplicate, "platform", deck)
	check(not duplicate.request_build("stockpile", base), "Covering a pile does not allow duplicate piles")
	check(not duplicate.request_build("platform", deck), "Covering a pile does not allow duplicate decks")

func check_retired_buildings() -> void:
	var model = Model.new()
	model.setup()
	# Isolate migration refunds from newly gathered timber.
	for worker in model.workers: worker.role = "idle"
	model.deposits.clear()
	model.plans.clear()
	var retired := {"archer_hut": 10, "wall": 1, "gate": 3, "watch_tower": 5, "brick_road": 1}
	var index := 0
	for kind: String in retired:
		var cell := Vector3i((-7 + index * 2) * 2, 0, 10)
		check(not model.request_build(kind, cell), "%s cannot be constructed" % kind)
		model.buildings[cell] = {"kind": kind, "direction": 0}
		model.plans[index + 1] = {"id": index + 1, "kind": kind, "cell": cell + Vector3i.BACK,
			"direction": 0, "installed": 0, "required": retired[kind], "reserved": 0}
		index += 1
	model.next_plan_id = 6
	var store = model.stores[Vector3i(-6, 0, 2)]
	var original_logs: int = store.count("log")
	for id in 2:
		check(store.reserve(id, "log"), "Legacy builder reserves timber")
		model.plans[id + 1].reserved = 1
		model.workers[id].job = {"kind": "build", "plan_id": id + 1, "source": store,
			"target": Vector3i((-7 + id * 2) * 2, 0, 12), "phase": "pickup", "labour": Labour.new(1.8)}
	model.workers[1].cargo = store.pickup(1)
	model.workers[1].job.phase = "travel"
	model.workers[2].cell = Vector3i(-14, 2, 10)
	model.workers[2].position = Navigation.point(model.workers[2].cell)
	model.workers[2].route = [model.workers[2].cell]
	var restored = Model.new()
	check(restored.restore(JSON.parse_string(JSON.stringify(model.snapshot()))), "Save containing retired buildings and active jobs loads")
	check(restored.buildings.is_empty() and restored.plans.is_empty(), "Retired buildings and construction plans are removed on load")
	check(restored.stores[Vector3i(-6, 0, 2)].reservations.is_empty(), "Cancelled builders release reserved timber")
	check(restored.workers[0].job.is_empty(), "Builder awaiting pickup returns to idle")
	check(restored.workers[1].cargo == "log" and restored.workers[1].job.get("phase") == "store", "Carried timber is retained for delivery to storage")
	check(restored.workers[2].cell == Vector3i(-14, 0, 10) and restored.workers[2].route.is_empty(), "Worker on removed roof returns safely to ground")
	check(not restored.navigation.surfaces.has(Vector3i(-14, 2, 10)), "Removed roof no longer creates a walking surface")
	check(Model.new().restore(JSON.parse_string(JSON.stringify(restored.snapshot()))), "Migrated save can be saved and reloaded")
	for step in 200:
		restored.tick(0.05)
	check(restored.workers[1].cargo.is_empty() and restored.resource_total("log") == original_logs, "Cancelled delivery returns timber without losing resources")
	var invalid = Model.new()
	invalid.setup()
	invalid.buildings[Vector3i(-14, 0, 10)] = {"kind": "unknown_building", "direction": 0}
	check(not Model.new().restore(invalid.snapshot()), "Unknown building types remain invalid")
