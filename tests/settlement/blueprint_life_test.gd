extends SceneTree
const Shape = preload("res://scripts/settlement/structure_blueprint.gd")
const Life = preload("res://scripts/settlement/structure_life.gd")
const Scene = preload("res://scenes/settlement/StructureWorkshop.tscn")
var failures: Array[String] = []
var checks := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message); printerr("FAIL: " + message)
func access(building: Dictionary, all: Array) -> bool:
	return Life.connected(building, Life.reachable(all), Life.occupancy(all))
func run() -> void:
	var base := Shape.preset(5)
	var upper := Shape.transformed(base, Vector3i.UP, 0)
	check(access(base, [base]), "Ground door connects to open map boundary")
	check(not access(upper, [base, upper]), "Structural support never grants elevated door access")
	base.ladders.append({"cell": Vector3i.ZERO, "side": Vector3i.BACK})
	check(access(upper, [base, upper]), "Explicit ladder reaches upper door threshold")
	var blocker := Shape.transformed(Shape.preset(5), Vector3i.BACK, 0)
	check(access(base, [base, blocker]), "Door into a neighbouring wall connects through its accessible building")
	check(not access(upper, [base, upper, blocker]), "Blocked ladder cannot grant access")
	base.ladders.clear()
	check_entrance_placement()
	var rng := RandomNumberGenerator.new()
	rng.seed = 17
	var ac := Life.automatic(base, base.cells, "ac", rng)
	check(not ac.is_empty() and ac.side != base.door.side, "Automatic AC avoids door")
	base.utilities.append(ac)
	check(Life.automatic(base, base.cells, "ac", rng).is_empty(), "Upgrade is idempotent")
	var same := ac.duplicate(true)
	same.kind = "dish"
	check(not Life.attachment_error(base, base.cells, same).is_empty(), "Manual overlapping utilities are rejected")
	var door_ac := ac.duplicate(true)
	door_ac.side = base.door.side
	check(not Life.attachment_error(base, base.cells, door_ac).is_empty(), "Manual utility cannot block door")
	var floating := ac.duplicate(true)
	floating.cell = Vector3i.UP
	floating.mount = "ground"
	check(not Life.attachment_error(upper, upper.cells, floating).is_empty(), "Sidewalk utility needs a bearing floor")
	var rotated := Shape.transformed(base, Vector3i(4, 1, 2), 1)
	check(rotated.door.side == Vector3i.LEFT and rotated.door.cell == Vector3i(4, 1, 2), "Door rotates and translates with building")
	check(rotated.utilities[0].offset == ac.offset and rotated.utilities[0].side == Shape.rotate_cell(ac.side, 1), "Rotation preserves manual facade offsets")
	var decoded := Shape.decode(JSON.parse_string(JSON.stringify(Shape.encode(base))))
	check(not decoded.is_empty() and decoded.utilities == base.utilities and decoded.door == base.door, "Save round trip preserves exact upgrade locations")
	var malformed := Shape.encode(base)
	malformed.utilities[0].offset[0] = 8
	check(Shape.decode(malformed).is_empty(), "Malformed attachment positions rejected")
	malformed = Shape.encode(base)
	malformed.door[0].side = [0, 1, 0]
	check(Shape.decode(malformed).is_empty(), "Non-wall entrances rejected")
	var blocked_utility := Shape.transformed(Shape.preset(5), ac.side, 0)
	check(not Shape.placement_error(blocked_utility, [base]).is_empty(), "New building cannot bury installed equipment")
	var ground_unit := base.duplicate(true)
	ground_unit.utilities[0].mount = "ground"
	ground_unit.utilities[0].offset.y = 0.18
	check(not Life.reachable([ground_unit]).has(ac.side), "Sidewalk equipment blocks its walking cell")
	var regained := Shape.empty()
	Life.normalize(regained)
	regained.cells[Vector3i.ZERO] = "stone"
	Life.normalize(regained)
	check(not regained.door.is_empty(), "Empty sculpt gains an entrance after adding a room")
	var reordered := Shape.document(base, [upper, Shape.preset(5)])
	check(not Shape.parse_document(JSON.parse_string(JSON.stringify(reordered))).is_empty(), "Save accepts upper building before its later relocated bearing")
	var crowd := Shape.encode(base)
	var duplicate: Dictionary = crowd.utilities[0].duplicate(true)
	duplicate.kind = "dish"
	crowd.utilities.append(duplicate)
	check(Shape.decode(crowd).is_empty(), "Imported utilities cannot overlap")
	var roof_equipment := Shape.transformed(Shape.preset(5), Vector3i.UP, 0)
	roof_equipment.utilities.append({"cell": Vector3i.UP, "side": Vector3i.RIGHT, "kind": "ac", "mount": "ground", "offset": Vector2(0, 0.18)})
	var terrace := Shape.transformed(Shape.preset(5), Vector3i.RIGHT, 0)
	var shared_support := Shape.document(Shape.preset(5), [roof_equipment, Shape.preset(5), terrace])
	check(not Shape.parse_document(JSON.parse_string(JSON.stringify(shared_support))).is_empty(), "Equipment can save on another building's roof")
	shared_support.assembly.pop_back()
	check(Shape.parse_document(JSON.parse_string(JSON.stringify(shared_support))).is_empty(), "Imported sidewalk equipment cannot float")
	var old := Shape.encode(base)
	old.erase("door"); old.erase("utilities"); old.erase("ladders")
	check(not Shape.decode(old).door.is_empty(), "Legacy blueprints gain a deterministic entrance")
	var variants := {}
	for i in 12:
		var fresh := Shape.preset(5)
		var entry := Life.automatic(fresh, fresh.cells, "ac", rng)
		variants[str(entry.side) + str(entry.offset)] = true
	check(variants.size() > 6, "Automatic placement varies naturally between buildings")
	var workshop := Scene.instantiate()
	workshop.restore_last = false
	root.add_child(workshop)
	await process_frame
	workshop.instances = [room(Vector3i.ZERO)]
	workshop.draft = room(Vector3i.ZERO, Vector3i.FORWARD)
	workshop.origin = Vector3i.BACK
	workshop.set_mode(1)
	workshop.place_copy()
	check(workshop.instances.size() == 1, "Place action rejects a sealed door connection without changing the assembly")
	check(workshop.overlay.buildings.size() == 2 and not Life.connected(workshop.overlay.buildings[1], workshop.overlay.reached, workshop.overlay.cells), "Preview includes the candidate's unreachable door before clicking")
	workshop.turns = 2
	workshop.place_copy()
	check(workshop.instances.size() == 1 and workshop.instances[0].cells.size() == 2, "An accessible door connection places one joined two-room building")
	workshop.instances = [room(Vector3i.ZERO), room(Vector3i.BACK)]
	workshop.selected_instance = 1
	workshop.begin_move()
	# Rotation about the map origin also moves this room, so restore its position.
	workshop.turns = 2
	workshop.origin = Vector3i.BACK * 2
	check(not workshop.commit_move() and workshop.instances[1].door.side == Vector3i.BACK, "Move rejects a rotated entrance that would seal the assembly")
	workshop.cancel_move()
	workshop.instances = [roof_equipment.duplicate(true), Shape.preset(5), terrace.duplicate(true)]
	workshop.selected_instance = 2
	workshop._remove_selected()
	check(workshop.instances.size() == 3, "Removing a floor cannot strand sidewalk equipment")
	workshop.instances = [base.duplicate(true), upper.duplicate(true)]
	workshop.set_mode(1)
	workshop.selected_instance = 0
	workshop.begin_move()
	workshop.origin = Vector3i(5, 0, 0)
	check(not workshop.commit_move() and workshop.instances[0].cells.has(Vector3i.ZERO), "Moving a bearing cannot strand upper buildings")
	workshop.cancel_move()
	workshop.selected_instance = 1
	workshop.begin_move()
	workshop.origin = Vector3i(4, -1, 0)
	check(workshop.commit_move() and workshop.instances[1].cells.has(Vector3i(4, 0, 0)), "Whole building can move from roof onto ground")
	workshop.undo()
	check(workshop.instances[1].cells.has(Vector3i.UP), "Undo restores moved building")
	workshop.redo()
	check(workshop.instances[1].cells.has(Vector3i(4, 0, 0)), "Redo restores destination")
	workshop.selected_instance = 1
	workshop.begin_move()
	workshop.origin = Vector3i(7, 0, 0)
	workshop.cancel_move()
	check(workshop.instances[1].cells.has(Vector3i(4, 0, 0)), "Cancelled move preserves original")
	workshop.selected_instance = 1
	check(workshop.upgrade("ac"), "Upgrade selected map building")
	var placed: Array = workshop.instances[1].utilities.duplicate(true)
	check(not workshop.upgrade("ac") and workshop.instances[1].utilities == placed, "Repeated upgrade cannot reroll placements")
	workshop.undo()
	check(workshop.instances[1].utilities.is_empty(), "Undo removes upgrade")
	workshop.redo()
	check(workshop.instances[1].utilities == placed, "Redo restores same randomized placement")
	# Exercise real projected wall hits for selection, entrance and manual details.
	workshop.instances = [Shape.preset(5)]
	workshop.selected_instance = -1
	workshop.brush = 3
	workshop._refresh()
	workshop.fit_view()
	await process_frame
	var point: Vector2 = workshop.camera.unproject_position(Vector3(0.5, 0.5, 0))
	workshop.inspect_at(point)
	check(workshop.selected_instance == 0, "Clicking a wall selects its building")
	workshop.brush = 6
	workshop.inspect_at(point)
	check(workshop.instances[0].utilities.size() == 1 and workshop.instances[0].utilities[0].side == Vector3i.RIGHT, "Manual AC uses clicked wall")
	workshop.inspect_at(point, true)
	check(workshop.instances[0].utilities.is_empty(), "Explicit erase removes manual AC")
	workshop.brush = 4
	workshop.inspect_at(point)
	check(workshop.instances[0].door.side == Vector3i.RIGHT, "Door tool uses clicked facade")
	workshop.brush = 5
	workshop.inspect_at(point)
	check(workshop.instances[0].ladders.size() == 1, "Ladder tool stores explicit connector")
	var path := "/tmp/pyramida-blueprint-life.pyrstructure"
	check(workshop._save(path), "Blueprint saves with attachments")
	workshop.instances.clear()
	check(workshop._load(path) and workshop.instances[0].ladders.size() == 1, "File loading restores explicit access")
	check(not workshop.advanced_panel.visible, "Advanced authoring controls start tucked away")
	workshop.free()
	if failures.is_empty(): print("PASS: %d blueprint access, attachments, movement and persistence checks" % checks)
	quit(0 if failures.is_empty() else 1)

