extends Node3D
const Perf = preload("res://scripts/settlement/performance_log.gd")
const Houses = preload("res://scripts/settlement/house_groups.gd")
const HouseShell = preload("res://scripts/settlement/house_shell.gd")
const Piles = preload("res://scripts/settlement/pile_groups.gd")
const Economy = preload("res://scripts/settlement/economy.gd")
const Catalog = preload("res://data/settlement/catalog.gd")
const Navigation = preload("res://scripts/settlement/navigation.gd")
const Assets = preload("res://scripts/settlement/asset_library.gd")
const BushView = preload("res://scripts/settlement/bush_view.gd")
const TreeView = preload("res://scripts/settlement/tree_view.gd")
const StoneView = preload("res://scripts/settlement/stone_view.gd")
const WorkerView = preload("res://scripts/settlement/worker_view.gd")
const Construction = preload("res://scripts/settlement/construction_site_view.gd")
var planning := false
var last_planning := false
var planned_decks: Dictionary = {}
var fog_enabled := false
var scenery: Node3D
var water_view: Node3D
var architecture: Node3D
var actors: Array[Node3D] = []
var route_strokes: Array[PackedVector3Array] = []
var last_revision := -1
var last_model_id := 0
var visibility_state: Array = []
var appearance_revision := -1
var show_routes := false
var garden_views: Dictionary = {}
var store_views: Dictionary = {}
var tree_views: Dictionary = {}
var display_level := 3
var cutaway := false
var entity_views: Dictionary = {}
var _wanted: Dictionary = {}

func setup(model) -> void:
	scenery = Node3D.new()
	scenery.set_script(preload("res://scripts/settlement/scenery_view.gd"))
	add_child(scenery)
	scenery.setup(model)
	water_view = Node3D.new()
	water_view.set_script(preload("res://scripts/settlement/water_view.gd"))
	add_child(water_view)
	for worker in model.workers:
		var view := Node3D.new()
		view.set_script(WorkerView)
		view.setup(worker.id)
		add_child(view)
		actors.append(view)
	architecture = Node3D.new()
	add_child(architecture)
	sync(model, 0, -1)

func _place(kind: String, cell: Vector3i, asset_kind := "") -> Node3D:
	# Salvage retains an inspectable inventory, but has no stockpile or building shell.
	var node := Node3D.new() if asset_kind == "salvage" else Assets.create(kind if asset_kind.is_empty() else asset_kind)
	node.position = Navigation.point(cell)
	node.set_meta("cell", cell)
	architecture.add_child(node)
	var definition: Dictionary = Catalog.DEFINITIONS.get(kind, {})
	if not definition.is_empty():
		var body := StaticBody3D.new()
		body.set_meta("cell", cell)
		body.set_meta("kind", kind)
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = definition.size
		collision.shape = shape
		collision.position = definition.offset
		body.add_child(collision)
		node.add_child(body)
		node.set_meta("collider", body)
	return node

