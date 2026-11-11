extends PanelContainer
## Shared compact object readout, with transparent hover and black selection styles.
const Tokens = preload("res://scripts/ui_visual_tokens.gd")
const Icon = preload("res://scripts/settlement/build_icon.gd")
const Catalog = preload("res://data/settlement/catalog.gd")
const Piles = preload("res://scripts/settlement/pile_groups.gd")
const Economy = preload("res://scripts/settlement/economy.gd")
const HouseSelection = preload("res://scripts/settlement/house_selection.gd")
const BuildingReadout = preload("res://scripts/settlement/building_readout.gd")
var benefit: HBoxContainer
var last_benefit: Array = []
var title: Label
var content: VBoxContainer
var rows: VBoxContainer
var last_rows: Array = []
var black_background := false
var style_initialized := false

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	content = VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_theme_constant_override("separation", Tokens.GAP_UNIT)
	add_child(content)
	title = Label.new()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.add_theme_font_size_override("font_size", Tokens.WORLD_TOOLTIP_FONT_SIZE)
	content.add_child(title)
	rows = VBoxContainer.new()
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.add_theme_constant_override("separation", Tokens.GAP_UNIT)
	content.add_child(rows)
	benefit = BuildingReadout.new()
	benefit.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_child(benefit)
	benefit.hide()
	set_black(false)

func set_black(black: bool) -> void:
	if style_initialized and black_background == black:
		return
	black_background = black
	style_initialized = true
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color.BLACK if black else Color.TRANSPARENT
	panel.content_margin_left = Tokens.PANEL_PADDING_X
	panel.content_margin_right = Tokens.PANEL_PADDING_X
	panel.content_margin_top = Tokens.PANEL_PADDING_Y
	panel.content_margin_bottom = Tokens.PANEL_PADDING_Y
	add_theme_stylebox_override("panel", panel)
	var ink := Color.WHITE if black else Color("352719")
	title.add_theme_color_override("font_color", ink)

func show_info(info: Dictionary, details: bool) -> void:
	title.text = info.title
	var purpose: Array = info.get("benefit", []) if details else []
	if purpose != last_benefit:
		last_benefit = purpose.duplicate(true)
		benefit.display(purpose, Color.WHITE)
	benefit.visible = not purpose.is_empty()
	var values: Array = info.rows if details else info.get("hover_rows",[])
	if values != last_rows:
		last_rows = values.duplicate(true)
		for child in rows.get_children():
			rows.remove_child(child)
			child.queue_free()
		for value: Dictionary in values:
			var row := HBoxContainer.new()
			row.alignment = BoxContainer.ALIGNMENT_CENTER
			row.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_theme_constant_override("separation", 4 * Tokens.GAP_UNIT)
			var icon := Icon.new()
			icon.kind = value.icon
			icon.ink = Color.WHITE
			row.add_child(icon)
			var count := Label.new()
			count.text = value.value
			count.mouse_filter = Control.MOUSE_FILTER_IGNORE
			count.add_theme_color_override("font_color", Color.WHITE)
			count.add_theme_font_size_override("font_size", Tokens.WORLD_TOOLTIP_FONT_SIZE)
			row.add_child(count)
			rows.add_child(row)
	var ink := Color.WHITE if black_background else Color("352719")
	for row in rows.get_children():
		if row.get_child(0).ink != ink:
			row.get_child(0).ink = ink
			row.get_child(0).queue_redraw()
		row.get_child(1).add_theme_color_override("font_color", ink)
	rows.visible = not values.is_empty()
	reset_size()

