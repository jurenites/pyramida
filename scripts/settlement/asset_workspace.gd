extends RefCounted
const Kit = preload("res://scripts/settlement/structure_parts.gd")
const Contract = preload("res://scripts/settlement/asset_contract.gd")
const CATEGORIES := ["component", "prefab", "primitive", "building"]

static func category_for(id: String, stored := "component") -> String:
	# Older workspaces stored buildings as generic components.
	if id in Kit.Appearance.buildings(): return "building"
	if id in Kit.Appearance.PRIMITIVES: return "primitive"
	return stored

static func library_group(category: String) -> String:
	return category if category in ["building", "prefab"] else "asset"

static func defaults(kind: String) -> Dictionary:
	if kind == "platform": return Contract.make(Vector3(2, 1, 2), Vector3(0, -1, 0))
	if kind in ["utility_ac", "utility_dish"]: return Contract.make(Vector3(0.5, 0.75, 0.5), Vector3(0, 0, 0.25), "wall")
	if kind == "utility_pipe": return Contract.make(Vector3(1, 0.1, 0.1), Vector3.ZERO, "free")
	var definition: Dictionary = Kit.Catalog.DEFINITIONS.get(kind, {})
	if not definition.is_empty():
		var size: Vector3 = definition.size
		# Catalog bounds include facade clearance (for example 1.96 m).
		# A new building's authored footprint occupies whole metre cells.
		if kind in Kit.Appearance.buildings():
			size.x = ceilf(size.x / Contract.Grid.CELL_SIZE) * Contract.Grid.CELL_SIZE
			size.z = ceilf(size.z / Contract.Grid.CELL_SIZE) * Contract.Grid.CELL_SIZE
		return Contract.make(size, definition.offset - Vector3(0, size.y / 2, 0))
	if kind.is_empty(): return Contract.make()
	var bounds := Kit.bounds({"kind": kind, "at": Vector3.ZERO, "rotation": Vector3.ZERO})
	return Contract.make(bounds.size.max(Vector3.ONE * 0.01), bounds.position + Vector3(bounds.size.x / 2, 0, bounds.size.z / 2))

static func valid(value: Variant) -> bool:
	if not value is Dictionary: return false
	if value.is_empty(): return true # Older workspaces.
	if not Contract.valid(value.get("contract")): return false
	if not value.get("active_asset") is String or value.active_asset.length() > 120: return false
	if value.get("category") not in CATEGORIES: return false
	if not value.get("assets") is Dictionary or value.assets.size() > 128: return false
	for id in value.assets:
		var entry: Variant = value.assets[id]
		if not id is String or id.length() > 120 or not entry is Dictionary: return false
		if not entry.get("name") is String or entry.name.length() > 80: return false
		if entry.get("category") not in CATEGORIES: return false
		if entry.has("base_asset"):
			if entry.category != "building" or not entry.base_asset is String: return false
			if entry.base_asset not in Kit.Appearance.buildings() and not (value.assets.has(entry.base_asset) and value.assets[entry.base_asset] is Dictionary and value.assets[entry.base_asset].get("category") == "building" and not value.assets[entry.base_asset].has("base_asset")): return false
		if not Contract.valid(entry.get("contract")) or Kit.decode(entry.get("parts")).is_empty(): return false
	var scopes: Variant = value.get("scopes", [])
	if not scopes is Array or scopes.size() > 8: return false
	for scope in scopes:
		if not scope is Dictionary or not Contract.valid(scope.get("contract")): return false
		if Kit.decode(scope.get("parts")).is_empty(): return false
		var index: Variant = scope.get("index")
		if not (index is int or index is float) or index != floorf(index) or index < 0 or index >= scope.parts.size(): return false
		if scope.parts[int(index)].kind != "assembly": return false
		for field in ["name", "active_asset", "building_kind"]:
			if not scope.get(field) is String or scope[field].length() > 120: return false
		if scope.building_kind not in [""] + Kit.Appearance.buildings(): return false
		if scope.get("category") not in CATEGORIES: return false
	return true

static func instance(kind: String, at: Vector3, rotation := Vector3.ZERO) -> Dictionary:
	var saved := Kit.Appearance.saved(kind) if kind in Kit.Appearance.buildings() else {}
	var children: Array = saved.parts.duplicate(true) if not saved.is_empty() else Kit.Appearance.defaults(kind)
	if kind == "plank": children = children.filter(func(p): return p.component == "Plank0")
	return {"kind": "assembly", "label": Kit.title(kind).capitalize(), "asset_ref": kind, "linked": true,
		"at": at, "rotation": rotation, "children": children, "contract": defaults(kind)}

