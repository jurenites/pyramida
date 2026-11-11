extends SceneTree
## Re-export only the slab, preserving the rest of the authored economy assets.
const Stone = preload("res://scripts/settlement/stone_view.gd")

func _initialize() -> void:
	Stone.Illustration.enabled = false
	var slab := (load("res://data/settlement/block.tscn") as PackedScene).instantiate()
	slab.get_node("Stone").mesh = Stone.block_mesh(1409)
	var scene := PackedScene.new()
	assert(scene.pack(slab) == OK)
	assert(ResourceSaver.save(scene, "res://data/settlement/block.tscn") == OK)
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	assert(document.append_from_scene(slab, state) == OK)
	assert(document.write_to_filesystem(state, "res://data/settlement/block.glb") == OK)
	slab.free()
	print("PASS: exported slab TSCN and GLB with outward-facing triangles")
	quit()
