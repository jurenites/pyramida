extends SceneTree
const Fence=preload("res://scripts/settlement/terrace_railing.gd")
var failures:=0
func check(ok: bool, message: String) -> void:
	if not ok: failures+=1; printerr("FAIL: "+message)
func _initialize() -> void:
	var diagonal:=false; var varied:=false; var joined:=false; var separate:=false
	for seed_ in 100:
		for length in [0.25,0.5,1.0,2.0,3.75]:
			var a:=Vector3.ZERO; var b:=Vector3(length,0,0)
			var parts:=Fence.parts(a,b,seed_)
			var count:=ceili(length/Fence.SPACING)
			if count>1:
				if parts.size()<count*4: joined=true
				if parts.size()==count*4: separate=true
			check(parts==Fence.parts(a,b,seed_),"Fence layout survives regeneration")
			for part in parts:
				if part.name=="TerraceFenceDiagonal": diagonal=true
				if part.name=="TerraceFenceTop" and absf(part.a.z-part.b.z)>0.01: varied=true
				for point: Vector3 in [part.a,part.b]:
					check(point.x>=Fence.WIDTH/2 and point.x<=length-Fence.WIDTH/2,"Stock stays clear of gate ends")
					check(absf(point.z)+Fence.WIDTH/2<Fence.CLEARANCE,"Navigation includes angled timber width")
				check(part.a.distance_to(part.b)>0.001,"No collapsed fence members")
	check(diagonal and varied,"Seeds include angled panels and worn diagonal lower members")
	check(joined and separate,"Panels include shared posts and separate end joints")
	print("PASS: 500 seeded fence runs retain gate and walking clearance" if failures==0 else "FAIL: fence geometry")
	quit(int(failures>0))
