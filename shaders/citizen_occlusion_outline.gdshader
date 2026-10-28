shader_type canvas_item;
render_mode unshaded;

uniform sampler2D visible_mask : filter_linear, repeat_disable;
uniform sampler2D silhouette_mask : filter_linear, repeat_disable;
uniform sampler2D selection_mask : filter_linear, repeat_disable;
uniform bool has_selection = false;
uniform vec2 stroke_uv;
uniform vec4 outline_color : source_color;
uniform vec4 selection_color : source_color;

float hidden_at(vec2 uv) {
	// Subtract coverage so matching antialiased edges cancel completely.
	return max(texture(silhouette_mask, uv).r - texture(visible_mask, uv).r, 0.0);
}

void fragment() {
	// Dilate only the concealed silhouette, then remove the whole body interior.
	// A shared mask joins overlapping limbs without drawing their internal seams.
	float concealed = 0.0;
	float selected = 0.0;
	for (int i = 0; i < 16; i++) {
		float angle = float(i) * 6.2831853 / 16.0;
		vec2 offset = vec2(cos(angle), sin(angle)) * stroke_uv;
		concealed = max(concealed, hidden_at(SCREEN_UV + offset));
		concealed = max(concealed, hidden_at(SCREEN_UV + offset * 0.5));
		if (has_selection) {
			selected = max(selected, texture(selection_mask, SCREEN_UV + offset).r);
			selected = max(selected, texture(selection_mask, SCREEN_UV + offset * 0.5).r);
		}
	}
	float edge = concealed * (1.0 - texture(silhouette_mask, SCREEN_UV).r);
	float selection_edge = has_selection ? selected * (1.0 - texture(selection_mask, SCREEN_UV).r) : 0.0;
	// Selection replaces the neutral occlusion cue, including antialiased edges.
	float hidden_alpha = outline_color.a * edge * (1.0 - selected);
	float selected_alpha = selection_color.a * selection_edge;
	float alpha = hidden_alpha + selected_alpha;
	vec3 colour = (outline_color.rgb * hidden_alpha + selection_color.rgb * selected_alpha) / max(alpha, 0.0001);
	COLOR = vec4(colour, alpha);
}
