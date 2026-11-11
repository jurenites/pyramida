extends RefCounted
## Cargo and UI share material colours. Timber retains its existing species palette.
const Palette = preload("res://scripts/game_palette.gd")
const Timber = preload("res://scripts/settlement/timber_palette.gd")
const COLOURS := {
	"log": Timber.BARK[0], "plank": Timber.WOOD[0],
	"grain": Palette.HAY_FIELD, "water": Palette.WATER_BLUE,
	"stone": Palette.LIMESTONE_SIDE, "block": Palette.MARBLE,
	"clay": Color("b08063"), "brick": Color("b97356"),
	"ore": Color("716b68"), "flour": Color("f0dfb8"),
	"pottery": Color("b05c3b"), "imbrex": Color("ba674d"),
	"rope": Color("d8ba7c"), "food": Color("ebb05c"),
	"berry": Color("bb5845"),
}

static func colour(kind: String) -> Color:
	return COLOURS.get(kind, Palette.CITIZEN_SKIN)

static func prepare(root: Node3D, kind: String) -> void:
	if kind == "grain":
		var hay := StandardMaterial3D.new()
		hay.albedo_color = colour(kind)
		hay.roughness = 1.0
		for mesh: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
			if str(mesh.name).begins_with("Straw"): mesh.material_override = hay
	# Distinguish the previously identical mineral meshes by profile as well as colour.
	if kind not in ["clay", "ore"]: return
	var stone := root.get_node_or_null("Stone") as MeshInstance3D
	if stone == null: return
	var material := StandardMaterial3D.new()
	material.albedo_color = colour(kind)
	material.roughness = 1.0
	stone.material_override = material
	stone.scale = Vector3(1.0, 0.48, 0.85) if kind == "clay" else Vector3(0.72, 1.2, 0.72)
	if kind == "ore":
		var seam := MeshInstance3D.new()
		seam.name = "MineralFace"
		var mesh := PrismMesh.new()
		mesh.size = Vector3(0.10, 0.18, 0.12)
		seam.mesh = mesh
		seam.position = Vector3(0.12, 0.10, 0.12)
		var mineral := StandardMaterial3D.new()
		mineral.albedo_color = Palette.TOOL_METAL
		seam.material_override = mineral
		root.add_child(seam)
