extends "res://tools/settlement/generate_assets.gd"
## Additive cargo kit: regenerate these two assets without touching authored buildings.

func _initialize() -> void:
	for kind in ["food_crate", "water_bucket"]:
		var asset := Node3D.new()
		asset.name = kind.to_pascal_case()
		if kind == "food_crate":
			food_crate(asset)
		else:
			water_bucket(asset)
		own(asset, asset)
		var scene := PackedScene.new()
		assert(scene.pack(asset) == OK)
		assert(ResourceSaver.save(scene, OUT + kind + ".tscn") == OK)
		var document := GLTFDocument.new()
		var state := GLTFState.new()
		assert(document.append_from_scene(asset, state) == OK)
		assert(document.write_to_filesystem(state, OUT + kind + ".glb") == OK)
		asset.free()
	print("PASS: exported food crate and water bucket as editable TSCN + GLB")
	quit()

func food_crate(parent: Node3D) -> void:
	box(parent, "CrateBase", Vector3(0, 0.025, 0), Vector3(0.52, 0.05, 0.38), WOOD)
	for x in [-0.24, 0.24]:
		for z in [-0.17, 0.17]:
			box(parent, "CornerPost", Vector3(x, 0.14, z), Vector3(0.04, 0.28, 0.04), WOOD)
	for y in [0.08, 0.19]:
		for z in [-0.17, 0.17]:
			box(parent, "LongSlat", Vector3(0, y, z), Vector3(0.5, 0.07, 0.035), PLANK)
		for x in [-0.24, 0.24]:
			box(parent, "EndSlat", Vector3(x, y, 0), Vector3(0.035, 0.07, 0.36), END_GRAIN)
	for index in 6:
		var centre := Vector3((index % 3 - 1) * 0.14, 0.20, (index / 3 - 0.5) * 0.15)
		foliage(parent, "Harvest", centre, Vector3(0.15, 0.14, 0.14), CLAY.lightened((index % 2) * 0.12))
		box(parent, "Leaf", centre + Vector3.UP * 0.07, Vector3(0.06, 0.015, 0.025), LEAF)

func water_bucket(parent: Node3D) -> void:
	cylinder(parent, "BucketBody", Vector3(0, 0.14, 0), 0.15, 0.28, WOOD, 0.20, 10)
	for y in [0.045, 0.23]:
		cylinder(parent, "Binding", Vector3(0, y, 0), 0.155 + y * 0.18, 0.025, DARK, -1, 10)
	cylinder(parent, "WaterSurface", Vector3(0, 0.282, 0), 0.176, 0.008, Color("609ca4"), -1, 10)
	for x in [-0.19, 0.19]:
		beam(parent, "HandleUpright", Vector3(x, 0.21, 0), Vector3(x, 0.43, 0), 0.025, END_GRAIN)
	beam(parent, "CarryHandle", Vector3(-0.19, 0.43, 0), Vector3(0.19, 0.43, 0), 0.035, END_GRAIN)
