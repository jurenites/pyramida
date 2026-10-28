extends SceneTree
const Model = preload("res://scripts/settlement/world_model.gd")
const HUD = preload("res://scripts/settlement/hud.gd")
const Labour = preload("res://scripts/applied_labour.gd")
var failures: Array[String] = []

func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var model = Model.new()
	model.setup()
	var hud := HUD.new()
	root.add_child(hud)
	hud.update(model, -1, 1)
	for resource in ["food", "log", "citizens"]:
		check(hud.resource_counts[resource].get_parent().visible, "Starting stock and population are visible: " + resource)
	for resource in ["grain", "plank", "stone", "block"]:
		check(not hud.resource_counts[resource].get_parent().visible, "Unobtained resource is hidden: " + resource)
	check(not hud.resource_counts.water.get_parent().visible, "Natural water does not reveal stored water")
	for count in hud.resource_counts.values():
		check(not count.get_parent().get_child(0).framed, "Top-bar symbols have no decorative frame")
	await process_frame
	await process_frame
	var panel: Control = hud.resource_label.get_parent().get_parent().get_parent()
	var initial_width := panel.size.x
	var inventory = model.stores.values()[0]
	inventory.store("grain", 0)
	check(not model.discovered_resources.has("grain"), "Zero is not a first acquisition")
	check(not inventory.store("block", 1000) and not model.discovered_resources.has("block"), "Failed storage does not reveal a resource")
	# Acquiring and spending between HUD updates must still be remembered.
	for resource in ["stone", "water"]:
		check(inventory.store(resource), "First unit can be stored")
		check(inventory.reserve(0, resource) and inventory.pickup(0) == resource, "Last unit can be spent")
	hud.update(model, -1, 1)
	check(hud.resource_counts.stone.get_parent().visible and hud.resource_counts.stone.text == "0/32", "Spent stone stays visible at zero")
	check(hud.resource_counts.water.get_parent().visible, "Spent water stays visible")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(model.snapshot()))
	var restored = Model.new()
	check(restored.restore(saved), "Discovery save loads")
	hud.update(restored, -1, 1)
	check(hud.resource_counts.stone.get_parent().visible and hud.resource_counts.stone.text == "0/32", "Zero-count discovery survives JSON reload")
	check(not hud.resource_counts.grain.get_parent().visible, "Never-obtained zero stays hidden after reload")
	restored.stores.values()[0].store("plank")
	check(restored.discovered_resources.has("plank"), "Loaded storage continues tracking acquisitions")
	# Actual gathering reveals a resource as soon as a citizen obtains it.
	var fresh = Model.new()
	fresh.setup()
	var worker: Dictionary = fresh.workers[0]
	for cell: Vector3i in fresh.deposits:
		var source = fresh.deposits[cell].inventory
		if source.count("stone") == 0:
			continue
		check(source.reserve(worker.id, "stone"), "Stone can be reserved for gathering")
		worker.job = {"kind": "gather", "phase": "collect", "source": source, "target": cell, "labour": Labour.new(0.1)}
		fresh.tick_citizen_job(worker, 1.0)
		check(worker.cargo == "stone" and fresh.discovered_resources.has("stone"), "Gathered cargo reveals stone before delivery")
		break
	# Older saves can recover discovery from inventory entries, including spent stock.
	for pair in saved.world.v:
		if pair[0] == "discovered_resources":
			saved.world.v.erase(pair)
			break
	check(restored.restore(saved) and restored.discovered_resources.has("stone"), "Legacy spent inventory remains revealed")
	var new_game = Model.new()
	new_game.setup()
	hud.update(new_game, -1, 1)
	await process_frame
	await process_frame
	check(not hud.resource_counts.stone.get_parent().visible and not hud.resource_counts.water.get_parent().visible, "Switching games resets resource visibility")
	check(is_equal_approx(panel.size.x, initial_width), "Resource bar shrinks back without empty resource slots")
	hud.free()
	if failures.is_empty():
		print("PASS: resource discovery, zero counts, gathering, saves, new games and unframed symbols")
	else:
		for message in failures:
			printerr("FAIL: " + message)
	quit(int(not failures.is_empty()))
