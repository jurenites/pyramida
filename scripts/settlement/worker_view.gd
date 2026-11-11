extends Node3D
const Assets = preload("res://scripts/settlement/asset_library.gd")
const Citizens = preload("res://scripts/settlement/citizen_lifecycle.gd")
const JointSpring = preload("res://scripts/settlement/joint_spring.gd")
const CitizenRig = preload("res://scripts/settlement/citizen_rig.gd")
const SkinPicker = preload("res://scripts/settlement/citizen_skin_picker.gd")
const WALK = preload("res://data/settlement/reference_man_walk.tres")
const RUN = preload("res://data/settlement/reference_child_walk.tres")
const ActivityPose = preload("res://scripts/settlement/citizen_activity_pose.gd")
const FootContact = preload("res://scripts/settlement/citizen_foot_contact.gd")
const LogHold = preload("res://scripts/settlement/citizen_log_hold.gd")
const Palette=preload("res://scripts/game_palette.gd")
const ADULT_SCALE := 1.5 # Authored ~0.94 m body -> ~1.4 m citizen.
const CHILD_SCALE := ADULT_SCALE * 0.70
const CLOTH_PALETTE := [Color("da783b"), Color("f18480"), Color("dfa438"), Palette.GRASS, Palette.WOODEN_ROOF]
const CARGO_ASSETS := {"imbrex": "imbrex", "rope": "rope", "flour": "flour", "clay": "clay", "brick": "brick", "ore": "ore", "pottery": "pottery", "log": "log", "food": "carried_berries", "water": "water_bucket", "grain": "grain", "plank": "plank", "stone": "raw_stone", "block": "block"}
var foot_contact := FootContact.new()
var body: Node3D
var cargo: Node3D
var last_cargo := ""
var phase := 0.0
var identity := 0
var ring: Node3D
var appearance := -1
var cloth_color := -1
var child_appearance := false
var previous_position := Vector3.ZERO
var has_position := false
var walk_blend := 0.0
var work_phase := 0.0
var activity_time := 0.0
var travel_grade := 0.0
var travel_direction := Vector3.FORWARD
var facing_sector := 0
var has_heading := false
var joints: Dictionary = {}
var joint_springs: Dictionary = {}
var skeleton: Skeleton3D
# Body geometry is shared by silhouette rendering and cursor picking. Cargo is excluded.
var silhouette_parts: Array[MeshInstance3D] = []
static var pick_meshes: Dictionary = {}
static var cloth_materials: Dictionary = {}
# Keep side views slightly turned toward the lens, like an eight-frame cutout sheet.
const VIEW_ANGLES := [0.0, 0.62, 1.20, 2.48, PI, -2.48, -1.20, -0.62]

static func direction_sector(direction: Vector3, camera_back: Vector3) -> int:
	var front := atan2(-camera_back.x, -camera_back.z)
	var heading := atan2(-direction.x, -direction.z)
	return posmod(roundi(wrapf(heading - front, -PI, PI) / (PI / 4.0)), 8)

func update_facing(camera: Camera3D) -> void:
	var back := camera.global_basis.z if is_instance_valid(camera) else Vector3.BACK
	back.y = 0.0
	if back.length_squared() < 0.00001:
		back = Vector3.BACK
	if has_heading:
		var candidate := direction_sector(travel_direction, back)
		var relative := wrapf(atan2(-travel_direction.x, -travel_direction.z) - atan2(-back.x, -back.z), -PI, PI)
		# A small dead band prevents noisy direction changes around sector boundaries.
		if absf(wrapf(relative - facing_sector * PI / 4.0, -PI, PI)) > PI / 8.0 + 0.06:
			facing_sector = candidate
	body.rotation.y = atan2(-back.x, -back.z) + VIEW_ANGLES[facing_sector]

func setup(index: int) -> void:
	identity = index
	set_appearance(index % 3, index % 5)
	# Internal selection state shared by body outlines, tooltips and work bars.
	ring = Node3D.new()
	ring.name = "SelectionRing"
	ring.position.y = 0.035
	add_child(ring)
	ring.visible = false

