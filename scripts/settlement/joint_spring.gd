extends RefCounted
## A constrained angular spring for the visual puppet; never moves simulation bodies.
var angle := 0.0
var velocity := 0.0
var lower: float
var upper: float
const FREQUENCY := 28.0
const DAMPING := 0.72

func _init(minimum: float, maximum: float) -> void:
	lower = minimum
	upper = maximum

func reset(target: float) -> float:
	angle = clampf(target, lower, upper)
	velocity = 0.0
	return angle

func step(target: float, delta: float) -> float:
	if delta <= 0.0:
		return angle
	target = clampf(target, lower, upper)
	# Exact damped-spring integration stays stable at fast simulation speeds and after hitches.
	var decay := FREQUENCY * DAMPING
	var frequency := FREQUENCY * sqrt(1.0 - DAMPING * DAMPING)
	var displacement := angle - target
	var coefficient := (velocity + decay * displacement) / frequency
	var cosine := cos(frequency * delta)
	var sine := sin(frequency * delta)
	var envelope := exp(-decay * delta)
	var oscillation := displacement * cosine + coefficient * sine
	angle = target + envelope * oscillation
	velocity = envelope * (-decay * oscillation + frequency * (coefficient * cosine - displacement * sine))
	if angle < lower or angle > upper:
		angle = clampf(angle, lower, upper)
		if (angle == lower and velocity < 0.0) or (angle == upper and velocity > 0.0):
			velocity = 0.0
	return angle
