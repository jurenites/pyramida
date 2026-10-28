extends SceneTree
## Update the editable scenes and Blender exports from the shared timber stock.
const Timber = preload("res://scripts/settlement/timber_kit.gd")
const Catalog = preload("res://data/settlement/catalog.gd")
const OUT := "res://data/settlement/"

func _initialize() -> void:
	for kind in Catalog.COSTS:
		if kind in Catalog.SEEDS or not ResourceLoader.exists(OUT + kind + ".tscn"): continue
		var asset := (load(OUT + kind + ".tscn") as PackedScene).instantiate() as Node3D
		save_asset(asset, kind)
	# Height/utility variants are independently authored source models.
	for kind in ["stairs_1m", "platform_2m", "waterworks_base"]:
		save_asset((load(OUT + kind + ".tscn") as PackedScene).instantiate(), kind)
	print("PASS: construction timber rebuilt from original log and single-plank meshes")
	quit()

func save_asset(asset: Node3D, kind: String) -> void:
	Timber.rebuild(asset)
	if kind.begins_with("stairs"): Timber.fit_ladder(asset, 1.0 if kind == "stairs_1m" else 2.0)
	var scene := PackedScene.new()
	assert(scene.pack(asset) == OK)
	assert(ResourceSaver.save(scene, OUT + kind + ".tscn") == OK)
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	assert(document.append_from_scene(asset, state) == OK)
	assert(document.write_to_filesystem(state, OUT + kind + ".glb") == OK)
	asset.free()
