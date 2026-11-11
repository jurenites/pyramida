extends Node3D
## Presentation-only transfers. Inventory changes exactly once, in the simulation.
const Frame = preload("res://scripts/settlement/timber_frame.gd")
const Assets = preload("res://scripts/settlement/asset_library.gd")
const Timber = preload("res://scripts/settlement/timber_kit.gd")
const PICKUP_SECONDS := 0.75
const DEPOSIT_SECONDS := 0.55
var view: Node3D
var model: RefCounted
var moving: Array[Dictionary] = []
var frames: Array[Dictionary] = []
var stocked: Array[Dictionary] = []
var recovery = preload("res://scripts/settlement/timber_recovery.gd").new()

func bind_model(next: RefCounted) -> void:
	if model == next: return
	if model != null:
		model.timber_cut.disconnect(cut)
		model.timber_stored.disconnect(store)
		model.timber_visuals_reset.disconnect(reset)
		model.timber_picked_up.disconnect(pickup)
		model.timber_installed.disconnect(install)
		model.timber_dismantled.disconnect(recovery.capture)
		model.timber_salvage_picked_up.disconnect(recovery.pickup)
	reset()
	model = next
	recovery.motion = self
	model.timber_cut.connect(cut)
	model.timber_stored.connect(store)
	model.timber_visuals_reset.connect(reset)
	model.timber_picked_up.connect(pickup)
	model.timber_installed.connect(install)
	model.timber_dismantled.connect(recovery.capture)
	model.timber_salvage_picked_up.connect(recovery.pickup)

func reset() -> void:
	recovery.reset()
	for transfer in moving + frames + stocked:
		if is_instance_valid(transfer.node): transfer.node.free()
	moving.clear()
	frames.clear()
	stocked.clear()
	if not is_instance_valid(view): return
	for actor in view.actors:
		if actor.last_cargo != "log": continue
		if is_instance_valid(actor.cargo): actor.cargo.free()
		actor.cargo = null
		actor.last_cargo = ""
	# Restoring the same model must also restore any detached tree sections.
	view.last_revision = -1
	view.appearance_revision = -1
	if is_instance_valid(view.scenery): view.scenery.model_id = 0

func cut(worker_id: int, cell: Vector3i, section: int) -> void:
	if worker_id >= view.actors.size() or not view.tree_views.has(cell): return
	var tree: Node3D = view.tree_views[cell]
	if not is_instance_valid(tree): return
	var log_ := tree.get_node_or_null("Segment%d" % section) as Node3D
	if log_ == null or not log_.has_node("Trunk"): return
	var trunk: MeshInstance3D = log_.get_node("Trunk")
	# Convert the existing section to the cargo origin, keeping every vertex in
	# exactly the same world position. Only branches/crown are stripped away.
	var pose: Transform3D = trunk.global_transform * Timber.sources("log")[0].pose.affine_inverse()
	pose = pose * Transform3D(Basis.IDENTITY, Vector3(0, -0.12, 0))
	var placeholder := Node3D.new()
	var old_name := log_.name
	log_.reparent(self, true)
	log_.name = "Log"
	placeholder.name = old_name
	placeholder.visible = false
	tree.add_child(placeholder)
	var parts := [log_.get_node("Trunk"), log_.get_node("BaseCut"), log_.get_node("CutFace")]
	for child in log_.get_children():
		if child not in parts: child.free()
	log_.global_transform = pose
	for index in parts.size():
		var part: MeshInstance3D = parts[index]
		part.name = ["Bark", "CutEnd", "CutEnd2"][index]
		part.transform = Transform3D(Basis.IDENTITY, Vector3(0, 0.12, 0)) * Timber.sources("log")[index].pose
		part.visible = true
	log_.visible = true
	log_.set_meta("variation_exempt", true)
	var actor: Node3D = view.actors[worker_id]
	actor.receive_log(log_)
	queue(log_, {"stage": "pickup", "actor": actor})

func queue(log_: Node3D, step: Dictionary) -> void:
	log_.set_meta("physical_timber", true)
	for transfer in moving:
		if transfer.node == log_:
			transfer.steps.append(step)
			return
	moving.append({"node": log_, "steps": [step], "stage": step.stage, "elapsed": 0.0, "from": log_.global_transform, "pose": log_.global_transform})

