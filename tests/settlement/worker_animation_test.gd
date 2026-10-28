extends SceneTree
const Worker = preload("res://scripts/settlement/worker_view.gd")
const Spring = preload("res://scripts/settlement/joint_spring.gd")
var failures: Array[String] = []
var checks := 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var actor := Worker.new()
	root.add_child(actor)
	actor.setup(1)
	var camera := Camera3D.new()
	root.add_child(camera)
	var citizen := {"position": Vector3(8, 0, 8), "cargo": "", "status": "idle", "appearance": 0, "cloth_color": 0}
	actor.sync(citizen, 1.0 / 60.0, false, camera)
	check(actor.phase == 0 and actor.position == citizen.position, "Initial placement does not create a walk or interpolate from the origin")
	for yaw in [0.0, 0.71, -2.4]:
		camera.rotation.y = yaw
		for sector in 8:
			var direction := camera.global_basis.z.rotated(Vector3.UP, sector * PI / 4.0)
			check(Worker.direction_sector(direction, camera.global_basis.z) == sector, "Eight directions remain camera-relative")
			citizen.position += direction * 0.1
			actor.sync(citizen, 1.0 / 60.0, false, camera)
			check(actor.facing_sector == sector, "Rendered facing follows the requested sector")
	var before := actor.position
	var phase := actor.phase
	actor.sync(citizen, 1.0 / 60.0, false, camera)
	check(actor.position != before and actor.phase > phase, "Between simulation ticks the renderer keeps walking toward its target")
	before = actor.position
	phase = actor.phase
	var pose: Vector3 = actor.body.get_node("LeftLeg").rotation
	var knee_pose: float = actor.joints["LeftLeg/Knee"].rotation.x
	var elbow_pose: float = actor.joints["LeftArm/Elbow"].rotation.x
	var elbow_velocity: float = actor.joint_springs["LeftArm/Elbow"].velocity
	actor.sync(citizen, 0.0, false, camera)
	check(actor.position == before and actor.phase == phase and actor.body.get_node("LeftLeg").rotation == pose, "Pause freezes position and gait")
	check(actor.joints["LeftLeg/Knee"].rotation.x == knee_pose and actor.joints["LeftArm/Elbow"].rotation.x == elbow_pose and actor.joint_springs["LeftArm/Elbow"].velocity == elbow_velocity, "Pause freezes joint angles and spring momentum")
	for frame in 120:
		actor.sync(citizen, 1.0 / 60.0, false, camera)
	check(actor.walk_blend == 0.0 and is_zero_approx(actor.body.position.y), "Stopped citizens settle into a still pose")
	check(absf(actor.joints["LeftLeg/Knee"].rotation.x) < 0.001 and absf(actor.joint_springs["LeftLeg/Knee"].velocity) < 0.001, "Knees settle without persistent jitter when walking stops")
	citizen.cargo = "log"
	citizen.position += Vector3.RIGHT * 0.1
	actor.sync(citizen, 0.1, false, camera)
	check(actor.cargo.get_parent() == actor.body.get_node("CargoSocket"), "Carried resource stays attached to the moving body")
	check(actor.body.get_node("LeftArm").rotation.x > 0.0 and actor.joints["LeftArm/Elbow"].rotation.x > 0.5, "Carrying folds the forearms toward the cargo in front")
	for variant in 4:
		citizen.appearance = variant
		actor.sync(citizen, 0.1, false, camera)
		for side in ["Left", "Right"]:
			check(actor.body.has_node(side + "Arm/Elbow/Forearm") and actor.body.has_node(side + "Leg/Knee/Shin"), "Every outfit has two connected segments per limb")
	citizen.cargo = ""
	var knee_min := 0.0
	var knee_max := -PI
	var elbow_min := PI
	var elbow_max := 0.0
	for frame in 120:
		citizen.position += Vector3.FORWARD * (2.25 / 60.0)
		actor.sync(citizen, 1.0 / 60.0, false, camera)
		knee_min = minf(knee_min, actor.joints["LeftLeg/Knee"].rotation.x)
		knee_max = maxf(knee_max, actor.joints["LeftLeg/Knee"].rotation.x)
		elbow_min = minf(elbow_min, actor.joints["LeftArm/Elbow"].rotation.x)
		elbow_max = maxf(elbow_max, actor.joints["LeftArm/Elbow"].rotation.x)
	check(knee_max - knee_min > 0.5 and knee_min >= -1.35 and knee_max <= 0, "Knees visibly fold and extend within their backward hinge limits")
	check(elbow_max - elbow_min > 0.3 and elbow_min >= 0 and elbow_max <= 1.65, "Elbows visibly bend independently within their forward hinge limits")
	citizen.life_stage = "child"
	actor.sync(citizen, 0.1, true, camera)
	check(actor.body.scale == Vector3.ONE * 0.64 and not actor.ring.visible, "Children share the gait at child size and remain unselected NPCs")
	citizen.position += Vector3.RIGHT * 10
	actor.sync(citizen, 0.1, false, camera)
	check(actor.phase == 0 and actor.walk_blend == 0, "Long relocations reset locomotion instead of producing a giant stride")
	check(actor.joint_springs["LeftLeg/Knee"].velocity == 0.0 and actor.joint_springs["LeftArm/Elbow"].velocity == 0.0, "Relocations clear spring momentum")
	var spring := Spring.new(0.0, 1.65)
	var coarse := Spring.new(0.0, 1.65)
	for frame in 24:
		spring.step(1.0, 1.0 / 60.0)
	coarse.step(1.0, 0.4)
	check(is_equal_approx(spring.angle, coarse.angle) and absf(spring.velocity - coarse.velocity) < 0.0001, "Spring integration gives the same response across frame rates")
	for delta in [1.0 / 144.0, 1.0 / 30.0, 0.25, 1.0, 5.0, 60.0]:
		for frame in 20:
			var angle := spring.step(-10.0 if frame % 2 == 0 else 10.0, delta)
			check(is_finite(angle) and is_finite(spring.velocity) and angle >= 0 and angle <= 1.65, "Joint limits remain stable through speed changes and long frames")
	actor.free()
	camera.free()
	if failures.is_empty():
		print("PASS: %d citizen animation checks" % checks)
		quit(0)
	else:
		for failure in failures:
			printerr("FAIL: " + failure)
		quit(1)
