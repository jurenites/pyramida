extends RefCounted
const Reviewed = preload("res://scripts/settlement/reviewed_balance.gd")
static func tier(building: Dictionary) -> int:
	return clampi(int(building.get("house_tier", 3)), 1, 3)
static func cost(target: int) -> Dictionary:
	var result := {}
	for key: String in Reviewed.data.house_tiers.upgrade_costs[str(target)]: result[key] = int(Reviewed.data.house_tiers.upgrade_costs[str(target)][key])
	return result
static func error(world, cell: Vector3i, ignored := -1) -> String:
	if world.buildings.get(cell, {}).get("kind") != "house": return "House required"
	if tier(world.buildings[cell]) >= 3: return "Already fully upgraded"
	if world.Relocation.locked(world, cell) and not world.plans.get(ignored, {}).get("house_upgrade", false): return "Finish moving first"
	for plan: Dictionary in world.plans.values():
		if plan.cell == cell and plan.id != ignored and not world.Deconstruction.is_salvage(plan): return "Already planned"
	return ""
static func request(world, cell: Vector3i) -> bool:
	world.last_message = error(world, cell)
	if not world.last_message.is_empty(): return false
	var building: Dictionary = world.buildings[cell]; var target := tier(building) + 1
	var materials := cost(target); var required := 0
	for amount: int in materials.values(): required += amount
	var id: int = world.next_plan_id; world.next_plan_id += 1
	world.plans[id] = {"id": id, "kind": "house", "cell": cell, "direction": building.direction, "placement_offset": building.get("placement_offset", Vector3.ZERO), "house_upgrade": true, "house_tier": target, "installed": 0, "required": required, "reserved": 0, "materials": materials, "used": {}, "claims": {}, "reviewed": true}
	world.last_message = "Upgrade queued"; world.revision += 1
	return true
static func complete(world, plan: Dictionary) -> void:
	world.buildings[plan.cell].house_tier = int(plan.house_tier)
	var materials: Dictionary = world.construction_materials.get(plan.cell, {}).duplicate()
	for resource: String in plan.materials: materials[resource] = int(materials.get(resource, 0)) + int(plan.materials[resource])
	world.construction_materials[plan.cell] = materials
	world.plans.erase(plan.id)
	for worker: Dictionary in world.workers:
		if worker.get("assigned_plan_id", -1) == plan.id: worker.assigned_plan_id = -1
	world.rebuild_navigation(); world.last_message = "Upgrade complete"
static func frame(node: Node3D, level: int) -> void:
	if node.has_node("TierFrame"): node.get_node("TierFrame").visible = level >= 2; return
	if level < 2: return
	var root := Node3D.new(); root.name = "TierFrame"; root.set_meta("variation_exempt", true); node.add_child(root)
	var frame_ = preload("res://scripts/settlement/structure_frame.gd")
	for x in [-1, 1]:
		for z in [-1, 1]: frame_.log_member(root, "Brace", Vector3(x * 0.78, 1.12, z * 0.78), Vector3(x * 0.22, 1.73, z * 0.78))
	preload("res://scripts/settlement/illustration_style.gd").apply(root, false, true)