func sync(model, delta: float, selected: int) -> void:
	if last_model_id != model.get_instance_id():
		last_model_id = model.get_instance_id()
		last_revision = -1
	if appearance_revision != Assets.Appearance.revision or last_planning != planning:
		last_planning = planning
		for node in entity_views.values(): node.free()
		entity_views.clear()
		appearance_revision = Assets.Appearance.revision
		last_revision = -1
	if last_revision != model.revision:
		planned_decks = model.Planning.platforms(model) if planning else {}
		var started := Perf.begin()
		scenery.sync(model)
		Perf.end("view.terrain", started)
		started = Perf.begin()
		water_view.sync(model)
		Perf.end("view.water", started)
		started = Perf.begin()
		_rebuild(model)
		visibility_state.clear()
		Perf.end("view.entities", started)
		last_revision = model.revision
	var dynamic_started := Perf.begin()
	# Applied labour advances between model revisions; reveal only the pieces earned by work.
	for plan: Dictionary in model.plans.values():
		if model.Deconstruction.is_salvage(plan): continue
		if planning and Construction.applies(plan): continue
		if plan.kind == "platform" and entity_views.has("plan:%s" % plan.id): model.Platforms.sync(entity_views["plan:%s" % plan.id], int(plan.get("platform_tier", 1)))
		if Construction.applies(plan):
			Construction.sync(entity_views["plan:%s" % plan.id], plan, model.workers)
	for cell: Vector3i in model.buildings:
		var building: Dictionary = model.buildings[cell]
		if building.kind != "windmill": continue
		var key := "building:%s" % cell
		if not entity_views.has(key): continue
		var working: bool = model.workers.any(func(worker): return worker.job.get("kind") == "process" and worker.job.get("target") == cell and worker.job.get("phase") == "work") and Economy.production_speed(model, cell) > 0
		preload("res://scripts/settlement/mill_view.gd").animate(entity_views[key], int(building.get("mill_tier", 3)), delta, working)
	# The clock advances even when no inventory or structure changes.
	scenery.update_lighting(model.time)
	while actors.size() > model.workers.size():
		actors.pop_back().free()
	while actors.size() < model.workers.size():
		var actor := Node3D.new()
		actor.set_script(WorkerView)
		actor.setup(actors.size())
		add_child(actor)
		actors.append(actor)
	var camera := get_viewport().get_camera_3d()
	for worker in model.workers:
		actors[worker.id].sync(worker, delta, worker.id == selected, camera, model.navigation)
		actors[worker.id].sync_plant_cargo(worker, model)
	for cell: Vector3i in garden_views:
		var garden: Dictionary = model.gardens[cell]
		var plants := garden_views[cell].get_node("Plants") as Node3D
		if garden.get("species") == "grass":
			plants.scale.y = 1.0 if garden.food > 0 else lerpf(0.08, 1.0, clampf(garden.growth / model.Farming.Balance.number("crop_growth_seconds"), 0.0, 1.0))
			for index in plants.get_child_count(): plants.get_child(index).visible = garden.food == 0 or index % 3 < garden.food
			continue
		var hay: bool = model.buildings.get(cell, {}).get("kind") == "hay_field"
		var growth: float = 1.0 if garden.food > 0 else (0.06 + garden.growth / 24.0 * 0.94 if hay else 0.25 + garden.growth / 24.0 * 0.75)
		plants.scale.y = growth
		plants.position.y = 0.012 if hay else 0.30 * (1.0 - growth)
		if hay:
			sync_hay_quarters(plants, garden)
	for cell: Vector3i in tree_views:
		TreeView.sync(tree_views[cell], model.trees[cell])
	for cell: Vector3i in model.deposits:
		var deposit: Dictionary = model.deposits[cell]
		if deposit.kind == "berry" and deposit.has("seed_growth"):
			var key := "deposit:%s" % cell
			if entity_views.has(key): entity_views[key].scale = Vector3.ONE * lerpf(0.18, 1.0, deposit.seed_growth)
	Perf.end("view.animation", dynamic_started)
	var visibility_started := Perf.begin()
	var next_visibility := [last_model_id, model.revision, appearance_revision, model.exploration.revision, fog_enabled, cutaway, display_level]
	if visibility_state != next_visibility:
		visibility_state = next_visibility
		for child: Node3D in architecture.get_children():
			var cell: Vector3i = child.get_meta("cell", Vector3i.ZERO)
			child.visible = (not cutaway or cell.y <= display_level) and (not fog_enabled or model.exploration.contains(Navigation.point(cell)))
			if child.has_meta("collider"):
				child.get_meta("collider").collision_layer = (2 if child.get_meta("planned", false) else 1) if child.visible and not child.get_meta("relocation_piece", false) else 0
		for cell: Vector3i in water_view.sources:
			var source: Node3D = water_view.sources[cell]
			source.visible = not fog_enabled or model.exploration.contains(Navigation.point(cell))
			for child in source.get_children():
				if child is StaticBody3D:
					child.collision_layer = 1 if source.visible else 0
	Perf.end("view.visibility", visibility_started)
	var grass_started := Perf.begin()
	scenery.sync_grass(model, fog_enabled)
	Perf.end("view.grass", grass_started)
	_sync_routes(model, selected)