func store(worker_id: int, cell: Vector3i, slot: int) -> void:
	if worker_id >= view.actors.size(): return
	var log_: Node3D = view.actors[worker_id].release_log(self)
	if log_ != null: queue(log_, {"stage": "deposit", "cell": cell, "slot": slot})

func pile_root(cell: Vector3i) -> Node3D:
	if view.store_views.has(cell): return view.store_views[cell]
	for plan: Dictionary in model.plans.values():
		if plan.get("deconstruction", false) and plan.relocation.stage == "dismantle" and plan.relocation.source == cell:
			return view.entity_views.get("plan:%s" % plan.id)
	return null

func pile_slot(cell: Vector3i, slot: int) -> Node3D:
	var pile := pile_root(cell)
	if not is_instance_valid(pile) or not pile.has_meta("logs"): return null
	var logs: Array = pile.get_meta("logs")
	return logs[mini(slot, logs.size() - 1)] if not logs.is_empty() else null

func pickup(worker_id: int, cell: Vector3i, slot: int) -> void:
	if worker_id >= view.actors.size(): return
	var target := pile_slot(cell, slot)
	if target == null: return
	var log_: Node3D
	# A fast simulation may collect a delivery before its animation has landed.
	for transfer in moving:
		for step: Dictionary in transfer.steps:
			if step.stage == "deposit" and step.cell == cell and step.slot == slot and not step.get("collected", false):
				step.collected = true
				log_ = transfer.node
				break
		if log_ != null: break
	var pile := target.get_parent()
	var logs: Array = pile.get_meta("logs")
	if log_ == null:
		if slot < logs.size():
			log_ = target
			var placeholder: Node3D = Assets.create("log")
			pile.add_child(placeholder)
			placeholder.transform = target.transform
			placeholder.visible = false
			placeholder.set_meta("variation_exempt", true)
			logs[slot] = placeholder
		else:
			for child in pile.get_children():
				if child.get_meta("timber_overflow_slot", -1) == slot: log_ = child; break
			if log_ == null:
				log_ = Assets.create("log")
				pile.add_child(log_)
				log_.transform = target.transform
	if log_.has_meta("timber_overflow_slot"): log_.remove_meta("timber_overflow_slot")
	for index in range(stocked.size() - 1, -1, -1):
		if stocked[index].node == log_: stocked.remove_at(index)
	log_.visible = true
	view.actors[worker_id].receive_log(log_)
	queue(log_, {"stage": "pickup", "actor": view.actors[worker_id]})

func install(worker_id: int, plan: Dictionary) -> void:
	if worker_id >= view.actors.size(): return
	var log_: Node3D = view.actors[worker_id].release_log(self)
	if log_ == null: return
	var binding := {"node": log_, "cell": plan.cell, "kind": plan.kind, "plan_id": plan.id,
		"slot": int(plan.get("used", {}).get("log", plan.installed)) - 1, "settled": false}
	frames.append(binding)
	queue(log_, {"stage": "frame", "binding": binding})

func frame_root(binding: Dictionary) -> Node3D:
	if model.plans.has(binding.plan_id) and view.entity_views.has("plan:%s" % binding.plan_id): return view.entity_views["plan:%s" % binding.plan_id]
	for plan: Dictionary in model.plans.values():
		if plan.get("deconstruction", false) and plan.relocation.stage == "dismantle" and plan.relocation.source == binding.cell:
			if view.entity_views.has("plan:%s" % plan.id): return view.entity_views["plan:%s" % plan.id]
	# Do not attach an abandoned plan to a different building placed in its cell.
	if model.buildings.has(binding.cell) and model.buildings[binding.cell].kind != binding.kind: return null
	for prefix in ["building", "stockpile", "platform", "stairs", "well", "garden", "soil_bed"]:
		var node: Node3D = view.entity_views.get("%s:%s" % [prefix, binding.cell])
		if is_instance_valid(node) and str(node.get_meta("asset", "")) == binding.kind: return node
	return null

func frame_slot(binding: Dictionary) -> Dictionary:
	var destination := frame_root(binding)
	if destination == null: return {}
	var slots := Frame.slots(destination)
	if binding.slot < 0 or binding.slot >= slots.size(): return {}
	return slots[binding.slot]

