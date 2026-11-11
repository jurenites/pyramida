extends SceneTree
const Fixture = preload("res://scripts/settlement/rope_bridge_fixture.gd")
const Bridges = Fixture.Bridges
var failures := 0
func check(value: bool, message: String) -> void:
	if not value: failures += 1; push_error(message)
func _initialize() -> void: call_deferred("run")
func record(a: Vector3, b: Vector3) -> Dictionary:
	return {"start": a, "end": b, "a": Vector3i(a.round()), "b": Vector3i(b.round()), "curve_version": 2}
func run() -> void:
	var base := record(Vector3(-4,3,0), Vector3(4,3,0))
	check(Bridges.intersects(base, record(Vector3(0,3,-4),Vector3(0,3,4))), "Crossing decks collide")
	check(Bridges.intersects(base, record(Vector3(-4,3,0.6),Vector3(4,3,0.6))), "Parallel rails need lateral clearance")
	check(Bridges.intersects(base, record(Vector3(3.7,3,-4),Vector3(3.7,3,0.1))), "Endposts do not get an intersection exemption")
	check(not Bridges.intersects(base, record(Vector3(0,6,-4),Vector3(0,6,4))), "Separated elevated overpasses remain valid")
	var world = Fixture.create()
	var id: int = world.plans.keys()[0]
	check(not Bridges.error(world, Fixture.START + Vector3(0,0,0.2), Fixture.END + Vector3(0,0,-0.2)).is_empty(), "Pending spans also block overlapping bridges")
	var old: Dictionary = world.plans[id].bridge.duplicate(true)
	check(Bridges.move_end(world, id, 0, Vector3.ZERO) == -1 and world.plans[id].bridge == old, "Invalid move leaves original plan untouched")
	var plan: Dictionary = world.plans[id]
	Bridges.complete(world, plan)
	var next: int = Bridges.move_end(world, id, 0, Fixture.START + Vector3(-0.1,0,0.2))
	check(next != -1 and not world.bridges.has(id), "Completed span becomes a rebuild plan when moved")
	if next != -1:
		check(world.plans[next].bridge.end == old.end and world.navigation.route(old.a, old.b).is_empty(), "Fixed endpoint remains and old routing is removed during rebuild")
		var recovered := {}
		for pile: Dictionary in world.plans.values():
			if world.Deconstruction.is_salvage(pile):
				for kind: String in pile.relocation.parts.amounts: recovered[kind] = int(recovered.get(kind,0)) + pile.relocation.parts.count(kind)
		check(recovered == plan.materials, "Move recovers the exact original Rope and Planks")
	var copy = Fixture.Model.new()
	check(copy.restore(JSON.parse_string(JSON.stringify(world.snapshot()))), "Moved span plus reusable materials survive save/load")
	var roofs = Fixture.Model.new()
	for centre: Vector3i in [Vector3i(0,0,0),Vector3i(8,1,2)]:
		for cell: Vector3i in roofs.Grid.support_cells(centre): roofs.ground[cell] = true
		roofs.buildings[centre] = {"kind": "house", "direction": 0, "house_tier": 2}
		roofs.exploration.reveal(Vector3(centre))
	roofs.unlock_production("sawmill"); roofs.unlock_production("rope_maker"); roofs.rebuild_navigation()
	var a := Vector3(0.75,2,0.1); var b := Vector3(7.25,3,1.9)
	var citizen: Dictionary = Fixture.create(false).workers[0].duplicate(true)
	citizen.cell = Vector3i(1,2,0); citizen.position = a; citizen.role = "idle"
	roofs.workers.append(citizen)
	check(Bridges.request(roofs,a,b), "Unequal-height real building roofs accept continuous landings: " + roofs.last_message)
	if not roofs.plans.is_empty():
		check(not roofs.Relocation.source_error(roofs,Vector3i.ZERO).is_empty(), "Attached roof cannot be relocated")
		check(not roofs.Deconstruction.request(roofs, Vector3i.ZERO), "Attached roof cannot be removed")
		check(not roofs.TerrainEditor.edit_error(roofs,Vector3i.ZERO,"terrain_raise").is_empty(), "Attached support terrain is protected")
		check(not Bridges.construction_error(roofs,"house",Vector3i(1,2,0),0,Vector3.ZERO).is_empty(), "New buildings cannot obstruct a planned bridge")
		var bridge_plan: Dictionary = roofs.plans.values()[0]; Bridges.complete(roofs,bridge_plan)
		check(not roofs.navigation.route(bridge_plan.bridge.a,bridge_plan.bridge.b).is_empty(), "Roof span is part of the normal routing graph")
		check(copy.restore(JSON.parse_string(JSON.stringify(roofs.snapshot()))), "Real rooftop bridge saves correctly")
	# Older bridge records keep their original curve and price.
	var legacy = Fixture.create(false)
	check(Bridges.request(legacy,Fixture.START,Fixture.END), "Legacy fixture")
	var legacy_plan: Dictionary = legacy.plans.values()[0]
	legacy_plan.bridge.erase("curve_version"); legacy_plan.materials = Bridges.record_cost(legacy_plan.bridge)
	legacy_plan.required = legacy_plan.materials.plank + legacy_plan.materials.rope
	check(copy.restore(JSON.parse_string(JSON.stringify(legacy.snapshot()))), "Previous prototype saves retain the old curve and exact construction cost")
	print("PASS: bridge intersection, roof support, independent moves, salvage and legacy saves" if failures == 0 else "FAIL: %d bridge editing checks" % failures)
	quit(1 if failures else 0)
