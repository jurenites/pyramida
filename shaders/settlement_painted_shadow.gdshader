shader_type spatial;
render_mode cull_disabled, ambient_light_disabled, specular_disabled;

global uniform float settlement_daylight;
uniform vec4 fill_colour : source_color = vec4(1.0);
uniform bool use_vertex_colour = false;
uniform vec3 shadow_ratio = vec3(0.62, 0.57, 0.53);
uniform bool wet_wood = false;
uniform bool shaped_surface = false;
uniform float water_level = -0.08;
varying float world_height;
varying float front_surface;
varying float face_tone;

void vertex() {
	world_height = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
	vec3 world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
	face_tone = mix(0.72, 1.0, smoothstep(0.0, 0.92, world_normal.y));
}

void fragment() {
	ALBEDO = fill_colour.rgb * (use_vertex_colour ? COLOR.rgb : vec3(1.0));
	if (shaped_surface) { ALBEDO *= face_tone; }
	// A narrow damp edge above the sea, with darker submerged timber below it.
	if (wet_wood) {
		float wetness = 1.0 - smoothstep(water_level - 0.04, water_level + 0.20, world_height);
		ALBEDO *= mix(vec3(1.0), vec3(0.48, 0.57, 0.55), wetness);
	}
	// Interior back faces remain in the ambient shade.
	front_surface = FRONT_FACING ? 1.0 : 0.0;
	EMISSION = ALBEDO * mix(vec3(1.0), shadow_ratio, settlement_daylight);
	ROUGHNESS = 1.0;
}

void light() {
	// Preserve the painted palette in sunlight; receive actual occluder shadows.
	// Backlit/grazing surfaces must not sample their own shadow as sunlight.
	// A short soft transition retains the painted style without speckled interiors.
	float sunlight = smoothstep(0.0, 0.2, dot(NORMAL, LIGHT));
	if (shaped_surface) { sunlight *= 0.55 + 0.45 * max(0.0, dot(NORMAL, LIGHT)); }
	if (LIGHT_IS_DIRECTIONAL) { DIFFUSE_LIGHT += ATTENUATION * (vec3(1.0) - shadow_ratio) * settlement_daylight * front_surface * sunlight; }
}
