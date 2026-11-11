extends RefCounted
## Asset presentation is replaceable; dimensions and rules belong to the model.
const Illustration = preload("res://scripts/settlement/illustration_style.gd")
const Appearance = preload("res://scripts/settlement/building_appearance.gd")
const Variation = preload("res://scripts/settlement/building_variation.gd")
const ROOT := "res://data/settlement/"
const FLOOR_SURFACE_CLEARANCE := 0.008 # Metres above the logical support plane.
static var cache: Dictionary = {}

static func create(kind: String) -> Node3D:
	if kind == "rope": return preload("res://scripts/settlement/rope_visuals.gd").coil()
	if kind == "rope_maker": return preload("res://scripts/settlement/rope_visuals.gd").maker()
	if kind == "waterworks":
		var utility := (load(ROOT + "waterworks_base.tscn") as PackedScene).instantiate() as Node3D
		Appearance.TimberPalette.prepare(utility, kind)
		separate_floor_surface(utility)
		preload("res://scripts/settlement/well_view.gd").wrap(utility)
		Illustration.apply(utility, false, true)
		return utility
	if kind == "vine_tree": return Node3D.new()
	if kind in preload("res://data/settlement/catalog.gd").SEEDS:
		var seed := preload("res://scripts/settlement/plant_view.gd").seed()
		Illustration.apply(seed)
		return seed
	if kind == "grass_patch": return preload("res://scripts/settlement/plant_view.gd").grass()
	if not cache.has(kind):
		var reviewed_path := ROOT + "reviewed_" + kind + ".tscn"
		cache[kind] = load(reviewed_path if ResourceLoader.exists(reviewed_path) else ROOT + kind + ".tscn")
	var instance := (cache[kind] as PackedScene).instantiate() as Node3D
	if kind in ["tree", "dead_tree", "palm"]:
		preload("res://scripts/settlement/timber_kit.gd").bind_tree_stock(instance)
	if kind == "hay_field":
		if instance.has_meta("hay_peg_identity"): instance.remove_meta("hay_peg_identity")
		preload("res://scripts/settlement/hay_field_view.gd").arrange_pegs(instance, Vector3i.ZERO, 0)
	Appearance.TimberPalette.prepare(instance, kind)
	preload("res://scripts/settlement/resource_palette.gd").prepare(instance, kind)
	if not instance.has_meta("reviewed_model") or Appearance.compatible_parts(instance, kind): Appearance.apply(instance, kind)
	if kind == "stone_storage": preload("res://scripts/settlement/stone_storage_view.gd").sync(instance, 1)
	if kind == "road": preload("res://scripts/settlement/stone_road.gd").sync(instance, Vector3i.ZERO, 0)
	separate_floor_surface(instance)
	if kind == "sawmill" and not instance.has_meta("reviewed_model"): preload("res://scripts/settlement/sawmill_view.gd").sync(instance, 1)
	Illustration.apply(instance, kind == "berry", kind in Appearance.buildings())
	if kind == "hay_field":
		for visual: GeometryInstance3D in instance.find_children("*", "GeometryInstance3D", true, false):
			visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return instance

static func separate_floor_surface(instance: Node3D) -> void:
	# Authored slabs end at y=0, coplanar with terrain and supporting decks.
	# Give only the finish a physical clearance; anchors and floor addresses stay
	# on the metre grid. Custom finishes already above that plane stay untouched.
	var floor_mesh := instance.get_node_or_null("Floor") as MeshInstance3D
	if floor_mesh == null or floor_mesh.mesh == null: return
	var bounds := floor_mesh.transform * floor_mesh.mesh.get_aabb()
	if absf(bounds.end.y) < 0.0001:
		floor_mesh.position.y += FLOOR_SURFACE_CLEARANCE

static func tint(node: Node, colour: Color, transparent := false) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = 1.0
	if transparent:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var visual := child as MeshInstance3D
		if transparent:
			visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		visual.material_override = material
