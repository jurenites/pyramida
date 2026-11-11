extends SceneTree
const Rules = preload("res://scripts/settlement/modular_house_rules.gd")
const Generator = preload("res://scripts/settlement/modular_house_generator.gd")
const Services = preload("res://scripts/settlement/modular_house_services.gd")
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; printerr("FAIL: " + message)
func _initialize() -> void:
	var rooms := Rules.rooms()
	check(rooms.size() == 3, "Two lower rooms and an upper room")
	check(Rules.bounds(rooms[0]).size == Vector3(2, 2, 2), "Exact minimum room module")
	check(rooms[1].entry.x == Rules.bounds(rooms[0]).end.x, "Child entry meets parent wall")
	check(Rules.terrace_tiles(rooms).size() == 7, "Upper room consumes 2 m²; balcony contributes 1 m²")
	check(not Rules.obstruction(rooms, Rules.flue(rooms, false)).is_empty(), "Upper room blocks straight exhaust")
	check(Rules.obstruction(rooms, Rules.flue(rooms, true)).is_empty(), "Exterior exhaust clears occupied rooms")
	check(Rules.supports(rooms).filter(func(s): return s.kind == "brace").size() == 2, "One-metre overhang generates paired braces")
	for support in Rules.supports(rooms):
		if support.kind == "brace":
			var delta: Vector3 = support.b - support.a
			check(is_equal_approx(absf(delta.y), absf(delta.z)), "Braces rise at 45 degrees")
	var extended := Rules.rooms(true, 2)
	check(Rules.supports(extended).filter(func(s): return s.kind == "pillar").size() == 2, "Longer overhang generates grounded pillars")
	check(Rules.supports(extended).filter(func(s): return s.kind == "tie").size() == 1, "Two-metre exposed pillars have a tie beam")
	check(Rules.obstruction(extended, Rules.flue(extended, true)).is_empty(), "Rerouted exhaust follows extended roof")
	var lower := Rules.rooms(false)
	check(Rules.terrace_tiles(lower).size() == 9, "Removing upper room restores outdoor area")
	check(Rules.obstruction(lower, Rules.flue(lower, false)).is_empty(), "Removing obstruction restores straight flue")
	check(Rules.supports(lower).all(func(s): return s.kind == "balcony_joist"), "Upper supports disappear with upper room")
	var terrace_areas := {}
	for seed_ in 48:
		var generated_rooms := Rules.layout(seed_)
		terrace_areas[Rules.terrace_tiles(generated_rooms).size()]=true
		check(generated_rooms==Rules.layout(seed_),"Room layout is deterministic")
		check(Rules.obstruction(generated_rooms,Rules.flue(generated_rooms,true)).is_empty(),"Generated metal exhaust clears every room")
		for tier in [0,1]:
			var generated := Generator.generate(generated_rooms,seed_,tier)
			for room in generated.rooms:
				check(Rules.bounds(room.record).size==Vector3(2,2,2),"Generated rooms preserve stock module size")
				for wall in room.walls:
					if wall.opening=="window": check(Generator.clear_window(wall,generated.supports,tier),"Generated layout keeps supports out of windows")
	check(terrace_areas.size()>1,"Terrace area varies along with footprint")
	for upper in [true, false]:
		for reach in [1.0, 2.0]:
			for tier in [0, 1]:
				for seed_ in 32:
					var layout := Rules.rooms(upper, reach)
					var generated := Generator.generate(layout, seed_, tier)
					check(generated == Generator.generate(layout, seed_, tier), "Generation is deterministic")
					for room in generated.rooms:
						var windows := 0
						for wall in room.walls:
							if wall.opening != "window": continue
							windows += 1
							check(Generator.clear_window(wall, generated.supports, tier), "No window intersects automatic supports or masonry shaft")
						check(windows > 0, "Each room retains natural light")
	var account := Services.new()
	check(not account.upgrade() and account.tier == 0, "No resource-free upgrade")
	account.collect(); check(not account.can_upgrade(), "Partial materials do not unlock upgrade")
	account.collect(); check(account.upgrade() and account.metal == 0 and account.tier == 1, "Upgrade consumes exact stock")
	check(not account.upgrade(), "Upgrades cannot be purchased twice")
	account.collect(); check(account.metal == 0, "Finite fixture supply cannot be collected twice")
	account.advance(31); check(account.brightness() > 0 and account.brightness() < 1, "Low construction charge dims lighting")
	account.advance(100); check(account.brightness() == 0 and account.charge == 0, "Disconnected battery expires")
	account.connected = true; account.advance(100)
	check(account.brightness() == 1, "A live connection restores lighting after battery expiry")
	account.connected = false; check(account.brightness() == 0, "Disconnecting does not refill the battery")
	print("PASS: modular house spatial rules" if failures == 0 else "FAIL: %d checks" % failures)
	quit(failures)
