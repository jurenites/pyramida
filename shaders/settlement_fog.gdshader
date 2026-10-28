shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled, depth_draw_never, depth_test_disabled;

uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;
uniform sampler2D fog_mask : filter_linear, repeat_disable;
uniform vec4 fog_color : source_color;
uniform vec2 mask_origin = vec2(-192.0);
uniform vec2 mask_size = vec2(384.0);

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}
void fragment() {
	float depth = texture(depth_texture, SCREEN_UV).r;
	vec4 view = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	view /= view.w;
	vec3 world = (INV_VIEW_MATRIX * view).xyz;
	vec2 mask_uv = (world.xz - mask_origin) / mask_size;
	float revealed = texture(fog_mask, mask_uv).r;
	bool inside = all(greaterThanEqual(mask_uv, vec2(0.0))) && all(lessThan(mask_uv, vec2(1.0)));
	// Keep the old opaque contour; cover actual terrain depth, including cliffs.
	if (depth > 0.00001 && inside && revealed >= 0.5) {
		discard;
	}
	ALBEDO = fog_color.rgb;
	// Draw last, without overwriting transparent construction in explored regions.
	ALPHA = 1.0;
}
