extends RefCounted
## Lightweight activity accents layered over the approved walk and carry pose.
static func apply(actor: Node3D, worker: Dictionary, time: float, grade: float, delta: float) -> void:
	var body: Node3D = actor.body
	var rig: Skeleton3D = actor.skeleton
	var still: float = 1.0 - actor.walk_blend
	var breathing := sin(time * 2.1)
	var pitch: float = -clampf(grade, -0.8, 0.8) * 0.18 * actor.walk_blend
	var head_yaw: float = sin(time * 0.7) * 0.07 * still
	var head_pitch: float = breathing * 0.012 * still
	var status: String = worker.get("status", "idle")
	var job: Dictionary = worker.get("job", {})
	var beat := sin(time * 5.0)
	var reach: bool = status in ["harvesting", "collecting water", "watering"] or job.get("phase", "") in ["pickup", "collect", "deposit", "deliver"]
	var processing := status == "economy_processing_text"
	var eating := status == "eating"
	var climbing: bool = worker.get("rescue_climbing", false)
	if climbing: pitch += 0.15
	if worker.get("cargo", "").is_empty() and (reach or processing or eating or climbing):
		pitch += (0.08 + 0.035 * (1.0 + beat)) * still if reach else 0.025 * beat * still
		head_pitch += 0.05 * still if reach else 0.015 * beat * still
		head_yaw *= 0.2
		for side in [-1, 1]:
			var arm: Node3D = body.get_node("LeftArm" if side < 0 else "RightArm")
			var swing := sin(time * 5.0 + (PI if side > 0 else 0.0))
			var lift: float = (0.48 + swing * 0.18) * still
			if eating: lift = (0.98 + beat * 0.18) * still if side > 0 else 0.08 * still
			if climbing: lift = 1.5 + swing * 0.25
			arm.rotation.x += body.spring("activity_arm_%d" % side, lift, delta)
			var bend := (0.70 + swing * 0.18) if not eating else (1.4 if side > 0 else 0.24)
			actor.pose_elbow(side, lerpf(0.24, bend, still), delta, delta == 0.0)
	else:
		for side in [-1, 1]:
			var arm: Node3D = body.get_node("LeftArm" if side < 0 else "RightArm")
			arm.rotation.x += body.spring("activity_arm_%d" % side, 0.0, delta)
	var torso_rotation := rig.get_bone_pose_rotation(1).get_euler()
	torso_rotation.x += body.spring("activity_pitch", pitch + breathing * 0.008 * still, delta)
	rig.set_bone_pose_rotation(1, Quaternion.from_euler(torso_rotation))
	var torso_position := rig.get_bone_pose_position(1)
	torso_position.y += breathing * 0.002 * still
	rig.set_bone_pose_position(1, torso_position)
	body.get_node("Head").rotation.y += body.spring("activity_look", head_yaw, delta)
	body.get_node("Head").rotation.x += body.spring("activity_nod", head_pitch, delta)
