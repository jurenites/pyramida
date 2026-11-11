extends SceneTree
const Worker = preload("res://scripts/settlement/worker_view.gd")
const Navigation = preload("res://scripts/settlement/navigation.gd")
const Indoor = preload("res://scripts/settlement/indoor_stair_contact.gd")
var failures := []
var checks := 0
var worst := 0.0
var sole_cache := {}
func _initialize() -> void: call_deferred("run")
func run() -> void:
	for yaw in 4:
		for variant in 3:
			for descending in [false,true]:
				var nav := Navigation.new()
				var center := Vector3(0.5,0,0.5)
				var turn := Basis(Vector3.UP,-yaw*PI/2)
				var lower := Vector3i((center+turn*Vector3(-0.5,0,-1.5)).round())
				var upper := Vector3i((center+turn*Vector3(0.5,2,-1.5)).round())
				var path: Array = [Vector3(lower)+Vector3.UP*0.16]
				for p: Vector3 in Indoor.Geometry.route(): path.append(center+turn*(p*2))
				path.append(Vector3(upper)+Vector3.UP*0.16)
				nav.room_nodes={lower:1,upper:2}; nav.room_heights={lower:0.16,upper:2.16}
				nav.rebuild({lower:true,upper:true},{})
				preload("res://scripts/settlement/room_navigation.gd").add_path(nav,lower,upper,path)
				Indoor.register(nav,lower,upper,center,-yaw*PI/2,path)
				var geometry: Dictionary=nav.room_stair_contacts[lower][upper]
				if descending: path.reverse()
				var worker := {"position":path[0],"cell":upper if descending else lower,"route":[lower if descending else upper],"route_index":0,"status":"walking","cargo":"log" if variant==0 else "","appearance":1 if variant==1 else 0,"cloth_color":variant,"life_stage":"child" if variant==2 else "adult"}
				var actor:=Worker.new(); root.add_child(actor); actor.setup(1)
				var camera:=Camera3D.new(); root.add_child(camera)
				var next := 1
				for frame in 2000:
					worker.position=worker.position.move_toward(path[next],0.018)
					actor.sync(worker,1.0/60.0,false,camera,nav)
					if frame%3==0:
						for side in [-1,1]:
							var contact: Dictionary=actor.foot_contact.contacts[side]
							if not contact.stance: continue
							var knee:=8 if side<0 else 10
							var part: MeshInstance3D=actor.body.get_node("Surface")
							var pose: Transform3D=actor.skeleton.get_bone_global_pose(knee)*part.skin.get_bind_pose(knee)
							var gap:=INF
							for vertex: Vector3 in soles(part.mesh,knee):
								var p: Vector3=geometry.transform.affine_inverse()*(part.global_transform*(pose*vertex))
								for trim: AABB in geometry.trim:
									if trim.grow(-0.001).has_point(p) and failures.size()<12: failures.append("Foot intersects tread edge: yaw %d body %d down %s frame %d"%[yaw,variant,descending,frame])
								for box: AABB in geometry.boxes:
									if absf(box.end.y-contact.point.y)>0.001: continue
									if p.x>=box.position.x and p.x<=box.end.x and p.z>=box.position.z and p.z<=box.end.z: gap=minf(gap,p.y-box.end.y)
							checks+=1; worst=maxf(worst,absf(gap-0.003))
							if absf(gap-0.003)>0.012 and failures.size()<12: failures.append("yaw %d body %d down %s frame %d side %d gap %.4f"%[yaw,variant,descending,frame,side,gap])
						if worker.cargo=="log":
							for side in [-1,1]:
								var grip: Vector3=Worker.LogHold.LOG_MESH_CENTRE+Worker.LogHold.grip_offset(actor.body.scale.x)*Vector3(side,1,1)
								if actor.cargo.to_local(actor.hand_position(side)).distance_to(grip)>0.001 and failures.size()<12: failures.append("Resized hand lost log grip")
							if not actor.cargo.global_basis.get_scale().is_equal_approx(Vector3.ONE) and failures.size()<12: failures.append("Carried log changed size")
					if frame==120:
						var pose: Transform3D=actor.body.transform
						var knee: Quaternion=actor.body.get_node("LeftLeg/Knee").quaternion
						actor.sync(worker,0,false,camera,nav)
						if pose!=actor.body.transform or knee!=actor.body.get_node("LeftLeg/Knee").quaternion: failures.append("Pause moved indoor contacts")
					if worker.position.distance_to(path[next])<0.0001:
						next+=1
						if next==path.size(): break
				# Settle on the destination floor after the route has completed.
				worker.cell=lower if descending else upper; worker.route=[]
				for frame in 30: actor.sync(worker,1.0/60.0,false,camera,nav)
				if not is_finite(actor.body.position.y): failures.append("Arrival produced invalid pose")
				actor.free(); camera.free()
	print("Indoor contact checks %d; maximum error %.5f m"%[checks,worst])
	for failure in failures: printerr(failure)
	quit(0 if failures.is_empty() else 1)
func soles(mesh: Mesh,bone: int) -> Array:
	var key:=str(mesh.get_instance_id())+":"+str(bone)
	if not sole_cache.has(key):
		var result:=[]
		for surface in mesh.get_surface_count():
			var arrays:=mesh.surface_get_arrays(surface)
			for i in arrays[Mesh.ARRAY_VERTEX].size():
				var p: Vector3=arrays[Mesh.ARRAY_VERTEX][i]
				if p.y<0.061 and arrays[Mesh.ARRAY_BONES][i*4]==bone and p not in result: result.append(p)
		sole_cache[key]=result
	return sole_cache[key]
