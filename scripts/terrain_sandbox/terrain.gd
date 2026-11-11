extends Node3D
## Construction owns excavation: every cleared volume contains an actual Support.
const Assembly = preload("res://scripts/settlement/support_assembly.gd")
const Landform = preload("res://scripts/terrain_sandbox/landform.gd")
const MAX_SUPPORTS := 128
const BAY := 1.0
const JOIN_SNAP := 0.16
const POST_FIT := 0.15 # Maximum horizontal corner mismatch; independent of placement snapping.
const FINE_STEP := 0.1
const CORNERS := [Vector3(-0.5,0,-0.5),Vector3(0.5,0,-0.5),Vector3(0.5,0,0.5),Vector3(-0.5,0,0.5)]
const SIDES := [Vector3.FORWARD,Vector3.RIGHT,Vector3.BACK,Vector3.LEFT]
const Frame = preload("res://scripts/settlement/structure_frame.gd")
var solid := CSGCombiner3D.new()
var supports: Array[Vector3] = []
var groups: Array[int] = []
var plank_turns: Array[int] = []
var yaws: Array[float] = []
var excavation_nodes: Array[CSGBox3D] = []
var support_nodes: Array[Node3D] = []
var seed_value := 1409
var source_solids: Array[Dictionary] = []

func _ready() -> void:
	solid.name = "Rock"
	solid.use_collision = true
	solid.collision_layer = 1
	add_child(solid)
	var land := CSGMesh3D.new()
	land.name = "Landform"
	land.mesh = Landform.terraces(seed_value)
	solid.add_child(land)
	var ridge := CSGMesh3D.new()
	ridge.name = "WesternRidge"
	ridge.mesh = Landform.ridge(seed_value + 112)
	solid.add_child(ridge)
	var fin := CSGMesh3D.new()
	fin.name = "FracturedFin"
	fin.mesh = Landform.fin(seed_value + 227)
	solid.add_child(fin)
	for piece: CSGMesh3D in [land,ridge,fin]:
		source_solids.append({"bounds":piece.mesh.get_aabb(),"faces":piece.mesh.get_faces()})

func solid_at(point: Vector3) -> bool:
	for index in supports.size():
		var local := Basis(Vector3.UP,yaws[index]).inverse()*(point-supports[index])
		if AABB(Vector3(-0.5,0,-0.5),Vector3.ONE).has_point(local): return false
	# CSG's built-in collision ignores back faces, so an inside-out physics ray
	# cannot distinguish solid interiors. Use parity on the original closed
	# polygon solids, minus the same fixed building volumes used by CSG.
	var direction := Vector3(0.317,1.0,0.193).normalized()
	for source in source_solids:
		if not source.bounds.has_point(point): continue
		var distances: Array[float] = []
		var faces: PackedVector3Array = source.faces
		for index in range(0,faces.size(),3):
			var hit: Variant = Geometry3D.ray_intersects_triangle(point,direction,faces[index],faces[index+1],faces[index+2])
			if hit == null: continue
			var distance := point.distance_squared_to(hit)
			var repeated := false
			for previous in distances:
				if absf(previous-distance)<0.00001: repeated = true; break
			if not repeated: distances.append(distance)
		if distances.size()%2 == 1: return true
	return false

func has_support(origin: Vector3) -> bool:
	for placed: Vector3 in supports:
		if placed.distance_squared_to(origin) < 0.0001: return true
	return false

