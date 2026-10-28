shader_type spatial;
render_mode cull_disabled, ambient_light_disabled, specular_disabled;

// Keep painted strata flat, but let the moving sun leave readable silhouettes.
// Fade the shadow contribution at the horizon; the world pass owns night tint.
uniform float daylight : hint_range(0.0, 1.0) = 1.0;
const float SHADOW_STRENGTH = 0.60;
void fragment() {
	vec3 paper = mix(COLOR.rgb / 12.92, pow((COLOR.rgb + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), COLOR.rgb));
	ALBEDO = paper;
	EMISSION = paper * (1.0 - SHADOW_STRENGTH * daylight);
	ROUGHNESS = 1.0;
}

void light() {
	// Godot applies ALBEDO after light(): multiplying it here stains the sand.
	DIFFUSE_LIGHT += vec3(ATTENUATION * SHADOW_STRENGTH * daylight);
}
