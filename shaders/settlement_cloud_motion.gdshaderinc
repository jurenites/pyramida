uniform vec2 wind_direction = vec2(0.85, 0.52);

vec3 cloud_drift(float seconds, float group_phase, float lobe_phase) {
	// Lobes travel together; neighbouring cloud groups take slightly different
	// headings and speeds. Bounded drift keeps the discovered coast clear.
	float heading = (group_phase - 0.5) * 1.1;
	vec2 wind = normalize(vec2(wind_direction.x*cos(heading)-wind_direction.y*sin(heading), wind_direction.x*sin(heading)+wind_direction.y*cos(heading)));
	vec2 crosswind = vec2(-wind.y,wind.x);
	float phase = group_phase * 6.28318;
	float travel = seconds * mix(0.045,0.075,group_phase) + phase;
	vec2 offset = wind * sin(travel) * 2.5 + crosswind * sin(travel*0.7+phase) * 0.65;
	return vec3(offset.x, sin(travel + lobe_phase*0.4)*0.3, offset.y);
}

vec3 local_drift(mat4 model, vec3 drift) {
	// Instance bases are orthogonal, with nonuniform radii and a group yaw.
	return vec3(dot(drift,model[0].xyz)/dot(model[0].xyz,model[0].xyz),
		dot(drift,model[1].xyz)/dot(model[1].xyz,model[1].xyz),
		dot(drift,model[2].xyz)/dot(model[2].xyz,model[2].xyz));
}
