shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;
uniform vec3 allowed_min;
uniform vec3 allowed_max;
uniform mat4 volume_inverse;
varying vec3 volume_position;
void vertex() {
	volume_position = (volume_inverse * MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	if (all(greaterThanEqual(volume_position, allowed_min)) && all(lessThanEqual(volume_position, allowed_max))) discard;
	ALBEDO = vec3(1.0, 0.08, 0.04);
	ALPHA = 0.52;
}
