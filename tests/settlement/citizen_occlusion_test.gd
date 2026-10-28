extends SceneTree
const Scene = preload("res://scenes/settlement/Terraces.tscn")
var failures: Array[String] = []
var game
var facade: Node3D

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition: failures.append(message)

func run() -> void:
	root.get_node("DisplayScale").apply_display_scale(1.0)
	root.size = Vector2i(1100, 760)
	game = Scene.instantiate()
	game.launch_to_menu = false
	root.add_child(game)
	game.capture = true
	game.set_process(false)
	game.set_process_input(false)
	game.set_process_unhandled_input(false)
	# Native focus/mouse/resize events must not reset this fixture's camera.
	game.viewport.size_changed.disconnect(game.rig.update_camera)
	game._clear_selection()
	game.world.scenery.hide()
	game.world.water_view.hide()
	game.world.architecture.hide()
	game.world.entity_views.clear()
	game.world.fog_enabled = false
	game.fog.hide()
	game.hud.root.hide()
	var camera: Camera3D = game.rig.camera
	camera.position = Vector3(0, 1, 12)
	camera.rotation = Vector3.ZERO
	camera.size = 5
	for id in game.world.actors.size():
		var actor = game.world.actors[id]
		actor.position = Vector3(-1.2 if id == 0 else 1.2, 0, 0)
		actor.body.rotation = Vector3.ZERO
	game.world.actors[1].hide()
	# Keep clothing distinct from the yellow contour in image assertions.
	game.world.actors[2].set_appearance(2, 0)
	game.world.actors[2].body.scale = Vector3.ONE * 0.64
	game.world.actors[2].body.rotation = Vector3.ZERO
	facade = Node3D.new()
	game.viewport.add_child(facade)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(9, 3, 0.2)
	mesh.mesh = box
	mesh.position = Vector3(0, 1, 2)
	var paint := StandardMaterial3D.new()
	paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	paint.albedo_color = Color("67594c")
	mesh.material_override = paint
	facade.add_child(mesh)
	var collider := StaticBody3D.new()
	collider.set_meta("cell", Vector3i.ZERO)
	collider.set_meta("kind", "house")
	collider.set_meta("entity_key", "building:fixture")
	var shape := CollisionShape3D.new()
	var volume := BoxShape3D.new()
	volume.size = box.size
	shape.shape = volume
	shape.position = mesh.position
	collider.add_child(shape)
	facade.add_child(collider)
	game.world.entity_views["building:fixture"] = facade
	for frame in 4: await process_frame
	await physics_frame
	for zoom in [5.0, 12.0]:
		camera.size = zoom
		for id in [0, 2]:
			var actor = game.world.actors[id]
			for path in ["Head/HeadShape", "Body", "LeftArm/Elbow/Forearm", "RightLeg/Knee/Shin"]:
				var part: MeshInstance3D = actor.body.get_node(path)
				var mouse := camera.unproject_position(part.global_position)
				check(game.object_at(mouse).get("worker_id", -1) == id, "Head/body/animated limbs beat the facade at zoom %s, person %s, %s" % [zoom, id, path])
			var outside := camera.unproject_position(actor.global_position + Vector3(0.5, 0.5, 0))
			check(not game.object_at(outside).has("worker_id"), "Empty space outside the silhouette still picks the building")
		var kid_mouse := camera.unproject_position(game.world.actors[2].body.get_node("Head/HeadShape").global_position)
		game._select_worker(false, kid_mouse)
		check(game.selected == -1 and game.selected_object.get("worker_id") == 2 and game.selected_workers.is_empty(), "Concealed kid is inspected, never commanded")
		game._select_worker(false, camera.unproject_position(game.world.actors[0].body.get_node("Head/HeadShape").global_position))
		check(game.selected == 0 and game.selected_workers == [0], "Concealed adult is selected")
	# Overlapping bodies resolve to the nearest person, regardless of array order.
	var front = game.world.actors[1]
	front.show()
	front.set_appearance(0, 0)
	front.position = game.world.actors[0].position + Vector3(0, 0, 1)
	front.body.rotation = Vector3.ZERO
	var overlap := camera.unproject_position(front.body.get_node("Head/HeadShape").global_position)
	check(game.object_at(overlap).get("worker_id") == 1, "Nearest overlapping person wins")
	front.hide()
	check(game.object_at(overlap).get("worker_id") == 0, "Hidden actors cannot steal selection")
	# Pose, outfit and camera changes must use current geometry, not stale bounds.
	var adult = game.world.actors[0]
	for variant in 4:
		adult.set_appearance(variant, variant)
		adult.body.rotation.y = 0.65
		adult.body.get_node("LeftArm").rotation.z = 0.8
		camera.position = Vector3(4, 4, 12)
		camera.look_at(Vector3(0, 0.5, 0))
		var hand: Node3D = adult.body.get_node("LeftArm/Elbow/Forearm")
		check(game.object_at(camera.unproject_position(hand.global_position)).get("worker_id") == 0, "Picking follows rotated and animated outfit %s" % variant)
	adult.set_appearance(0, 0)
	adult.body.rotation = Vector3.ZERO
	camera.position = Vector3(0, 1, 12)
	camera.rotation = Vector3.ZERO
	camera.size = 5
	game.citizen_outline.sync(game.world, camera, game.model)
	check(game.citizen_outline.proxies.size() > 1, "Both body and building geometry feed the masks")
	check(game.citizen_outline.silhouette.size == Vector2i(game.citizen_outline.size), "Masks use logical UI dimensions")
	var shaded_area := 0.0
	for rect in game.citizen_outline.regions: shaded_area += rect.get_area()
	check(shaded_area < game.citizen_outline.size.x * game.citizen_outline.size.y * 0.2, "Outline shader only shades small regions around people")
	var neutral: Color = game.citizen_outline.material.get_shader_parameter("outline_color")
	var selected_colour: Color = game.citizen_outline.material.get_shader_parameter("selection_color")
	check(neutral.a > 0.9 and neutral.a > selected_colour.a and neutral != selected_colour, "Unselected occlusion uses a more opaque neutral colour distinct from selection")
	for id in [0, 2]: game.world.actors[id].ring.show()
	game.citizen_outline.sync(game.world, camera, game.model)
	for id in [0, 2]:
		for part in game.world.actors[id].silhouette_parts:
			check(game.citizen_outline.proxies[part].layers == 5, "Selected adult and child geometry joins the complete silhouette pass")
	game.hud.update_selection(game.world, camera, {"worker_id": 2}, game.model)
	check(game.hud.selection_strokes.is_empty(), "Selected citizens and kids have no foot circles")
	for id in [0, 2]: game.world.actors[id].ring.hide()
	game.citizen_outline.sync(game.world, camera, game.model)
	check(game.citizen_outline.selection.render_target_update_mode == SubViewport.UPDATE_DISABLED, "No selection suspends its extra rendering pass")
	for part in adult.silhouette_parts:
		check(game.citizen_outline.proxies[part].layers == 1, "Deselection updates existing proxy geometry immediately")
	if DisplayServer.get_name() != "headless":
		await verify_render()
	var explored: Dictionary = game.model.exploration.cells
	game.model.exploration.cells = {}
	game.world.fog_enabled = true
	game.citizen_outline.sync(game.world, camera, game.model)
	check(not game.citizen_outline.visible, "Unexplored citizens have no x-ray outlines")
	check(not game.object_at(overlap).has("worker_id"), "Unexplored citizens are not picked")
	game.model.exploration.cells = explored
	game.citizen_outline.sync(game.world, camera, game.model, false)
	check(not game.citizen_outline.visible and game.citizen_outline.silhouette.render_target_update_mode == SubViewport.UPDATE_DISABLED and game.citizen_outline.selection.render_target_update_mode == SubViewport.UPDATE_DISABLED, "Menus suspend the overlay and its render passes")
	game.free()
	for failure in failures: printerr("FAIL: " + failure)
	if failures.is_empty(): print("PASS: concealed adult/child silhouettes, precise picking, overlap depth, visibility and outline rendering")
	quit(int(not failures.is_empty()))