func set_appearance(variant: int, colour: int, stage := "") -> void:
	var child := stage == "child" if not stage.is_empty() else child_appearance
	if appearance == variant and cloth_color == colour and child_appearance == child:
		return
	var angle := body.rotation.y if is_instance_valid(body) else 0.0
	var held_log: Node3D = cargo if is_instance_valid(cargo) and last_cargo == "log" else null
	if held_log != null: held_log.reparent(self, true)
	if is_instance_valid(body):
		body.free()
	appearance = variant
	cloth_color = colour
	child_appearance = child
	# Retain saved appearance IDs; odd adult outfits use the approved woman.
	body = Assets.create("reference_child" if child else "reference_woman" if variant % 2 == 1 else "reference_man")
	body.rotation.y = angle
	add_child(body)
	skeleton = body.get_node_or_null("Skeleton3D")
	joints.clear()
	joint_springs.clear()
	for path in ["LeftArm/Elbow", "RightArm/Elbow", "LeftLeg/Knee", "RightLeg/Knee"]:
		joints[path] = body.get_node(path)
		var knee: bool = path.ends_with("Knee")
		joint_springs[path] = JointSpring.new(-2.15 if knee else 0.0, 0.0 if knee else 1.65)
	var material_key := Vector2i(colour, int(Assets.Illustration.enabled))
	if not cloth_materials.has(material_key):
		var paint := StandardMaterial3D.new()
		paint.albedo_color = CLOTH_PALETTE[colour]
		paint.roughness = 0.95
		paint.vertex_color_use_as_albedo = true
		paint.cull_mode = BaseMaterial3D.CULL_DISABLED
		if Assets.Illustration.enabled:
			paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		cloth_materials[material_key] = paint
	var material: StandardMaterial3D = cloth_materials[material_key]
	for part in body.find_children("*", "MeshInstance3D", true, false):
		if part.get_meta("citizen_cloth", false):
			part.material_override = material
		if part.has_meta("citizen_cloth_surface"):
			part.set_surface_override_material(int(part.get_meta("citizen_cloth_surface")), material)
	silhouette_parts.assign(body.find_children("*", "MeshInstance3D", true, false))
	if held_log != null: held_log.reparent(body.get_node("CargoSocket"), true)
	else: last_cargo = ""

func receive_log(log_: Node3D) -> void:
	if is_instance_valid(cargo) and cargo != log_: cargo.free()
	cargo = log_
	cargo.reparent(body.get_node("CargoSocket"), true)
	last_cargo = "log"

func release_log(parent: Node3D) -> Node3D:
	if last_cargo != "log" or not is_instance_valid(cargo): return null
	var log_ := cargo
	log_.reparent(parent, true)
	cargo = null
	last_cargo = ""
	return log_

# Test the actual articulated surface, independent of buildings in front of it.
# Cached BVHs avoid scanning triangles or maintaining moving physics colliders.
func pick_distance(origin: Vector3, direction: Vector3) -> float:
	var nearest := INF
	if not is_visible_in_tree(): return nearest
	if skeleton != null: CitizenRig.sync(body, skeleton)
	for part in silhouette_parts:
		if not part.is_visible_in_tree() or part.mesh == null: continue
		var inverse := part.global_transform.affine_inverse()
		var local_origin := inverse * origin
		var local_direction := (inverse.basis * direction).normalized()
		if part.skin != null and skeleton != null:
			if part.custom_aabb.intersects_ray(local_origin, local_direction) == null: continue
			var transforms: Array[Transform3D] = []
			for bind in part.skin.get_bind_count():
				transforms.append(skeleton.get_bone_global_pose(part.skin.get_bind_bone(bind)) * part.skin.get_bind_pose(bind))
			var distance: float = SkinPicker.for_mesh(part.mesh).distance(local_origin, local_direction, transforms)
			if is_finite(distance):
				nearest = minf(nearest, origin.distance_to(part.global_transform * (local_origin + local_direction * distance)))
			continue
		if part.mesh.get_aabb().intersects_ray(local_origin, local_direction) == null: continue
		if not pick_meshes.has(part.mesh):
			pick_meshes[part.mesh] = part.mesh.generate_triangle_mesh()
		var geometry: TriangleMesh = pick_meshes[part.mesh]
		var hit := geometry.intersect_ray(local_origin, local_direction)
		if not hit.is_empty():
			nearest = minf(nearest, origin.distance_to(part.global_transform * hit.position))
	return nearest

func hand_position(side: int) -> Vector3:
	var bone := 4 if side < 0 else 6
	var part: MeshInstance3D = body.get_node("Surface")
	var rest := part.skin.get_bind_pose(bone).inverse().origin + Vector3(side * 0.087, -0.077, 0)
	return body.to_global(body.posed_point(bone, rest))