static func describe(model, target: Dictionary) -> Dictionary:
	var result := {"title": "", "rows": []}
	if target.has("worker_id"):
		var worker: Dictionary = model.workers[target.worker_id]
		result.title = person_title(worker)
		return result
	var kind: String = target.kind
	var cell: Vector3i = target.cell
	result.title = Catalog.title(kind)
	if target.has("bridge_id") and model.bridges.has(target.bridge_id): return result
	# A plan at a resource cell must never inherit that resource's inventory.
	if str(target.get("entity_key", "")).begins_with("plan:"):
		for plan: Dictionary in model.plans.values():
			if target.entity_key == "plan:%s" % plan.id:
				if plan.get("deconstruction", false):
					if plan.relocation.stage == "salvage":
						result.title = TranslationServer.translate("salvage_materials_text")
						for resource: String in plan.relocation.parts.amounts:
							var amount: int = plan.relocation.parts.count(resource)
							if amount > 0: result.rows.append({"icon": resource, "value": str(amount)})
					return result
				for resource: String in plan.materials:
					result.rows.append({"icon": resource, "value": "%d/%d" % [plan.used.get(resource, 0), plan.materials[resource]]})
				if plan.kind == "well":
					var incoming := 1
					if plan.has("relocation"):
						incoming = model.Hydrology.units(plan.relocation.payload.get("buildings", model.buildings.get(plan.relocation.source, {})))
					var count: int = incoming + (model.Hydrology.units(model.buildings.get(cell, {})) if model.wells.has(cell) else 0)
					result.rows.append({"icon":"water", "value":str(model.Hydrology.capacity(model,cell,count))})
		return result
	if Economy.is_workplace(kind) and model.buildings.get(cell, {}).get("kind") == kind:
		result["benefit"] = BuildingReadout.benefit(kind)
		var assigned := 0
		for worker: Dictionary in model.workers:
			# Keep dedicated staff visible during meals, hauling and idle gaps.
			if worker.get("assigned_workplace") == cell:
				assigned += 1
		result.rows.append({"icon": "citizens", "value": str(assigned)})
	if kind == "tree" and model.trees.has(cell):
		var tree: Dictionary = model.trees[cell]
		result.title = TranslationServer.translate("stump_name_text" if tree.inventory.count("log") == 0 else ("dead_tree_name_text" if tree.get("kind", "living") == "dead" else "tree_name_text"))
		if tree.get("kind") == "palm" and tree.inventory.count("log") > 0: result.title = TranslationServer.translate("palm_name_text")
		if float(tree.get("seed_growth", 1.0)) < 1.0: result.title = TranslationServer.translate("palm_seedling_name_text" if tree.get("kind") == "palm" else "sapling_name_text")
		result.rows.append({"icon": "log", "value": "%d/%d" % [tree.inventory.count("log"), tree.inventory.capacity]})
	elif kind == "hay_field" and model.gardens.has(cell):
		result.rows.append({"icon": "grain", "value": str(model.gardens[cell].food)})
	elif model.deposits.has(cell):
		var deposit: Dictionary = model.deposits[cell]
		var berry: bool = deposit.kind == "berry"
		result.title = TranslationServer.translate("bush_name_text" if berry else "stone_name_text")
		result.rows.append({"icon": "berry" if berry else "stone", "value": "%d/%d" % [deposit.inventory.total(), deposit.inventory.capacity]})
	elif model.wells.has(cell):
		var inventory = model.wells[cell]
		result.title = Catalog.title(model.buildings.get(cell, {}).get("kind", "well"))
		result.rows.append({"icon": "water", "value": "%d/%d" % [inventory.count("water"), inventory.capacity]})
		result.hover_rows = result.rows.duplicate(true)
	elif model.water_sources.has(cell) and not model.buildings.has(cell):
		var source: Dictionary = model.water_sources[cell]
		result.title = TranslationServer.translate("puddle_name_text" if source.kind == "puddle" else "stream_name_text")
		result.rows.append({"icon": "water", "value": "%d/%d" % [source.inventory.count("water"), source.inventory.capacity]})
	elif kind == "house":
		var total: Dictionary = model.Houses.totals(model, cell, HouseSelection.members(model, target))
		if target.get("house_scope") == "floor": result.title = TranslationServer.translate("house_floor_name_text")
		elif target.get("house_scope") == "room": result.title = TranslationServer.translate("house_room_name_text")
		result.rows.append({"icon": "citizens", "value": "%d/%d" % [total.residents, total.capacity]})
		result.rows.append({"icon": "food", "value": "%d/%d" % [total.food, total.food_capacity]})
	elif Piles.is_pile(model, cell):
		var total := Piles.totals(model, cell)
		for resource: String in Economy.RESOURCES:
			var amount: int = total.amounts.get(resource, 0)
			if amount > 0:
				result.rows.append({"icon": resource, "value": "%d/%d" % [amount, total.capacity]})
	elif model.stores.has(cell):
		for resource: String in Economy.RESOURCES:
			var amount: int = model.stores[cell].count(resource)
			if amount > 0 or Economy.accepts(model, cell, resource):
				result.rows.append({"icon": resource, "value": "%d/%d" % [amount, model.stores[cell].capacity]})
	elif kind == "soil_bed":
		pass
	elif model.gardens.has(cell):
		if model.gardens[cell].get("species") == "vegetables": result.title = TranslationServer.translate("vegetables_name_text")
		result.rows.append({"icon": Economy.field_resource(model, cell), "value": str(model.gardens[cell].food)})

	return result

static func person_title(worker: Dictionary) -> String:
	if worker.get("life_stage", "adult") != "adult":
		return TranslationServer.translate("kid_name_text")
	var role: String = worker.get("role", "auto")
	# Assigned occupations survive meals, travel and gaps between tasks.
	# Automatic workers take the occupation of their current production job.
	if role == "auto":
		var job: Dictionary = worker.get("job", {})
		match job.get("kind", ""):
			"build", "relocate": role = "builder"
			"fell": role = "woodcutter"
			"water", "harvest": role = "farmer"
			"gather": role = "miner" if job.get("resource") == "stone" else "forager"
			"restock", "collect_water": role = "hauler"
			"process", "extract":
				role = {"plank": "sawyer", "food": "baker", "block": "mason", "flour": "miller", "pottery": "potter", "brick": "kilner", "imbrex": "tiler", "clay": "claydigger", "ore": "prospector"}.get(job.get("output", ""), "idle")
			_: role = "idle"
	if role == "idle":
		return TranslationServer.translate("willager_name_text")
	return TranslationServer.translate("person_job_%s_text" % role)

static func name_anchor_mesh(node: Node3D, mesh: MeshInstance3D) -> bool:
	if not mesh.is_visible_in_tree() or mesh.mesh == null: return false
	var rotor := node.get_node_or_null("WindTower/Rotor")
	return rotor == null or not rotor.is_ancestor_of(mesh)

static func stationary_height(node: Node3D, fallback: float) -> float:
	if not node.has_node("WindTower/Rotor"): return fallback
	var height := 0.0
	for mesh: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		if not name_anchor_mesh(node, mesh): continue
		var pose := preload("res://scripts/settlement/timber_frame.gd").relative(node, mesh)
		height = maxf(height, (pose * mesh.get_aabb()).end.y)
	return height if height > 0 else fallback
