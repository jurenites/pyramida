shader_type spatial;
render_mode unshaded, cull_disabled;
uniform float coast_phase = 0.0;
varying vec2 world_position;
void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}
void fragment() {
	float shore = 24.0 + sin(world_position.y * 0.045 + coast_phase) * 5.0 + sin(world_position.y * 0.12 + coast_phase) * 1.8;
	float depth = world_position.x - shore;
	if (depth < -0.65) { discard; }
	vec3 shallow = vec3(0.30, 0.66, 0.62);
	vec3 deep = vec3(0.13, 0.43, 0.53);
	vec3 water = mix(shallow, deep, smoothstep(0.0, 16.0, depth));
	float ripple = sin(depth * 4.2 - TIME * 1.3 + sin(world_position.y * 0.5) * 0.35);
	float foam = smoothstep(0.88, 1.0, ripple) * (1.0 - smoothstep(0.0, 3.5, depth));
	water = mix(water, vec3(0.86, 0.91, 0.76), foam * 0.65);
	ALBEDO = mix(water / 12.92, pow((water + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), water));
}
