extends SceneTree
const Rig = preload("res://scripts/settlement/citizen_rig.gd")
var Character: PackedScene = preload("res://data/settlement/reference_man.tscn")
var failures: Array[String] = []
func check(ok: bool, message: String) -> void:
	if not ok and message not in failures: failures.append(message)
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty(): Character = load("res://data/settlement/reference_%s.tscn" % args[0])
	call_deferred("run")
func run() -> void:
	var actor := Character.instantiate()
	root.add_child(actor)
	var part: MeshInstance3D = actor.get_node("Surface")
	var skeleton: Skeleton3D = actor.get_node("Skeleton3D")
	var shorts: MeshInstance3D = actor.get_node("Shorts")
	check(shorts.mesh != part.mesh and shorts.skin == part.skin, "Shorts are an independent mesh on the same skeleton")
	var dressed: Mesh = part.mesh
	actor.set_shorts_visible(false)
	check(not shorts.visible and part.mesh != dressed, "Removing shorts restores the full body")
	var triangles := part.mesh.get_faces().size() / 3
	for accessory: MeshInstance3D in actor.find_children("*", "MeshInstance3D", true, false):
		if accessory != part: triangles += accessory.mesh.get_faces().size() / 3
	if actor.has_node("Hair"):
		var hair: MeshInstance3D = actor.get_node("Hair")
		check(hair.skin == part.skin, "Hair follows the same posed skeleton")
		var hair_arrays := hair.mesh.surface_get_arrays(0)
		for slot in hair_arrays[Mesh.ARRAY_WEIGHTS].size():
			if hair_arrays[Mesh.ARRAY_WEIGHTS][slot] > 0:
				check(hair_arrays[Mesh.ARRAY_BONES][slot] == 2, "Hair is attached to the animated head")
	if actor.has_node("Top"): check(not actor.get_node("Top").visible, "Removing the outfit also removes the separate top")
	check(triangles < 1000, "Complete body, clothing and hair stay below 1000 triangles")
	actor.set_shorts_visible(true)
	check(shorts.visible and part.mesh == dressed, "Dressing masks covered skin without deleting the editable body")
	for mesh: Mesh in [part.mesh, shorts.mesh, actor.get_meta("unclothed_mesh")]:
		var arrays := mesh.surface_get_arrays(0)
		for index in arrays[Mesh.ARRAY_VERTEX].size():
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS].slice(index * 4, index * 4 + 4)
			var total := 0.0
			for weight in weights: total += weight
			check(absf(total - 1) < 0.0001, "All skin weights stay normalized")
	var planted_positions := []
	var body_heights := []
	var head_angles := []
	var torso_angles := []
	var chest_heights := []
	var head_heights := []
	var elbow_angles := [[], []]
	for frame in 60:
		actor.pose(frame / 60.0, true, actor.Gait.cycle_seconds / 60.0)
		await process_frame
		for side_index in 2:
			var shoulder_bone := 3 + side_index * 2
			var elbow_bone := shoulder_bone + 1
			var side := -1.0 if side_index == 0 else 1.0
			var shoulder := skeleton.get_bone_global_pose(shoulder_bone).origin
			var elbow := skeleton.get_bone_global_pose(elbow_bone).origin
			var hand := skeleton.get_bone_global_pose(elbow_bone) * part.skin.get_bind_pose(elbow_bone) * (part.skin.get_bind_pose(elbow_bone).inverse().origin + Vector3(side * 0.094, -0.084, 0))
			elbow_angles[side_index].append((elbow - shoulder).angle_to(hand - elbow))
		chest_heights.append(skeleton.get_bone_global_pose(1).origin.y)
		head_heights.append(skeleton.get_bone_global_pose(2).origin.y)
		body_heights.append(actor.position.y)
		head_angles.append(actor.get_node("Head").rotation.x)
		torso_angles.append(skeleton.get_bone_pose_rotation(1).get_euler().y)
		check(actor.Gait.planted(frame / 60.0) or actor.Gait.planted(frame / 60.0 + 0.5), "Normal walking always has a support leg")
		if actor.Gait.planted(frame / 60.0):
			var foot: Vector3 = actor.transform * (skeleton.get_bone_global_pose(8) * part.skin.get_bind_pose(8) * Vector3(part.skin.get_bind_pose(8).inverse().origin.x, 0.008, 0))
			planted_positions.append(foot.z - frame / 60.0 * actor.Gait.stride_length * actor.scale.x)
		var body_faces := Rig.posed_faces(part, skeleton)
		var cloth_faces := Rig.posed_faces(shorts, skeleton)
		if actor.has_node("Top"): cloth_faces.append_array(Rig.posed_faces(actor.get_node("Top"), skeleton))
		check(not crosses(body_faces, cloth_faces) and not crosses(cloth_faces, body_faces), "Clothing does not intersect exposed skin during the walk")
		var floor_ := INF
		for vertex in body_faces:
			floor_ = minf(floor_, (actor.transform * vertex).y)
		check(floor_ >= -0.012, "No animated body or foot penetrates the floor")
		check(floor_ < 0.01, "At least one foot stays grounded throughout the walk")
	check(float(planted_positions.max()) - float(planted_positions.min()) < 0.002, "Planted leg does not slide as the character travels")
	check(float(body_heights.max()) - float(body_heights.min()) < 0.025, "Root settles subtly instead of bouncing or floating")
	check(float(head_angles.max()) - float(head_angles.min()) > 0.015, "Head has subtle secondary motion")
	check(float(torso_angles.max()) - float(torso_angles.min()) > 0.06, "Torso turns with the shoulder swing")
	for angles: Array in elbow_angles:
		check(float(angles.max()) > 0.7 and float(angles.max()) - float(angles.min()) > 0.4, "Both forearms visibly flex instead of twisting around their length")
	check(float(chest_heights.max()) - float(chest_heights.min()) > 0.025, "Torso visibly rises and falls through the spine")
	check(float(head_heights.max()) - float(head_heights.min()) > 0.03, "Head follows the step rise and fall")
	actor.pose(0.74)
	await process_frame
	check(skeleton.get_bone_global_pose(8).origin.y < skeleton.get_bone_global_pose(7).origin.y, "Normal stride keeps the lifted knee below its hip")
	actor.pose(0.0, false)
	await process_frame
	var idle_body := Rig.posed_faces(part, skeleton)
	var idle_shorts := Rig.posed_faces(shorts, skeleton)
	if actor.has_node("Top"): idle_shorts.append_array(Rig.posed_faces(actor.get_node("Top"), skeleton))
	check(not crosses(idle_body, idle_shorts) and not crosses(idle_shorts, idle_body), "Standing skin clears the separate clothing")
	check(is_zero_approx(actor.get_node("LeftLeg").rotation.x), "Standing returns to the rest pose")
	check(skeleton.get_bone_pose_position(1).is_equal_approx(skeleton.get_bone_rest(1).origin), "Standing settles the torso to its rest height")
	check(skeleton.get_bone_pose_position(2).is_equal_approx(skeleton.get_bone_rest(2).origin), "Standing settles the head to its shortened rest height")
	actor.free()
	for failure in failures: printerr("FAIL: " + failure)
	if failures.is_empty(): print("PASS: low-poly character, separate clothing, skin clearance and sixty grounded walk poses")
	quit(int(not failures.is_empty()))

func crosses(edges: PackedVector3Array, target: PackedVector3Array) -> bool:
	var triangles := TriangleMesh.new()
	triangles.create_from_faces(target)
	for first in range(0, edges.size(), 3):
		for corner in 3:
			var a := edges[first + corner]
			var b := edges[first + (corner + 1) % 3]
			var length_ := a.distance_to(b)
			if length_ < 0.0001: continue
			var direction := (b - a) / length_
			var hit := triangles.intersect_ray(a + direction * 0.00001, direction)
			if not hit.is_empty() and a.distance_to(hit.position) < length_ - 0.00001:
				return true
	return false