func can_place_support(origin: Vector3,yaw := 0.0) -> bool:
	if not is_finite(yaw) or absf(yaw)>PI/12+0.00001: return false
	if supports.size() >= MAX_SUPPORTS or not origin.is_finite() or origin.length() > 40: return false
	if origin.y < -1.5 or origin.y > 20: return false
	if not is_equal_approx(origin.x, snappedf(origin.x,FINE_STEP)) or not is_equal_approx(origin.z, snappedf(origin.z,FINE_STEP)): return false
	for index in supports.size():
		if Assembly.overlaps(origin,yaw,supports[index],yaws[index]): return false
	var founded := has_support(origin - Vector3.UP * BAY)
	if not founded:
		founded = true
		for x in [-0.38, 0.38]:
			for z in [-0.38, 0.38]:
				if not solid_at(origin + Basis(Vector3.UP,yaw)*Vector3(x,-0.025,z)): founded = false
	if not founded: return false
	# No placing isolated structures deep inside unexposed rock.
	for direction: Vector3 in [Vector3.RIGHT,Vector3.LEFT,Vector3.FORWARD,Vector3.BACK,Vector3.UP]:
		if has_support(origin + direction * BAY) or not solid_at(origin + Vector3.UP * 0.5 + direction * 0.55): return true
	return false

func place_support(origin: Vector3, turn := -1, yaw := 0.0) -> bool:
	if not can_place_support(origin,yaw): return false
	_add_support(origin,turn,yaw)
	return true

func _add_support(origin: Vector3, turn := -1, yaw := 0.0) -> void:
	# Fixed building footprint, not a configurable tunnel brush or span.
	var excavation := CSGBox3D.new()
	excavation.name = "SupportExcavation%d" % supports.size()
	excavation.size = Vector3.ONE * BAY
	excavation.position = origin + Vector3.UP * 0.5
	excavation.rotation.y=yaw
	excavation.material = Landform.material(Landform.Palette.LIMESTONE_SIDE.darkened(0.18))
	excavation.operation = CSGShape3D.OPERATION_SUBTRACTION
	solid.add_child(excavation)
	var frame := Node3D.new()
	frame.position = origin
	frame.rotation.y=yaw
	add_child(frame)
	var assembly = fitting_assembly()
	groups.append(assembly.group_for(origin,yaw))
	yaws.append(yaw)
	plank_turns.append(default_turn(origin) if turn < 0 else posmod(turn,2))
	supports.append(origin); excavation_nodes.append(excavation); support_nodes.append(frame)
	_sync_decks()

func default_turn(origin: Vector3) -> int:
	return posmod(hash([seed_value,origin]),2)

func snap_to_existing(origin: Vector3) -> Vector3:
	# The oldest building wins equal-distance ties; only the proposal moves.
	var result := origin
	var distance := JOIN_SNAP * JOIN_SNAP
	for placed in supports:
		for side: Vector3 in [Vector3.UP,Vector3.DOWN,Vector3.LEFT,Vector3.RIGHT,Vector3.FORWARD,Vector3.BACK]:
			var socket := placed + side
			var candidate := socket.distance_squared_to(origin)
			if candidate < distance and not has_support(socket):
				distance = candidate; result = socket
	return result

func fitting_assembly():
	var result := Assembly.new()
	for index in supports.size(): result.add(supports[index],yaws[index],groups[index])
	return result

func _sync_decks() -> void:
	var assembly = fitting_assembly()
	var layouts: Array[Dictionary] = assembly.layouts()
	for index in supports.size():
		var layout := layouts[index]
		var signature := [layout.posts,layout.beams,layout.corners,layout.open_top,plank_turns[index]]
		var frame := support_nodes[index]
		if frame.get_meta("join_signature",[]) == signature: continue
		for child in frame.get_children(): child.free()
		frame.set_meta("join_signature",signature.duplicate(true))
		frame.set_meta("support_group",groups[index])
		populate_bay(frame,layout.posts,layout.beams,layout.corners,hash([seed_value,supports[index]]),layout.open_top,plank_turns[index])
		var body := StaticBody3D.new(); body.collision_layer = 2; body.collision_mask = 0
		body.set_meta("support_origin",supports[index]); frame.add_child(body)
		for visual: MeshInstance3D in frame.find_children("*","MeshInstance3D",true,false):
			var shape := CollisionShape3D.new()
			shape.shape = visual.mesh.create_trimesh_shape()
			shape.transform = frame.global_transform.affine_inverse() * visual.global_transform
			body.add_child(shape)