static func example() -> Array:
	# Each level has its own room, explicit ladder and floor-mounted machine.
	var parts: Array = []
	for level in 3:
		var room := instance("house", Vector3(0, level * 2, 0))
		# Open intermediate roofs so the next module sits on its real floor.
		if level < 2:
			room.hidden_components = ["Roof"]
			room.children = visible_components(room.children, room.hidden_components)
		parts.append(room)
		if level < 2:
			parts.append(instance("stairs", Vector3(0, level * 2, 2), Vector3(0, PI / 2, 0)))
			parts.append(instance("platform", Vector3(0, (level + 1) * 2, 2)))
		parts.append(instance("utility_ac", Vector3(1, level * 2 + 0.7, 0), Vector3(0, PI / 2, 0)))
		var branch := instance("utility_pipe", Vector3(1.02, level * 2 + 0.79, 0.48), Vector3(0, PI / 2, 0))
		branch.scale = Vector3(1.2, 1, 1)
		parts.append(branch)
		parts.append(instance("utility_pipe", Vector3(1.07, level * 2 + 1, 1.08), Vector3(0, 0, PI / 2)))
		parts.append(instance("utility_pipe", Vector3(1.07, level * 2 + 2, 1.08), Vector3(0, 0, PI / 2)))
	parts.append(instance("sawmill", Vector3(-2.5, 0, 0)))
	parts.append(instance("log_shed", Vector3(-2.5, 0, -2)))
	return parts

# Children on linked instances are a disposable rendering/editing cache. Only the
# reference and instance transform are written to the workspace document.
static func encode_parts(parts: Array) -> Array:
	return Kit.Appearance.encode(parts, true)

static func resolve(parts: Array, assets: Dictionary, trail: Array = [], budget: Array = [], depth := 0) -> bool:
	if budget.is_empty(): budget.append(0)
	if depth > 8: return false
	for part: Dictionary in parts:
		budget[0] += 1
		if budget[0] > Kit.LIMIT: return false
		if part.kind != "assembly": continue
		var next := trail
		if part.get("linked", false):
			var id: String = part.asset_ref
			if id in trail: return false
			next = trail + [id]
			if assets.has(id):
				part.children = assets[id].parts.duplicate(true)
				part.contract = assets[id].contract.duplicate(true)
			elif id in Kit.kinds():
				var saved := Kit.Appearance.saved(id) if id in Kit.Appearance.buildings() else {}
				part.children = saved.parts.duplicate(true) if not saved.is_empty() else Kit.Appearance.defaults(id)
				if id == "plank": part.children = part.children.filter(func(p): return p.component == "Plank0")
				part.contract = defaults(id)
			else: return false
		if not resolve(part.children, assets, next, budget, depth + 1): return false
		if part.has("hidden_components"): part.children = visible_components(part.children, part.hidden_components)
		if part.has("timber_species"): Kit.Appearance.set_timber_species(part, part.timber_species)
	return true

static func migrate_links(parts: Array, asset_ids: Array = []) -> void:
	for part: Dictionary in parts:
		if part.kind != "assembly": continue
		if part.has("asset_ref") and not part.has("linked"):
			# Old snapshots can outlive a deleted custom source. Keep those local.
			part.linked = part.asset_ref in asset_ids or part.asset_ref in Kit.kinds()
		migrate_links(part.children, asset_ids)

static func valid_links(value: Dictionary, parts: Array) -> bool:
	var assets := {}
	for id: String in value.get("assets", {}):
		assets[id] = value.assets[id].duplicate(true)
		assets[id].parts = Kit.decode(assets[id].parts).parts
	for id: String in assets:
		if not resolve(assets[id].parts.duplicate(true), assets, [id]): return false
	for scope: Dictionary in value.get("scopes", []):
		if not resolve(Kit.decode(scope.parts).parts, assets): return false
	return resolve(parts.duplicate(true), assets)

static func visible_components(parts: Array, hidden: Array) -> Array:
	var result: Array = []
	for part: Dictionary in parts:
		var path: String = part.get("component", part.get("label", ""))
		if hidden.any(func(prefix): return path == prefix or path.begins_with(prefix + "/")): continue
		if part.kind == "assembly": part.children = visible_components(part.children, hidden)
		result.append(part)
	return result
