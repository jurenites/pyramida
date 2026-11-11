extends SceneTree
const HUD = preload("res://scripts/settlement/hud.gd")
const Readout = preload("res://scripts/settlement/building_readout.gd")
const Model = preload("res://scripts/settlement/world_model.gd")
const Tooltip = preload("res://scripts/settlement/object_tooltip.gd")
const Assets = preload("res://scripts/settlement/asset_library.gd")
const Palette = preload("res://scripts/settlement/resource_palette.gd")
var failures: Array[String] = []
var checks := 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

func run() -> void:
	var hud := HUD.new()
	root.add_child(hud)
	for dimensions in [Vector2i(1100,760), Vector2i(1440,900)]:
		root.size = dimensions
		for category: String in Model.Catalog.CATEGORIES:
			hud.show_category(category)
			for frame in 3: await process_frame
			for kind: String in Model.Catalog.CATEGORIES[category]:
				var row: Button = hud.buttons[kind]
				check(not row.has_node("ConstructionCost") and not row.has_node("BuildingBenefit"),"Build list shows icon and name only: "+kind)
				check(row.custom_minimum_size.y==44,"Compact build row: "+kind)
				check(not Readout.benefit(kind).is_empty(),"Purpose remains available for tooltip: "+kind)
	hud.build_panel.show(); hud.show_category("housing")
	hud.show_building_tooltip(hud.buttons.house,"house")
	await create_timer(0.4).timeout
	check(hud.description_tooltip.visible and hud.description_cost.visible and hud.description_benefit.visible,"Hover reveals cost and benefit")
	hud.hide_building_tooltip()
	check(not hud.description_tooltip.visible,"Details disappear after hover")
	for resource: String in Model.Economy.RESOURCES:
		check(Palette.COLOURS.has(resource), "Resource has a coloured miniature: " + resource)
	# Verify the configurable source changes both construction and its UI, without stale copied prices.
	var original: Dictionary = Model.Catalog.Reviewed.buildings.house.cost.duplicate()
	Model.Catalog.Reviewed.buildings.house.cost = {"log": 7, "clay": 2}
	check(Model.Catalog.recipe("house") == {"log": 7, "clay": 2}, "Construction reads changed balance")
	check(Readout.costs("house") == [{"text":"−7"},{"icon":"log"},{"text":"−2"},{"icon":"clay"}], "UI reads the same changed balance")
	Model.Catalog.Reviewed.buildings.house.cost = original
	var bridge_rules: Dictionary = Model.Catalog.Reviewed.data.rope_bridge_cost
	var previous: float = bridge_rules.planks_per_metre
	bridge_rules.planks_per_metre = 2.0
	check(preload("res://scripts/settlement/rope_bridges.gd").cost_for_length(2.1) == {"plank":5,"rope":2}, "Bridge rates round each material up")
	bridge_rules.planks_per_metre = previous
	check(Readout.benefit("well")[1].text == "3 / 2 / 1 · rain", "Menu does not promise the maximum water yield everywhere")
	check(Readout.benefit("house")[0].text == "+1" and Readout.benefit("house")[2].text == "place", "House promises one place rather than instant residents")
	var tip := Tooltip.new()
	root.add_child(tip)
	var info := {"title":"Sawmill", "rows":[], "benefit":Readout.benefit("sawmill")}
	tip.show_info(info, true)
	check(tip.benefit.visible, "Selected workplace reveals its production chain")
	tip.show_info(info, false)
	check(not tip.benefit.visible, "Hover remains name-only")
	var clay := Assets.create("clay")
	var ore := Assets.create("ore")
	check(clay.get_node("Stone").scale.y < ore.get_node("Stone").scale.y, "Minerals have distinct world silhouettes")
	check(ore.has_node("MineralFace"), "Ore has a visible mineral facet")
	clay.free(); ore.free(); tip.free(); hud.free()
	if failures.is_empty(): print("PASS: %d resource menu checks" % checks)
	else:
		for failure in failures: printerr("FAIL: " + failure)
	quit(int(not failures.is_empty()))
