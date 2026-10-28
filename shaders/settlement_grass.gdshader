shader_type spatial;
render_mode unshaded, cull_disabled;

uniform float wind_strength = 0.16;
uniform float wind_speed = 1.2;
uniform vec2 wind_direction = vec2(0.92, 0.38);
varying vec4 tuft_color;

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	tuft_color = vec4(mix(COLOR.rgb / 12.92, pow((COLOR.rgb + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), COLOR.rgb)), COLOR.a);
	// Upright cutout blades always face the camera. Root vertices stay planted.
	vec3 right = normalize(vec3(INV_VIEW_MATRIX[0].x, 0.0, INV_VIEW_MATRIX[0].z));
	vec3 forward = normalize(cross(right, vec3(0.0, 1.0, 0.0)));
	mat4 billboard = mat4(vec4(right * length(MODEL_MATRIX[0].xyz), 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
		vec4(forward * length(MODEL_MATRIX[2].xyz), 0.0), MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = VIEW_MATRIX * billboard;
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	float gust = 0.55 + 0.45 * sin(dot(origin.xz, wind_direction) * 0.33 - TIME * wind_speed);
	float flutter = sin(TIME * 3.4 + dot(origin.xz, vec2(2.7, 1.3))) * 0.12;
	vec2 bend = wind_direction * wind_strength * (gust + flutter) * UV.y * UV.y;
	VERTEX.x += dot(vec3(bend.x, 0.0, bend.y), right);
	VERTEX.z += dot(vec3(bend.x, 0.0, bend.y), forward);
	VERTEX.y -= length(bend) * 0.18;
}

void fragment() {
	ALBEDO = tuft_color.rgb * mix(0.86, 1.08, UV.y);
	ROUGHNESS = 1.0;
}
