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
	check(actor.walk_blend == 0.0 and absf(actor.body.position.y) < 0.01, "Stopped citizens settle into a still pose")
	check(absf(actor.joints["LeftLeg/Knee"].rotation.x) < 0.001 and absf(actor.joint_springs["LeftLeg/Knee"].velocity) < 0.001, "Knees settle without persistent jitter when walking stops")
	citizen.cargo = "log"
	citizen.position += Vector3.RIGHT * 0.1
	actor.sync(citizen, 0.1, false, camera)
	check(actor.cargo.get_parent() == actor.body.get_node("CargoSocket"), "Carried resource stays attached to the moving body")
	check(actor.body.to_local(actor.hand_position(-1)).z < -0.1 and actor.joints["LeftArm/Elbow"].quaternion.get_angle() > 0.4, "Carrying folds the forearms toward the cargo in front")
	for variant in 4:
		citizen.appearance = variant
		actor.sync(citizen, 0.1, false, camera)
		check(actor.body.get_meta("variant", "man") == ("woman" if variant % 2 == 1 else "man"), "Saved adult appearance IDs map to the approved models")
		if variant % 2 == 1:
			check(actor.body.has_node("Top") and not actor.body.has_node("Hairband"), "Live woman retains separate coral clothing and no headband")
		for side in ["Left", "Right"]:
			check(actor.body.has_node(side + "Arm/Elbow") and actor.body.has_node(side + "Leg/Knee") and actor.skeleton.find_bone(side + "Knee") >= 0, "Every outfit has connected knee and elbow controls driving its shared skeleton")
	citizen.cargo = "food"
	citizen.cargo_food = "bread"
	actor.sync(citizen, 0.1, false, camera)
	check(actor.cargo.name == "Bread" and actor.cargo.has_node("Loaf"), "Baked food is carried as a loaf")
	citizen.erase("cargo_food")
	actor.sync(citizen, 0.1, false, camera)
	check(actor.cargo.name == "CarriedBerries", "Gathered food keeps its bare-hand berry appearance")
	citizen.cargo = ""
	var knee_min := 0.0
	var knee_max := -PI
	var elbow_min := PI
	var elbow_max := 0.0
	var knee_above_hip := false
	var lowest_sole := INF
	var highest_sole := -INF
	for frame in 120:
		citizen.position += Vector3.FORWARD * (2.25 / 60.0)
		actor.sync(citizen, 1.0 / 60.0, false, camera)
		knee_min = minf(knee_min, actor.joints["LeftLeg/Knee"].rotation.x)
		knee_max = maxf(knee_max, actor.joints["LeftLeg/Knee"].rotation.x)
		elbow_min = minf(elbow_min, actor.joints["LeftArm/Elbow"].rotation.x)
		elbow_max = maxf(elbow_max, actor.joints["LeftArm/Elbow"].rotation.x)
		var leg: Node3D = actor.body.get_node("LeftLeg")
		knee_above_hip = knee_above_hip or actor.joints["LeftLeg/Knee"].global_position.y > leg.global_position.y + 0.01
		if actor.walk_blend == 1.0 and frame % 4 == 0:
			# Check the rendered mesh vertices independently of the height solver.
			var sole := INF
			var mesh: MeshInstance3D = actor.body.get_node("Surface")
			for vertex: Vector3 in Worker.CitizenRig.posed_faces(mesh, actor.skeleton):
				sole = minf(sole, (mesh.global_transform * vertex).y - actor.global_position.y)
			lowest_sole = minf(lowest_sole, sole)
			highest_sole = maxf(highest_sole, sole)
	check(knee_max - knee_min > 0.5 and knee_min >= -2.15 and knee_max <= 0, "Knees visibly fold and extend within their backward hinge limits")
	check(not knee_above_hip, "Approved short steps keep the knees below the hips")
	check(lowest_sole >= -0.001 and highest_sole < 0.025, "Adult steps keep a supporting sole near the floor throughout the cycle")
	check(elbow_max - elbow_min > 0.3 and elbow_min >= 0 and elbow_max <= 1.65, "Elbows visibly bend independently within their forward hinge limits")
	citizen.life_stage = "child"
	actor.sync(citizen, 0.1, true, camera)
	check(actor.body.scale == Vector3.ONE * Worker.CHILD_SCALE and not actor.ring.visible, "Children keep child size and remain unselected NPCs")
	check(Worker.RUN.stride_length * Worker.CHILD_SCALE < Worker.WALK.stride_length * Worker.ADULT_SCALE, "Children take more steps per metre than adults")
	check(actor.body.get_meta("variant") == "child" and actor.body.has_node("Hair"), "Children use the approved smaller model and short hair")
	check(Worker.RUN.cycle_seconds < Worker.WALK.cycle_seconds, "Child cadence is quicker than the adult reference")
	var child_pose := actor.body.transform
	actor.sync(citizen, 0.0, false, camera)
	check(actor.body.transform.is_equal_approx(child_pose), "Pause freezes the child run's lean and flight")
	citizen.position += Vector3.RIGHT * 10
	actor.sync(citizen, 0.1, false, camera)
	check(actor.phase == 0 and actor.walk_blend == 0, "Long relocations reset locomotion instead of producing a giant stride")
	check(actor.joint_springs["LeftLeg/Knee"].velocity == 0.0 and actor.joint_springs["LeftArm/Elbow"].velocity == 0.0, "Relocations clear spring momentum")
	citizen.life_stage = "adult"
	actor.sync(citizen, 0.1, false, camera)
	check(actor.body.get_meta("variant", "man") == "woman" and actor.body.scale == Vector3.ONE * Worker.ADULT_SCALE, "Growing up selects the saved adult appearance at adult scale")
	# Work and cargo use the same separate clothing as the reviewed walk.
	var clothing_clear := true
	for variant in [0, 1]:
		citizen.appearance = variant
		for action in ["walking", "carrying", "building", "harvesting", "collecting water", "watering", "eating", "economy_processing_text", "idle"]:
			citizen.cargo = "log" if action == "carrying" else ""
			citizen.status = action if action not in ["walking", "carrying"] else "idle"
			for frame in 24:
				if action in ["walking", "carrying"]: citizen.position.z -= 0.025
				actor.sync(citizen, 1.0 / 30.0, false, camera)
				await process_frame
				if action == "carrying":
					for side in [-1, 1]:
						var hand := actor.cargo.to_local(actor.hand_position(side))
						var target: Vector3 = Worker.LogHold.LOG_MESH_CENTRE + Worker.LogHold.grip_offset(actor.body.scale.x) * Vector3(side, 1, 1)
						check(hand.distance_to(target) < 0.001, "Both hands stay locked to the log during motion")
						check(hand.y < Worker.LogHold.LOG_MESH_CENTRE.y - 0.115, "Hands support the log below its underside")
				var skin := Worker.CitizenRig.posed_faces(actor.body.get_node("Surface"), actor.skeleton)
				for part: MeshInstance3D in actor.silhouette_parts:
					if not part.get_meta("citizen_cloth", false): continue
					var cloth := Worker.CitizenRig.posed_faces(part, actor.skeleton)
					clothing_clear = clothing_clear and not crosses(skin, cloth) and not crosses(cloth, skin)
	check(clothing_clear, "Live walk, carry and building poses keep clothing clear of exposed skin")
	citizen.cargo = ""
	citizen.status = "idle"
	var looks := []
	for frame in 120:
		actor.sync(citizen, 1.0 / 60.0, false, camera)
		looks.append(actor.body.get_node("Head").rotation.y)
	check(float(looks.max()) - float(looks.min()) > 0.02, "Stationary citizens look around instead of freezing")
	var paused_torso := actor.skeleton.get_bone_pose(1)
	var paused_head: Quaternion = actor.body.get_node("Head").quaternion
	actor.sync(citizen, 0.0, false, camera)
	check(actor.skeleton.get_bone_pose(1).is_equal_approx(paused_torso) and actor.body.get_node("Head").quaternion.is_equal_approx(paused_head), "Pause freezes idle breathing and looking")
	var slopes := []
	for rise in [0.01, -0.01]:
		for frame in 60:
			citizen.position += Vector3(0, rise, -0.02)
			actor.sync(citizen, 1.0 / 60.0, false, camera)
		slopes.append(actor.skeleton.get_bone_pose_rotation(1).get_euler().x)
	check(slopes[0] < -0.02 and slopes[1] > 0.04, "Uphill and downhill travel give distinct balancing leans")
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

func crosses(edges: PackedVector3Array, target: PackedVector3Array) -> bool:
	var triangles := TriangleMesh.new()
	triangles.create_from_faces(target)
	for first in range(0, edges.size(), 3):
		for corner in 3:
			var a := edges[first + corner]
			var b := edges[first + (corner + 1) % 3]
			var length_ := a.distance_to(b)
			if length_ < 0.0001: continue
			var direction := (b - a) / length_
			var hit := triangles.intersect_ray(a + direction * 0.00001, direction)
			if not hit.is_empty() and a.distance_to(hit.position) < length_ - 0.00001:
				return true
	return false
