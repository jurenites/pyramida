shader_type spatial;
render_mode unshaded, cull_front;

uniform float outline_pixels = 1.0;
uniform vec2 viewport_size = vec2(72.0);

void vertex() {
	vec4 clip_position = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec3 view_normal = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec2 projected_normal = (PROJECTION_MATRIX * vec4(view_normal, 0.0)).xy;
	float normal_length = length(projected_normal);
	if (normal_length > 0.0001) {
		projected_normal /= normal_length;
		clip_position.xy += projected_normal * clip_position.w * outline_pixels * 2.0 / viewport_size;
	}
	POSITION = clip_position;
}

void fragment() {
	ALBEDO = vec3(1.0);
}
