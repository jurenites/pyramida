shader_type spatial;
render_mode cull_disabled, ambient_light_disabled, specular_disabled;
#include "res://shaders/coastal_sand.gdshaderinc"

global uniform float settlement_daylight;
uniform vec4 fill_colour : source_color = vec4(1.0);
uniform bool soil_edge_enabled = false;
uniform sampler2D soil_edge_field : filter_linear, repeat_disable;
uniform vec4 soil_edge_bounds;
uniform vec3 soil_levels = vec3(0.0, 2.0, 4.0);
uniform bool grass_surface = false;
uniform bool folded_layers = false;
uniform bool dry_island = false;
uniform bool rocky_heights = false;
uniform bool shore_sand = false;
uniform bool submerged_terrain = false;
varying vec3 world_position;
uniform vec4 lowland_green : source_color = vec4(0.494, 0.620, 0.322, 1.0);
uniform vec4 upland_green : source_color = vec4(0.769, 0.827, 0.549, 1.0);
uniform vec4 dry_sand : source_color = vec4(0.898, 0.839, 0.667, 1.0);
uniform vec4 dry_rock : source_color = vec4(0.706, 0.635, 0.541, 1.0);
uniform vec4 cliff_soil : source_color = vec4(0.349, 0.431, 0.400, 1.0);
uniform vec4 high_rock : source_color = vec4(0.537, 0.573, 0.541, 1.0);
varying float world_height;
uniform vec3 shadow_ratio = vec3(0.62, 0.57, 0.53);
varying float front_surface;
varying vec3 world_normal;
void vertex() { world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL); world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; world_height = world_position.y; }

void fragment() {
	float facet = 0.76 + 0.26 * (dot(normalize(world_normal), normalize(vec3(-0.6, 1.0, 0.4))) * 0.5 + 0.5);
	vec3 surface_colour = fill_colour.rgb;
	if (grass_surface) {
		// World-space height gives each flat shelf one consistent shade, including
		// disconnected caps and rebuilt CSG cuts. Low ground stays the richest green.
		float elevation = clamp(world_height / 6.0, 0.0, 1.0);
		surface_colour = dry_island ? dry_sand.rgb : mix(lowland_green.rgb, upland_green.rgb, elevation);
		// Third two-metre terrace and everything above it is exposed rock.
		if (rocky_heights) {
			float rock = step(5.99, world_height);
			if (folded_layers) {
				float weathering = sin(world_position.x * 0.37) * sin(world_position.z * 0.29) * 0.25;
				rock = smoothstep(4.35 + weathering, 5.99, world_height);
				if (soil_edge_enabled) {
					vec3 cover = texture(soil_edge_field, (world_position.xz - soil_edge_bounds.xy) / soil_edge_bounds.zw).rgb;
					float soil = world_height < (soil_levels.x + soil_levels.y) * 0.5 ? cover.r : (world_height < (soil_levels.y + soil_levels.z) * 0.5 ? cover.g : cover.b);
					surface_colour = mix(surface_colour, dry_island ? dry_rock.rgb * 0.78 : cliff_soil.rgb, 1.0 - soil);
				}
			}
			surface_colour = mix(surface_colour, dry_island ? dry_rock.rgb : high_rock.rgb, rock);
		}
	}
	ALBEDO = surface_colour * facet;
	float submerged_sand = (shore_sand || submerged_terrain) ? smoothstep(0.0, 0.6, -0.65 - world_height) : 0.0;
	ALBEDO = mix(ALBEDO, coastal_floor(world_position, -0.65, TIME, shore_sand), submerged_sand);
	// Interior back faces remain in the ambient shade.
	front_surface = (FRONT_FACING ? 1.0 : 0.0) * (1.0 - submerged_sand);
	EMISSION = ALBEDO * mix(vec3(1.0), shadow_ratio, settlement_daylight);
	EMISSION = mix(EMISSION, ALBEDO, submerged_sand);
	ROUGHNESS = 1.0;
}

void light() {
	// Preserve the painted palette in sunlight; receive actual occluder shadows.
	// Backlit/grazing surfaces must not sample their own shadow as sunlight.
	// A short soft transition retains the painted style without speckled interiors.
	float sunlight = smoothstep(0.0, 0.2, dot(NORMAL, LIGHT));
	if (LIGHT_IS_DIRECTIONAL) { DIFFUSE_LIGHT += ATTENUATION * (vec3(1.0) - shadow_ratio) * settlement_daylight * front_surface * sunlight; }
}
