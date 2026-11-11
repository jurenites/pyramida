extends Node3D
const Perf = preload("res://scripts/settlement/performance_log.gd")
const Houses = preload("res://scripts/settlement/house_groups.gd")
const HouseShell = preload("res://scripts/settlement/house_shell.gd")
const Economy = preload("res://scripts/settlement/economy.gd")
const Catalog = preload("res://data/settlement/catalog.gd")
const Navigation = preload("res://scripts/settlement/navigation.gd")
const Assets = preload("res://scripts/settlement/asset_library.gd")
const BushView = preload("res://scripts/settlement/bush_view.gd")
const TreeView = preload("res://scripts/settlement/tree_view.gd")
const StoneView = preload("res://scripts/settlement/stone_view.gd")
const WorkerView = preload("res://scripts/settlement/worker_view.gd")
const Construction = preload("res://scripts/settlement/construction_site_view.gd")
const Timber = preload("res://scripts/settlement/timber_kit.gd")
var planning := false
var bridge_view: Node3D
var last_planning := false
var planned_decks: Dictionary = {}
var fog_enabled := false
var scenery: Node3D
var water_view: Node3D
var roof_rain_view: Node3D
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
var growing_trees: Array[Vector3i] = []
var growing_bushes: Array[Vector3i] = []
var display_level := 3
var cutaway := false
var entity_views: Dictionary = {}
var _wanted: Dictionary = {}
var timber_motion: Node3D

