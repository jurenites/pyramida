shader_type spatial;
render_mode unshaded, fog_disabled;
#include "res://shaders/settlement_cloud_motion.gdshaderinc"

uniform vec4 cloud_color : source_color = vec4(1.0);
uniform vec4 shade_color : source_color = vec4(0.72, 0.79, 0.84, 1.0);
uniform float cloud_time = 0.0;
varying vec3 face_normal;
varying float active;

void vertex() {
	active = step(0.999, INSTANCE_CUSTOM.r) * step(0.999, INSTANCE_CUSTOM.b);
	VERTEX = (VERTEX + local_drift(MODEL_MATRIX,cloud_drift(cloud_time,INSTANCE_CUSTOM.g,INSTANCE_CUSTOM.a))) * active;
	face_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	if (active < 0.5) { discard; }
	float light = clamp(dot(normalize(face_normal), normalize(vec3(-0.4, 0.85, 0.3))) * 0.55 + 0.55, 0.0, 1.0);
	ALBEDO = mix(shade_color.rgb, cloud_color.rgb, light);
}
