extends RefCounted
## Salvage owns the recovered frame pieces until the simulation assigns a carrier.
const Frame = preload("res://scripts/settlement/timber_frame.gd")
const Assets = preload("res://scripts/settlement/asset_library.gd")
var motion: Node3D
var groups: Dictionary = {}

func reset() -> void:
	for pieces: Array in groups.values():
		for piece: Dictionary in pieces:
			if is_instance_valid(piece.node): piece.node.free()
	groups.clear()

func capture(plan: Dictionary, remaining := -1) -> void:
	if groups.has(plan.id): return
	var world: RefCounted = motion.model
	var view: Node3D = motion.view
	var structural := int(plan.materials.get("log", 0))
	var salvaging: bool = world.Deconstruction.is_salvage(plan)
	if remaining < 0:
		remaining = plan.relocation.parts.count("log") if salvaging else structural + (world.stores[plan.relocation.source].count("log") if world.stores.has(plan.relocation.source) else 0)
	var source: Node3D = motion.frame_root({"cell": plan.relocation.source, "kind": plan.kind, "plan_id": plan.id})
	var temporary: bool = source == null or source.get_meta("asset", "") != plan.kind
	if temporary:
		source = Assets.create(plan.kind)
		motion.add_child(source)
		source.global_transform = Transform3D(Basis(Vector3.UP, -plan.direction * PI * 0.5), Vector3(plan.relocation.source) + plan.get("placement_offset", Vector3.ZERO))
		if plan.kind == "platform": world.Platforms.sync(source, int(plan.get("platform_tier", 1)))
		if plan.kind == "sawmill": preload("res://scripts/settlement/sawmill_view.gd").sync(source, int(plan.get("sawmill_tier", 2)))
		if plan.kind == "windmill": preload("res://scripts/settlement/mill_view.gd").sync(source, int(plan.get("mill_tier", 3)))
		Assets.Variation.apply(source, plan.kind, plan.relocation.source, world.world_seed)
	var slots := Frame.slots(source)
	var pieces: Array[Dictionary] = []
	for index in mini(structural, remaining):
		var log_: Node3D
		# Prefer the exact object that originally arrived from the tree.
		for binding: Dictionary in motion.frames.duplicate():
			if binding.cell == plan.relocation.source and binding.slot == index and is_instance_valid(binding.node):
				log_ = binding.node
				motion.frames.erase(binding)
				log_.reparent(motion, true)
				# Dismantling may finish before a rendered placement animation.
				if index < slots.size(): log_.global_transform = source.global_transform * slots[index].pose
				for transfer: Dictionary in motion.moving.duplicate():
					if transfer.node == log_: motion.moving.erase(transfer)
				break
		if log_ == null and index < slots.size(): log_ = Frame.extract(source, slots[index], motion)
		if log_ != null: pieces.append({"node": log_, "slot": index, "pose": log_.global_transform})
	# Contents are separate from the construction recipe and must not duplicate it.
	for index in range(structural, remaining):
		var log_: Node3D
		var stored_slot := index - structural
		if source.has_meta("logs"):
			var logs: Array = source.get_meta("logs")
			if stored_slot < logs.size(): log_ = logs[stored_slot]
			else:
				for child in source.get_children():
					if child.get_meta("timber_overflow_slot", -1) == stored_slot: log_ = child; break
		if log_ == null: log_ = view.entity_views.get("parts:%s:log:%s" % [plan.id, index])
		if log_ == null: continue # The ordinary loose salvage view supplies it later.
		for binding: Dictionary in motion.stocked.duplicate():
			if binding.node == log_: motion.stocked.erase(binding)
		detach_entity(log_)
		log_.reparent(motion, true)
		if log_.has_meta("timber_overflow_slot"): log_.remove_meta("timber_overflow_slot")
		pieces.append({"node": log_, "slot": index, "pose": log_.global_transform})
	groups[plan.id] = pieces
	if temporary: source.free()

func pickup(worker_id: int, plan_id: int, slot: int) -> void:
	if worker_id >= motion.view.actors.size(): return
	if not groups.has(plan_id) and motion.model.plans.has(plan_id): capture(motion.model.plans[plan_id], slot + 1)
	var log_: Node3D
	for piece: Dictionary in groups.get(plan_id, []):
		if piece.slot == slot:
			log_ = piece.node
			groups[plan_id].erase(piece)
			break
	var key := "parts:%s:log:%s" % [plan_id, slot]
	if log_ == null: log_ = motion.view.entity_views.get(key)
	if not is_instance_valid(log_): return
	detach_entity(log_)
	log_.visible = true
	log_.set_meta("variation_exempt", true)
	motion.view.actors[worker_id].receive_log(log_)
	motion.queue(log_, {"stage": "pickup", "actor": motion.view.actors[worker_id]})

func sync() -> void:
	var world: RefCounted = motion.model
	var view: Node3D = motion.view
	# Saves reconstruct only remaining stock at the original frame positions.
	for plan: Dictionary in world.plans.values():
		if world.Deconstruction.is_salvage(plan) and not plan.get("dropped_cargo", false) and not groups.has(plan.id): capture(plan)
	for id: int in groups.keys():
		var pieces: Array = groups[id]
		if not world.plans.has(id):
			for piece: Dictionary in pieces:
				if is_instance_valid(piece.node): piece.node.free()
			groups.erase(id)
			continue
		var plan: Dictionary = world.plans[id]
		for piece: Dictionary in pieces:
			var key := "parts:%s:log:%s" % [id, piece.slot]
			var placeholder: Node3D = view.entity_views.get(key)
			if is_instance_valid(placeholder) and placeholder != piece.node: placeholder.hide()
			if not is_instance_valid(piece.node): continue
			piece.node.global_transform = piece.pose
			var cell: Vector3i = plan.relocation.source
			piece.node.visible = (not view.cutaway or cell.y <= view.display_level) and (not view.fog_enabled or world.exploration.contains(Vector3(cell)))

func detach_entity(log_: Node3D) -> void:
	for key: String in motion.view.entity_views.keys():
		if motion.view.entity_views[key] == log_: motion.view.entity_views.erase(key)
	if log_.has_meta("collider"):
		log_.get_meta("collider").free()
		log_.remove_meta("collider")
