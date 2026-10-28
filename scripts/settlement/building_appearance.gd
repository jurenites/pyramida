extends RefCounted
## Editable visual components; gameplay markers and building contracts stay in the source scene.
const Catalog = preload("res://data/settlement/catalog.gd")
const TimberPalette = preload("res://scripts/settlement/timber_palette.gd")
const LIMIT := 2048
const PRIMITIVES := ["log", "plank", "grain", "berry", "tree", "palm", "raw_stone", "block", "rock", "utility_ac", "utility_dish", "utility_pipe", "stick", "bed", "bench", "table", "urn", "food_crate", "water_bucket", "pottery", "roof_face", "ceramic_roof_tile", "metal_roof_sheet"]
const SOURCE_COMPONENTS := {"roof_face": ["house", "Roof/Cap"]}
const Contract = preload("res://scripts/settlement/asset_contract.gd")
static var directory := "user://building_appearances"
static var mesh_directory := "user://blueprint_meshes"
static var revision := 0
static var scenes: Dictionary = {}
static var components: Dictionary = {}
static var overrides: Dictionary = {}
static var building_kinds: Array = []

static func buildings() -> Array:
	if not building_kinds.is_empty(): return building_kinds
	var result: Array = []
	for kind: String in Catalog.COSTS:
		if not Catalog.DEFINITIONS.get(kind, {}).get("living", false) and ResourceLoader.exists("res://data/settlement/" + kind + ".tscn"):
			result.append(kind)
	building_kinds = result
	return building_kinds

static func original(kind: String) -> Node3D:
	if kind in SOURCE_COMPONENTS:
		# Reuse the building's exact mesh/material and authored scale, anchored
		# at its own floor centre for independent insertion in the workspace.
		var reference: Array = SOURCE_COMPONENTS[kind]
		var mesh := source(reference[0], reference[1])
		mesh.name = "RoofFace"
		mesh.basis = library(reference[0])[reference[1]].pose.basis
		var bounds: AABB = mesh.transform * mesh.mesh.get_aabb()
		mesh.position -= Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z)
		var root := Node3D.new()
		root.add_child(mesh)
		return root
	if not scenes.has(kind): scenes[kind] = load(import_path(kind) if imported(kind) else "res://data/settlement/" + kind + ".tscn")
	var node := (scenes[kind] as PackedScene).instantiate() as Node3D
	TimberPalette.prepare(node, kind)
	return node

static func library(kind: String) -> Dictionary:
	if not components.has(kind):
		var root := original(kind)
		var entries := {}
		_collect(root, root, Transform3D.IDENTITY, true, entries)
		components[kind] = entries
		root.free()
	return components[kind]

static func _collect(root: Node3D, node: Node3D, parent: Transform3D, visible: bool, entries: Dictionary) -> void:
	for child in node.get_children():
		if not child is Node3D: continue
		var pose: Transform3D = parent * child.transform
		var shown: bool = visible and child.visible
		if child is MeshInstance3D and child.mesh != null:
			var packed := PackedScene.new()
			var copy := child.duplicate() as MeshInstance3D
			for nested in copy.get_children(): nested.free()
			copy.transform = Transform3D.IDENTITY
			packed.pack(copy)
			copy.free()
			entries[str(root.get_path_to(child))] = {"scene": packed, "pose": pose, "visible": shown, "fixed_size": child.has_meta("timber_stock")}
		_collect(root, child, pose, shown, entries)

static func source(kind: String, path: String) -> MeshInstance3D:
	return (library(kind)[path].scene as PackedScene).instantiate() as MeshInstance3D

static func defaults(kind: String) -> Array:
	var result: Array = []
	for path: String in library(kind):
		var entry: Dictionary = library(kind)[path]
		if not entry.visible: continue
		var pose: Transform3D = entry.pose
		result.append({"kind": kind, "component": path, "at": pose.origin,
			"rotation": Vector3.ZERO, "basis": pose.basis})
	return result