func pose_elbow(side: int, target: float, delta: float, reset: bool) -> void:
	var path := "LeftArm/Elbow" if side < 0 else "RightArm/Elbow"
	var spring: RefCounted = joint_springs[path]
	var angle: float = spring.reset(target) if reset else spring.step(target, delta)
	joints[path].quaternion = Quaternion(Vector3(0.66, side * 0.75, 0).normalized(), angle)

func sync(worker: Dictionary, delta: float, selected: bool, camera: Camera3D = null, navigation = null) -> void:
	var old_body := body
	var adult := Citizens.is_adult(worker)
	set_appearance(int(worker.get("appearance", identity % 3)), int(worker.get("cloth_color", identity % 5)), "adult" if adult else "child")
	var appearance_changed := old_body != body
	var gait = WALK if adult else RUN
	var size := ADULT_SCALE if adult else CHILD_SCALE
	body.scale = Vector3.ONE * size
	var offset := Vector3((identity % 3 - 1) * 0.14, 0, (identity % 3 - 1) * 0.12)
	var on_room_path: bool=navigation!=null and (navigation.room_nodes.has(worker.cell) or (worker.get("route_index",0)<worker.get("route",[]).size() and navigation.room_paths.get(worker.cell,{}).has(worker.route[worker.route_index])))
	var ladder: Dictionary = FootContact.ladder(navigation, worker) if navigation != null else {}
	var indoor: Dictionary = FootContact.Indoor.active(navigation, worker) if navigation != null else {}
	var stepped := not ladder.is_empty() or not indoor.is_empty()
	var rescuing: bool = worker.has("rescue_route")
	if on_room_path or stepped or rescuing: offset=Vector3.ZERO
	var target: Vector3 = worker.position + offset
	var movement: Vector3 = worker.position - previous_position
	var teleport := not has_position or appearance_changed or movement.length() > 3.0
	var horizontal_distance := Vector2(movement.x, movement.z).length()
	if teleport: travel_grade = 0.0
	elif delta > 0.0 and horizontal_distance > 0.0001:
		travel_grade = clampf(movement.y / horizontal_distance, -0.8, 0.8)
	previous_position = worker.position
	if teleport:
		position = target
		has_position = true
		walk_blend = 0.0
		phase = 0.0
	elif delta > 0.0:
		var horizontal := Vector3(movement.x, 0, movement.z)
		if horizontal.length_squared() > 0.000001:
			travel_direction = horizontal.normalized()
			has_heading = true
		var before := position
		# Smooth fixed simulation ticks into a continuous rendered walk.
		position = position.lerp(target, 1.0 - exp(-22.0 * delta))
		var travelled := Vector2(before.x, before.z).distance_to(Vector2(position.x, position.z))
		if worker.get("rescue_climbing", false): travelled = before.distance_to(position)
		var walking := travelled > 0.0001
		walk_blend = move_toward(walk_blend, 1.0 if walking else 0.0, delta * 9.0)
		# Compressed world travel can exceed the short limbs' natural stride.
		# Keep ordinary walking readable. On ladders, each half-cycle advances
		# one authored rung (16 cm), so contact follows the connector distance.
		phase += (travelled / (0.4 if not indoor.is_empty() else 0.32) if stepped else minf(travelled / (gait.stride_length * size), delta * 1.5 / gait.cycle_seconds)) * TAU
	if navigation != null and worker.cell.y == 0 and not on_room_path and ladder.is_empty() and not rescuing:
		var floor_cell := Vector3i(roundi(position.x / navigation.CELL_SIZE), 0, roundi(position.z / navigation.CELL_SIZE))
		# Correct the smoothed visual and personal spacing offset to the actual slope.
		if navigation.terrain_shapes.has(floor_cell):
			position.y = navigation.surface_height(floor_cell, position)
	if not is_instance_valid(camera):
		camera = get_viewport().get_camera_3d()
	if worker.get("rescue_climbing", false) and worker.has("rescue_route"):
		var next: Vector3i = worker.rescue_route[worker.rescue_index]
		var path: Array = worker.rescue_paths.get(worker.cell, {}).get(next, [])
		if not path.is_empty():
			var facing: Vector3 = path.back() - path.front()
			if facing.y < 0.0: facing = -facing
			facing.y = 0.0
			if not facing.is_zero_approx(): travel_direction = facing.normalized(); has_heading = true
	update_facing(camera)
	if (stepped or worker.get("rescue_climbing", false)) and has_heading:
		body.rotation.y = atan2(-travel_direction.x, -travel_direction.z)
	if delta > 0.0 or teleport:
		var pose_delta := 0.0 if teleport else delta
		body.pose(phase / TAU, walk_blend > 0.0, pose_delta, walk_blend)
		activity_time += delta
		ActivityPose.apply(self, worker, activity_time + identity * 1.71, travel_grade, pose_delta)
		if (not on_room_path or stepped) and not rescuing:
			foot_contact.apply(self, worker, navigation, pose_delta, teleport)
		var left_arm: Node3D = body.get_node("LeftArm")
		var right_arm: Node3D = body.get_node("RightArm")
		if teleport:
			for spring: RefCounted in joint_springs.values(): spring.reset(0.0)
		if worker.cargo == "log":
			LogHold.apply(body)
		elif not worker.cargo.is_empty() or worker.has("plant_plan_id"):
			left_arm.rotation = Vector3(0.60, -0.20, 0.45)
			right_arm.rotation = Vector3(0.60, 0.20, -0.45)
			pose_elbow(-1, 1.05, delta, teleport)
			pose_elbow(1, 1.05, delta, teleport)
		if worker.cargo.is_empty() and worker.status in ["building", "cutting timber"]:
			work_phase += delta * 8.0
			right_arm.rotation.x = 0.5 + sin(work_phase) * 0.45
			pose_elbow(1, 0.65 + (1.0 - cos(work_phase)) * 0.4, delta, teleport)
		var slipping: float=worker.get("slip_remaining",0)
		if slipping>0:
			var sit:=minf(1.0,minf((1.4-slipping)/0.18,slipping/0.35))
			body.position.y=-0.23*size*maxf(0,sit)
			for side in ["Left","Right"]:
				body.get_node(side+"Leg").rotation.x=1.25*sit
				body.get_node(side+"Leg/Knee").rotation.x=-0.35*sit
				body.get_node(side+"Arm").rotation.x=-0.45*sit
		else: body.position.y=0.0
		CitizenRig.sync(body, skeleton)
		# Every carried item follows the real skinned hands, including torso bob.
		if worker.cargo != "log":
			body.get_node("CargoSocket").basis = Basis.IDENTITY.scaled(Vector3.ONE / size)
			body.get_node("CargoSocket").position = body.to_local((hand_position(-1) + hand_position(1)) * 0.5) + Vector3.UP * (0.060 if worker.cargo == "food" else 0.018) / size
	var cargo_visual: String = "bread" if worker.cargo == "food" and worker.get("cargo_food", "") == "bread" else worker.cargo
	if last_cargo != cargo_visual:
		if is_instance_valid(cargo):
			cargo.free()
		last_cargo = cargo_visual
		if not last_cargo.is_empty():
			cargo = Assets.create("bread" if last_cargo == "bread" else CARGO_ASSETS[last_cargo])
			body.get_node("CargoSocket").add_child(cargo)
	ring.visible = selected and adult

