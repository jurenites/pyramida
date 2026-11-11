extends SceneTree
const Model = preload("res://scripts/settlement/world_model.gd")
const Fixture = preload("res://tests/settlement/reviewed_balance_test.gd")
const Depot = preload("res://scripts/settlement/stone_storage_view.gd")
const Assets = preload("res://scripts/settlement/asset_library.gd")
const View = preload("res://scripts/settlement/world_view.gd")
var failures: Array[String] = []
func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message); printerr("FAIL: " + message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var fixture := Fixture.new()
	var world = fixture.fixture()
	fixture.finish(world, "stone_storage", Vector3i(5, 0, 0))
	check(fixture.failures.is_empty(), "Depot builds")
	var inventory = world.stores[Vector3i(5, 0, 0)]
	check(inventory.capacity == 18 and inventory.slots.size() == 18, "18 shared positions")
	inventory.store("stone", 2); inventory.store("block"); inventory.store("stone")
	check(inventory.slots.slice(0, 4) == ["stone", "stone", "block", "stone"], "Delivery order keeps mixed cargo in place")
	inventory.reserve(0, "stone"); inventory.pickup(0)
	inventory.reserve(0, "stone"); inventory.pickup(0)
	check(inventory.slots[1] == "" and inventory.slots[2] == "block", "Pickup leaves other cargo in place")
	inventory.store("block")
	check(inventory.slots[1] == "block" and inventory.slots[2] == "block", "New cargo fills first vacancy")
	while inventory.total() < 18: inventory.store("stone" if inventory.total() % 2 == 0 else "block")
	check(not inventory.store("stone"), "Nineteenth delivery rejected")
	var view := View.new(); root.add_child(view); view.setup(world)
	await process_frame
	var depot: Node3D = view.store_views[Vector3i(5, 0, 0)]
	check(depot.has_meta("depot_grid") and depot.get_node("EconomyStock").get_child_count() == 18, "Live view shows all delivered cargo")
	for index in 18:
		var cargo: MeshInstance3D = depot.get_node("EconomyStock/Slot%d" % index)
		var base := cargo.position + Vector3.UP * cargo.mesh.get_aabb().position.y * cargo.scale.y
		var height := Depot.PAD_HEIGHT
		if index >= 9:
			var below: MeshInstance3D = depot.get_node("EconomyStock/Slot%d" % (index - 9))
			height = below.position.y + below.mesh.get_aabb().end.y * below.scale.y
		check(base.is_equal_approx(Depot.slot_position(index, height)), "Cargo touches pad or item below")
		check(cargo.get_meta("resource") == inventory.slots[index], "Slot displays correct resource")
	var retained := depot.get_node("EconomyStock/Slot0")
	inventory.reserve(0, "block"); inventory.pickup(0)
	Depot.sync_stock(depot, inventory, Vector3i(5, 0, 0), world.world_seed)
	check(depot.get_node("EconomyStock/Slot0") == retained, "Other item meshes remain stable")
	var restored = Model.new()
	check(restored.restore(JSON.parse_string(JSON.stringify(world.snapshot()))), "Depot save loads")
	check(restored.stores[Vector3i(5, 0, 0)].slots == inventory.slots, "Exact vacancies survive reload")
	var original: Array = inventory.slots.duplicate()
	inventory.slots.clear() # Old save: amounts existed before physical slots.
	var migrated = Model.new()
	check(migrated.restore(JSON.parse_string(JSON.stringify(world.snapshot()))), "Old Depot migrates")
	check(migrated.stores[Vector3i(5, 0, 0)].slots.size() == 18 and migrated.stores[Vector3i(5, 0, 0)].total() == inventory.total(), "Migration preserves quantities")
	inventory.slots.assign(original)
	inventory.slots[0] = "" # Malformed layout must not silently hide a stone.
	check(not Model.new().restore(JSON.parse_string(JSON.stringify(world.snapshot()))), "Mismatched saved slots rejected")
	inventory.slots.assign(original)
	var components := Assets.Appearance.defaults("stone_storage")
	check(components.any(func(part): return part.component == "PostLeftBack"), "Post editable in Blueprints")
	check(not Assets.Appearance.can_resize(components.filter(func(part): return part.component == "PostLeftBack")[0]), "Shared stock stays rigid; widening joins modules")
	check(not components.any(func(part): return part.component.begins_with("Shelf") or part.component.begins_with("Middle")), "Open frame has no middle shelf or rails")
	var floor_: MeshInstance3D = depot.get_node("Floor")
	check(is_equal_approx(floor_.position.y + floor_.mesh.get_aabb().end.y, Depot.PAD_HEIGHT), "Raised pad height")
	check(floor_.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON, "Pad casts real shadows")
	var arrays := floor_.mesh.surface_get_arrays(0)
	for i in arrays[Mesh.ARRAY_VERTEX].size():
		if arrays[Mesh.ARRAY_NORMAL][i].y > 0.5:
			check(arrays[Mesh.ARRAY_COLOR][i].is_equal_approx(Depot.Palette.SAND_SURFACE), "Pad top matches surrounding sand")
	check(not Assets.Appearance.decode(Assets.Appearance.encode(components)).is_empty(), "Editable model roundtrips")
	var pair := Model.Inventory.new(); pair.capacity = 18; pair.enable_slots()
	pair.store("stone"); pair.store("block")
	pair.slots[1] = ""; pair.slots[9] = "block"
	var pair_view := Assets.create("stone_storage")
	Depot.sync_stock(pair_view, pair, Vector3i.ZERO, 37)
	var upper: MeshInstance3D = pair_view.get_node("EconomyStock/Slot9")
	var previous_height := upper.position.y
	pair.reserve(0, "stone"); pair.pickup(0)
	Depot.sync_stock(pair_view, pair, Vector3i.ZERO, 37)
	check(upper.position.y < previous_height and is_equal_approx(upper.position.y + upper.mesh.get_aabb().position.y * upper.scale.y, Depot.PAD_HEIGHT), "Upper item settles on pad after lower pickup")
	check(pair.total() == 1 and pair.slots[9] == "block", "Settling preserves inventory and assigned column")
	pair_view.free()
	view.queue_free(); fixture.free(); await process_frame
	print("PASS: Depot grid, stable deliveries/pickups, save migration and editable parts" if failures.is_empty() else "FAIL: Depot storage")
	quit(0 if failures.is_empty() else 1)