static func pose(part: Dictionary) -> Transform3D:
	var basis: Basis = part.get("basis", Basis.IDENTITY)
	if fixed_size(part):
		# Source component bases encode authored geometry. Instance transforms
		# may rotate that geometry, but may not stretch it (including old saves).
		if part.has("component"):
			var authored: Basis = library(part.kind)[part.component].pose.basis
			# Unpacking a cut log bakes its length into the cylinder's local Y.
			var axial_scale := minf(absf(basis.get_scale().y), absf(authored.get_scale().y))
			basis = basis.orthonormalized().scaled_local(authored.get_scale())
			if part.kind == "log": basis.y = basis.y.normalized() * maxf(0.01, axial_scale)
		else: basis = basis.orthonormalized()
		if log_length_axis(part) >= 0: basis = basis.scaled_local(resize_scale(part))
		return Transform3D(Basis.from_euler(part.rotation) * basis, part.at)
	return Transform3D((Basis.from_euler(part.rotation) * basis).scaled_local(part.get("scale", Vector3.ONE)), part.at)

static func log_length_axis(part: Dictionary) -> int:
	if part.kind == "log" and not part.has("component"): return 0
	if part.kind == "assembly" and part.get("asset_ref", "") == "log" and not part.has("building_family"): return 0
	return -1

static func can_resize(part: Dictionary, axis := -1) -> bool:
	var length_axis := log_length_axis(part)
	if length_axis >= 0: return axis < 0 or axis == length_axis
	return not fixed_size(part)

static func resize_scale(part: Dictionary) -> Vector3:
	var axis := log_length_axis(part)
	if axis < 0: return Vector3.ONE if fixed_size(part) else part.get("scale", Vector3.ONE)
	var result := Vector3.ONE
	var basis: Basis = part.get("basis", Basis.IDENTITY)
	result[axis] = clampf(basis[axis].length() * part.get("scale", Vector3.ONE)[axis], 0.01, 1.0)
	return result

static func set_resize_scale(part: Dictionary, value: Vector3) -> void:
	var axis := log_length_axis(part)
	if axis >= 0:
		# Length may also have been baked into the basis by grouping/library edits.
		if part.has("basis"): part.basis = part.basis.orthonormalized()
		part.scale = Vector3.ONE
		part.scale[axis] = clampf(value[axis], 0.01, 1.0)
	elif not fixed_size(part): part.scale = value

static func fixed_size(part: Dictionary) -> bool:
	if part.kind in ["log", "plank"]: return true
	if part.kind == "assembly":
		if part.has("building_family"): return true
		if part.get("asset_ref", "") in buildings() + ["log", "plank"]: return true
		for child: Dictionary in part.get("children", []):
			if fixed_size(child): return true
	if not part.has("component"): return part.kind in buildings()
	return library(part.kind).get(part.component, {}).get("fixed_size", false)

static func has_timber(part: Dictionary) -> bool:
	if part.kind == "assembly":
		return part.children.any(func(child): return has_timber(child))
	if part.kind in ["log", "plank"]: return true
	if part.has("component"): return library(part.kind).get(part.component, {}).get("fixed_size", false)
	return library(part.kind).values().any(func(entry): return entry.get("fixed_size", false))

static func timber_species(part: Dictionary) -> String:
	if part.kind != "assembly": return part.get("timber_species", "tree")
	var species := ""
	for child: Dictionary in part.children:
		if not has_timber(child): continue
		var next := timber_species(child)
		if next.is_empty() or (not species.is_empty() and species != next): return ""
		species = next
	return species

static func set_timber_species(part: Dictionary, species: String) -> void:
	if species not in TimberPalette.SPECIES: return
	if part.kind == "assembly":
		part.timber_species = species
		for child: Dictionary in part.children: set_timber_species(child, species)
	elif has_timber(part): part.timber_species = species

