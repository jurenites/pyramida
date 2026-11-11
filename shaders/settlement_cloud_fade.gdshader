shader_type spatial;
render_mode unshaded, fog_disabled, depth_draw_never;
#include "res://shaders/settlement_cloud_motion.gdshaderinc"

uniform vec4 cloud_color : source_color = vec4(1.0);
uniform vec4 shade_color : source_color = vec4(0.72, 0.79, 0.84, 1.0);
uniform float cloud_time = 0.0;
uniform vec3 camera_focus = vec3(0.0);
uniform float camera_reach = 12.0;
varying vec3 face_normal;
varying float opacity;

void vertex() {
	float remaining = INSTANCE_CUSTOM.r;
	float active = 1.0 - step(0.999, remaining) * step(0.999, INSTANCE_CUSTOM.b);
	VERTEX = (VERTEX * mix(0.025, 1.0, smoothstep(0.0, 1.0, remaining))
		+ local_drift(MODEL_MATRIX,cloud_drift(cloud_time,INSTANCE_CUSTOM.g,INSTANCE_CUSTOM.a))) * active;
	face_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
	opacity = smoothstep(0.0, 0.75, remaining) * INSTANCE_CUSTOM.b * active;
	// The orthographic camera moves back when zooming out. Its ground focus is
	// the useful measure of approach, rather than the native camera distance.
	float nearby = 1.0 - smoothstep(camera_reach, camera_reach + 24.0, distance(MODEL_MATRIX[3].xz,camera_focus.xz));
	if (INSTANCE_CUSTOM.b < 0.999) { opacity *= mix(1.0,0.28,nearby); }
}

void fragment() {
	if (opacity < 0.005) { discard; }
	float light = clamp(dot(normalize(face_normal), normalize(vec3(-0.4, 0.85, 0.3))) * 0.55 + 0.55, 0.0, 1.0);
	ALBEDO = mix(shade_color.rgb, cloud_color.rgb, light);
	float soft_rim = smoothstep(0.02,0.42,abs(dot(normalize(NORMAL),normalize(VIEW))));
	ALPHA = opacity * soft_rim;
}
