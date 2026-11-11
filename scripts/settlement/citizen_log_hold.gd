extends RefCounted
## Two hands support the underside of the real, rigid log. All targets live
## in torso space so walking bob, leaning and turning cannot open the grip.
const LOG_CENTRE := Vector3(0, 0.18, -0.230)
const GRIP_OFFSET := Vector3(0.18, -0.120, 0.050)
const HAND_FROM_ELBOW := Vector3(0.087, -0.077, 0)
const LOG_MESH_CENTRE := Vector3(0, 0.12, 0)

static func grip_offset(size: float) -> Vector3:
	# Spread the larger hands along the unchanged timber, keeping their
	# underside contact at the log's real radius.
	return GRIP_OFFSET * Vector3(size, 1, 1)

static func centre(size: float) -> Vector3:
	return LOG_CENTRE + GRIP_OFFSET * Vector3(0,1,1) * (1.0-1.0/size)

static func apply(body: Node3D) -> void:
	var size: float = body.scale.x
	var rig: Skeleton3D = body.get_node("Skeleton3D")
	for side in [-1, 1]:
		var shoulder := 3 if side < 0 else 5
		var elbow := shoulder + 1
		var start := rig.get_bone_rest(shoulder).origin
		var upper_rest := rig.get_bone_rest(elbow).origin
		var hand_rest := HAND_FROM_ELBOW * Vector3(side, 1, 1)
		var target := centre(size) + grip_offset(size) * Vector3(side, 1, 1) / size
		var reach := target - start
		var first := upper_rest.length()
		var second := hand_rest.length()
		var distance := clampf(reach.length(), absf(first - second) + 0.0001, first + second - 0.0001)
		var direction := reach.normalized()
		var along := (first * first - second * second + distance * distance) / (2.0 * distance)
		var height := sqrt(maxf(0.0, first * first - along * along))
		# Elbows stay below/outside the chest; forearms support the log from below.
		var pole := Vector3(side * 0.5, -1.0, 0.25)
		var outward := (pole - direction * pole.dot(direction)).normalized()
		var joint := start + direction * along + outward * height
		var upper := (joint - start).normalized()
		var lower := (start + direction * distance - joint).normalized()
		var normal := upper.cross(lower).normalized()
		var rest_axis := upper_rest.normalized()
		var rest_normal := Vector3(0.08, side * 0.09, 0).normalized()
		var rest_frame := Basis(rest_axis, rest_normal, rest_axis.cross(rest_normal))
		var frame := Basis(upper, normal, upper.cross(normal))
		var shoulder_basis := (frame * rest_frame.transposed()).orthonormalized()
		var arm: Node3D = body.get_node("LeftArm" if side < 0 else "RightArm")
		arm.quaternion = shoulder_basis.get_rotation_quaternion()
		arm.get_node("Elbow").quaternion = Quaternion(hand_rest.normalized(), (shoulder_basis.inverse() * lower).normalized())
	body.get_node("CargoSocket").transform = body.bone_pose(1) * Transform3D(Basis.IDENTITY.scaled(Vector3.ONE / size), centre(size) - LOG_MESH_CENTRE / size)
