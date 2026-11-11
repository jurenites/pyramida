extends RefCounted
## One demo cell is a 2 m room module. Coordinates here stay in demo units.
## Local front is -Z; every prefab has a lower entrance in the front-left quarter.
const THICKNESS := 0.05

static func exit_normal(normal: Vector3i, quarter: bool) -> Vector3i:
	return Vector3i(-normal.z,0,normal.x) if quarter else normal

static func parts(quarter := false) -> Array:
	var result: Array=[]
	for i in 5:
		var h: float=(i+1)*0.1
		result.append({"position":Vector3(-0.25,h-THICKNESS/2,-0.45+i*0.1),"size":Vector3(0.42,THICKNESS,0.1)})
		result.append({"position":Vector3(-0.25,h+0.006,-0.49+i*0.1),"size":Vector3(0.42,0.012,0.02),"edge":true})
	if quarter:
		result.append({"position":Vector3(-0.23,0.5-THICKNESS/2,0.23),"size":Vector3(0.46,THICKNESS,0.46),"name":"TurnLanding"})
		for i in 5:
			result.append({"wedge":i,"height":0.6+i*0.1})
		result.append({"position":Vector3(0.25,1-THICKNESS/2,-0.25),"size":Vector3(0.5,THICKNESS,0.5),"name":"UpperPlatform"})
	else:
		result.append({"position":Vector3(0,0.5-THICKNESS/2,0.23),"size":Vector3(0.92,THICKNESS,0.46),"name":"TurnLanding"})
		for i in 5:
			var h: float=0.6+i*0.1
			result.append({"position":Vector3(0.25,h-THICKNESS/2,-0.05-i*0.1),"size":Vector3(0.42,THICKNESS,0.1)})
			result.append({"position":Vector3(0.25,h+0.006,-0.01-i*0.1),"size":Vector3(0.42,0.012,0.02),"edge":true})
	return result

static func wedge_polygon(index: int) -> PackedVector2Array:
	var a: float=PI/2-index*PI/10
	var b: float=a-PI/10
	return PackedVector2Array([Vector2(cos(a),sin(a))*0.04,Vector2(cos(a),sin(a))*0.46,Vector2(cos(b),sin(b))*0.46,Vector2(cos(b),sin(b))*0.04])

static func route(quarter := false) -> Array:
	var points: Array=[]
	for i in 5: points.append(Vector3(-0.25,(i+1)*0.1,-0.45+i*0.1))
	points.append(Vector3(-0.25,0.5,0.25))
	if quarter:
		points.append(Vector3(-0.04,0.5,0.25))
		for i in 5:
			var angle: float=PI/2-(i+0.5)*PI/10
			points.append(Vector3(cos(angle)*0.25,0.6+i*0.1,sin(angle)*0.25))
		points.append(Vector3(0.25,1,-0.25))
		points.append(Vector3(0.5,1,-0.25))
	else:
		points.append(Vector3(0.25,0.5,0.25))
		for i in 5: points.append(Vector3(0.25,0.6+i*0.1,-0.05-i*0.1))
	return points
