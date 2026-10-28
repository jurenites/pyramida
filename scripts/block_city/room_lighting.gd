extends RefCounted
## Emissive glazing and inexpensive ceiling-light pools, without per-room shadow lights.
const WARM := Color("ffd18a")
const UNLIT_GLASS := Color("78898b")
static var pool_material: ShaderMaterial

static func glow(mesh: MeshInstance3D, strength := 1.0) -> void:
	var material: StandardMaterial3D=mesh.material_override
	material.albedo_color=WARM
	material.emission_enabled=true
	material.emission=WARM
	material.emission_energy_multiplier=strength

static func interior(game, parent: Node3D, cell: Vector3i, role: String, open_floor: bool) -> void:
	var lights:=Node3D.new(); lights.name="CeilingLight"; parent.add_child(lights)
	lights.set_meta("cell",cell)
	var offset:=Vector3(0.5,0.87,0.5) if role not in ["stairs","elevator"] else Vector3(0.12,0.84,0.5)
	var housing: MeshInstance3D=game.box(lights,Vector3(cell)+offset,Vector3(0.24,0.045,0.18),Color("d5d5cd"))
	housing.name="Fixture"
	housing.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var bulb: MeshInstance3D=game.box(lights,Vector3(cell)+offset,Vector3(0.20,0.05,0.14),WARM)
	bulb.name="WarmEmitter"; glow(bulb,1.0)
	bulb.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if open_floor or role in ["stairs","elevator"]: return
	if pool_material==null:
		var shader:=Shader.new()
		shader.code="""shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never;
void fragment() {
	float radius = length((UV - vec2(0.5)) * 2.0);
	float falloff = 1.0 - smoothstep(0.12, 1.0, radius);
	ALBEDO = vec3(1.0, 0.73, 0.36);
	EMISSION = vec3(1.0, 0.64, 0.25) * 0.18 * falloff;
	ALPHA = falloff * 0.55;
}"""
		pool_material=ShaderMaterial.new(); pool_material.shader=shader
	var pool:=MeshInstance3D.new(); pool.name="WarmLightPool"
	var plane:=PlaneMesh.new(); plane.size=Vector2(0.9,0.9); pool.mesh=plane
	pool.material_override=pool_material
	pool.position=Vector3(cell)+Vector3(0.5,0.084 if role=="hall" else 0.074,0.5)
	pool.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lights.add_child(pool)
