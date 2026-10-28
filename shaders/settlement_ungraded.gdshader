shader_type spatial;
render_mode unshaded, fog_disabled;

global uniform vec3 settlement_day_tint;
// Kept in sRGB so this exactly cancels the illustrated pass's sRGB grading.
uniform vec4 fill_colour = vec4(1.0);

vec3 srgb_to_linear(vec3 colour) {
	return mix(colour / 12.92, pow((colour + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), colour));
}

void fragment() {
	ALBEDO = srgb_to_linear(fill_colour.rgb / max(settlement_day_tint, vec3(0.001)));
}