func setup(model) -> void:
	bridge_view = Node3D.new(); add_child(bridge_view)
	scenery = Node3D.new()
	scenery.set_script(preload("res://scripts/settlement/scenery_view.gd"))
	add_child(scenery)
	scenery.setup(model)
	water_view = Node3D.new()
	water_view.set_script(preload("res://scripts/settlement/water_view.gd"))
	add_child(water_view)
	roof_rain_view=preload("res://scripts/settlement/roof_rain_view.gd").new(); add_child(roof_rain_view)
	for worker in model.workers:
		var view := Node3D.new()
		view.set_script(WorkerView)
		view.setup(worker.id)
		add_child(view)
		actors.append(view)
	architecture = Node3D.new()
	add_child(architecture)
	timber_motion = preload("res://scripts/settlement/timber_motion.gd").new()
	add_child(timber_motion)
	timber_motion.view = self
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
	timber_motion.bind_model(model)
	if last_model_id != model.get_instance_id():
		last_model_id = model.get_instance_id()
		last_revision = -1
	if last_revision != model.revision or appearance_revision != Assets.Appearance.revision or last_planning != planning:
		timber_motion.before_rebuild()
	if appearance_revision != Assets.Appearance.revision:
		for node in entity_views.values(): node.free()
		entity_views.clear()
		appearance_revision = Assets.Appearance.revision
		last_revision = -1
	if last_planning != planning:
		last_planning = planning
		# Only worksites switch between staged construction and a finished ghost.
		# Reconciliation handles merged decks and roof visibility in place.
		for key: String in entity_views.keys():
			if not key.begins_with("plan:"): continue
			entity_views[key].free()
			entity_views.erase(key)
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
		preload("res://scripts/settlement/rope_visuals.gd").sync(bridge_view, model)
		visibility_state.clear()
		Perf.end("view.entities", started)
		last_revision = model.revision
	var dynamic_started := Perf.begin()
	# Applied labour advances between model revisions; reveal only the pieces earned by work.
	for plan: Dictionary in model.plans.values():
		if plan.kind in model.Rooms.COSTS or plan.kind == "rope_bridge": continue
		if model.Deconstruction.is_salvage(plan): continue
		if planning and Construction.applies(plan): continue
		if plan.kind == "platform" and entity_views.has("plan:%s" % plan.id): model.Platforms.sync(entity_views["plan:%s" % plan.id], int(plan.get("platform_tier", 1)))
		if Construction.applies(plan):
			Construction.sync(entity_views["plan:%s" % plan.id], plan, model.workers)
	for cell: Vector3i in model.buildings:
		var building: Dictionary = model.buildings[cell]
		if building.kind not in ["windmill", "mill"]: continue
		var key := "building:%s" % cell
		if not entity_views.has(key): continue
		var working: bool = model.workers.any(func(worker): return worker.job.get("kind") == "process" and worker.job.get("target") == cell and worker.job.get("phase") == "work") and Economy.production_speed(model, cell) > 0
		preload("res://scripts/settlement/mill_view.gd").animate(entity_views[key], int(building.get("mill_tier", 3)), delta, working)
	# The clock advances even when no inventory or structure changes.
	roof_rain_view.sync(model)
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
			preload("res://scripts/settlement/plant_view.gd").sync_grass(garden_views[cell], model, cell)
			continue
		var hay: bool = model.Farming.is_hay(model, cell)
		if hay:
			preload("res://scripts/settlement/hay_surface.gd").animate(model, cell, garden_views[cell])
			continue
		var growth: float = 1.0 if garden.food > 0 else (0.06 + garden.growth / 24.0 * 0.94 if hay else 0.25 + garden.growth / 24.0 * 0.75)
		plants.scale.y = growth
		plants.position.y = 0.012 if hay else 0.30 * (1.0 - growth)
		if hay:
			sync_hay_quarters(plants, garden)
	# Mature scenery changes on model revisions; only seedlings need frame updates.
	for cell: Vector3i in growing_trees:
		TreeView.sync(tree_views[cell], model.trees[cell])
	for cell: Vector3i in growing_bushes:
		entity_views["deposit:%s" % cell].scale = Vector3.ONE * lerpf(0.18, 1.0, model.deposits[cell].seed_growth)
	Perf.end("view.animation", dynamic_started)
	var visibility_started := Perf.begin()
	var next_visibility := [last_model_id, model.revision, appearance_revision, model.exploration.revision, fog_enabled, cutaway, display_level]
	if visibility_state != next_visibility:
		visibility_state = next_visibility
		for child: Node3D in architecture.get_children():
			_sync_entity_visibility(child, model)
		for span: Node3D in bridge_view.get_children():
			var record: Dictionary = model.RopeBridges.get_record(model, span.get_meta("bridge_id"))
			span.visible = (not cutaway or maxf(record.start.y, record.end.y) <= display_level) and (not fog_enabled or (model.exploration.contains(record.start) and model.exploration.contains(record.end)))
			for body in span.get_children():
				if body is StaticBody3D: body.collision_layer = 4 if span.visible else 0
		for cell: Vector3i in water_view.sources:
			var source: Node3D = water_view.sources[cell]
			source.visible = not fog_enabled or model.exploration.contains(Navigation.point(cell))
			for child in source.get_children():
				if child is StaticBody3D:
					child.collision_layer = 1 if source.visible else 0
	else:
		# Seedlings can grow into the fog between exploration/model revisions.
		for cell: Vector3i in growing_trees:
			_sync_entity_visibility(tree_views[cell], model)
	Perf.end("view.visibility", visibility_started)
	_sync_routes(model, selected)
	timber_motion.advance(delta)

func bridge_node(id: int) -> Node3D:
	for span: Node3D in bridge_view.get_children():
		if span.get_meta("bridge_id", -1) == id: return span
	return null

func _sync_entity_visibility(node: Node3D, model) -> void:
	var cell: Vector3i = node.get_meta("cell", Vector3i.ZERO)
	var revealed := true
	if fog_enabled:
		revealed = TreeView.fully_revealed(node, model.exploration) if tree_views.get(cell) == node else model.exploration.contains(Navigation.point(cell))
	node.visible = (not cutaway or cell.y <= display_level) and revealed
	if node.has_meta("collider"):
		node.get_meta("collider").collision_layer = (2 if node.get_meta("planned", false) else 1) if node.visible and not node.get_meta("relocation_piece", false) and not node.get_meta("resource_empty", false) else 0

static func sync_hay_quarters(plants: Node3D, crop: Dictionary) -> void:
	var farming = preload("res://scripts/settlement/farming.gd")
	var standing: int = farming.standing_quarters(crop)
	for tuft: Node3D in plants.get_children():
		var quarter: int = int(tuft.get_meta("hay_quarter", farming.quarter_at(tuft.position)))
		tuft.visible = (standing & (1 << quarter)) != 0 or float(crop.get("quarter_growth", [crop.growth, crop.growth, crop.growth, crop.growth])[quarter]) > 0.0