var plant_cargo: Node3D
var last_plant_plan := -1

func sync_plant_cargo(worker: Dictionary, model) -> void:
	var id: int = worker.get("plant_plan_id", -1)
	if id == last_plant_plan: return
	last_plant_plan = id
	if is_instance_valid(plant_cargo): plant_cargo.free()
	if id == -1 or not model.plans.has(id): return
	var plan: Dictionary = model.plans[id]
	var kind: String = plan.kind
	if kind == "vine_tree": kind = "seed_vine"
	if kind == "tree": kind = preload("res://scripts/settlement/tree_view.gd").asset(plan.relocation.payload.trees)
	if kind == "garden" and plan.relocation.payload.gardens.get("species") == "grass": kind = "grass_patch"
	plant_cargo = Assets.create(kind)
	if plan.kind == "tree": preload("res://scripts/settlement/tree_view.gd").sync(plant_cargo, plan.relocation.payload.trees)
	if plan.kind == "berry":
		preload("res://scripts/settlement/bush_view.gd").sync(plant_cargo, plan.relocation.source, model.world_seed, int(plan.relocation.payload.deposits.get("appearance_seed", -1)))
		for child in plant_cargo.get_children():
			if child is MeshInstance3D and str(child.name).begins_with("Berry"):
				child.visible = int(str(child.name).trim_prefix("Berry")) < plan.relocation.payload.deposits.inventory.count("food")
	plant_cargo.scale *= 0.45
	body.get_node("CargoSocket").add_child(plant_cargo)
