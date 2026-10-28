extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var scene: PackedScene = load("res://scenes/settlement/EditorWorld.tscn")
	var preview := scene.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE if Engine.is_editor_hint() else PackedScene.GEN_EDIT_STATE_DISABLED)
	assert(preview.get_node("TerrainAndLighting").find_children("RockChunk_*", "MeshInstance3D", true, false).size() == 36)
	assert(preview.find_children("*", "MeshInstance3D", true, false).size() > 100)
	assert(preview.find_children("*", "CollisionObject3D", true, false).is_empty())
	root.add_child(preview)
	await process_frame
	await process_frame
	if Engine.is_editor_hint():
		assert(is_instance_valid(preview) and preview.is_inside_tree())
		preview.free()
	else:
		assert(not is_instance_valid(preview))
	print("PASS: serialized editor geometry and runtime preview isolation")
	quit()
