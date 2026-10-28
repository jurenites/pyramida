extends SceneTree
const Model = preload("res://scripts/settlement/world_model.gd")
const Navigation = preload("res://scripts/settlement/navigation.gd")
const Assets = preload("res://scripts/settlement/asset_library.gd")
var failures: Array[String] = []
var checks := 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)

func _initialize() -> void:
	for direction in 4:
		var model = Model.new()
		for cell in Navigation.Grid.support_cells(Vector3i.ZERO): model.ground[cell] = true
		model.rebuild_navigation()
		check(model.request_build("stairs", Vector3i.ZERO, direction), "Ladder can stand alone on ground")
		model._complete_plan(model.plans[model.next_plan_id - 1])
		check(model.occupied(Vector3i.ZERO), "Ladder reserves its own cell")
		check(not model.request_build("house", Vector3i.ZERO), "Buildings cannot overlap a ladder")
		var upper: Vector3i = Navigation.DIRECTIONS[direction] * 2 + Navigation.Grid.STOREY
		check(model.navigation.route(Vector3i.ZERO, upper).is_empty(), "No route exists to a missing landing")
		model.platforms[upper] = true
		model.rebuild_navigation()
		var lower: Vector3i = -Navigation.DIRECTIONS[direction] * 2
		check(model.navigation.route(Vector3i.ZERO, upper).is_empty(), "Missing approach A cannot connect directly from ladder B")
		model.ground[lower] = true
		model.rebuild_navigation()
		check(model.navigation.route(lower, upper).size() == 2, "Approach A connects through ladder B to C")
		check(model.navigation.route(upper, lower).size() == 2, "Ladder connects downwards to A")
		var entrance := Navigation.point(lower) + Vector3(Navigation.DIRECTIONS[direction])
		var lip := Navigation.point(upper) - Vector3(Navigation.DIRECTIONS[direction])
		check(model.navigation.movement_target(lower, upper, Navigation.point(lower)).is_equal_approx(entrance), "Ascent walks to the lower edge of B first")
		check(model.navigation.movement_target(lower, upper, entrance).is_equal_approx(lip), "Climb spans both edges of B")
		check(model.navigation.movement_target(upper, lower, Navigation.point(upper)).is_equal_approx(lip), "Descent crosses intact C before climbing down")
		check(model.navigation.movement_target(upper, lower, lip).is_equal_approx(entrance), "Descent crosses the full ladder")
		for endpoints in [[lower, upper], [upper, lower]]:
			var position := Navigation.point(endpoints[0])
			var travelled := 0.0
			for tick in 600:
				var target: Vector3 = model.navigation.movement_target(endpoints[0], endpoints[1], position)
				var next := position.move_toward(target, 0.025)
				travelled += position.distance_to(next)
				position = next
				var along := position.dot(Vector3(Navigation.DIRECTIONS[direction]))
				var height := clampf((along + 1.0) / 2.0, 0, 1) * Navigation.Grid.STOREY_HEIGHT
				check(absf(position.y - height) < 0.001, "Resident follows edge-to-edge slope in either direction")
				if position.is_equal_approx(Navigation.point(endpoints[1])): break
			check(position.is_equal_approx(Navigation.point(endpoints[1])), "Traversal reaches destination without stalling")
			check(absf(travelled - model.navigation.edge_distance(endpoints[0], endpoints[1])) < 0.001, "Routing cost matches actual walking distance")
		model.workers.append({"cell": lower, "route": [upper], "route_index": 0})
		check(not model.remove_at(Vector3i.ZERO), "Cannot remove B while a resident traverses A to C")
		model.workers.clear()
		check(not model.request_build("platform", Navigation.Grid.STOREY), "Deck cannot intersect ladder volume")
		var saved = Model.new()
		saved.setup()
		saved.stairs[Vector3i(-4, 0, 0)] = direction
		saved.rebuild_navigation()
		var restored = Model.new()
		check(restored.restore(JSON.parse_string(JSON.stringify(saved.snapshot()))), "Standalone ladder survives save and load")
		check(restored.stairs.get(Vector3i(-4, 0, 0)) == direction, "Reload retains ladder orientation")
		var asset := Assets.create("stairs")
		asset.rotation.y = -direction * PI * 0.5
		for child in asset.find_children("*", "MeshInstance3D", true, false):
			var bounds: AABB = child.mesh.get_aabb()
			for corner in 8:
				var point: Vector3 = asset.transform * child.transform * bounds.get_endpoint(corner)
				check(absf(point.x) <= 1.001 and absf(point.z) <= 1.001 and point.y >= -0.001 and point.y <= Navigation.Grid.STOREY_HEIGHT + 0.001, "All rotated ladder geometry stays in one cell")
		asset.free()
	if failures.is_empty():
		print("PASS: %d standalone ladder checks" % checks)
		quit(0)
	else:
		for failure in failures:
			printerr("FAIL: " + failure)
		quit(1)