func _entity(key: String, kind: String, cell: Vector3i, asset_kind := "", direction := 0) -> Node3D:
	_wanted[key] = true
	var variant := kind if asset_kind.is_empty() else asset_kind
	if entity_views.has(key) and entity_views[key].get_meta("asset") != variant:
		entity_views[key].free()
		entity_views.erase(key)
	if not entity_views.has(key):
		var node := _place(kind, cell, variant)
		node.set_meta("asset", variant)
		node.set_meta("planned", key.begins_with("plan:"))
		if node.has_meta("collider"):
			node.get_meta("collider").set_meta("entity_key", key)
		entity_views[key] = node
	var result: Node3D = entity_views[key]
	# Plan IDs survive relocation/retargeting, so their cell can change in place.
	if result.get_meta("cell") != cell:
		result.set_meta("cell", cell)
		if result.has_meta("collider"): result.get_meta("collider").set_meta("cell", cell)
	# Visibility/picking belong to the visibility pass. Resetting them here
	# briefly reveals every fog-hidden subtree on each inventory update.
	var angle := -direction * PI * 0.5
	if not is_equal_approx(result.rotation.y, angle): result.rotation.y = angle
	return result

func _rebuild(model) -> void:
	var section_started := Perf.begin()
	# Reconcile identity, preserving unchanged assets, colliders and materials.
	_wanted.clear()
	var dismantling := {}
	for plan: Dictionary in model.plans.values():
		if plan.kind in model.Rooms.COSTS or plan.kind == "rope_bridge": continue
		if plan.get("deconstruction", false) and plan.relocation.stage == "dismantle":
			dismantling[plan.cell] = true
	garden_views.clear()
	store_views.clear()
	tree_views.clear()
	growing_trees.clear()
	growing_bushes.clear()
	for cell: Vector3i in model.deposits:
		var deposit: Dictionary = model.deposits[cell]
		var node := _entity("deposit:%s" % cell, deposit.kind, cell)
		for child in node.get_children():
			if child is MeshInstance3D:
				child.visible = not child.name.begins_with("Berry") or int(str(child.name).trim_prefix("Berry")) < deposit.inventory.count("food")
		if deposit.kind == "berry":
			BushView.sync(node, cell, model.world_seed, int(deposit.get("appearance_seed", -1)))
			if deposit.has("seed_growth"):
				node.scale = Vector3.ONE * lerpf(0.18, 1.0, deposit.seed_growth)
				if float(deposit.seed_growth) < 1.0: growing_bushes.append(cell)
		if deposit.kind == "limestone":
			StoneView.sync(node, cell, model.world_seed, deposit.inventory, false, preload("res://scripts/settlement/solid_islands.gd").enabled(model) and model.generator_version>=10)
	Perf.end("view.reconcile.deposits", section_started)
	section_started = Perf.begin()
	for cell: Vector3i in model.platforms:
		if dismantling.has(cell) or (planning and not planned_decks.has(cell)): continue
		var deck := _entity("platform:%s" % cell, "platform", cell)
		model.Platforms.sync(deck, model.Platforms.tier(model.platforms[cell]))
	for cell: Vector3i in model.stairs:
		if dismantling.has(cell): continue
		var stair := _entity("stairs:%s" % cell, "stairs", cell, "", model.stairs[cell])
		preload("res://scripts/settlement/construction_variants.gd").stairs(stair, model.navigation.stair_landing(cell, model.stairs[cell]).y - cell.y)
	for cell: Vector3i in model.stores:
		if dismantling.has(cell): continue
		var kind: String = model.buildings[cell].kind if model.buildings.has(cell) else "stockpile"
		if kind == "stockpile" and model.stores[cell].total() == 0: continue
		var key := "%s:%s" % ["building" if model.buildings.has(cell) and kind not in Catalog.STORAGE else "stockpile", cell]
		var node := _entity(key, kind, cell, "salvage" if kind == "stockpile" else "", int(model.buildings[cell].direction) if model.buildings.has(cell) else 0)
		if kind == "hay_barn": preload("res://scripts/settlement/hay_barn_view.gd").sync(model, cell, node)
		if kind == "stone_storage":
			var tier := int(model.buildings[cell].get("storage_tier", 1))
			preload("res://scripts/settlement/stone_storage_view.gd").sync(node, tier)
		store_views[cell] = node
		if kind == "stone_storage" and node.has_meta("depot_grid"):
			preload("res://scripts/settlement/stone_storage_view.gd").sync_stock(node, model.stores[cell], cell, model.world_seed)
			continue
		for child in node.get_children():
			if child.has_meta("timber_overflow_slot") and int(child.get_meta("timber_overflow_slot")) >= model.stores[cell].count("log"): child.free()
		if not node.has_meta("logs"):
			var log_nodes: Array[Node3D] = []
			for index in 12:
				var log_node := Assets.create("log")
				log_node.set_meta("variation_exempt", true)
				log_node.transform=preload("res://scripts/settlement/stored_goods_layout.gd").log_pose(kind,index)
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
		for resource in ["food", "grain", "plank", "stone", "block", "pottery", "flour", "clay", "brick", "ore", "imbrex"]:
			var amount: int = model.stores[cell].count(resource)
			if kind in ["goods_rack", "small_warehouse"]: amount = mini(amount, maxi(0, 8 - slot))
			for index in (amount if resource in ["stone", "block", "pottery"] else mini(amount, 4)):
				var cargo := Assets.create("bread" if resource == "food" else WorkerView.CARGO_ASSETS[resource])
				cargo.set_meta("resource", resource)
				if resource in ["stone", "block"]:
					var stone_mesh: MeshInstance3D = cargo.get_node("Stone")
					var shape_seed := StoneView.Random.world_coordinate_seed(cell.x, cell.z, model.world_seed, 610 + index)
					stone_mesh.mesh = StoneView.block_mesh(shape_seed) if resource == "block" else StoneView.raw_mesh(shape_seed)
					if kind == "stone_storage" and resource == "stone":
						stone_mesh.scale = Vector3.ONE * 0.7
						stone_mesh.position.y = -0.15
				cargo.transform=preload("res://scripts/settlement/stored_goods_layout.gd").cargo_pose(kind,resource,slot)
				stock.add_child(cargo)
				slot += 1
	Perf.end("view.reconcile.stores", section_started)
	section_started = Perf.begin()
	for cell: Vector3i in model.soil_beds:
		if not dismantling.has(cell) or model.Relocation.kind_at(model, cell) != "soil_bed":
			_entity("soil_bed:%s" % cell, "soil_bed", cell)
	for cell: Vector3i in model.gardens:
		if dismantling.has(cell) and (not model.Farming.is_hay(model, cell) or model.buildings.get(cell, {}).get("kind") == "hay_field"): continue
		var kind: String = "grass_patch" if model.gardens[cell].get("species") == "grass" else ("hay_field" if model.Farming.is_hay(model, cell) else "garden")
		garden_views[cell] = _entity("garden:%s" % cell, kind, cell, "", int(model.Farming.field_layout(model, cell).get("direction", 0)) if kind == "hay_field" else 0)
		if kind == "hay_field":
			preload("res://scripts/settlement/hay_field_view.gd").sync(model, cell, garden_views[cell], dismantling)
			preload("res://scripts/settlement/hay_surface.gd").sync(model, cell, garden_views[cell])
	Perf.end("view.reconcile.gardens", section_started)
	section_started = Perf.begin()
	for cell: Vector3i in model.trees:
		var node := _entity("tree:%s" % cell, "tree", cell, TreeView.asset(model.trees[cell]))
		tree_views[cell] = node
		TreeView.sync(node, model.trees[cell])
		if float(model.trees[cell].get("seed_growth", 1.0)) < 1.0: growing_trees.append(cell)
	for cell: Vector3i in model.vines:
		var vine := _entity("vine:%s" % cell, "vine_tree", cell)
		preload("res://scripts/settlement/vine_view.gd").sync(vine, model, cell)
	Perf.end("view.reconcile.nature", section_started)
	section_started = Perf.begin()
	for cell: Vector3i in model.wells:
		if dismantling.has(cell): continue
		var building: Dictionary = model.buildings.get(cell, {})
		var kind: String = building.get("kind", "well")
		var node := _entity("well:%s" % cell, kind, cell, "", int(building.get("direction", 0)))
		preload("res://scripts/settlement/well_view.gd").sync(node, model.Hydrology.units(building), model.wells[cell].count("water"), model.wells[cell].capacity, kind == "waterworks")
	for cell: Vector3i in model.buildings:
		if dismantling.has(cell): continue
		var building: Dictionary = model.buildings[cell]
		if building.kind in Catalog.STORAGE or building.kind in ["hay_field", "well", "waterworks"]:
			continue
		var node := _entity("building:%s" % cell, building.kind, cell, "", int(building.direction))
		if building.kind=="support" and building.has("support_yaw"): node.rotation.y=float(building.support_yaw)
		if building.kind == "claypit": preload("res://scripts/settlement/claypit_view.gd").sync(node, model, cell)
		if building.kind == "road": preload("res://scripts/settlement/stone_road.gd").sync(node, cell, model.world_seed, model)
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
		if plan.kind in model.Rooms.COSTS or plan.kind == "rope_bridge": continue
		if plan.get("collect_vine", false) or plan.get("collect_bush", false): continue
		if planning and plan.kind == "platform" and model.Planning.includes(plan) and not planned_decks.has(plan.cell): continue
		var plant: Dictionary = {}
		if plan.has("relocation") and model.Relocation.portable_plant(plan):
			var field: String = {"tree": "trees", "berry": "deposits", "garden": "gardens", "vine_tree": "vines"}[plan.kind]
			plant = plan.relocation.payload.get(field, model.get(field).get(plan.relocation.source, {}))
		var asset_kind := TreeView.asset(plant) if plan.kind == "tree" else ""
		if plan.kind == "vine_tree": asset_kind = "seed_vine"
		if plan.has("bush_payload"): asset_kind = "berry"
		if plan.get("house_upgrade", false): asset_kind = "salvage"
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
		if plan.get("deconstruction", false) and not salvaging:
			# Keep the actual authored frame while the citizen dismantles it.
			var plan_key := "plan:%s" % plan.id
			if not entity_views.has(plan_key):
				for source_key: String in entity_views.keys():
					var source: Node3D = entity_views[source_key]
					if source.get_meta("cell") != plan.relocation.source or source.get_meta("asset") != plan.kind or source.get_meta("planned", false): continue
					entity_views.erase(source_key)
					entity_views[plan_key] = source
					source.set_meta("planned", true)
					if source.has_meta("collider"): source.get_meta("collider").set_meta("entity_key", plan_key)
					break
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
		if plan.has("delivered"):
			var slot := 0
			for resource: String in plan.delivered.amounts:
				for index in plan.delivered.count(resource):
					var piece := _entity("staged:%s:%s:%s" % [plan.id, resource, index], "road", plan.cell, "bread" if resource == "food" else WorkerView.CARGO_ASSETS[resource])
					piece.set_meta("placement_offset", Vector3((slot % 3 - 1) * 0.4, 0.14 + (slot / 3) * 0.18, Catalog.Reviewed.size(plan.kind).z * 0.5 + 0.25) if Catalog.Reviewed.has(plan.kind) else Vector3(0, 0.14, 1.25))
					piece.set_meta("relocation_piece", true)
					slot += 1
		if plan.has("relocation") and plan.relocation.stage in ["rebuild", "salvage"]:
			var move: Dictionary = plan.relocation
			var slot := 0
			for resource: String in move.parts.amounts:
				for index in move.parts.count(resource):
					var piece := _entity("parts:%s:%s:%s" % [plan.id, resource, index], "road", move.pickup_cell, "bread" if resource == "food" else WorkerView.CARGO_ASSETS[resource])
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
		if plan.kind=="support" and plan.has("support_yaw"):
			node.rotation.y=float(plan.support_yaw)
			preload("res://scripts/settlement/structure_frame.gd").sync_foundation(node, model, plan.cell, plan.get("placement_offset", Vector3.ZERO), float(plan.support_yaw))
			if node.has_node("Deck"): node.get_node("Deck").rotation.y=(posmod(hash([model.world_seed,plan.cell]),2)+int(plan.direction))*PI/2
		if plan.kind == "platform" and not salvaging: model.Platforms.sync(node, model.Platforms.tier(planned_decks.get(plan.cell, 1)) if planning else int(plan.get("platform_tier", 1)))
		if planning and Construction.applies(plan):
			Construction.preview(node)
		elif plan.get("house_upgrade", false):
			# The existing occupied House remains visible throughout the work.
			pass
		elif Construction.applies(plan):
			var marker_base: Vector3i = plan.cell
			if plan.kind == "platform": marker_base -= Vector3i.UP * int(plan.get("platform_tier", 1))
			Construction.prepare(node, plan.kind, model.ground.has(marker_base) or model.rock_supports(marker_base))
		elif plan.get("deconstruction", false):
			pass # Dismantling retains authored materials and physical stock.
		elif plan.kind in Catalog.SEEDS:
			pass # The small, solid seed marker stays legible against sand.
		elif not node.has_meta("tinted"):
			Assets.tint(node, Color(0.92, 0.67, 0.46, 1.0) if plan.get("deconstruction", false) else Color(0.75, 0.88, 0.78, 0.23), true)
			node.set_meta("tinted", true)

	Perf.end("view.reconcile.plans", section_started)
	section_started = Perf.begin()
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
			if key.begins_with("garden:") and model.Farming.is_hay(model, cell): offset = model.Farming.field_layout(model, cell).get("placement_offset", Vector3.ZERO)
			if key.begins_with("vine:"): offset = model.vines[cell].get("placement_offset", Vector3.ZERO)
			if key.begins_with("soil_bed:"): offset = Vector3.ZERO
			var position_ := Navigation.point(cell) + offset
			if key.begins_with("building:") or key.begins_with("stockpile:") or key.begins_with("plan:") or key.begins_with("platform:") or key.begins_with("stairs:"):
				position_.y += preload("res://scripts/settlement/structure_elevation.gd").base_shift(model,cell,node.get_meta("asset"),0,offset)
			if model.ground.has(cell) and (key.begins_with("tree:") or (key.begins_with("deposit:") and model.deposits[cell].kind == "berry") or key.begins_with("vine:") or node.get_meta("asset") in Catalog.SEEDS):
				position_.y = model.navigation.surface_height(cell, position_)
			if not node.position.is_equal_approx(position_): node.position = position_
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
			if node.get_meta("asset") in ["log_shed", "hay_barn"] and node.has_node("Canopy") and not node.has_meta("construction_parts"):
				node.get_node("Canopy").visible = not model.Planning.upper_used(model, cell, "log_shed") if planning else not model.roof_panel_covered(cell, Vector3.ZERO)
	var connected_frames_started := Perf.begin()
	preload("res://scripts/settlement/connected_frames.gd").sync(model, store_views)
	Perf.end("view.placement.connected_frames", connected_frames_started)
	var structure_frame_started := Perf.begin()
	preload("res://scripts/settlement/structure_frame.gd").sync(model, entity_views)
	Perf.end("view.placement.structure_frame", structure_frame_started)
	for cell: Vector3i in store_views:
		var node: Node3D = store_views[cell]
		if model.buildings.get(cell, {}).get("kind", "") == "log_shed" and not node.has_meta("construction_parts"):
			preload("res://scripts/settlement/shed_roof.gd").sync(node, hash([model.world_seed, cell]))
		elif model.buildings.get(cell, {}).get("kind", "") == "hay_barn" and not node.has_meta("construction_parts"):
			preload("res://scripts/settlement/barn_roof.gd").sync(node, hash([model.world_seed, cell]))
	var house_posts_started := Perf.begin()
	preload("res://scripts/settlement/house_posts.gd").sync(model, entity_views)
	Perf.end("view.placement.house_posts", house_posts_started)
	var house_roofs_started := Perf.begin()
	preload("res://scripts/settlement/house_roofs.gd").sync(model, entity_views, planning)
	Perf.end("view.placement.house_roofs", house_roofs_started)
	for node: Node3D in entity_views.values():
		if node.get_meta("planned",false) or node.has_meta("construction_parts"): continue
		var cell: Vector3i = node.get_meta("cell",Vector3i.ZERO)
		if model.buildings.has(cell): preload("res://scripts/settlement/rope_visuals.gd").roof_landing(node, model, cell)
	preload("res://scripts/settlement/home_assembly.gd").sync(model,entity_views)
	Perf.end("view.reconcile.placement", section_started)

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