static func encode(parts: Array, references := false) -> Array:
	var result: Array = []
	for part: Dictionary in parts:
		var entry := {"kind": part.kind}
		for field in ["at", "rotation", "scale"]:
			if not part.has(field): continue
			var vector: Vector3 = part[field]
			entry[field] = [vector.x, vector.y, vector.z]
		if references and part.get("linked", false):
			entry.linked = true
		elif part.has("children"):
			entry.children = encode(part.children, references)
			if references and part.has("linked"): entry.linked = part.linked
		for field in ["label", "asset_ref", "contract", "timber_species", "building_family", "hidden_components"]:
			if part.has(field): entry[field] = part[field]
		if part.has("component"): entry.component = part.component
		if part.has("basis"):
			entry.basis = []
			for axis in 3:
				for row in 3: entry.basis.append(part.basis[axis][row])
		result.append(entry)
	return result

static func decode(value: Variant, depth := 0, budget: Array = []) -> Dictionary:
	if budget.is_empty(): budget.append(0)
	if not value is Array or value.size() > LIMIT or depth > 8: return {}
	var parts: Array = []
	for entry: Variant in value:
		budget[0] += 1
		if budget[0] > LIMIT: return {}
		if not entry is Dictionary or not entry.get("kind") is String: return {}
		if entry.kind not in PRIMITIVES + buildings() + ["assembly"] and not (imported(entry.kind) and ResourceLoader.exists(import_path(entry.kind))): return {}
		var part := {"kind": entry.kind}
		if entry.has("timber_species"):
			if entry.timber_species not in TimberPalette.SPECIES: return {}
			part.timber_species = entry.timber_species
		if entry.kind == "assembly":
			var nested := decode(entry.get("children", [] if entry.get("linked", false) else null), depth + 1, budget)
			if nested.is_empty() or entry.has("component"): return {}
			part.children = nested.parts
		if entry.has("linked"):
			if not entry.linked is bool or entry.kind != "assembly" or not entry.get("asset_ref") is String or entry.asset_ref.is_empty(): return {}
			part.linked = entry.linked
		if entry.has("hidden_components"):
			if entry.kind != "assembly" or not entry.hidden_components is Array or entry.hidden_components.size() > LIMIT: return {}
			for path: Variant in entry.hidden_components:
				if not path is String or path.is_empty() or path.length() > 120: return {}
			part.hidden_components = entry.hidden_components.duplicate()
		if entry.has("building_family"):
			if entry.kind != "assembly" or not entry.building_family is String or entry.building_family.is_empty() or entry.building_family.length() > 120: return {}
			part.building_family = entry.building_family
		for field in ["label", "asset_ref"]:
			if not entry.has(field): continue
			if not entry[field] is String or entry[field].length() > 120: return {}
			part[field] = entry[field]
		if entry.has("contract"):
			if not Contract.valid(entry.contract): return {}
			part.contract = entry.contract.duplicate(true)
		if entry.has("component"):
			if not entry.component is String or not library(entry.kind).has(entry.component): return {}
			part.component = entry.component
		for field in ["at", "rotation", "scale"]:
			if field == "scale" and not entry.has(field): continue
			var vector: Variant = entry.get(field)
			if not vector is Array or vector.size() != 3: return {}
			for number: Variant in vector:
				if not (number is int or number is float) or not is_finite(float(number)) or absf(number) > 32: return {}
				if field == "scale" and absf(number) < 0.001: return {}
			part[field] = Vector3(vector[0], vector[1], vector[2])
		if entry.has("basis"):
			if not entry.basis is Array or entry.basis.size() != 9: return {}
			for number: Variant in entry.basis:
				if not (number is int or number is float) or not is_finite(float(number)) or absf(number) > 32: return {}
			var axes := Basis.IDENTITY
			for axis in 3: axes[axis] = Vector3(entry.basis[axis * 3], entry.basis[axis * 3 + 1], entry.basis[axis * 3 + 2])
			if absf(axes.determinant()) < 0.000001: return {}
			part.basis = axes
		parts.append(part)
	return {"parts": parts}

