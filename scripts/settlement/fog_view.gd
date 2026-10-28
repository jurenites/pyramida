extends MeshInstance3D
## Depth-aware replacement for the original flat fog plane; HUD is outside this viewport.
const Exploration = preload("res://scripts/settlement/exploration.gd")
const Palette = preload("res://scripts/game_palette.gd")
var material := ShaderMaterial.new()
var image: Image
var texture: ImageTexture
var model_id := 0
var revision := -1
var bounds := Rect2i()

func _ready() -> void:
	name = "ExplorationFog"
	var quad := QuadMesh.new()
	quad.size = Vector2(2, 2)
	mesh = quad
	extra_cull_margin = 16384
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	material.shader = preload("res://shaders/settlement_fog.gdshader")
	material.render_priority = 127
	material.set_shader_parameter("fog_color", Palette.FOG_AND_SHADOW)
	material_override = material

func visible_bounds() -> Rect2i:
	var camera := get_parent() as Camera3D
	var size := Vector2(camera.get_viewport().size)
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	# Reconstruct a mask window for every visible height, not just the ground plane.
	for screen in [Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)]:
		var origin := camera.project_ray_origin(screen)
		var direction := camera.project_ray_normal(screen)
		for height in [-12.0, 0.0, Exploration.Catalog.MAX_LEVEL * Exploration.Navigation.LEVEL_HEIGHT]:
			var point: Vector3 = origin + direction * ((height - origin.y) / direction.y)
			low = low.min(Vector2(point.x, point.z))
			high = high.max(Vector2(point.x, point.z))
	# Snap to 16 m windows to avoid reallocating the mask for every camera pixel.
	var start := Vector2i(floori(low.x / 16) * 32 - 32, floori(low.y / 16) * 32 - 32)
	var end := Vector2i(ceili(high.x / 16) * 32 + 32, ceili(high.y / 16) * 32 + 32)
	return Rect2i(start, end - start)

func sync(model, enabled: bool, _focus := Vector3.ZERO) -> void:
	visible = enabled
	if not enabled:
		return
	var next_bounds := visible_bounds()
	if model_id == model.get_instance_id() and revision == model.exploration.revision and bounds == next_bounds:
		return
	model_id = model.get_instance_id()
	revision = model.exploration.revision
	if image == null or bounds.size != next_bounds.size:
		image = Image.create(next_bounds.size.x, next_bounds.size.y, false, Image.FORMAT_R8)
		texture = null
	bounds = next_bounds
	image.fill(Color.BLACK)
	for cell: Vector2i in model.exploration.cells:
		if bounds.has_point(cell):
			var pixel := cell - bounds.position
			image.set_pixel(pixel.x, pixel.y, Color.WHITE)
	if texture == null:
		texture = ImageTexture.create_from_image(image)
		material.set_shader_parameter("fog_mask", texture)
	else:
		texture.update(image)
	material.set_shader_parameter("mask_origin", Vector2(bounds.position) * Exploration.Mask.CELL_SIZE)
	material.set_shader_parameter("mask_size", Vector2(bounds.size) * Exploration.Mask.CELL_SIZE)
