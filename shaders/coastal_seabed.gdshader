shader_type spatial;
render_mode unshaded, cull_disabled;
#include "res://shaders/coastal_sand.gdshaderinc"
uniform bool continuous_coast = false;
uniform vec4 sand_colour : source_color = vec4(0.66, 0.68, 0.51, 1.0);
uniform float water_level = -0.65;
uniform float wave_time_override = -1.0;
varying vec3 world;
void vertex() { world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float clock = wave_time_override >= 0.0 ? wave_time_override : TIME;
	vec2 p = world.xz;
	// Subtle moving light on the visible bed gives the clear shallows depth cues.
	float a = sin(p.x * 2.3 + 0.6 * sin(p.y * 1.7) + clock * 0.45);
	float b = sin(p.y * 2.1 + 0.7 * sin(p.x * 1.5) - clock * 0.33);
	float veins = pow(max(0.0, 1.0 - abs(a + b) * 0.5), 20.0);
	float fade = exp(-max(0.0, water_level - world.y) * 0.7);
	fade *= 1.0 - smoothstep(0.3, 1.2, max(fwidth(p.x), fwidth(p.y)));
	float sand = 0.025 * sin(p.x * 0.63 + p.y * 0.34);
	ALBEDO = sand_colour.rgb * (1.0 + sand) + vec3(0.11, 0.15, 0.10) * veins * fade;
	if (continuous_coast) ALBEDO = coastal_sand(world, water_level, clock);
}
