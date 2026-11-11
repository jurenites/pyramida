extends SceneTree
const Model = preload("res://scripts/settlement/world_model.gd")
const View = preload("res://scripts/settlement/world_view.gd")
const HUD = preload("res://scripts/settlement/hud.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var model = Model.new(); model.streaming_enabled = false; model.soil_enabled = false
	for kind: String in Model.Economy.RECIPES: model.unlock_production(kind)
	for kind: String in Model.Economy.EXTRACTORS: model.unlock_production(kind)
	for x in range(-17, 18):
		for z in range(-15, 16): model.ground[Vector3i(x, 0, z)] = true
	model.workers.append({"id": 0, "cell": Vector3i.ZERO, "position": Vector3.ZERO, "route": [], "route_index": 0, "job": {}, "cargo": "", "status": "idle", "distance": 0.0, "hunger": 0.0, "role": "idle", "life_stage": "adult"})
	model.exploration.update(model.workers); model.rebuild_navigation()
	var i := 0
	for row: Dictionary in Model.Catalog.Reviewed.data.buildings:
		var cell := Vector3i((i % 5 - 2) * 6, 0, (i / 5) * 6 - 9)
		if row.id in ["well", "claypit"]:
			var stock := Model.Inventory.new(); stock.capacity = 3; stock.store("water", 3)
			model.water_sources[cell] = {"kind": "puddle", "inventory": stock}
		assert(model.request_build(row.id, cell), model.last_message)
		for plan: Dictionary in model.plans.values():
			if plan.cell == cell:
				plan.used = plan.materials.duplicate(); plan.installed = plan.required; model._complete_plan(plan)
		i += 1
	assert(model.request_build("sawmill", Vector3i.ZERO))
	var site: Dictionary = model.plans.values()[0]
	site.delivered = Model.Inventory.new(); site.delivered.store("log", 2)
	var view := View.new(); root.add_child(view); view.setup(model)
	var hud := HUD.new(); root.add_child(hud)
	await process_frame
	hud.update(model, -1, 0)
	for row: Dictionary in Model.Catalog.Reviewed.data.buildings: assert(hud.buttons.has(row.id), "Missing menu " + row.name)
	var listed := {}
	for category: String in Model.Catalog.CATEGORIES:
		hud.category_buttons[category].pressed.emit()
		assert(hud.current_category == category and hud.category_lists[category].visible, "Category opens its own list")
		assert(hud.category_title.text != "settlement_category_" + category + "_text", "Group label is translated")
		for kind: String in Model.Catalog.CATEGORIES[category]:
			assert(not listed.has(kind), "A building appears in only one group: " + kind)
			listed[kind] = true
			hud.select_tool(kind)
			assert(hud.current_category == category, "Selecting or copying a building opens its resource group")
			assert(hud.buttons[kind].get_parent() == hud.category_lists[category], "Building belongs to its group list")
	assert(view.entity_views.has("staged:%s:log:0" % site.id), "Staged material is visible")
	for cell: Vector3i in model.buildings:
		var kind: String = model.buildings[cell].kind
		if kind not in Model.Economy.RECIPES: continue
		assert(view.entity_views.has("building:%s" % cell), "Workplace has one rendered entity")
		assert(not view.entity_views.has("stockpile:%s" % cell), "No duplicate workplace mesh")
	assert(not hud.detail_panel.visible, "No new details panel")
	hud.queue_free(); view.queue_free(); await process_frame
	print("PASS: grouped building menus, selection routing, live models, staged cargo and workplace buffers")
	quit()
