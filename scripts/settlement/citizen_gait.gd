extends Resource
## One leg's repeating poses: cycle fraction, thigh angle, knee angle (radians).
## The opposite leg samples half a cycle later. Timing lives in the .tres assets.
@export var stride_length := 1.2
@export var poses := PackedVector3Array()
@export var arm_swing := 0.5
@export var elbow_bend := 0.75
@export var sway := 0.045
@export var lean := 0.0
@export var flight_height := 0.0

func leg_pose(cycle: float) -> Vector2:
	var t := fposmod(cycle, 1.0)
	for index in range(1, poses.size()):
		var next := poses[index]
		if t <= next.x:
			var previous := poses[index - 1]
			# Ease into the lifted pose and into contact, without a hard knee snap.
			var blend := smoothstep(previous.x, next.x, t)
			return Vector2(lerpf(previous.y, next.y, blend), lerpf(previous.z, next.z, blend))
	return Vector2(poses[0].y, poses[0].z)

func flight(cycle: float) -> float:
	# Two small airborne beats per running cycle; walking stays grounded.
	return pow(maxf(0.0, sin(cycle * TAU * 2.0)), 2.0) * flight_height
