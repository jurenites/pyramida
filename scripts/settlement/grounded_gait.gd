extends Resource
## Editable foot paths. A planted foot travels backwards at the body's speed.
@export var half_step := 0.10
@export var stance_fraction := 0.60
@export var clearance := 0.045
@export var contact_height := 0.03
@export var cycle_seconds := 0.90
@export var arm_swing := 0.32
@export var elbow_bend := 0.18
@export var torso_twist := 0.065
@export var head_nod := 0.022
@export var torso_bob := 0.018
@export var head_bob := 0.004
var stride_length: float:
	get: return half_step * 2.0 / stance_fraction

func planted(cycle: float) -> bool:
	return fposmod(cycle, 1.0) < stance_fraction

func foot_target(cycle: float) -> Vector2:
	var phase := fposmod(cycle, 1.0)
	if phase < stance_fraction:
		return Vector2(half_step - phase * stride_length, contact_height)
	var t := (phase - stance_fraction) / (1.0 - stance_fraction)
	# Hermite tangents match ground speed at toe-off and touchdown. No pause
	# at either end of the swing, and no sliding during the planted phase.
	var tangent := -stride_length * (1.0 - stance_fraction)
	var forward := (2*t*t*t - 3*t*t + 1) * -half_step + (t*t*t - 2*t*t + t) * tangent + (-2*t*t*t + 3*t*t) * half_step + (t*t*t - t*t) * tangent
	return Vector2(forward, contact_height + clearance * pow(sin(PI * t), 2.0))

func leg_pose(cycle: float) -> Vector2:
	var target := foot_target(cycle)
	var thigh := 0.15
	var shin := 0.182
	var down := 0.34 - target.y
	var distance_squared := target.x * target.x + down * down
	var knee := -acos(clampf((distance_squared - thigh*thigh - shin*shin) / (2*thigh*shin), -1.0, 1.0))
	var hip := atan2(target.x, down) - atan2(shin * sin(knee), thigh + shin * cos(knee))
	return Vector2(hip, knee)