func room(cell: Vector3i, side := Vector3i.BACK) -> Dictionary:
	var result := Shape.transformed(Shape.preset(5), cell, 0)
	result.door.side = side
	return result

func check_entrance_placement() -> void:
	var base := room(Vector3i.ZERO)
	var neighbour := room(Vector3i.BACK)
	check(Shape.placement_error(neighbour, [base]).is_empty(), "A shared doorway preserves access to the existing building")
	var sealed := room(Vector3i.BACK, Vector3i.FORWARD)
	check(not access(base, [base, sealed]) and not access(sealed, [base, sealed]), "A sealed pair cannot bootstrap its own entrance access")
	check(not Shape.placement_error(sealed, [base]).is_empty(), "Placement rejects a connection that seals the only outdoor entrance")
	var chain: Array = [base, neighbour, room(Vector3i.BACK * 2)]
	for building: Dictionary in chain:
		check(access(building, chain), "Every building in a door-to-wall chain reaches the exterior")
	chain.reverse()
	check(Life.access_error(chain).is_empty(), "Connection chains are independent of building order")
	for turn in 4:
		var rotated: Array = []
		for building: Dictionary in chain: rotated.append(Shape.transformed(building, Vector3i(4, 0, 4), turn))
		check(Life.access_error(rotated).is_empty(), "Door-to-wall access follows rotated and translated entrances")
	var upper := room(Vector3i.UP)
	check(not Shape.placement_error(upper, [base]).is_empty(), "A supported upper building still needs entrance access")
	base.ladders.append({"cell": Vector3i.ZERO, "side": Vector3i.BACK})
	check(Shape.placement_error(upper, [base]).is_empty(), "An explicit ladder makes the upper entrance placeable")
	check(not Shape.placement_error(neighbour, [base, upper]).is_empty(), "A new ground building cannot bury the only ladder to an existing entrance")
	var no_ladder := base.duplicate(true)
	no_ladder.ladders.clear()
	check(Life.loses_access([base, upper], [no_ladder, upper]), "Removing the only ladder loses upper entrance access")
	var second_base := room(Vector3i.RIGHT)
	second_base.ladders.append({"cell": Vector3i.RIGHT, "side": Vector3i.BACK})
	var alternate_upper := room(Vector3i.UP, Vector3i.RIGHT)
	check(not Life.loses_access([base, alternate_upper, second_base], [no_ladder, alternate_upper, second_base]), "An alternate roof route permits removal of a redundant ladder")
	var touching := room(Vector3i(1, 1, 0), Vector3i.FORWARD)
	check(not access(touching, [base, upper, second_base, touching]), "Touching accessible walls do not create a passage without a door")
	touching.door.side = Vector3i.LEFT
	check(access(touching, [base, upper, second_base, touching]), "An upper-floor door can connect into an accessible neighbouring room")
	var sealed_top := room(Vector3i.UP, Vector3i.FORWARD)
	check(not access(sealed_top, [base, sealed_top]), "A ladder ending beneath a room cannot bypass its walls or entrance")
	var tall := room(Vector3i.ZERO)
	tall.cells[Vector3i.UP] = "stone"
	var upstairs := room(Vector3i(1, 1, 0), Vector3i.LEFT)
	check(not access(upstairs, [tall, upstairs]), "A tall building does not imply an internal staircase")
	var no_door := room(Vector3i.ZERO)
	no_door.door = {}
	check(not Shape.placement_error(no_door, []).is_empty(), "A building with no entrance cannot be placed")
	var equipment := room(Vector3i(1, 0, 1))
	equipment.utilities.append({"cell": Vector3i(1, 0, 1), "side": Vector3i.LEFT, "kind": "ac", "mount": "ground", "offset": Vector2(0, 0.18)})
	check(not Shape.placement_error(equipment, [room(Vector3i.ZERO)]).is_empty(), "Ground equipment cannot block another building's doorway")
	var restored := Shape.parse_document(JSON.parse_string(JSON.stringify(Shape.document(base, chain))))
	check(not restored.is_empty() and Life.access_error(restored.instances).is_empty(), "Door connections recompute correctly after saving and loading")