func drawn_pixels(image: Image) -> int:
	var count := 0
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).r > 0.5: count += 1
	return count

func verify_render() -> void:
	for frame in 5: await process_frame
	await RenderingServer.frame_post_draw
	var full := game.citizen_outline.silhouette.get_texture().get_image() as Image
	var visible_body := game.citizen_outline.exposed.get_texture().get_image() as Image
	check(drawn_pixels(full) > 100, "Full mask contains adult and kid bodies")
	check(drawn_pixels(visible_body) == 0, "Solid facade hides both bodies in the exposed mask")
	var outlined := root.get_texture().get_image()
	check(neutral_pixels(outlined) > 100 and outline_pixels(outlined) == 0, "Unselected concealed contours use neutral grey, never selection yellow")
	outlined.save_png("/tmp/pyramida-citizen-occlusion.png")
	game.world.actors[0].ring.show()
	game.citizen_outline.sync(game.world, game.rig.camera, game.model)
	for frame in 3: await process_frame
	await RenderingServer.frame_post_draw
	var mixed := root.get_texture().get_image()
	check(outline_pixels(mixed) > 100 and neutral_pixels(mixed) > 100, "A selected concealed adult is yellow while the unselected concealed kid stays grey")
	mixed.save_png("/tmp/pyramida-citizen-mixed-selection.png")
	game.world.actors[0].ring.hide()
	# Lower the wall: only concealed lower edges should remain outlined.
	facade.position.y = -1.9
	game.citizen_outline.sync(game.world, game.rig.camera, game.model)
	for frame in 3: await process_frame
	await RenderingServer.frame_post_draw
	visible_body = game.citizen_outline.exposed.get_texture().get_image()
	check(drawn_pixels(visible_body) > 0 and drawn_pixels(visible_body) < drawn_pixels(full), "Partial occlusion preserves exposed upper bodies")
	var partial := root.get_texture().get_image()
	check(neutral_pixels(partial) > 0 and neutral_pixels(partial) < neutral_pixels(outlined), "Only concealed edges are outlined behind a partial wall")
	partial.save_png("/tmp/pyramida-citizen-partial.png")
	for id in [0, 2]: game.world.actors[id].ring.show()
	game.citizen_outline.sync(game.world, game.rig.camera, game.model)
	for frame in 3: await process_frame
	await RenderingServer.frame_post_draw
	var selected_mask: Image = game.citizen_outline.selection.get_texture().get_image()
	check(absi(drawn_pixels(full) - drawn_pixels(selected_mask)) < 5, "Selection contains complete adult and kid bodies through a partial wall")
	var selected_partial := root.get_texture().get_image()
	var selected_count := outline_pixels(selected_partial)
	check(selected_count > 100, "Selected citizens have yellow contours around exposed and concealed body edges")
	selected_partial.save_png("/tmp/pyramida-citizen-selected-partial.png")
	facade.hide()
	game.citizen_outline.sync(game.world, game.rig.camera, game.model)
	for frame in 3: await process_frame
	await RenderingServer.frame_post_draw
	var selected_exposed := root.get_texture().get_image()
	check(outline_pixels(selected_exposed) > selected_count * 0.8, "Selection keeps its complete contour when the building is removed")
	selected_exposed.save_png("/tmp/pyramida-citizen-selected-exposed.png")
	for id in [0, 2]: game.world.actors[id].ring.hide()
	game.citizen_outline.sync(game.world, game.rig.camera, game.model)
	for frame in 3: await process_frame
	await RenderingServer.frame_post_draw
	visible_body = game.citizen_outline.exposed.get_texture().get_image()
	check(absi(drawn_pixels(full) - drawn_pixels(visible_body)) < 5, "Removing the building leaves no concealed outline")
	var exposed_image := root.get_texture().get_image()
	check(outline_pixels(exposed_image) == 0, "Visible people have no x-ray contour")
	exposed_image.save_png("/tmp/pyramida-citizen-exposed.png")
	game.citizen_outline.hide()
	for frame in 3: await process_frame
	await RenderingServer.frame_post_draw
	var without_effect := root.get_texture().get_image()
	check(exposed_image.get_data() == without_effect.get_data(), "Exposed antialiased edges have no faint residual halo")

func outline_pixels(image: Image) -> int:
	var count := 0
	for y in image.get_height():
		for x in image.get_width():
			var colour := image.get_pixel(x, y)
			if colour.r > 0.75 and colour.g > 0.55 and colour.g < 0.85 and colour.b < 0.65 and colour.r - colour.g > 0.1 and colour.g - colour.b > 0.08: count += 1
	return count

func neutral_pixels(image: Image) -> int:
	var count := 0
	for y in image.get_height():
		for x in image.get_width():
			var colour := image.get_pixel(x, y)
			if colour.r > 0.65 and colour.r < 0.83 and colour.g > 0.65 and colour.g < 0.8 and colour.b > 0.55 and colour.b < 0.73 and absf(colour.r - colour.g) < 0.07: count += 1
	return count
