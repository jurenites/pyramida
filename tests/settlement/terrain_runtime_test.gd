extends SceneTree
const Nav = preload("res://scripts/settlement/navigation.gd")
const Hydro = preload("res://scripts/settlement/hydrology.gd")
const Model = preload("res://scripts/settlement/world_model.gd")
var failures: Array[String] = []
var checks := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game = load("res://scenes/settlement/Terraces.tscn").instantiate()
	game.launch_to_menu = false
	root.add_child(game)
	game.speed = 0
	game.capture = true
	for frame in 3:
		await physics_frame
	var space: PhysicsDirectSpaceState3D = game.viewport.world_3d.direct_space_state
	var peak := Vector3i.ZERO
	for surface: Vector3i in game.model.ground:
		if surface.y > peak.y:
			peak = surface
	var p := Nav.point(peak)
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3.UP * 10, p - Vector3.UP * 30))
	check(not hit.is_empty() and hit.collider.has_meta("terrain") and absf(hit.position.y - p.y) < 0.1, "Mountain has a solid raycast surface at its generated height")
	game.rig.focus = p
	game.rig.update_camera()
	game.tool = "house"
	var placement: Dictionary = game.placement_at(game.rig.camera.unproject_position(p), false)
	check(placement.get("cell") == peak, "Cursor placement snaps to actual mountain height")
	var tested_slope := false
	var clicked_slope := false
	for slope: Vector3i in game.model.terrain_shapes:
		var corners: Array = game.model.terrain_shapes[slope]
		if corners.min() < 0.3 or corners.max() > 2.3: continue
		var slope_point := Nav.point(slope) + Vector3(0.2, 0, 0.1)
		var slope_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(slope_point + Vector3.UP * 8, slope_point - Vector3.UP))
		if slope_hit.is_empty(): continue
		check(absf(game.model.navigation.surface_height(slope, slope_hit.position) - slope_hit.position.y) < 0.002, "Walking height agrees with physical terrain collision")
		check(slope_hit.collider.has_meta("terrain") and slope_hit.position.y > 0.1, "Gravel apron has collision above the flat floor")
		check(absf(slope_hit.normal.y) > 0.5 and absf(slope_hit.normal.y) < 0.999, "Gravel collision follows a real diagonal slope")
		tested_slope = true
		game.rig.focus = slope_hit.position
		game.rig.update_camera()
		game.tool = "inspect"
		var mouse: Vector2 = game.rig.camera.unproject_position(slope_hit.position)
		if game.command_target_at(mouse).get("cell") != slope: continue
		game.model.set_role(0, "idle")
		game.model.tick(3.0)
		game.selected_workers.assign([0])
		game.command_at(mouse)
		check(game.model.workers[0].job.get("kind") == "move" and game.model.workers[0].job.get("target") == slope, "Real terrain click queues travel to the slope")
		check(0 not in game.model.idle_citizen_ids(), "Slope click immediately removes the traveller from idle count")
		clicked_slope = true
		break
	check(tested_slope, "A real gravel slope was tested")
	check(clicked_slope, "A visible gravel slope received a real player command")
	var tested_cliff := false
	for cell: Vector3i in game.model.ground:
		for direction: Vector3i in Nav.DIRECTIONS:
			var other: Vector3i = game.model.surface_at(cell.x + direction.x, cell.z + direction.z)
			if other.y > cell.y - 2 or game.model.trees.has(cell):
				continue
			var end := Nav.point(cell) - Vector3.UP
			hit = space.intersect_ray(PhysicsRayQueryParameters3D.create(end + Vector3(direction) * 1.8, end))
			if not hit.is_empty() and hit.collider.has_meta("terrain"):
				check(absf(hit.normal.y) < 0.1, "Exposed canyon walls have vertical collision faces")
				tested_cliff = true
				break
		if tested_cliff:
			break
	check(tested_cliff, "A real canyon wall was tested")
	var cell := Vector3i(-8, 0, 0)
	game.hud.update(game.model, -1, 0, {"cell": cell, "kind": "puddle"})
	check(game.hud.collect_button.visible and not game.hud.collect_button.disabled, "Inspecting a puddle exposes collection action")
	game.hud.collect_button.pressed.emit()
	check(game.model.water_orders.get(cell) == 3, "Collection button queues actual source inventory")
	var old_id: int = game.world.water_view.sources[cell].get_instance_id()
	game.model.revision += 1
	game.world.sync(game.model, 0, -1)
	check(game.world.water_view.sources[cell].get_instance_id() == old_id, "Water amount updates reuse source nodes")
	Hydro.tick(game.model, 94)
	game.world.sync(game.model, 0, -1)
	check(game.world.water_view.rain.emitting, "Rain weather starts visual rainfall")
	var signature: int = game.world.scenery.signature
	game.model = Model.new()
	game.model.setup(773)
	game.world.last_revision = -1
	game.world.sync(game.model, 0, -1)
	check(game.world.scenery.signature != signature and game.world.scenery.signature == hash([game.model.ground, game.model.terrain_shapes]), "Switching worlds rebuilds terrain scenery")
	game.free()
	if failures.is_empty():
		print("PASS: %d terrain picking, water UI, rain and world-switch checks" % checks)
		quit()
	else:
		for failure in failures:
			printerr("FAIL: " + failure)
		quit(1)
