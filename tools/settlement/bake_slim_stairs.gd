extends SceneTree
const Stair=preload("res://scripts/settlement/stair_timber.gd")
func _initialize() -> void:
	for kind in ["stairs","stairs_1m","reviewed_stair"]:
		var path="res://data/settlement/%s.tscn" % kind
		var asset=load(path).instantiate()
		if kind=="reviewed_stair":
			for part in asset.get_children():
				if part is MeshInstance3D: part.free()
			preload("res://scripts/settlement/structure_frame.gd").populate(asset,"stair")
		else: Stair.populate(asset,1 if kind=="stairs_1m" else 2)
		for part in asset.find_children("*","",true,false): part.owner=asset
		var scene=PackedScene.new(); assert(scene.pack(asset)==OK)
		assert(ResourceSaver.save(scene,path)==OK)
		var export_path=path.replace(".tscn",".glb")
		if FileAccess.file_exists(export_path):
			var document:=GLTFDocument.new(); var state:=GLTFState.new()
			assert(document.append_from_scene(asset,state)==OK)
			assert(document.write_to_filesystem(state,export_path)==OK)
		asset.free()
	print("PASS: slim stairs baked into editable main-game assets")
	quit()
