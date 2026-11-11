extends RefCounted
## Visual wood choices share the exact same stock geometry and construction recipe.
const SPECIES := ["tree", "palm", "dead_tree"]
const LABELS := ["Tree", "Palm", "Dead tree"]
const Palette=preload("res://scripts/game_palette.gd")
const BARK := [Color("986a4b"), Palette.TIMBER_SIDE, Palette.HOME_DOORWAY]
const WOOD := [Color("d1a775"), Palette.PEACH_SHADOW, Palette.SAND_SURFACE]
static var materials: Dictionary = {}

static func material(species: String, stock: String, surface: int) -> StandardMaterial3D:
	var key := "%s:%s:%d" % [species, stock, surface]
	if not materials.has(key):
		var index := SPECIES.find(species)
		var result := StandardMaterial3D.new()
		result.roughness = 0.92
		result.albedo_color = BARK[index] if stock == "log" and surface == 0 else WOOD[index]
		if stock == "plank": result.albedo_color = result.albedo_color.lightened((surface % 3) * 0.035)
		materials[key] = result
	return materials[key]

static func prepare(root: Node3D, kind: String) -> void:
	# Mark the unbatched cargo meshes too, including the separate cut-end discs.
	if kind in ["log", "plank"]:
		for mesh in root.get_children():
			if not mesh is MeshInstance3D: continue
			mesh.set_meta("timber_stock", kind)
			if kind == "log": mesh.set_meta("timber_cut", mesh.name != "Bark")
	apply(root, "tree")

static func apply(root: Node3D, species: String) -> void:
	if species not in SPECIES: return
	var meshes: Array = root.find_children("*", "MeshInstance3D", true, false)
	if root is MeshInstance3D: meshes.append(root)
	for mesh: MeshInstance3D in meshes:
		var stock: String = mesh.get_meta("timber_stock", "")
		if stock not in ["log", "plank"] or mesh.mesh == null: continue
		mesh.material_override = null
		for surface in mesh.mesh.get_surface_count():
			mesh.set_surface_override_material(surface, material(species, stock, 1 if mesh.get_meta("timber_cut", false) else surface))
		if mesh.has_meta("timber_paint"):
			var colour: Color = mesh.get_meta("timber_paint")
			var paint_key := "paint:" + colour.to_html()
			if not materials.has(paint_key):
				var paint := StandardMaterial3D.new(); paint.albedo_color = colour; paint.roughness = 0.92
				materials[paint_key] = paint
			mesh.material_override = materials[paint_key]
		mesh.set_meta("timber_species", species)