func before_rebuild() -> void:
	# Plan roots are disposable; the installed stock is not.
	for binding in frames + stocked:
		if is_instance_valid(binding.node): binding.node.reparent(self, true)

func reconcile() -> void:
	for index in range(stocked.size() - 1, -1, -1):
		var binding := stocked[index]
		if not is_instance_valid(binding.node): stocked.remove_at(index); continue
		var log_: Node3D = binding.node
		var target := pile_slot(binding.cell, binding.slot)
		if target == null or not model.stores.has(binding.cell) or model.stores[binding.cell].count("log") <= binding.slot:
			log_.free(); stocked.remove_at(index); continue
		if log_.get_parent() == self: seat_in_pile(log_, binding, target)
	for index in range(frames.size() - 1, -1, -1):
		var binding := frames[index]
		if not is_instance_valid(binding.node): frames.remove_at(index); continue
		var slot := frame_slot(binding)
		if slot.is_empty():
			binding.node.free(); frames.remove_at(index); continue
		Frame.mask(slot)
		if binding.settled:
			binding.node.reparent(frame_root(binding), false)
			binding.node.transform = slot.pose

func seat_in_pile(log_: Node3D, binding: Dictionary, target: Node3D) -> void:
	var pile := pile_root(binding.cell)
	var logs: Array = pile.get_meta("logs")
	# A detached actual slot already retains its local pose in the binding.
	var pose: Transform3D = binding.get("local_pose", target.transform)
	var overflow: bool = binding.slot >= logs.size()
	log_.reparent(pile, false)
	log_.transform = pose
	log_.visible = not overflow
	log_.set_meta("variation_exempt", true)
	if overflow: log_.set_meta("timber_overflow_slot", binding.slot)
	else:
		logs[binding.slot] = log_
		if target != log_: target.free()
	binding.local_pose = pose

func advance(delta: float) -> void:
	recovery.sync()
	reconcile()
	for index in range(moving.size() - 1, -1, -1):
		var transfer: Dictionary = moving[index]
		if not is_instance_valid(transfer.node): moving.remove_at(index); continue
		var log_: Node3D = transfer.node
		var step: Dictionary = transfer.steps[0]
		var target: Node3D
		# Hide pending placeholders even while the log is still reaching the hands.
		for pending: Dictionary in transfer.steps:
			if pending.stage != "deposit" or pending.get("collected", false): continue
			var placeholder := pile_slot(pending.cell, pending.slot)
			if placeholder != null and pending.slot < placeholder.get_parent().get_meta("logs").size(): placeholder.visible = false
		var end: Transform3D
		if step.stage == "pickup":
			if not is_instance_valid(step.actor): log_.free(); moving.remove_at(index); continue
			end = step.actor.body.get_node("CargoSocket").global_transform
		elif step.stage == "deposit":
			target = pile_slot(step.cell, step.slot)
			if target == null: log_.free(); moving.remove_at(index); continue
			end = target.global_transform
		else:
			var slot := frame_slot(step.binding)
			if slot.is_empty(): log_.free(); moving.remove_at(index); continue
			end = frame_root(step.binding).global_transform * slot.pose
		if delta <= 0.0:
			log_.global_transform = transfer.pose
			continue
		var duration := PICKUP_SECONDS if step.stage == "pickup" else DEPOSIT_SECONDS
		transfer.elapsed = minf(duration, transfer.elapsed + delta)
		var t: float = transfer.elapsed / duration
		var pose: Transform3D = transfer.from.interpolate_with(end, t * t * (3.0 - 2.0 * t))
		pose.origin.y += sin(t * PI) * (0.12 if step.stage == "pickup" else 0.18)
		log_.global_transform = pose
		transfer.pose = pose
		if t < 1.0: continue
		transfer.steps.pop_front()
		if not transfer.steps.is_empty():
			transfer.stage = transfer.steps[0].stage
			transfer.elapsed = 0.0
			transfer.from = end
			continue
		if step.stage == "pickup": log_.transform = Transform3D.IDENTITY
		elif step.stage == "deposit":
			var binding := {"node": log_, "cell": step.cell, "slot": step.slot}
			seat_in_pile(log_, binding, target)
			stocked.append(binding)
		else:
			step.binding.settled = true
			log_.reparent(frame_root(step.binding), false)
			log_.transform = frame_slot(step.binding).pose
		moving.remove_at(index)
