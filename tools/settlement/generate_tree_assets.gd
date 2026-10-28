extends "res://tools/settlement/generate_assets.gd"
## Replace only the two tree assets; preserve edited buildings and cargo.

func _initialize() -> void:
	for kind in ["tree", "dead_tree"]:
		var asset := Node3D.new()
		asset.name = kind.to_pascal_case()
		tree(asset, kind == "dead_tree")
		own(asset, asset)
		var scene := PackedScene.new()
		assert(scene.pack(asset) == OK)
		assert(ResourceSaver.save(scene, OUT + kind + ".tscn") == OK)
		var document := GLTFDocument.new()
		var state := GLTFState.new()
		assert(document.append_from_scene(asset, state) == OK)
		assert(document.write_to_filesystem(state, OUT + kind + ".glb") == OK)
		asset.free()
	print("PASS: exported living/dead trees with three removable trunk sections")
	quit()
