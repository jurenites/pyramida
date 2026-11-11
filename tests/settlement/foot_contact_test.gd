extends SceneTree
const Worker = preload("res://scripts/settlement/worker_view.gd")
const Navigation = preload("res://scripts/settlement/navigation.gd")
var failures := []
var max_gap := 0.0
var sole_cache := {}
var rung_bounds := {}
var min_gap := INF
var checks := 0
func _initialize() -> void: call_deferred("run")
func run() -> void:
	for direction in 4:
		for variant in [0,1,2]:
			for ladder_rise in [0,1,2]:
				for descending in [false,true]:
					var nav := Navigation.new()
					var turn := Basis(Vector3.UP, -direction*PI/2)
					var lower := Vector3i(turn*Vector3(-2,0,0))
					var upper := Vector3i(turn*Vector3(2,ladder_rise,0))
					var surfaces := {}
					var shapes := {}
					for x in range(-3,4):
						for z in range(-3,4):
							var cell := Vector3i(x,0,z)
							surfaces[cell]=true
							if ladder_rise == 0: shapes[cell]=[(x-0.5)*0.35+1.1,(x+0.5)*0.35+1.1,(x+0.5)*0.35+1.1,(x-0.5)*0.35+1.1]
					surfaces[upper]=true
					nav.rebuild(surfaces, {Vector3i.ZERO:direction} if ladder_rise>0 else {}, {}, shapes)
					# Descending from an indoor landing must still use ladder contact.
					if direction==3 and ladder_rise>0: nav.room_nodes[upper]=1
					var actor := Worker.new(); root.add_child(actor); actor.setup(1)
					var camera := Camera3D.new(); root.add_child(camera)
					var worker := {"cell":upper if descending else lower,"route":[lower if descending else upper],"route_index":0,"cargo":"","status":"walking","appearance":variant%2,"cloth_color":variant,"life_stage":"child" if variant==2 else "adult","position":Vector3.ZERO}
					for frame in 360:
						var x := lerpf(-1.35,1.35,frame/359.0)
						if descending: x=-x
						worker.position=turn*Vector3(x,clampf((x+1)/2,0,1)*ladder_rise if ladder_rise>0 else 0,0)
						if ladder_rise==0: worker.position.y=worker.position.x*0.35+1.1
						actor.sync(worker,1.0/60.0,false,camera,nav)
						for side in [-1,1]:
							var contact: Dictionary=actor.foot_contact.contacts[side]
							if not contact.stance: continue
							var gap := INF
							var knee := 8 if side<0 else 10
							var part: MeshInstance3D=actor.body.get_node("Surface")
							var posed: Transform3D=actor.skeleton.get_bone_global_pose(knee)*part.skin.get_bind_pose(knee)
							for point: Vector3 in soles(part.mesh,knee):
								var world: Vector3=part.global_transform*(posed*point)
								var height: float=world.x*0.35+1.1
								if ladder_rise>0:
									world=turn.inverse()*world
									height=ladder_rise if world.x>=1 else 0
									for box: AABB in ladder_bounds(ladder_rise):
										if absf(box.end.y-contact.point.y)<0.001 and world.x>=box.position.x and world.x<=box.end.x and world.z>=box.position.z and world.z<=box.end.z: height=maxf(height,box.end.y)
								gap=minf(gap,world.y-height)
							max_gap=maxf(max_gap,gap); min_gap=minf(min_gap,gap); checks+=1
							if (not is_finite(gap) or absf(gap-0.003)>0.012) and failures.size()<12: failures.append("direction %d variant %d rise %d descending %s frame %d gap %.4f"%[direction,variant,ladder_rise,descending,frame,gap])
						if frame==180:
							var transform_: Transform3D=actor.body.transform
							var knee_pose: Quaternion=actor.body.get_node("LeftLeg/Knee").quaternion
							actor.sync(worker,0,false,camera,nav)
							if actor.body.transform != transform_ or actor.body.get_node("LeftLeg/Knee").quaternion != knee_pose: failures.append("Pause changed contact")
					actor.free(); camera.free()
	print("Contact checks %d, gap range %.5f..%.5f"%[checks,min_gap,max_gap])
	for failure in failures: printerr(failure)
	quit(0 if failures.is_empty() else 1)

func soles(mesh: Mesh, bone: int) -> Array:
	var key := str(mesh.get_instance_id())+":"+str(bone)
	if not sole_cache.has(key):
		var points := []
		for surface in mesh.get_surface_count():
			var arrays := mesh.surface_get_arrays(surface)
			for i in arrays[Mesh.ARRAY_VERTEX].size():
				var vertex: Vector3=arrays[Mesh.ARRAY_VERTEX][i]
				if vertex.y<0.061 and arrays[Mesh.ARRAY_BONES][i*4]==bone and vertex not in points: points.append(vertex)
		sole_cache[key]=points
	return sole_cache[key]
func ladder_bounds(rise: int) -> Array:
	if not rung_bounds.has(rise):
		var scene: Node3D=load("res://data/settlement/stairs_1m.tscn" if rise==1 else "res://data/settlement/stairs.tscn").instantiate()
		var boxes := []
		for part in scene.get_children():
			if part is MeshInstance3D and part.visible and str(part.name).begins_with("LadderRung"): boxes.append(part.transform*part.mesh.get_aabb())
		rung_bounds[rise]=boxes; scene.free()
	return rung_bounds[rise]
