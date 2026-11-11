extends SceneTree
const Model = preload("res://scripts/settlement/world_model.gd")
const HUD = preload("res://scripts/settlement/hud.gd")
var failures: Array[String] = []

func check(value: bool, message: String) -> void:
	if not value: failures.append(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var model = Model.new()
	model.setup()
	model.trees.clear()
	model.deposits.clear()
	for citizen: Dictionary in model.workers: model.set_role(citizen.id, "idle")
	model.rebuild_navigation()
	var hud := HUD.new()
	root.add_child(hud)
	hud.update(model, -1, 0)
	for kind in ["quarry", "support", "sawmill", "house", "hay_field", "seed_tree", "seed_palm"]:
		check(model.building_unlocked(kind) and hud.buttons[kind].visible, "Starting tier is available: " + kind)
	for kind in ["log_shed", "masonry", "pottery_workshop", "kiln"]:
		check(not model.building_unlocked(kind) and not hud.buttons[kind].visible, "Producer-dependent construction is hidden: " + kind)
	check(not model.request_build("log_shed", Vector3i(4, 0, 0)) and model.plans.is_empty(), "Direct requests cannot bypass a missing producer")
	# Obtaining an output alone is no longer the unlock trigger.
	model.discover_resource("plank")
	check(not model.building_unlocked("log_shed"), "Acquisition history alone does not replace producer completion")
	model.discovered_resources.erase("plank")
	check(model.request_build("sawmill", Vector3i.ZERO), "Producer can be planned at zero stock")
	var producer_id: int = model.next_plan_id - 1
	check(not model.building_unlocked("log_shed"), "An unfinished producer does not unlock its output")
	check(model.debug_finish_plan(producer_id), "Complete the producer without making its output")
	hud.update(model, -1, 0)
	check(model.resource_total("plank") == 0 and hud.buttons.log_shed.visible and not hud.buttons.log_shed.disabled, "Completed sawmill immediately unlocks plank-cost construction")
	check(not model.discovered_resources.has("plank") and not hud.resource_counts.plank.get_parent().visible, "Unlocking does not invent stock or reveal the resource counter")
	check(model.building_unlocked("masonry") and not model.building_unlocked("kiln"), "Unlocks follow recipe materials rather than a fixed building order")
	model.unlock_production("claypit")
	check(model.building_unlocked("pottery_workshop") and not model.building_unlocked("kiln"), "One of two required producer outputs is insufficient")
	model.unlock_production("masonry")
	check(model.building_unlocked("kiln"), "All required producer outputs unlock the building")
	check(model.request_build("log_shed", Vector3i(4, 0, 0)), "Unlocked construction can be planned with no materials")
	var id: int = model.next_plan_id - 1
	model.order_build(0, id)
	for step in 20: model.tick(0.05)
	check(model.plans.has(id) and model.plans[id].installed == 0, "Construction waits without inventing materials")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(model.snapshot()))
	var restored = Model.new()
	check(restored.restore(saved), "Unlock history and waiting plans save and restore")
	check(restored.building_unlocked("log_shed") and restored.building_unlocked("kiln") and restored.plans.has(id), "Zero-stock unlocks and waiting plans survive reload")
	# Older saves recover unlocks from completed producers, never queued ones.
	var legacy := saved.duplicate(true)
	for pair in legacy.world.v:
		if pair[0] == "unlocked_materials":
			legacy.world.v.erase(pair)
			break
	check(restored.restore(legacy) and restored.building_unlocked("log_shed"), "Legacy producer restores its output unlock")
	check(not restored.building_unlocked("kiln"), "Restoring another settlement replaces the previous unlock history")
	# Supply the waiting site through the actual producer buffer.
	model.stores[Vector3i.ZERO].store("log", 2)
	model.stores[Vector3i.ZERO].store("plank", 1)
	model.order_build(0, id)
	for step in 1600:
		model.workers[0].hunger = 0
		model.tick(0.05)
		if not model.plans.has(id): break
	check(model.buildings.get(Vector3i(4, 0, 0), {}).get("kind") == "log_shed", "Waiting plan finishes once the required quantities arrive")
	check(model.stores[Vector3i.ZERO].count("log") == 0 and model.stores[Vector3i.ZERO].count("plank") == 0, "Construction consumes its full recipe")
	model.buildings.erase(Vector3i.ZERO)
	model.stores.erase(Vector3i.ZERO)
	model.construction_materials.erase(Vector3i.ZERO)
	model.rebuild_navigation()
	check(restored.restore(JSON.parse_string(JSON.stringify(model.snapshot()))) and restored.building_unlocked("log_shed"), "Unlock survives producer removal and reload")
	var fresh = Model.new()
	fresh.setup()
	fresh.set_debug_mode(true)
	hud.update(fresh, -1, 0)
	check(hud.buttons.kiln.visible, "Debug exposes locked construction")
	fresh.set_debug_mode(false)
	hud.update(fresh, -1, 0)
	check(not hud.buttons.log_shed.visible and not hud.buttons.kiln.visible, "New settlements reset unlocks and debug does not invent history")
	hud.free()
	if failures.is_empty(): print("PASS: producer unlocks, starting tier, waiting plans, delivery, saves, migration and new games")
	for message: String in failures: printerr("FAIL: " + message)
	quit(int(not failures.is_empty()))