static func populate_bay(root: Node3D, posts: Array, beams: Array, corners: Array, seed_: int, open_top := false, turn := 0) -> void:
	for i in 4:
		# Exposed piles rise above boards, while internal vertical seams stay open.
		if posts[i]: Frame.log_member(root,"Post%d" % i,corners[i],corners[i] + Vector3.UP * (1.0 if open_top else 1.12))
		if beams[i]: Frame.log_member(root,"Beam%d" % i,corners[i] + Vector3.UP * 0.84,corners[(i+1)%4] + Vector3.UP * 0.84)
	if open_top: return
	var deck := Node3D.new(); deck.name = "Deck"; root.add_child(deck)
	deck.rotation.y = turn * PI / 2
	var rng := RandomNumberGenerator.new(); rng.seed = seed_
	var poses: Array[Transform3D] = []
	var bounds := AABB(); var first := true
	for source: Dictionary in Frame.Timber.sources("plank"):
		var box: AABB = source.pose * source.mesh.get_aabb()
		bounds = box if first else bounds.merge(box); first = false
	# Rigid stock boards, staggered laps and visible gaps rather than a slab.
	for row in 3:
		var stagger := rng.randf_range(-0.045,0.045)
		for end in 2:
			var basis := Basis.from_euler(Vector3(rng.randf_range(-0.008,0.008),rng.randf_range(-0.045,0.045),0))
			var at := Vector3((-0.14 if end == 0 else 0.14)+stagger,0.97-end*0.008+rng.randf_range(-0.004,0.004),(row-1)*0.32+rng.randf_range(-0.012,0.012))
			poses.append(Transform3D(basis,at-basis*bounds.get_center()))
	Frame.stock(deck,"Boards","plank",poses)

static func support_model(turn := 0) -> Node3D:
	var result := Node3D.new()
	var corners: Array = []
	for corner: Vector3 in CORNERS: corners.append(corner * 0.76)
	populate_bay(result,[true,true,true,true],[true,true,true,true],corners,0,false,turn)
	return result

func undo() -> void:
	if supports.is_empty(): return
	var excavation: CSGBox3D = excavation_nodes.pop_back()
	solid.remove_child(excavation); excavation.free()
	var frame: Node3D = support_nodes.pop_back(); frame.free()
	supports.pop_back(); groups.pop_back(); plank_turns.pop_back(); yaws.pop_back(); _sync_decks()

func clear() -> void:
	while not supports.is_empty(): undo()

func snapshot() -> Dictionary:
	var records: Array = []
	for index in supports.size():
		var origin := supports[index]
		records.append([origin.x,origin.y,origin.z,plank_turns[index],yaws[index]])
	return {"version":5,"seed":seed_value,"supports":records}

func restore(data: Variant) -> bool:
	if not data is Dictionary or int(data.get("version",0)) not in [4,5] or data.get("seed") != seed_value or not data.get("supports") is Array: return false
	if data.supports.size() > MAX_SUPPORTS: return false
	var validated: Array[Vector3] = []
	var angles: Array[float] = []
	for record: Variant in data.supports:
		if not record is Array or record.size() != (4 if int(data.version)==4 else 5): return false
		for value: Variant in record:
			if not (value is int or value is float) or not is_finite(float(value)): return false
		if float(record[3]) != 0.0 and float(record[3]) != 1.0: return false
		if record.size()==5 and absf(record[4])>PI/12+0.00001: return false
		var origin := Vector3(record[0],record[1],record[2])
		if origin.length() > 40 or origin.y < -1.5 or origin.y > 20: return false
		if not is_equal_approx(origin.x,snappedf(origin.x,FINE_STEP)) or not is_equal_approx(origin.z,snappedf(origin.z,FINE_STEP)): return false
		var yaw := float(record[4]) if record.size()==5 else 0.0
		for index in validated.size():
			if Assembly.overlaps(origin,yaw,validated[index],angles[index]): return false
		validated.append(origin); angles.append(yaw)
	clear()
	for index in validated.size(): _add_support(validated[index],int(data.supports[index][3]),float(data.supports[index][4]) if int(data.version)==5 else 0.0)
	return true