static func sync_hay_quarters(plants: Node3D, crop: Dictionary) -> void:
	var farming = preload("res://scripts/settlement/farming.gd")
	var standing: int = farming.standing_quarters(crop)
	for tuft: Node3D in plants.get_children():
		var quarter: int = farming.quarter_at(tuft.position)
		tuft.visible = (standing & (1 << quarter)) != 0 if crop.food > 0 else crop.growth > 0.0

func _entity(key: String, kind: String, cell: Vector3i, asset_kind := "", direction := 0) -> Node3D:
	_wanted[key] = true
	var variant := kind if asset_kind.is_empty() else asset_kind
	if entity_views.has(key) and entity_views[key].get_meta("asset") != variant:
		entity_views[key].free()
		entity_views.erase(key)
	if not entity_views.has(key):
		var node := _place(kind, cell, variant)
		node.set_meta("asset", variant)
		node.visible = not cutaway or cell.y <= display_level
		entity_views[key] = node
	var result: Node3D = entity_views[key]
	result.position = Navigation.point(cell)
	result.visible = not cutaway or cell.y <= display_level
	result.set_meta("cell", cell)
	result.set_meta("planned", key.begins_with("plan:"))
	if result.has_meta("collider"):
		var body: StaticBody3D = result.get_meta("collider")
		body.set_meta("cell", cell)
		body.set_meta("entity_key", key)
		body.collision_layer = (2 if result.get_meta("planned") else 1) if result.visible else 0
	result.rotation.y = -direction * PI * 0.5
	return result

