extends Node3D
## Approved family motion, shared by the live citizens and review previews.
const Rig = preload("res://scripts/settlement/citizen_rig.gd")
const GaitResource = preload("res://scripts/settlement/grounded_gait.gd")
@export var Gait: GaitResource = preload("res://data/settlement/reference_man_walk.tres")
const Spring = preload("res://scripts/settlement/joint_spring.gd")
var springs: Dictionary = {}

func spring(key: String, target: float, delta: float) -> float:
	if not springs.has(key):
		springs[key] = Spring.new(-1.3, 1.3)
		return springs[key].reset(target)
	return springs[key].step(target, delta) if delta > 0 else springs[key].reset(target)

func set_shorts_visible(show: bool) -> void:
	for part: MeshInstance3D in find_children("*", "MeshInstance3D", true, false):
		if part.has_meta("citizen_cloth"): part.visible = show
	# Keep a complete editable body, but omit covered skin while dressed.
	# This avoids hidden thighs punching through the garment during high steps.
	get_node("Surface").mesh = get_meta("clothed_mesh" if show else "unclothed_mesh")

func pose(cycle: float, walking := true, delta := 0.0, blend := 1.0) -> void:
	var amount := clampf(blend, 0.0, 1.0) if walking else 0.0
	var left: Vector2 = Gait.leg_pose(cycle) * amount
	var right: Vector2 = Gait.leg_pose(cycle + 0.5) * amount
	get_node("LeftLeg").rotation = Vector3(left.x, 0, 0)
	get_node("RightLeg").rotation = Vector3(right.x, 0, 0)
	get_node("LeftLeg/Knee").rotation.x = left.y
	get_node("RightLeg/Knee").rotation.x = right.y
	# Arm on the opposite side leads the planted leg. Only secondary motion
	# uses springs: lagging the supporting legs would introduce foot sliding.
	var beat := cos(cycle * TAU) * amount
	var arm_beat := cos(cycle * TAU - 0.12) * amount
	# Relax the A-pose toward the ribs. Back swing is slightly smaller than
	# forward swing; elbows follow later instead of locking to the shoulders.
	var left_target := -arm_beat * Gait.arm_swing * (0.82 if arm_beat > 0 else 1.0)
	var right_target := arm_beat * Gait.arm_swing * (0.82 if arm_beat < 0 else 1.0)
	var left_arm := spring("left_arm", left_target, delta)
	var right_arm := spring("right_arm", right_target, delta)
	var left_rest := spring("left_arm_rest", 0.45 + sin(cycle * TAU) * 0.012 * amount, delta)
	var right_rest := spring("right_arm_rest", -0.45 + sin(cycle * TAU) * 0.012 * amount, delta)
	get_node("LeftArm").rotation = Vector3(left_arm, 0.035 * beat, left_rest)
	get_node("RightArm").rotation = Vector3(right_arm, 0.035 * beat, right_rest)
	var elbow_beat := cos(cycle * TAU - 0.48)
	# Bend around the actual diagonal upper-arm axis, not world X. The latter
	# mostly twists these A-pose limbs and leaves their silhouettes rigid.
	var left_elbow := spring("left_elbow", 0.24 + (0.5 - 0.5 * elbow_beat) * Gait.elbow_bend * amount, delta)
	var right_elbow := spring("right_elbow", 0.24 + (0.5 + 0.5 * elbow_beat) * Gait.elbow_bend * amount, delta)
	get_node("LeftArm/Elbow").quaternion = Quaternion(Vector3(0.66, -0.75, 0).normalized(), left_elbow)
	get_node("RightArm/Elbow").quaternion = Quaternion(Vector3(0.66, 0.75, 0).normalized(), right_elbow)
	var twist := spring("torso_yaw", -beat * Gait.torso_twist, delta)
	var roll := spring("torso_roll", sin(cycle * TAU) * 0.025 * amount, delta)
	var settle := spring("torso_pitch", (0.025 + cos(cycle * TAU * 2.0) * 0.015) * amount, delta)
	var skeleton: Skeleton3D = get_node("Skeleton3D")
	# Two weight shifts per stride: sink at landing, rise over the supporting
	# leg. Move the upper body through the spine, leaving foot targets planted.
	var step_phase := cycle * TAU * 2.0
	var torso_lift := spring("torso_lift", -cos(step_phase) * Gait.torso_bob * amount, delta)
	var head_lift := spring("head_lift", -cos(step_phase - 0.35) * Gait.head_bob * amount, delta)
	skeleton.set_bone_pose_position(1, skeleton.get_bone_rest(1).origin + Vector3.UP * torso_lift)
	skeleton.set_bone_pose_position(2, skeleton.get_bone_rest(2).origin + Vector3.UP * head_lift)
	skeleton.set_bone_pose_rotation(1, Quaternion.from_euler(Vector3(settle, twist, roll)))
	# Head follows a little later and counters most of the shoulder motion.
	get_node("Head").rotation = Vector3(
		spring("head_pitch", -settle * 0.65 + sin(cycle * TAU * 2.0) * Gait.head_nod * amount, delta),
		spring("head_yaw", -twist * 0.7, delta),
		spring("head_roll", -roll * 0.7, delta))
	rotation.z = 0.0
	Rig.sync(self, skeleton)
	skeleton.force_update_all_bone_transforms()
	# Compose the newly assigned local poses immediately. Skeleton global poses
	# are cached until the frame update, which otherwise makes grounding lag.
	var current: Array[Transform3D] = []
	for bone in skeleton.get_bone_count():
		var local: Transform3D = skeleton.get_bone_pose(bone)
		var parent := skeleton.get_bone_parent(bone)
		current.append(current[parent] * local if parent >= 0 else local)
	var surface: MeshInstance3D = get_node("Surface")
	var sole := INF
	# Use the actual rounded leg-end vertices; these limbs have no separate feet.
	var samples: Dictionary = get_meta("sole_samples")
	for bone: int in samples:
		var transform_: Transform3D = current[bone] * surface.skin.get_bind_pose(bone)
		for point: Vector3 in samples[bone]:
			sole = minf(sole, (basis * (transform_ * point)).y)
	position.y = 0.004 - sole

func bone_pose(bone: int) -> Transform3D:
	# Compose current local poses without waiting a frame for the skeleton cache.
	var skeleton: Skeleton3D = get_node("Skeleton3D")
	var transform_ := skeleton.get_bone_pose(bone)
	var parent := skeleton.get_bone_parent(bone)
	while parent >= 0:
		transform_ = skeleton.get_bone_pose(parent) * transform_
		parent = skeleton.get_bone_parent(parent)
	return transform_

func posed_point(bone: int, point: Vector3) -> Vector3:
	return bone_pose(bone) * get_node("Surface").skin.get_bind_pose(bone) * point
