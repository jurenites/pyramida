extends RefCounted
## A producer may supply a site without becoming its builder or installing materials.
static func staged(plan: Dictionary, resource: String) -> int:
	return plan.delivered.count(resource) if plan.has("delivered") else 0

static func assign(world, worker: Dictionary) -> bool:
	if worker.cargo.is_empty() or worker.has("relocation_cargo") or not world.Citizens.is_adult(worker): return false
	var amount: int = worker.get("cargo_amount", 1)
	for plan: Dictionary in world.plans.values():
		if plan.has("relocation") or plan.has("sowing") or not plan.has("materials"): continue
		var missing := int(plan.materials.get(worker.cargo, 0)) - int(plan.used.get(worker.cargo, 0)) - int(plan.claims.get(worker.cargo, 0)) - staged(plan, worker.cargo)
		if missing < amount: continue
		var route: Array[Vector3i] = world.nearest_route(worker.cell, world.work_cells(plan.kind, plan.cell, plan.direction))
		if route.is_empty(): continue
		world.Jobs.claim_material(plan, worker.cargo, amount)
		worker.job = {"kind": "delivery", "plan_id": plan.id, "resource": worker.cargo, "amount": amount,
			"target": route.back(), "phase": "travel", "labour": world.Jobs.Labour.new(0.1)}
		world.Jobs._set_route(world, worker, route, "carrying to construction")
		return true
	return false

static func finish(world, worker: Dictionary) -> void:
	var job: Dictionary = worker.job
	if not world.plans.has(job.plan_id):
		worker.job = {"kind": "restock", "target": worker.cell, "phase": "store", "labour": world.Jobs.Labour.new(0.1)}
		return
	var plan: Dictionary = world.plans[job.plan_id]
	if not plan.has("delivered"):
		plan.delivered = world.Inventory.new()
		plan.delivered.capacity = maxi(1, plan.required)
	if not plan.delivered.store(worker.cargo, job.amount): return
	world.Jobs.claim_material(plan, worker.cargo, -job.amount)
	worker.cargo = ""
	worker.cargo_amount = 1
	worker.job = {}
	world.Jobs.clear_retry(worker)
	world.deliveries += 1
	world.revision += 1