func _rebuild(model) -> void:
	# Reconcile identity, preserving unchanged assets, colliders and materials.
	_wanted.clear()
	var dismantling := {}
	for plan: Dictionary in model.plans.values():
		if plan.get("deconstruction", false) and plan.relocation.stage == "dismantle":
			dismantling[plan.cell] = true
	garden_views.clear()
	store_views.clear()
	tree_views.clear()
	for cell: Vector3i in model.deposits:
		var deposit: Dictionary = model.deposits[cell]
		var node := _entity("deposit:%s" % cell, deposit.kind, cell)
		for child in node.get_children():
			if child is MeshInstance3D:
				child.visible = not child.name.begins_with("Berry") or int(str(child.name).trim_prefix("Berry")) < deposit.inventory.count("food")
		if deposit.kind == "berry":
			BushView.sync(node, cell, model.world_seed, int(deposit.get("appearance_seed", -1)))
		if deposit.kind == "limestone":
			StoneView.sync(node, cell, model.world_seed, deposit.inventory)
	for cell: Vector3i in model.platforms:
		if dismantling.has(cell) or (planning and not planned_decks.has(cell)): continue
		var deck := _entity("platform:%s" % cell, "platform", cell)
		model.Platforms.sync(deck, model.Platforms.tier(model.platforms[cell]))
	for cell: Vector3i in model.stairs:
		if dismantling.has(cell): continue
		var stair := _entity("stairs:%s" % cell, "stairs", cell, "", model.stairs[cell])
		preload("res://scripts/settlement/construction_variants.gd").stairs(stair, model.navigation.stair_landing(cell, model.stairs[cell]).y - cell.y)
	for cell: Vector3i in model.stores:
		if dismantling.has(cell) or model.Houses.is_house(model, cell): continue
		var kind: String = model.buildings[cell].kind if model.buildings.has(cell) else "stockpile"
		var node := _entity("stockpile:%s" % cell, kind, cell, "", int(model.buildings[cell].direction) if model.buildings.has(cell) else 0)
		if kind == "hay_barn": preload("res://scripts/settlement/hay_barn_view.gd").sync(model, cell, node)
		if kind == "stone_storage":
			var tier := int(model.buildings[cell].get("storage_tier", 1))
			node.get_node("Beams").visible = tier >= 2
			node.get_node("Enclosure").visible = tier == 3
		store_views[cell] = node
		if not node.has_meta("logs"):
			var log_nodes: Array[Node3D] = []
			for index in 12:
				var log_node := Assets.create("log")
				log_node.set_meta("variation_exempt", true)
				# Four logs per discrete stack layer.
				@warning_ignore("integer_division")
				log_node.position = Vector3(0, 0.18 + (index / 4) * 0.22, -0.42 + (index % 4) * 0.27)
				if kind == "log_shed":
					log_node.rotation.y = PI * 0.5
					log_node.position = Vector3((index % 3 - 1) * 0.23, 0.10 + (index / 6) * 0.23, -0.46 if index % 6 < 3 else 0.46)
				node.add_child(log_node)
				log_nodes.append(log_node)
			node.set_meta("logs", log_nodes)
		var logs: Array = node.get_meta("logs")
		for index in logs.size():
			logs[index].visible = kind not in ["goods_rack", "small_warehouse"] and index < model.stores[cell].count("log")
		if node.has_node("EconomyStock"):
			node.get_node("EconomyStock").free()
		var stock := Node3D.new()
		stock.name = "EconomyStock"
		node.add_child(stock)
		var slot := 0
		for resource in ["food", "grain", "plank", "stone", "block", "pottery"]:
			var amount: int = model.stores[cell].count(resource)
			if kind in ["goods_rack", "small_warehouse"]: amount = mini(amount, maxi(0, 8 - slot))
			for index in (amount if resource in ["stone", "block", "pottery"] else mini(amount, 4)):
				var cargo := Assets.create(WorkerView.CARGO_ASSETS[resource])
				cargo.set_meta("resource", resource)
				if resource in ["stone", "block"]:
					var stone_mesh: MeshInstance3D = cargo.get_node("Stone")
					var shape_seed := StoneView.Random.world_coordinate_seed(cell.x, cell.z, model.world_seed, 610 + index)
					stone_mesh.mesh = StoneView.block_mesh(shape_seed) if resource == "block" else StoneView.raw_mesh(shape_seed)
					if kind == "stone_storage" and resource == "stone":
						stone_mesh.scale = Vector3.ONE * 0.7
						stone_mesh.position.y = -0.15
				# Six items per layer, arranged in two rows of three.
				@warning_ignore("integer_division")
				cargo.position = Vector3((slot % 3 - 1) * 0.42, 0.15 + (slot / 6) * 0.28, (slot / 3 % 2 - 0.5) * 0.48)
				if kind == "stone_storage": cargo.position = Vector3((slot % 4 - 1.5) * 0.57, 0.18 + (slot / 16) * 0.35, (slot / 4 % 4 - 1.5) * 0.57)
				if kind == "hay_barn": cargo.position = Vector3(0, 0.15 + (slot / 3) * 0.25, (slot % 3 - 1) * 0.55)
				cargo.scale = Vector3.ONE * 0.7
				if kind in ["goods_rack", "small_warehouse"]:
					cargo.position = Vector3(-0.20 + (slot % 2) * 0.40, 0.14 + (slot / 4) * 0.34, -0.20 + (slot / 2 % 2) * 0.38)
					cargo.scale = Vector3.ONE * 0.42
				if resource == "plank":
					cargo.scale = Vector3.ONE
					cargo.rotation.y = PI * 0.5
					cargo.position = Vector3((slot % 3 - 1) * 0.25, 0.14 + (slot / 3) * 0.20, 0)
				stock.add_child(cargo)
				slot += 1
	_sync_pile_corners(model)
	for cell: Vector3i in model.soil_beds:
		if not dismantling.has(cell) or model.Relocation.kind_at(model, cell) != "soil_bed":
			_entity("soil_bed:%s" % cell, "soil_bed", cell)
	for cell: Vector3i in model.gardens:
		if dismantling.has(cell): continue
		var kind: String = "grass_patch" if model.gardens[cell].get("species") == "grass" else ("hay_field" if model.buildings.has(cell) else "garden")
		garden_views[cell] = _entity("garden:%s" % cell, kind, cell, "", int(model.buildings[cell].direction) if model.buildings.has(cell) else 0)
		if kind == "hay_field": preload("res://scripts/settlement/hay_field_view.gd").sync(model, cell, garden_views[cell], dismantling)
	for cell: Vector3i in model.trees:
		var node := _entity("tree:%s" % cell, "tree", cell, TreeView.asset(model.trees[cell]))
		tree_views[cell] = node
	for cell: Vector3i in model.vines:
		var vine := _entity("vine:%s" % cell, "vine_tree", cell)
		preload("res://scripts/settlement/vine_view.gd").sync(vine, model, cell)
	for cell: Vector3i in model.wells:
		if dismantling.has(cell): continue
		var building: Dictionary = model.buildings.get(cell, {})
		var kind: String = building.get("kind", "well")
		var node := _entity("well:%s" % cell, kind, cell, "", int(building.get("direction", 0)))
		preload("res://scripts/settlement/well_view.gd").sync(node, int(building.get("well_units", 3)), model.wells[cell].count("water"), model.wells[cell].capacity, kind == "waterworks")
	for cell: Vector3i in model.buildings:
		if dismantling.has(cell): continue
		var building: Dictionary = model.buildings[cell]
		if building.kind in Catalog.STORAGE or building.kind in ["hay_field", "well", "waterworks"]:
			continue
		var node := _entity("building:%s" % cell, building.kind, cell, "", int(building.direction))
		if building.kind == "windmill": preload("res://scripts/settlement/mill_view.gd").sync(node, int(building.get("mill_tier", 3)))
		if building.kind == "sawmill": preload("res://scripts/settlement/sawmill_view.gd").sync(node, int(building.get("sawmill_tier", 2)))
		if building.kind == "house":
			var rooms := Houses.members(model, cell)
			if rooms.size() > 1 or node.has_node("JoinedWalls"):
				var neighbours: Array = []
				for side: Vector3i in Houses.SIDES:
					if cell + side * 2 in rooms: neighbours.append(side)
				var doors: Array = [Houses.SIDES[int(building.direction)]]
				HouseShell.apply(node, neighbours, doors)
	for plan: Dictionary in model.plans.values():
		if plan.get("collect_vine", false) or plan.get("collect_bush", false): continue
		if planning and plan.kind == "platform" and model.Planning.includes(plan) and not planned_decks.has(plan.cell): continue
		var plant: Dictionary = {}
		if plan.has("relocation") and model.Relocation.portable_plant(plan):
			var field: String = {"tree": "trees", "berry": "deposits", "garden": "gardens"}[plan.kind]
			plant = plan.relocation.payload.get(field, model.get(field).get(plan.relocation.source, {}))
		var asset_kind := TreeView.asset(plant) if plan.kind == "tree" else ""
		if plan.has("bush_payload"): asset_kind = "berry"
		if plan.kind == "garden" and plant.get("species") == "grass": asset_kind = "grass_patch"
		var salvaging: bool = plan.get("deconstruction", false) and plan.relocation.stage == "salvage"
		var well_count := 0
		if plan.kind == "well" and not salvaging:
			well_count = model.Hydrology.units(model.buildings.get(plan.cell, {})) if model.wells.has(plan.cell) else 0
			well_count += model.Hydrology.units(plan.get("relocation", {}).get("payload", {}).get("buildings", model.buildings.get(plan.get("relocation", {}).get("source"), {}))) if plan.has("relocation") else 1
			var key := "plan:%s" % plan.id
			if entity_views.has(key) and entity_views[key].get_meta("well_plan_units", -1) != well_count:
				entity_views[key].free()
				entity_views.erase(key)
		var node := _entity("plan:%s" % plan.id, "stockpile" if salvaging else plan.kind,
			plan.relocation.pickup_cell if salvaging else plan.cell, "salvage" if salvaging else asset_kind, int(plan.direction))
		if plan.kind == "windmill" and not salvaging and not node.has_meta("construction_parts"):
			preload("res://scripts/settlement/mill_view.gd").sync(node, int(plan.get("mill_tier", 3)))
		if plan.kind == "sawmill" and not salvaging and not node.has_meta("construction_parts"):
			preload("res://scripts/settlement/sawmill_view.gd").sync(node, int(plan.get("sawmill_tier", plan.get("relocation", {}).get("payload", {}).get("buildings", {}).get("sawmill_tier", 2))))
		if plan.kind == "stone_storage" and not salvaging and not node.has_meta("construction_parts"):
			preload("res://scripts/settlement/stone_storage_view.gd").sync(node, int(plan.get("storage_tier", 1)))
		if plan.kind == "stairs" and not salvaging: preload("res://scripts/settlement/construction_variants.gd").stairs(node, model.navigation.stair_landing(plan.cell, plan.direction).y - plan.cell.y)
		if plan.has("bush_payload"):
			BushView.sync(node, plan.cell, model.world_seed, int(plan.bush_payload.get("appearance_seed", -1)))
			BushView.transplant(node, plan.bush_payload)
		if well_count > 0 and not node.has_meta("construction_parts"):
			node.set_meta("well_plan_units", well_count)
			preload("res://scripts/settlement/well_view.gd").sync(node, well_count, 0, 3)
		if plan.kind == "tree" and not plant.is_empty(): TreeView.sync(node, plant)
		if plan.kind == "berry" and not plant.is_empty():
			BushView.sync(node, plan.relocation.source, model.world_seed, int(plant.get("appearance_seed", -1)))
			for child in node.get_children():
				if child is MeshInstance3D and str(child.name).begins_with("Berry"):
					child.visible = int(str(child.name).trim_prefix("Berry")) < plant.inventory.count("food")
		if plan.has("relocation") and plan.relocation.stage in ["rebuild", "salvage"]:
			var move: Dictionary = plan.relocation
			var slot := 0
			for resource: String in move.parts.amounts:
				for index in move.parts.count(resource):
					var piece := _entity("parts:%s:%s:%s" % [plan.id, resource, index], "road", move.pickup_cell, WorkerView.CARGO_ASSETS[resource])
					# Match the discrete rows and layers used by stored cargo.
					@warning_ignore("integer_division")
					piece.set_meta("placement_offset", Vector3((slot % 3 - 1) * 0.4, 0.12 + (slot / 6) * 0.18, (slot / 3 % 2 - 0.5) * 0.4) + (plan.get("placement_offset", Vector3.ZERO) if salvaging else Vector3.ZERO))
					piece.set_meta("relocation_piece", true)
					slot += 1
			if model.Relocation.portable_plant(plan) and not model.workers.any(func(worker): return worker.get("plant_plan_id", -1) == plan.id):
				var package := _entity("uprooted:%s" % plan.id, plan.kind, move.pickup_cell, asset_kind)
				if plan.kind == "tree": TreeView.sync(package, plant)
				if plan.kind == "berry":
					BushView.sync(package, move.source, model.world_seed, int(plant.get("appearance_seed", -1)))
					for child in package.get_children():
						if child is MeshInstance3D and str(child.name).begins_with("Berry"):
							child.visible = int(str(child.name).trim_prefix("Berry")) < plant.inventory.count("food")

		node.set_meta("placement_offset", Vector3.ZERO if salvaging else plan.get("placement_offset", Vector3.ZERO))
		if plan.kind == "platform" and not salvaging: model.Platforms.sync(node, model.Platforms.tier(planned_decks.get(plan.cell, 1)) if planning else int(plan.get("platform_tier", 1)))
		if planning and Construction.applies(plan):
			Construction.preview(node)
		elif Construction.applies(plan):
			var marker_base: Vector3i = plan.cell
			if plan.kind == "platform": marker_base -= Vector3i.UP * int(plan.get("platform_tier", 1))
			Construction.prepare(node, plan.kind, model.ground.has(marker_base) or model.rock_supports(marker_base))
		elif plan.kind in Catalog.SEEDS:
			pass # The small, solid seed marker stays legible against sand.
		elif not node.has_meta("tinted"):
			Assets.tint(node, Color(0.92, 0.67, 0.46, 1.0) if plan.get("deconstruction", false) else Color(0.75, 0.88, 0.78, 0.23), true)
			node.set_meta("tinted", true)

	for key: String in entity_views.keys():
		if not _wanted.has(key):
			entity_views[key].free()
			entity_views.erase(key)
		else:
			var node: Node3D = entity_views[key]
			var cell: Vector3i = node.get_meta("cell")
			Assets.Variation.apply(node, node.get_meta("asset"), cell, model.world_seed)
			var planned: bool = node.get_meta("planned", false)
			var offset: Vector3 = node.get_meta("placement_offset", Vector3.ZERO) if planned or node.get_meta("relocation_piece", false) else model.buildings.get(cell, {}).get("placement_offset", Vector3.ZERO)
			if key.begins_with("vine:"): offset = model.vines[cell].get("placement_offset", Vector3.ZERO)
			if key.begins_with("soil_bed:"): offset = Vector3.ZERO
			node.position = Navigation.point(cell) + offset
			if model.ground.has(cell) and (key.begins_with("tree:") or (key.begins_with("deposit:") and model.deposits[cell].kind == "berry") or key.begins_with("vine:") or node.get_meta("asset") in Catalog.SEEDS):
				node.position.y = model.navigation.surface_height(cell, node.position)
			if node.has_node("Roof") and not node.has_meta("construction_parts"):
				var supported: bool = model.Planning.upper_used(model, cell, node.get_meta("asset")) if planning else (not planned and model.needs_stack_support(cell))
				var natural_roof: bool = node.get_meta("asset") in Catalog.NATURAL_ROOFS or (node.get_meta("asset") == "sawmill" and int(model.buildings.get(cell, {}).get("sawmill_tier", 2)) == 3)
				node.get_node("Roof").visible = natural_roof or supported
				if node.has_node("StackSupport"):
					node.get_node("StackSupport").visible = supported or (node.get_meta("asset") == "sawmill" and natural_roof)
				node.get_node("Floor").visible = natural_roof or cell.y > model.surface_at(cell.x, cell.z).y
				for panel: Node3D in node.get_node("Roof").get_children():
					var panel_offset := panel.position.rotated(Vector3.UP, node.rotation.y)
					panel.visible = not model.Planning.upper_used(model, cell, node.get_meta("asset"), panel_offset) if planning else (planned or not model.roof_panel_covered(cell, panel_offset))

