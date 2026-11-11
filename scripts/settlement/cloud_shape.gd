extends RefCounted
## Smooth unions of ellipsoids, meshed once and shared by whole cloud groups.
const STEP := 0.14
const LOW := Vector3(-2.24,-1.40,-1.68)
const SIZE := Vector3i(33,21,25)
const CORNERS := [Vector3i(0,0,0),Vector3i(1,0,0),Vector3i(1,1,0),Vector3i(0,1,0),Vector3i(0,0,1),Vector3i(1,0,1),Vector3i(1,1,1),Vector3i(0,1,1)]
const TETS := [[0,5,1,6],[0,1,2,6],[0,2,3,6],[0,3,7,6],[0,7,4,6],[0,4,5,6]]
const EDGES := [[0,1],[1,2],[2,0],[0,3],[1,3],[2,3]]
const FACES := [[],[0,3,2],[0,1,4],[1,4,2,2,4,3],[1,2,5],[0,3,5,0,5,1],[0,2,5,0,5,4],[5,4,3],[3,4,5],[4,5,0,5,2,0],[1,5,0,5,3,0],[5,2,1],[3,4,2,2,4,1],[4,1,0],[2,3,0],[]]
static var cache: Dictionary = {}

static func lobes(kind: int) -> Array:
	# Unequal connected lobes make a bent bank, a long streamer, a fork and
	# a raised cumulus. Every neck is part of the same continuous surface.
	match kind:
		0: return [[Vector3(-1.05,-0.12,-0.12),Vector3(0.72,0.48,0.61)], [Vector3(-0.45,0.12,-0.25),Vector3(0.85,0.68,0.70)], [Vector3(0.32,0.22,0.0),Vector3(0.76,0.74,0.72)], [Vector3(0.92,-0.08,0.43),Vector3(0.66,0.44,0.57)], [Vector3(1.42,-0.20,0.63),Vector3(0.42,0.30,0.36)]]
		1: return [[Vector3(-1.32,-0.17,0.24),Vector3(0.58,0.38,0.43)], [Vector3(-0.68,0.0,0.05),Vector3(0.85,0.56,0.60)], [Vector3(0.10,0.08,-0.15),Vector3(0.79,0.62,0.68)], [Vector3(0.83,-0.06,-0.34),Vector3(0.72,0.43,0.47)], [Vector3(1.40,-0.13,-0.45),Vector3(0.48,0.29,0.32)]]
		2: return [[Vector3(-1.12,-0.05,0),Vector3(0.74,0.48,0.54)], [Vector3(-0.34,0.13,0),Vector3(0.87,0.67,0.73)], [Vector3(0.45,0.17,-0.42),Vector3(0.72,0.58,0.57)], [Vector3(0.98,-0.03,-0.78),Vector3(0.57,0.35,0.40)], [Vector3(0.50,-0.02,0.50),Vector3(0.66,0.48,0.59)], [Vector3(1.04,-0.10,0.83),Vector3(0.41,0.30,0.34)]]
		_: return [[Vector3(-0.92,-0.17,0),Vector3(0.83,0.48,0.66)], [Vector3(-0.19,0.17,-0.12),Vector3(0.77,0.76,0.79)], [Vector3(0.36,0.47,-0.07),Vector3(0.55,0.66,0.58)], [Vector3(0.62,-0.08,0.23),Vector3(0.81,0.51,0.64)], [Vector3(1.22,-0.20,0.44),Vector3(0.50,0.32,0.42)]]

static func field(point: Vector3, parts: Array) -> float:
	var result := 10.0
	for part in parts:
		var radius: Vector3 = part[1]
		var distance: float = ((point-part[0])/radius).length() - 1.0
		distance *= minf(radius.x,minf(radius.y,radius.z))
		var blend := clampf(0.5 + 0.5*(distance-result)/0.24,0,1)
		result = lerpf(distance,result,blend) - 0.24*blend*(1-blend)
	return result

static func index(p: Vector3i) -> int:
	return (p.z*SIZE.y+p.y)*SIZE.x+p.x

static func mesh(kind: int) -> ArrayMesh:
	if cache.has(kind): return cache[kind]
	var parts := lobes(kind)
	var values := PackedFloat32Array(); values.resize(SIZE.x*SIZE.y*SIZE.z)
	var gradients := PackedVector3Array(); gradients.resize(values.size())
	for z in SIZE.z:
		for y in SIZE.y:
			for x in SIZE.x:
				var p := Vector3i(x,y,z)
				values[index(p)] = field(LOW+Vector3(p)*STEP,parts)
	for z in range(1,SIZE.z-1):
		for y in range(1,SIZE.y-1):
			for x in range(1,SIZE.x-1):
				var p := Vector3i(x,y,z)
				gradients[index(p)] = Vector3(values[index(p+Vector3i.RIGHT)]-values[index(p+Vector3i.LEFT)],values[index(p+Vector3i.UP)]-values[index(p+Vector3i.DOWN)],values[index(p+Vector3i.BACK)]-values[index(p+Vector3i.FORWARD)]).normalized()
	var surface := SurfaceTool.new(); surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z in range(SIZE.z-1):
		for y in range(SIZE.y-1):
			for x in range(SIZE.x-1):
				var origin := Vector3i(x,y,z)
				var ids: Array[int] = []
				var positions: Array[Vector3] = []
				var inside := 0
				for corner in CORNERS:
					var p: Vector3i = origin+corner
					ids.append(index(p)); positions.append(LOW+Vector3(p)*STEP)
					if values[index(p)] < 0: inside += 1
				if inside == 0 or inside == 8: continue
				for tet in TETS:
					var mask := 0
					for i in 4:
						if values[ids[tet[i]]] < 0: mask |= 1 << i
					var faces: Array = FACES[mask]
					for start in range(0,faces.size(),3):
						var vertices: Array[Vector3] = []; var normals: Array[Vector3] = []
						for i in 3:
							var edge: Array = EDGES[faces[start+i]]
							var a: int = tet[edge[0]]; var b: int = tet[edge[1]]
							var t := values[ids[a]]/(values[ids[a]]-values[ids[b]])
							vertices.append(positions[a].lerp(positions[b],t))
							normals.append(gradients[ids[a]].lerp(gradients[ids[b]],t).normalized())
						var order := [0,1,2]
						if (vertices[1]-vertices[0]).cross(vertices[2]-vertices[0]).dot(normals[0]+normals[1]+normals[2]) > 0: order = [0,2,1]
						for i in order:
							surface.set_normal(normals[i]); surface.add_vertex(vertices[i])
	surface.index()
	cache[kind] = surface.commit()
	return cache[kind]
