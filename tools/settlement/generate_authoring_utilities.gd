extends SceneTree
const View = preload("res://scripts/settlement/structure_workshop_view.gd")
func own(node: Node, root: Node) -> void:
	for child in node.get_children():
		child.owner = root
		own(child, root)
func _initialize() -> void:
	for kind in ["ac", "dish", "pipe"]:
		var asset := Node3D.new()
		asset.name = "Utility" + kind.capitalize()
		if kind == "pipe":
			var mesh := CylinderMesh.new()
			mesh.top_radius = 0.045
			mesh.bottom_radius = 0.045
			mesh.height = 1.0
			var node := MeshInstance3D.new()
			node.name = "Pipe"
			node.mesh = mesh
			node.position.y = 0.05
			node.rotation.z = PI / 2
			node.material_override = View.material(Color("9d7952"))
			asset.add_child(node)
		else:
			View.details(asset, {"cells": {Vector3i.ZERO: "stone"}, "door": {}, "doors": [], "utilities": [{"kind": kind, "cell": Vector3i.ZERO, "side": Vector3i(0,0,1), "mount": "wall", "offset": Vector2.ZERO}]}, true)
			# Place the original wall model's mounting plane at local Z=0.
			for child in asset.get_children(): child.position += Vector3(0, 0.32, -0.48)
		for point in ([Vector3(-0.5,0.05,0), Vector3(0.5,0.05,0)] if kind == "pipe" else [Vector3(0,0.32,0)]):
			var port := Marker3D.new()
			port.name = "Port" + str(asset.get_child_count())
			port.position = point
			asset.add_child(port)
		own(asset, asset)
		var scene := PackedScene.new()
		assert(scene.pack(asset) == OK)
		assert(ResourceSaver.save(scene, "res://data/settlement/utility_" + kind + ".tscn") == OK)
		var document := GLTFDocument.new()
		var state := GLTFState.new()
		assert(document.append_from_scene(asset, state) == OK)
		assert(document.write_to_filesystem(state, "res://data/settlement/utility_" + kind + ".glb") == OK)
		asset.free()
	print("PASS: utility assets and Blender GLBs exported")
	quit()
