extends SceneTree
const Rig = preload("res://scripts/settlement/camera_rig.gd")
var failures: Array[String] = []
var checks := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(720, 450)
	root.add_child(viewport)
	var rig = Rig.new()
	viewport.add_child(rig)
	rig.setup()
	for size in [Vector2i(720, 450), Vector2i(550, 380), Vector2i(900, 700)]:
		viewport.size = size
		for zoom in [10.0, 23.0, 110.0]:
			rig.zoom = zoom
			for yaw in [-0.65, 0.3, 1.8]:
				rig.yaw = yaw
				rig.focus = Vector3(-1, 1, 0)
				rig.update_camera()
				var origin: Vector2 = rig.camera.unproject_position(Vector3(4, 2.4, 3))
				for frame in 60:
					rig.focus += Vector3(0.017, 0, -0.009)
					var logical: Vector3 = rig.focus
					rig.update_camera()
					var shift: Vector2 = rig.camera.unproject_position(Vector3(4, 2.4, 3)) - origin
					check(shift.distance_to(shift.round()) < 0.004, "Panning moves projected edges by whole render pixels")
					check(rig.focus == logical, "Pixel snapping does not discard logical movement")
	# Explicit focus heights remain absolute, with no automatic vertical settling.
	for elevation in [0.0, 1.0, 25.0]:
		rig.focus = Vector3(0, elevation, 0)
		rig.update_camera()
		for frame in 120:
			rig.focus += Vector3(0.017, 0, -0.009)
			var logical: Vector3 = rig.focus
			rig.update_camera()
			rig.advance(1.0 / 60)
			check(rig.focus == logical, "Camera updates preserve absolute focus height")
		var stopped: Vector3 = rig.focus
		for frame in 120: rig.advance(1.0 / 60)
		check(rig.focus == stopped, "Camera stays in place after movement stops")
	viewport.free()
	if failures.is_empty():
		print("PASS: %d pixel camera checks" % checks)
		quit()
	else:
		printerr("FAIL: %d failures; %s" % [failures.size(), failures[0]])
		quit(1)
