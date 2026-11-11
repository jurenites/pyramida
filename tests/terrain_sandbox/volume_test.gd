extends SceneTree
const Terrain = preload("res://scripts/terrain_sandbox/terrain.gd")
var failures: Array[String] = []
var checks := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message); printerr("FAIL: " + message)
func _initialize() -> void: call_deferred("run")
func settle() -> void:
	await process_frame
	await process_frame
	await physics_frame
	await physics_frame
func count_posts(terrain) -> int:
	var count := 0
	for frame in terrain.support_nodes:
		for child in frame.get_children():
			if str(child.name).begins_with("Post"): count += 1
	return count
func run() -> void:
	var terrain := Terrain.new(); root.add_child(terrain)
	await settle()
	check(not terrain.has_method("cut"),"Only construction excavates")
	check(terrain.solid_at(Vector3(0,1,0)),"Closed rock recognizes its interior")
	check(not terrain.place_support(Vector3(0,18,0)),"Floating modules rejected")
	check(not terrain.place_support(Vector3(0,1,0)),"Buried remote excavation rejected")
	var entry := Vector3(0,2,8)
	for z in [8,7,6,5]:
		for y in [2,3]:
			check(terrain.place_support(Vector3(0,y,z)),"Construct adjacent metre modules")
			await settle()
	check(terrain.groups == [0,0,0,0,4,4,4,4],"Tunnel divides into two stable two-metre groups")
	check(not terrain.support_nodes[0].has_node("Deck") and terrain.support_nodes[1].has_node("Deck"),"Vertical pair removes the interior deck")
	check(not terrain.support_nodes[0].has_node("Beam0"),"Vertical pair removes waist-high crossbars")
	check(terrain.support_nodes[2].has_node("Beam0") == false,"Lower passage stays open at group boundary")
	check(terrain.solid_at(entry+Vector3(0.6,0.5,-0.3)),"Excavation stays inside the one-metre footprint")
	var person := CapsuleShape3D.new(); person.radius = 0.24; person.height = 1.4
	var query := PhysicsShapeQueryParameters3D.new(); query.shape = person; query.collision_mask = 3
	var clear := true
	for z in [8.0,7.5,7.0,6.5,6.0,5.5,5.0]:
		query.transform.origin = Vector3(0,2.75,z)
		if not root.world_3d.direct_space_state.intersect_shape(query).is_empty(): clear = false
	check(clear,"Adult capsule clears vertical pairs and separate group boundaries")
	check(not terrain.place_support(entry),"Overlapping modules rejected")
	var saved: Variant = JSON.parse_string(JSON.stringify(terrain.snapshot()))
	var old_groups := terrain.groups.duplicate()
	var old_turns := terrain.plank_turns.duplicate()
	terrain.clear(); check(terrain.restore(saved),"Construction save restores")
	check(terrain.groups == old_groups,"Save restores original bounded group identity")
	check(terrain.plank_turns == old_turns,"Plank orientation persists without rerolling")
	var before := terrain.snapshot()
	check(not terrain.restore({"version":4,"seed":1409,"supports":[[0,2,8,0],[0,2,8,1]]}),"Invalid overlapping save rejected")
	check(terrain.snapshot() == before,"Rejected save leaves existing world intact")
	check(not terrain.restore({"version":3,"seed":1409,"supports":[]}),"Two-metre-bay saves are never silently resized")
	terrain.clear(); await settle()
	for x in [2,3,4,5,6]:
		check(terrain.place_support(Vector3(x,6.6,2)),"Surface metre module placement")
	check(terrain.groups == [0,0,2,2,4],"Long row retains separate pairs")
	check(count_posts(terrain) == 8,"Separate groups share one post at each touching boundary corner")
	check(not terrain.support_nodes[0].has_node("Beam1"),"Internal horizontal seam disappears")
	check(terrain.support_nodes[1].has_node("Beam1") and not terrain.support_nodes[2].has_node("Beam3"),"Existing group owns the coincident boundary beam")
	var original := terrain.supports.duplicate()
	check(terrain.snap_to_existing(Vector3(2.12,6.6,3.02)).is_equal_approx(Vector3(2,6.6,3)),"Near-fitting new module aligns to oldest existing socket")
	check(terrain.snap_to_existing(Vector3(2.3,6.6,3)).is_equal_approx(Vector3(2.3,6.6,3)),"Beyond snap tolerance remains separate")
	check(terrain.supports == original,"Snapping never moves built structures")
	terrain.clear()
	for x in [2,3]:
		for z in [2,3]:
			for y in [6.6,7.6]: check(terrain.place_support(Vector3(x,y,z)),"Fill bounded cube")
	check(terrain.groups.count(0) == 8,"Eight metre modules form one two-metre cube")
	check(count_posts(terrain) == 8,"Cube keeps four outer legs on each vertical metre")
	check(terrain.place_support(Vector3(4,6.6,2)),"Ninth module starts separate structure")
	check(terrain.groups[8] != 0 and count_posts(terrain) == 11,"Full cube retains its own legs and shares its existing corner with new building")
	terrain.undo(); terrain.undo()
	check(terrain.support_nodes[6].has_node("Deck"),"Undo restores exposed deck below removed upper module")
	terrain.clear()
	check(terrain.place_support(Vector3(2.1,6.6,2.3),1),"Fine-positioned module retains one-metre dimensions")
	check(terrain.place_support(Vector3(3.1,6.6,2.3),0),"Exact fine-positioned neighbor joins")
	check(count_posts(terrain) == 4,"Fine-positioned pair shares legs")
	check(terrain.place_support(Vector3(4.2,6.6,2.3),1),"Deliberate gap is allowed")
	check(terrain.groups[2] != terrain.groups[0],"Gapped module keeps separate structure")
	check(is_equal_approx(terrain.support_nodes[0].get_node("Deck").rotation.y,PI/2),"Quarter-turn board direction is independent of structure alignment")
	var posts := terrain.support_nodes[0].get_node("Post0") as MeshInstance3D
	check(posts.mesh.get_aabb().end.y > 1.08,"Exposed piles project above deck")
	var fine := terrain.snapshot(); terrain.clear(); check(terrain.restore(fine),"Fine positioning and chosen board turns round-trip")
	check(terrain.supports[0].is_equal_approx(Vector3(2.1,6.6,2.3)),"Save preserves precise positions")
	terrain.clear()
	for x in [2,3]:
		for z in [2,3]:
			for y in [6.6,7.6]: check(terrain.place_support(Vector3(x,y,z)),"Create older full group")
	var fixed_origins := terrain.supports.duplicate()
	var fixed_signatures: Array = []
	for frame in terrain.support_nodes: fixed_signatures.append(frame.get_meta("join_signature").duplicate(true))
	for x in [4,5]:
		for z in [2,3]:
			for y in [6.6,7.6]: check(terrain.place_support(Vector3(x,y,z)),"Create neighboring full group")
	check(terrain.groups.count(0) == 8 and terrain.groups.count(8) == 8,"Sharing posts never merges group identities")
	check(count_posts(terrain) == 12,"Two full cubes have one log at each shared corner per height")
	var unchanged := true
	for index in 8:
		if terrain.supports[index] != fixed_origins[index] or terrain.support_nodes[index].get_meta("join_signature") != fixed_signatures[index]: unchanged = false
	check(unchanged,"Older group geometry and placement retain priority")
	var joined_save: Variant = JSON.parse_string(JSON.stringify(terrain.snapshot()))
	terrain.clear(); check(terrain.restore(joined_save),"Shared group save restores")
	check(count_posts(terrain) == 12,"Restore reconstructs single-owner posts")
	for index in 8: terrain.undo()
	check(count_posts(terrain) == 8,"Undo newer building leaves older supports intact")
	test_fitting(terrain,Vector3(4.1,6.6,2.1),6,"Ten-centimetre offsets in both directions fit without grid snapping")
	test_fitting(terrain,Vector3(4.2,6.6,2),8,"Twenty-centimetre gap keeps independent posts")
	test_fitting(terrain,Vector3(4,6.7,2),8,"Different floor elevations keep independent posts")
	test_fitting(terrain,Vector3(4,6.6,3),8,"Diagonal corner contact does not remove a bearing")
	terrain.free()
	if failures.is_empty(): print("PASS: %d bounded Support group, clearance, snapping, timber and save checks" % checks)
	quit(int(not failures.is_empty()))

func test_fitting(terrain, later: Vector3, expected: int, message: String) -> void:
	terrain.clear()
	terrain.place_support(Vector3(2,6.6,2)); terrain.place_support(Vector3(3,6.6,2))
	var records: Array = terrain.snapshot().supports
	# Restore also exercises non-grid/height offsets that may come from editors.
	records.append([later.x,later.y,later.z,0,0.0]); records.append([later.x+1,later.y,later.z,1,0.0])
	check(terrain.restore({"version":5,"seed":1409,"supports":records}),"Restore fitting fixture")
	check(count_posts(terrain) == expected,message)
	check(terrain.supports[2].is_equal_approx(later),"Post fitting preserves the new building's requested transform")
	if expected == 6:
		var old_corner: Vector3 = terrain.support_nodes[1].get_meta("join_signature")[2][1]+terrain.supports[1]
		var new_corner: Vector3 = terrain.support_nodes[2].get_meta("join_signature")[2][0]+terrain.supports[2]
		check(old_corner.is_equal_approx(new_corner),"New bearing ends precisely on the older log")
