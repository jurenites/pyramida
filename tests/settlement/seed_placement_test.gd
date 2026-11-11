extends SceneTree
const Model = preload("res://scripts/settlement/world_model.gd")
const HUD = preload("res://scripts/settlement/hud.gd")
var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world = Model.new()
	var spot := Vector3i.ZERO
	world.ground[spot] = true
	for kind in ["seed_tree", "seed_palm", "seed_vegetables"]:
		check(world.build_error(kind, spot).is_empty(), kind + " needs soil only at its own root spot")
		world.terrain_shapes[spot] = [0.0, 0.1, 0.1, 0.0]
		check(world.build_error(kind, spot).is_empty(), kind + " accepts uneven soil")
		world.trees[Vector3i.RIGHT] = {"kind": "living"}
		check(world.build_error(kind, spot).is_empty(), kind + " can be planted beside an existing tree")
		world.trees[spot] = {"kind": "living"}
		check(not world.build_error(kind, spot).is_empty(), kind + " cannot replace an existing root")
		world.trees.clear()
		world.buildings[Vector3i.RIGHT] = {"kind": "house", "direction": 0}
		check(not world.build_error(kind, spot).is_empty(), kind + " rejects the actual building footprint")
		world.buildings.clear()
		world.plans[1] = {"id": 1, "kind": "seed_tree", "cell": Vector3i.RIGHT, "direction": 0}
		check(world.build_error(kind, spot).is_empty(), kind + " can sit beside another seed order")
		world.plans[1].cell = spot
		check(not world.build_error(kind, spot).is_empty(), kind + " cannot duplicate a seed order")
		world.plans[1].kind = "house"
		world.plans[1].cell = Vector3i.RIGHT
		check(not world.build_error(kind, spot).is_empty(), kind + " protects queued building footprints")
		world.plans.clear()
		world.platforms[Vector3i.UP] = true
		world.soil_beds[Vector3i.UP] = {"materials": {"log": 1}}
		check(not world.build_error(kind, Vector3i.UP).is_empty(), kind + " rejects soil beds on a platform")
		world.platforms.clear()
		world.soil_beds.clear()
		world.water_sources[spot] = {"kind": "puddle"}
		check(not world.build_error(kind, spot).is_empty(), kind + " cannot be placed in water")
		world.water_sources.clear()
	var high := Vector3i(20, 4, 20)
	world.ground[high] = true
	check(world.build_error("seed_tree", high).is_empty(), "Elevated natural soil does not need a neighbouring floor")
	var hud := HUD.new()
	root.add_child(hud)
	world.vine_discovered = true
	world.vine_roots = 2
	world.bush_discovered = true
	hud.update(world, -1, 1)
	check(not hud.category_lists.has("nature"), "No Nature construction category")
	for kind in ["seed_tree", "seed_palm"]:
		check(not hud.buttons.has(kind), "Seed buttons removed: " + kind)
	for kind in ["seed_vegetables", "seed_bush", "seed_vine", "seed_grass"]:
		check(not hud.buttons.has(kind), "Nature excludes " + kind)
	hud.free()
	for failure in failures: printerr("FAIL: " + failure)
	if failures.is_empty(): print("PASS: soil-only seed placement, close planting, building exclusion and no Nature menu")
	quit(int(not failures.is_empty()))
