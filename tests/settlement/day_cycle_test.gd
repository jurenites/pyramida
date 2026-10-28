extends SceneTree
const Model = preload("res://scripts/settlement/world_model.gd")
const View = preload("res://scripts/settlement/world_view.gd")
const Settings = preload("res://scripts/gameplay_settings.gd")
const Illustration = preload("res://scripts/settlement/illustration_style.gd")
const HUD = preload("res://scripts/settlement/hud.gd")
const Palette = preload("res://scripts/game_palette.gd")
const DayCycle = preload("res://scripts/settlement/day_cycle.gd")
const CameraRig = preload("res://scripts/settlement/camera_rig.gd")
var failures: Array[String] = []
var checks := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var model = Model.new()
	model.setup()
	var hud = HUD.new()
	root.add_child(hud)
	var view = View.new()
	root.add_child(view)
	view.setup(model)
	var crown: Node3D = view.tree_views[Vector3i(-8, 0, -4)].get_node("Segment3/Crown")
	for leaves: MeshInstance3D in crown.get_children():
		check(leaves.material_override.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED, "Illustrated foliage uses flat colours; the world pass handles time of day")
	var sun: DirectionalLight3D = view.scenery.sun
	var rig = CameraRig.new()
	root.add_child(rig)
	rig.setup()
	check(sun.directional_shadow_max_distance > rig.camera.position.distance_to(rig.focus) + rig.zoom,
		"Shadow coverage reaches the village beyond the camera's offset")
	rig.free()
	# Probe the actual light direction arbitrarily close to both horizons,
	# including repeated days, where an uncapped orbit creates huge streaks.
	for phase in [0.000001, 0.001, 0.02, 0.04, 0.125, 0.25, 0.375, 0.46, 0.48, 0.499, 0.499999, 1.000001, 1.499999]:
		DayCycle.apply(sun, view.scenery.settings, Settings.SIMULATION_DAY_SECONDS * phase)
		var direction := sun.basis.z
		var shadow_length := Vector2(direction.x, direction.z).length() / direction.y
		check(direction.y > 0.0 and is_finite(shadow_length) and shadow_length <= 4.001,
			"Ground shadows stay within four times caster height at phase %f" % phase)
		check(is_equal_approx(sun.light_energy, 0.85 * DayCycle.daylight_at(Settings.SIMULATION_DAY_SECONDS * phase)),
			"Capping shadow length preserves the clock-driven horizon fade")
	model.time = Settings.SIMULATION_DAY_SECONDS * 0.04
	view.sync(model, 0, -1)
	var dawn_direction := sun.basis.z
	var dawn_shadow := Vector2(dawn_direction.x, dawn_direction.z).length() / dawn_direction.y
	check(dawn_shadow > 3.0, "Rising sun casts shadows longer than three times the object height")
	model.time = Settings.SIMULATION_DAY_SECONDS * 0.25
	view.sync(model, 0, -1)
	check(Vector2(sun.basis.z.x, sun.basis.z.z).length() < 0.01, "Noon contracts the long shadows beneath their casters")
	model.time = Settings.SIMULATION_DAY_SECONDS * 0.46
	view.sync(model, 0, -1)
	check(dawn_direction.x * sun.basis.z.x < 0 and absf(sun.basis.z.x / sun.basis.z.y) > 3.0,
		"Setting sun stretches the shadows in the opposite direction")
	check(is_equal_approx(float(Illustration.ground_material.get_shader_parameter("daylight")), 1.0),
		"Low daytime sun retains the full illustrated ground shadow contribution")
	check(DayCycle.daylight_at(0.0) == 0.0 and DayCycle.daylight_at(Settings.SIMULATION_DAY_SECONDS * 0.001) < 0.01,
		"Shadows fade smoothly as the sun reaches the horizon")
	var ground_id: int = view.scenery.find_children("RockChunk_*", "MeshInstance3D", true, false)[0].get_instance_id()
	model.time = Settings.SIMULATION_DAY_SECONDS * 0.125
	view.sync(model, 0, -1)
	var ink := ShaderMaterial.new()
	ink.shader = Illustration.EDGE_SHADER
	Illustration.update(ink, model.time)
	var morning_tint: Vector3 = ink.get_shader_parameter("day_tint")
	var morning := sun.basis.z
	var revision: int = model.revision
	model.time = Settings.SIMULATION_DAY_SECONDS * 0.375
	view.sync(model, 0, -1)
	check(morning.x * sun.basis.z.x < 0, "Sun crosses to opposite side, reversing cast shadow direction")
	check(sun.shadow_enabled and sun.visible, "Daytime sunlight casts real shadows")
	check(model.revision == revision and view.scenery.find_children("RockChunk_*", "MeshInstance3D", true, false)[0].get_instance_id() == ground_id, "Lighting moves without rebuilding terrain or requiring world revisions")
	var rotation := sun.rotation
	view.sync(model, 10, -1)
	check(sun.rotation.is_equal_approx(rotation), "Render delta cannot advance a paused sun")
	model.time = Settings.SIMULATION_DAY_SECONDS * 0.75
	view.sync(model, 0, -1)
	Illustration.update(ink, model.time)
	var night_tint: Vector3 = ink.get_shader_parameter("day_tint")
	check(night_tint.length() < morning_tint.length() and night_tint.z > night_tint.x, "Flat world becomes darker and cooler at night")
	check(not sun.visible and sun.light_energy == 0, "Sun below horizon cannot illuminate terrain from underneath")
	check(float(Illustration.ground_material.get_shader_parameter("daylight")) == 0.0,
		"Night removes the ground shadow contribution without darkening painted terrain twice")
	check(view.scenery.settings.background_color.is_equal_approx(Palette.NIGHT_SKY), "Night uses original dark sky palette")
	check(view.scenery.settings.ambient_light_energy > 0, "Night retains readable ambient illumination")
	var copy = Model.new()
	check(copy.restore(JSON.parse_string(JSON.stringify(model.snapshot()))), "Nighttime world restores")
	view.sync(copy, 0, -1)
	Illustration.update(ink, copy.time)
	check(ink.get_shader_parameter("day_tint").is_equal_approx(night_tint), "Reload restores illustrated night colours")
	check(not sun.visible and sun.rotation.is_equal_approx(Vector3(-TAU * 0.75, -PI / 2, 0)), "Restored clock immediately restores night and sun angle")
	model.time = Settings.SIMULATION_DAY_SECONDS * 1.125
	view.sync(model, 0, -1)
	check(sun.basis.z.is_equal_approx(morning), "Next day repeats the orbit without drift")
	for sample in [{"phase": 0.499, "night": false, "day": "1"}, {"phase": 0.5, "night": true, "day": "1"}, {"phase": 0.75, "night": true, "day": "1"}, {"phase": 1.0, "night": false, "day": "2"}]:
		model.time = Settings.SIMULATION_DAY_SECONDS * sample.phase
		hud.update(model, -1, 1)
		check(hud.day_icon.is_night == sample.night and hud.day_label.text == sample.day, "Sun/moon and numeric day follow the saved clock boundary")
		if sample.night:
			check(hud.root.modulate.b > hud.root.modulate.r, "UI takes on a blue tint at nightfall")
			var outline_colour: Color = hud.root.modulate * hud.idle_button.modulate
			check(outline_colour.is_equal_approx(Color.WHITE), "White idle outline is preserved through the night tint")
		else:
			if sample.phase == 1.0:
				check(hud.root.modulate == Color.WHITE, "Dawn restores the daytime UI palette")
	hud.free()
	view.free()
	if failures.is_empty():
		print("PASS: %d moving sunlight, night, pause and save checks" % checks)
		quit()
	else:
		for failure in failures:
			printerr("FAIL: " + failure)
		quit(1)
