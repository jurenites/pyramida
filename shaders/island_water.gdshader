shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform vec4 deep_colour : source_color = vec4(0.055, 0.40, 0.47, 1.0);
uniform vec4 open_colour : source_color = vec4(0.075, 0.51, 0.53, 1.0);
// Freshwater patches share the shallow-water shading without surf or offshore opacity.
uniform bool puddle_surface = false;
uniform bool natural_reef = false;
uniform vec2 wind_direction = vec2(0.85, 0.52);
uniform float wind_speed : hint_range(0.0, 4.0) = 1.25;
uniform float wave_strength : hint_range(0.0, 1.0) = 0.65;
// A fixed phase is useful for render checks; normal play uses the live clock.
uniform float wave_time_override = -1.0;
uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;
uniform sampler2D coast_field : repeat_disable, filter_linear;
uniform bool coast_enabled = false;
uniform vec4 coast_bounds = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec4 shallow_colour : source_color = vec4(0.15, 0.69, 0.65, 1.0);
uniform vec4 reef_colour : source_color = vec4(0.36, 0.80, 0.73, 1.0);
uniform vec4 foam_colour : source_color = vec4(0.92, 0.97, 0.89, 1.0);
varying vec2 world_xz;
varying float water_y;
void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_xz = world.xz;
	water_y = world.y;
}
float wave_hash(vec2 cell) {
	return fract(sin(dot(cell, vec2(127.1, 311.7))) * 43758.5453);
}
float wave_noise(vec2 point) {
	vec2 cell = floor(point);
	vec2 blend = fract(point);
	blend = blend * blend * (3.0 - 2.0 * blend);
	return mix(mix(wave_hash(cell), wave_hash(cell + vec2(1.0, 0.0)), blend.x),
		mix(wave_hash(cell + vec2(0.0, 1.0)), wave_hash(cell + vec2(1.0, 1.0)), blend.x), blend.y);
}
void fragment() {
	vec2 wind = wind_direction / max(length(wind_direction), 0.001);
	vec2 crosswind = vec2(-wind.y, wind.x);
	float clock = wave_time_override >= 0.0 ? wave_time_override : TIME;
	vec2 coast_uv = (world_xz - coast_bounds.xy) / coast_bounds.zw;
	vec3 coast = puddle_surface ? vec3(100.0, 0.0, 0.0) : vec3(100.0, 1.0, 100.0);
	if (coast_enabled && all(greaterThanEqual(coast_uv, vec2(0.0))) && all(lessThanEqual(coast_uv, vec2(1.0)))) {
		coast = texture(coast_field, coast_uv).rgb;
	}
	float strength = wave_strength * mix(0.12, 1.0, coast.g);
	// Reconstruct the opaque scene under this pixel. Works for orthographic cameras,
	// submerged rocks, buildings and excavated solids as well as the seabed.
	float depth = texture(depth_texture, SCREEN_UV).r;
	#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 ndc = vec3(SCREEN_UV, depth) * 2.0 - 1.0;
	#else
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth);
	#endif
	vec4 bottom = INV_VIEW_MATRIX * INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	float thickness = max(0.0, water_y - bottom.y / bottom.w);
	float shallows = exp(-thickness * 0.55);
	// The entire pattern advects downwind. Crests run across that direction.
	vec2 drift = world_xz - wind * wind_speed * clock;
	float along = dot(drift, wind);
	float across = dot(drift, crosswind);
	float bend = 1.8 * wave_noise(vec2(along * 0.11, across * 0.24)) + 0.32 * sin(across * 0.43);
	float swell = along * 0.78 + bend;
	float ripple = along * 2.1 + across * 0.16 + 0.5 * sin(across * 0.7);
	float slope = (0.24 * cos(swell) + 0.065 * cos(ripple)) * strength;
	vec3 normal = normalize(vec3(-wind.x * slope, 1.0, -wind.y * slope));
	float facet = dot(normal, normalize(vec3(-0.55, 1.0, 0.35)));
	float broad = 0.5 + sin(along * 0.052 + across * 0.071) * 0.5 * mix(0.15, 1.0, coast.g);
	vec3 water = mix(deep_colour.rgb, open_colour.rgb, broad);
	water = mix(water, shallow_colour.rgb, shallows * 0.65);
	// A shallow submerged shelf is readable even well away from the coastline.
	if (!puddle_surface) { water = mix(water, reef_colour.rgb, (1.0 - smoothstep(0.85, 2.4, thickness)) * (natural_reef ? 0.38 : 0.8)); }
	water *= 0.89 + 0.20 * facet + 0.035 * strength * sin(swell);
	// Offshore water has blue, softly shaded wavelets, not long white stripes.
	float breakup = smoothstep(0.48, 0.78, wave_noise(vec2(along * 0.65, across * 1.15)));
	float crest = pow(max(0.0, sin(ripple)), 5.0) * breakup;
	float distance_fade = 1.0 - smoothstep(0.4, 1.6, fwidth(ripple));
	water += open_colour.rgb * crest * 0.075 * strength * distance_fade;
	float shore_distance = max(0.0, coast.r);
	// Project onto the nearby coast so a packet keeps its timing while travelling
	// toward land. The distance gradient bends its short front around rocks/bays.
	vec2 texel = 1.0 / vec2(textureSize(coast_field, 0));
	vec2 outward = wind;
	if (coast_enabled && shore_distance < 6.0) {
		vec2 gradient = vec2(
			texture(coast_field, coast_uv + vec2(texel.x, 0.0)).r - texture(coast_field, coast_uv - vec2(texel.x, 0.0)).r,
			texture(coast_field, coast_uv + vec2(0.0, texel.y)).r - texture(coast_field, coast_uv - vec2(0.0, texel.y)).r);
		outward = gradient / max(length(gradient), 0.001);
	}
	vec2 anchor = world_xz - outward * min(shore_distance, 6.0);
	float timing = wave_noise(anchor * 0.28) * 2.2;
	float age = mod(clock + timing, 5.0);
	float packet = smoothstep(0.24, 0.70, wave_noise(anchor * 1.05));
	float front = 3.6 * (1.0 - age / 3.2);
	float rolling = (1.0 - smoothstep(0.10, 0.42, abs(shore_distance - front))) * (1.0 - step(3.2, age));
	rolling *= packet * mix(0.15, 1.0, coast.g);
	water += shallow_colour.rgb * rolling * 0.16;
	// At impact the foam rises quickly, spreads slightly, breaks up and dies out
	// completely before the next packet arrives. There is no permanent white rim.
	float foam_age = max(0.0, age - 3.2);
	float lifetime = smoothstep(0.0, 0.12, foam_age) * exp(-foam_age * 2.1);
	lifetime *= 1.0 - smoothstep(1.35, 1.75, foam_age);
	float width = 0.20 + 0.32 * foam_age;
	float edge = 1.0 - smoothstep(width * 0.25, width + 0.18, shore_distance);
	float contact = 1.0 - smoothstep(0.025, 0.18, thickness);
	float froth = wave_noise(world_xz * 3.5 + outward * foam_age * 0.6);
	float holes = smoothstep(0.18 + foam_age * 0.20, 0.65, froth);
	float foam = max(edge, contact) * lifetime * packet * holes * mix(0.45, 1.0, coast.g);
	if (puddle_surface) { foam = 0.0; }
	ALBEDO = mix(water, foam_colour.rgb, clamp(foam, 0.0, 0.9));
	// Real alpha blending reveals the underlying rock/sand; deep water stays opaque.
	float opacity = 0.30 + 0.70 * (1.0 - exp(-thickness * 0.65));
	if (natural_reef && !puddle_surface) opacity = 0.42 + 0.58 * (1.0 - exp(-thickness * 0.95));
	// Tiny flush patches need enough pigment to read as water at town zoom.
	if (puddle_surface) { opacity = max(opacity, 0.72); }
	// Hide the distant finite bed boundary smoothly, before the field runs out.
	opacity = mix(opacity, 1.0, smoothstep(14.0, 23.0, coast.b));
	ALPHA = mix(opacity, 1.0, foam) * (puddle_surface ? 1.0 : smoothstep(0.0, 0.10, thickness));
}
