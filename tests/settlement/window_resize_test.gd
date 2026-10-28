extends SceneTree
const Surface = preload("res://scripts/window_world_surface.gd")
const Rig = preload("res://scripts/settlement/camera_rig.gd")
var failures: Array[String] = []
var checks := 0
var settled_count := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)

func wait_for_settle(scaling: Node) -> void:
	var deadline := Time.get_ticks_msec() + 2000
	while scaling._pending and Time.get_ticks_msec() < deadline:
		await process_frame
	check(not scaling._pending, "Resize verification completes within two seconds")

func run() -> void:
	var scaling := root.get_node("DisplayScale")
	scaling.resize_settled.connect(func(): settled_count += 1)
	var surface := Surface.new()
	surface.fill_window = true
	surface.stretch = true
	surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(surface)
	var world := SubViewport.new()
	world.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	surface.add_child(world)
	var rig := Rig.new()
	world.add_child(rig)
	rig.setup()
	var paper := ColorRect.new()
	paper.color = Color("fcebcf")
	paper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	world.add_child(paper)
	var densities := [1.0, 1.5, 2.0, 1.0]
	var native := OS.get_cmdline_user_args().has("--native-display")
	if native:
		densities = [root.content_scale_factor]
	for density in densities:
		scaling.apply_display_scale(density)
		for shrink in [1, 2]:
			surface.stretch_shrink = shrink
			# Alternate dimensions quickly, including odd physical dimensions.
			for index in 12:
				var logical := Vector2(1100 + (index % 3) * 37, 760 + (index % 4) * 19)
				root.size = Vector2i(logical * density) + Vector2i.ONE
				await process_frame
			var previous_count := settled_count
			await wait_for_settle(scaling)
			check(settled_count == previous_count + 1, "One final verification per resize burst")
			check(scaling._layout_matches(root.size), "Root and world agree after rapid resizing")
			check(surface.size.is_equal_approx(root.get_visible_rect().size), "World covers both bottom and right edges")
			check(is_equal_approx(root.get_final_transform().get_scale().x, density), "UI point scale remains constant")
			check(world.size == Vector2i(surface.size / shrink), "World resolution follows its rendering mode")
			for fraction in [Vector2(0.1, 0.1), Vector2(0.5, 0.5), Vector2(0.9, 0.9)]:
				var point: Vector2 = surface.size * fraction
				var world_point: Vector2 = surface.viewport_point(point, world)
				check(world_point.is_equal_approx(Vector2(world.size) * fraction), "Picking tracks the visible rectangle")
				var origin: Vector3 = rig.camera.project_ray_origin(world_point)
				var ray: Vector3 = rig.camera.project_ray_normal(world_point)
				var ground := origin + ray * (-origin.y / ray.y)
				var projected: Vector2 = rig.camera.unproject_position(ground)
				check(projected.distance_to(world_point) < 0.01, "Camera projection and picking stay aligned")
			if native:
				await RenderingServer.frame_post_draw
				var image := root.get_texture().get_image()
				check(image != null and not image.is_empty(), "Native framebuffer can be checked")
				if image != null and not image.is_empty():
					check(image.get_size() == DisplayServer.window_get_size(root.get_window_id()), "Framebuffer covers the native window")
					for sample in [Vector2i(image.get_width() - 2, 10), Vector2i(10, image.get_height() - 2), image.get_size() - Vector2i(2, 2)]:
						var colour := image.get_pixelv(sample)
						check(colour.r > 0.5 and colour.g > 0.5, "Native framebuffer has no black bottom/right edge")
	# Reproduce a stale full-window surface after the last resize notification.
	scaling._request_resize()
	for frame in 3:
		await process_frame
	surface.size -= Vector2(90, 70)
	check(not surface.surface_matches(), "Test injects stale surface bounds")
	await wait_for_settle(scaling)
	check(surface.surface_matches(), "Final check repairs stale surface bounds")
	var verified_count := settled_count
	await create_timer(0.3).timeout
	check(settled_count == verified_count, "Idle windows do not repeat resize work")
	# Picking must also work in inset authoring views.
	surface.fill_window = false
	surface.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	surface.position = Vector2(43, 61)
	surface.size = Vector2(601, 403)
	check(surface.viewport_point(surface.position + surface.size * 0.75, world).is_equal_approx(Vector2(world.size) * 0.75),
		"Picking accounts for an inset surface origin")
	# SceneTree pause must not suppress the final resize check.
	paused = true
	scaling._request_resize()
	await wait_for_settle(scaling)
	check(scaling._layout_matches(root.size), "Resize checks still run while the tree is paused")
	paused = false
	surface.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS: %d window resize, recovery and cursor checks" % checks)
		quit(0)
	else:
		for failure in failures:
			printerr("FAIL: " + failure)
		quit(1)
