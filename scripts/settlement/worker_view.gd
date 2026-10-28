extends Node3D
const Assets = preload("res://scripts/settlement/asset_library.gd")
const Citizens = preload("res://scripts/settlement/citizen_lifecycle.gd")
const JointSpring = preload("res://scripts/settlement/joint_spring.gd")
const CLOTH_PALETTE := [Color("518e9a"), Color("cc765c"), Color("d3ad53"), Color("869c70"), Color("9583ad")]
const CARGO_ASSETS := {"pottery": "pottery", "log": "log", "food": "food_crate", "water": "water_bucket", "grain": "grain", "plank": "plank", "stone": "raw_stone", "block": "block"}
var body: Node3D
var cargo: Node3D
var last_cargo := ""
var phase := 0.0
var identity := 0
var ring: Node3D
var appearance := -1
var cloth_color := -1
var previous_position := Vector3.ZERO
var has_position := false
var walk_blend := 0.0
var work_phase := 0.0
var travel_direction := Vector3.FORWARD
var facing_sector := 0
var has_heading := false
var joints: Dictionary = {}
var joint_springs: Dictionary = {}
# Body geometry is shared by silhouette rendering and cursor picking. Cargo is excluded.
var silhouette_parts: Array[MeshInstance3D] = []
static var pick_meshes: Dictionary = {}
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

func set_appearance(variant: int, colour: int) -> void:
	if appearance == variant and cloth_color == colour:
		return
	var angle := body.rotation.y if is_instance_valid(body) else 0.0
	if is_instance_valid(body):
		body.free()
	appearance = variant
	cloth_color = colour
	body = Assets.create("citizen_%d" % variant)
	body.rotation.y = angle
	add_child(body)
	joints.clear()
	joint_springs.clear()
	for path in ["LeftArm/Elbow", "RightArm/Elbow", "LeftLeg/Knee", "RightLeg/Knee"]:
		joints[path] = body.get_node(path)
		var knee: bool = path.ends_with("Knee")
		joint_springs[path] = JointSpring.new(-1.35 if knee else 0.0, 0.0 if knee else 1.65)
	var material := StandardMaterial3D.new()
	material.albedo_color = CLOTH_PALETTE[colour]
	material.roughness = 0.95
	if Assets.Illustration.enabled:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for part in body.find_children("*", "MeshInstance3D", true, false):
		if part.get_meta("citizen_cloth", false):
			part.material_override = material
	silhouette_parts.assign(body.find_children("*", "MeshInstance3D", true, false))
	last_cargo = ""

# Test the actual articulated surface, independent of buildings in front of it.
# Cached BVHs avoid scanning triangles or maintaining moving physics colliders.
func pick_distance(origin: Vector3, direction: Vector3) -> float:
	var nearest := INF
	if not is_visible_in_tree(): return nearest
	for part in silhouette_parts:
		if not part.is_visible_in_tree() or part.mesh == null: continue
		var inverse := part.global_transform.affine_inverse()
		var local_origin := inverse * origin
		var local_direction := (inverse.basis * direction).normalized()
		if part.mesh.get_aabb().intersects_ray(local_origin, local_direction) == null: continue
		if not pick_meshes.has(part.mesh):
			pick_meshes[part.mesh] = part.mesh.generate_triangle_mesh()
		var geometry: TriangleMesh = pick_meshes[part.mesh]
		var hit := geometry.intersect_ray(local_origin, local_direction)
		if not hit.is_empty():
			nearest = minf(nearest, origin.distance_to(part.global_transform * hit.position))
	return nearest

func bend_joint(path: String, target: float, delta: float, reset: bool) -> void:
	var spring: RefCounted = joint_springs[path]
	joints[path].rotation.x = spring.reset(target) if reset else spring.step(target, delta)

func sync(worker: Dictionary, delta: float, selected: bool, camera: Camera3D = null, navigation = null) -> void:
	set_appearance(int(worker.get("appearance", identity % 3)), int(worker.get("cloth_color", identity % 5)))
	var adult := Citizens.is_adult(worker)
	var size := 1.0 if adult else 0.64
	body.scale = Vector3.ONE * size
	var offset := Vector3((identity % 3 - 1) * 0.14, 0, (identity % 3 - 1) * 0.12)
	var target: Vector3 = worker.position + offset
	var movement: Vector3 = worker.position - previous_position
	var teleport := not has_position or movement.length() > 3.0
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
		var travelled := before.distance_to(position)
		var walking := travelled > 0.0001
		walk_blend = move_toward(walk_blend, 1.0 if walking else 0.0, delta * 9.0)
		phase += travelled * TAU / (1.2 * size)
	if navigation != null and worker.cell.y == 0:
		var floor_cell := Vector3i(roundi(position.x / navigation.CELL_SIZE), 0, roundi(position.z / navigation.CELL_SIZE))
		# Correct the smoothed visual and personal spacing offset to the actual slope.
		if navigation.terrain_shapes.has(floor_cell):
			position.y = navigation.surface_height(floor_cell, position)
	if not is_instance_valid(camera):
		camera = get_viewport().get_camera_3d()
	update_facing(camera)
	var stride := sin(phase) * walk_blend
	var left_leg := body.get_node("LeftLeg") as Node3D
	var right_leg := body.get_node("RightLeg") as Node3D
	var left_arm := body.get_node("LeftArm") as Node3D
	var right_arm := body.get_node("RightArm") as Node3D
	left_leg.rotation = Vector3(stride * 0.65, 0, -0.025 + stride * 0.12)
	right_leg.rotation = Vector3(-stride * 0.65, 0, 0.025 - stride * 0.12)
	left_leg.position.y = 0.29 + maxf(0.0, stride) * 0.015
	right_leg.position.y = 0.29 + maxf(0.0, -stride) * 0.015
	left_arm.rotation = Vector3(-stride * 0.40, 0, -0.16 - stride * 0.28)
	right_arm.rotation = Vector3(stride * 0.40, 0, 0.16 - stride * 0.28)
	body.position.y = (1.0 - cos(phase * 2.0)) * 0.018 * walk_blend * size
	body.rotation.z = stride * 0.025
	# Knees fold back as the foot lifts; elbows bend forward with a soft delayed response.
	bend_joint("LeftLeg/Knee", -(0.06 + maxf(0.0, sin(phase + 0.55)) * 1.05) * walk_blend, delta, teleport)
	bend_joint("RightLeg/Knee", -(0.06 + maxf(0.0, -sin(phase + 0.55)) * 1.05) * walk_blend, delta, teleport)
	var left_elbow := 0.12 + maxf(0.0, -stride) * 0.75
	var right_elbow := 0.12 + maxf(0.0, stride) * 0.75
	if not worker.cargo.is_empty() or worker.has("plant_plan_id"):
		left_arm.rotation = Vector3(0.5, 0, -0.12)
		right_arm.rotation = Vector3(0.5, 0, 0.12)
		left_elbow = 1.0
		right_elbow = 1.0
	if worker.status == "building" or worker.status == "cutting timber":
		work_phase += delta * 8.0
		right_arm.rotation.x = 0.5 + sin(work_phase) * 0.45
		right_elbow = 0.65 + (1.0 - cos(work_phase)) * 0.4
	bend_joint("LeftArm/Elbow", left_elbow, delta, teleport)
	bend_joint("RightArm/Elbow", right_elbow, delta, teleport)
	if last_cargo != worker.cargo:
		if is_instance_valid(cargo):
			cargo.free()
		last_cargo = worker.cargo
		if not last_cargo.is_empty():
			cargo = Assets.create(CARGO_ASSETS[last_cargo])
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
