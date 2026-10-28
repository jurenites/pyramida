shader_type canvas_item;
render_mode unshaded;

uniform float edge_width : hint_range(0.0, 2.0) = 0.65;
uniform float roughness : hint_range(0.0, 2.0) = 0.8;
uniform float ink_strength : hint_range(0.0, 1.0) = 0.32;
uniform vec3 day_tint = vec3(1.0);
uniform bool linear_source = false;

vec4 painted_colour(vec4 colour) {
	if (linear_source) {
		colour.rgb = mix(colour.rgb * 12.92, 1.055 * pow(max(colour.rgb, vec3(0.0)), vec3(1.0 / 2.4)) - 0.055, step(vec3(0.0031308), colour.rgb));
	}
	return colour;
}

// Static, continuous offsets give contours an irregular drawn edge, not animated noise.
vec2 paper_offset(vec2 p) {
	return vec2(sin(p.y * 0.39 + sin(p.x * 0.17)), sin(p.x * 0.43 + sin(p.y * 0.13))) * 0.65
		+ vec2(sin(p.y * 1.07), sin(p.x * 0.97)) * 0.22;
}
void fragment() {
	vec2 pixel = TEXTURE_PIXEL_SIZE;
	vec2 uv = UV + paper_offset(UV / pixel) * pixel * roughness;
	vec4 fill = painted_colour(texture(TEXTURE, uv));
	vec2 dx = vec2(pixel.x * edge_width, 0.0);
	vec2 dy = vec2(0.0, pixel.y * edge_width);
	float edge = max(length(fill.rgb - painted_colour(texture(TEXTURE, uv + dx)).rgb), length(fill.rgb - painted_colour(texture(TEXTURE, uv - dx)).rgb));
	edge = max(edge, max(length(fill.rgb - painted_colour(texture(TEXTURE, uv + dy)).rgb), length(fill.rgb - painted_colour(texture(TEXTURE, uv - dy)).rgb)));
	float stroke = smoothstep(0.08, 0.35, edge) * ink_strength;
	vec3 ink = fill.rgb * vec3(0.45, 0.40, 0.35);
	COLOR = vec4(mix(fill.rgb, ink, stroke) * day_tint, fill.a);
}
