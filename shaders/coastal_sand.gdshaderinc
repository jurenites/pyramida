float seabed_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float seabed_noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(seabed_hash(i), seabed_hash(i + vec2(1.0, 0.0)), f.x),
		mix(seabed_hash(i + vec2(0.0, 1.0)), seabed_hash(i + vec2(1.0)), f.x), f.y);
}
vec3 coastal_floor(vec3 world, float water_level, float clock, bool sandy) {
	vec2 p = world.xz;
	float depth = max(0.0, water_level - world.y);
	vec2 warped = p * 0.10 + vec2(seabed_noise(p * 0.21), seabed_noise(p * 0.18 + 17.0)) * 1.4;
	float patches = smoothstep(0.46, 0.72, seabed_noise(warped));
	vec3 substrate = mix(vec3(0.075, 0.17, 0.145), vec3(0.34, 0.31, 0.19), sandy ? patches : 0.0);
	// All submerged materials approach one dark teal tone at depth. Rock toes
	// cannot end in a differently coloured sand pedestal against the outer bed.
	substrate = mix(substrate, vec3(0.025, 0.105, 0.115), smoothstep(1.5, 4.5, depth));
	vec2 q = p + 0.6 * vec2(sin(p.y * 0.37), cos(p.x * 0.29));
	float a = sin(q.x * 2.3 + 0.6 * sin(q.y * 1.7) + clock * 0.45);
	float b = sin(q.y * 2.1 + 0.7 * sin(q.x * 1.5) - clock * 0.33);
	float veins = pow(max(0.0, 1.0 - abs(a + b) * 0.5), 20.0);
	float fade = exp(-depth * 0.7);
	fade *= 1.0 - smoothstep(0.3, 1.2, max(fwidth(p.x), fwidth(p.y)));
	float sand = 0.025 * sin(p.x * 0.63 + p.y * 0.34);
	return substrate * (1.0 + sand) + vec3(0.025, 0.045, 0.035) * veins * fade;
}
vec3 coastal_sand(vec3 world, float water_level, float clock) {
	return coastal_floor(world, water_level, clock, true);
}