static func saved(kind: String) -> Dictionary:
	if not overrides.has(kind):
		overrides[kind] = {}
		var path := directory.path_join(kind + ".json")
		if FileAccess.file_exists(path):
			var file := FileAccess.open(path, FileAccess.READ)
			if file != null and file.get_length() <= 4 * 1024 * 1024:
				overrides[kind] = decode(JSON.parse_string(file.get_as_text()))
	return overrides[kind]

static func save(kind: String, parts: Array) -> bool:
	if kind not in buildings() or parts.is_empty(): return false
	var encoded := encode(parts)
	var checked := decode(encoded)
	if checked.is_empty(): return false
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory)) != OK: return false
	var path := directory.path_join(kind + ".json")
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify(encoded))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK or DirAccess.rename_absolute(ProjectSettings.globalize_path(path + ".tmp"), ProjectSettings.globalize_path(path)) != OK: return false
	overrides[kind] = checked
	revision += 1
	return true

static func apply(root: Node3D, kind: String) -> void:
	if kind not in buildings(): return
	var custom := saved(kind)
	if custom.is_empty(): return
	root.set_meta("custom_appearance", true)
	# Retain named mesh nodes for crop growth, joined walls, roofs and pile corners.
	# A removed component has no render layers, even when gameplay toggles visibility.
	for part: Dictionary in defaults(kind): root.get_node(part.component).layers = 0
	var used := {}
	for part: Dictionary in custom.parts:
		var path: String = part.get("component", "")
		if part.kind == kind and not path.is_empty() and not used.has(path):
			var mesh := root.get_node(path) as MeshInstance3D
			var parent_pose := Transform3D.IDENTITY
			var parent := mesh.get_parent() as Node3D
			while parent != root:
				parent_pose = parent.transform * parent_pose
				parent = parent.get_parent() as Node3D
			mesh.transform = parent_pose.affine_inverse() * pose(part)
			mesh.layers = 1
			TimberPalette.apply(mesh, part.get("timber_species", "tree"))
			used[path] = true
		else:
			var addition: Node3D
			if part.kind == "assembly":
				addition = assembly_node(part.children)
			elif not path.is_empty():
				addition = source(part.kind, path)
			else:
				addition = original(part.kind)
				if part.kind == "plank":
					for child in addition.get_children():
						if child.name != "Plank0": child.free()
			addition.transform = pose(part)
			if part.has("timber_species"): TimberPalette.apply(addition, part.timber_species)
			# Copies of source components retain their source parent, including the
			# windmill's rotor and tier visibility groups. Their authored pose is in
			# building space, so convert it back into that parent's local space.
			var attachment := root
			if part.kind == kind and not path.is_empty():
				attachment = root.get_node(path).get_parent() as Node3D
				var parent_pose := Transform3D.IDENTITY
				var ancestor := attachment
				while ancestor != root:
					parent_pose = ancestor.transform * parent_pose
					ancestor = ancestor.get_parent() as Node3D
				addition.transform = parent_pose.affine_inverse() * pose(part)
			attachment.add_child(addition, true)

static func assembly_node(parts: Array) -> Node3D:
	var root := Node3D.new()
	for part: Dictionary in parts:
		var node: Node3D
		if part.kind == "assembly": node = assembly_node(part.children)
		elif part.has("component"): node = source(part.kind, part.component)
		else:
			node = original(part.kind)
			if part.kind == "plank":
				for child in node.get_children():
					if child.name != "Plank0": child.free()
		node.transform = pose(part)
		if part.has("timber_species"): TimberPalette.apply(node, part.timber_species)
		root.add_child(node)
	return root

static func imported(kind: String) -> bool:
	return kind.begins_with("imported_") and kind.trim_prefix("imported_").is_valid_int() and not kind.contains("/")

static func import_path(kind: String) -> String:
	return mesh_directory.path_join(kind + ".tscn")
