extends RefCounted
## Lighting follows saved simulation time, never wall-clock or render-frame time.
const Settings = preload("res://scripts/gameplay_settings.gd")
const Palette = preload("res://scripts/game_palette.gd")
const MAX_SHADOW_LENGTH_PER_HEIGHT := 4.0

static func daylight_at(elapsed: float) -> float:
	var phase := fposmod(elapsed, Settings.SIMULATION_DAY_SECONDS) / Settings.SIMULATION_DAY_SECONDS
	return smoothstep(0.0, 0.16, sin(phase * TAU))

static func apply(sun: DirectionalLight3D, environment: Environment, elapsed: float) -> void:
	var phase := fposmod(elapsed, Settings.SIMULATION_DAY_SECONDS) / Settings.SIMULATION_DAY_SECONDS
	var sun_height := sin(phase * TAU)
	var daylight := daylight_at(elapsed)
	# The sun crosses from east to west, then travels below the horizon.
	var sun_angle := phase * TAU
	if sun_height > 0.0:
		# Near-horizontal rays produce effectively infinite ground streaks.
		# Limit projection length while the real clock still controls the fade.
		var minimum_elevation := atan(1.0 / MAX_SHADOW_LENGTH_PER_HEIGHT)
		sun_angle = clampf(sun_angle, minimum_elevation, PI - minimum_elevation)
	sun.rotation = Vector3(-sun_angle, -PI / 2.0, 0.0)
	sun.visible = sun_height > 0.0
	sun.light_energy = 0.85 * daylight
	sun.light_color = cycle_color(phase, Palette.MORNING_LIGHT,
		Palette.SUN.lightened(0.65), Palette.EVENING_LIGHT, Palette.NIGHT_LIGHT)
	environment.background_color = cycle_color(phase, Palette.MORNING_SKY,
		Palette.SAND_SURFACE, Palette.EVENING_SKY, Palette.NIGHT_SKY)
	environment.ambient_light_color = cycle_color(phase, Palette.MORNING_LIGHT,
		Color("d4dfdc"), Palette.EVENING_LIGHT, Palette.NIGHT_LIGHT)
	# Keep buildings and paths readable during the dark half of the cycle.
	environment.ambient_light_energy = lerpf(0.32, 0.45, daylight)

static func cycle_color(phase: float, morning: Color, day: Color, evening: Color, night: Color) -> Color:
	if phase < 0.12:
		return morning.lerp(day, smoothstep(0.0, 0.12, phase))
	if phase < 0.38:
		return day
	if phase < 0.5:
		return day.lerp(evening, smoothstep(0.38, 0.5, phase))
	if phase < 0.62:
		return evening.lerp(night, smoothstep(0.5, 0.62, phase))
	if phase < 0.86:
		return night
	return night.lerp(morning, smoothstep(0.86, 1.0, phase))

# Cool the paper and sand together as dusk crosses into night.
static func night_amount(phase: float) -> float:
	return smoothstep(0.44, 0.54, phase) * (1.0 - smoothstep(0.88, 1.0, phase))