func _sync_pile_corners(model) -> void:
	var visited := {}
	for cell: Vector3i in store_views:
		if visited.has(cell) or not Piles.is_pile(model, cell):
			continue
		var members := Piles.members(model, cell)
		for member in members:
			visited[member] = true
			for index in 4:
				if store_views.has(member): store_views[member].get_node("CornerStone%d" % index).hide()
		for corner in Piles.outline(members):
			if store_views.has(corner.cell): store_views[corner.cell].get_node("CornerStone%d" % corner.index).show()

func _sync_routes(model, selected: int) -> void:
	# Keep navigation in world space; the HUD draws it in logical UI points.
	route_strokes.clear()
	for worker in model.workers:
		if (not show_routes and worker.id != selected) or worker.route_index >= worker.route.size():
			continue
		var previous: Vector3 = worker.position + Vector3.UP * 0.08
		var current: Vector3i = worker.cell
		var stroke := PackedVector3Array([previous])
		for index in range(worker.route_index, worker.route.size()):
			var target: Vector3i = worker.route[index]
			if fog_enabled and not model.exploration.contains(Navigation.point(target)):
				break
			var points: Array[Vector3] = [model.navigation.surface_point(target)]
			if model.navigation.ladder_cell(current, target) != null:
				points = model.navigation.ladder_waypoints(current, target, previous - Vector3.UP * 0.08)
			elif current.y == target.y and (model.navigation.terrain_shapes.has(current) or model.navigation.terrain_shapes.has(target)):
				points = model.navigation.slope_waypoints(current, target, previous - Vector3.UP * 0.08)
			for point in points:
				var next := point + Vector3.UP * 0.08
				stroke.append(next)
				previous = next
			current = target
		if stroke.size() > 1:
			route_strokes.append(stroke)
