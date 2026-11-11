shader_type spatial;
render_mode unshaded, cull_disabled;

uniform float wind_strength = 0.16;
uniform float wind_speed = 1.2;
// Every leaf receives the same patch centre, never its individual root.
instance uniform vec2 wind_origin = vec2(0.0);
varying vec4 tuft_color;

vec2 gradient(vec2 lattice) {
	float angle = fract(sin(dot(lattice, vec2(127.1, 311.7))) * 43758.5453) * 6.2831853;
	return vec2(cos(angle), sin(angle));
}

// Broad, continuous Perlin wind field: neighbouring patches share weather.
float wind_noise(vec2 point) {
	vec2 cell = floor(point);
	vec2 local = fract(point);
	vec2 blend = local * local * local * (local * (local * 6.0 - 15.0) + 10.0);
	return mix(mix(dot(gradient(cell), local),
		dot(gradient(cell + vec2(1.0, 0.0)), local - vec2(1.0, 0.0)), blend.x),
		mix(dot(gradient(cell + vec2(0.0, 1.0)), local - vec2(0.0, 1.0)),
		dot(gradient(cell + vec2(1.0)), local - vec2(1.0)), blend.x), blend.y);
}

void vertex() {
	tuft_color = vec4(mix(COLOR.rgb / 12.92, pow((COLOR.rgb + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), COLOR.rgb)), COLOR.a);
	// Upright cutout blades always face the camera. Root vertices stay planted.
	vec3 right = normalize(vec3(INV_VIEW_MATRIX[0].x, 0.0, INV_VIEW_MATRIX[0].z));
	vec3 forward = normalize(cross(right, vec3(0.0, 1.0, 0.0)));
	mat4 billboard = mat4(vec4(right * length(MODEL_MATRIX[0].xyz), 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
		vec4(forward * length(MODEL_MATRIX[2].xyz), 0.0), MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = VIEW_MATRIX * billboard;
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	// Batched field blades supply independent lean; ordinary Grass leaves use zero.
	VERTEX.x += INSTANCE_CUSTOM.x * UV.y;
	vec2 field = wind_origin * 0.045 + vec2(TIME * 0.014, TIME * 0.009);
	float angle = 0.4 + wind_noise(field) * 2.8;
	vec2 direction = vec2(cos(angle), sin(angle));
	float phase = wind_noise(wind_origin * 0.035 + vec2(17.3, 8.1)) * 2.0;
	float sway = 0.35 + 0.65 * sin(TIME * wind_speed + phase);
	vec2 bend = direction * wind_strength * sway * UV.y * UV.y;
	VERTEX.x += dot(vec3(bend.x, 0.0, bend.y), right);
	VERTEX.z += dot(vec3(bend.x, 0.0, bend.y), forward);
	VERTEX.y -= length(bend) * 0.18;
}

void fragment() {
	ALBEDO = tuft_color.rgb * mix(0.86, 1.08, UV.y);
	ROUGHNESS = 1.0;
}
