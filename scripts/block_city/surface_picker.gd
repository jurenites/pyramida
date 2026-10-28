extends RefCounted
## Logical tile faces, nearest visible hit first; cutaway roofs never catch the ray.
static func cast(model, origin: Vector3, direction: Vector3, mode := 0, level := 100, underground := false, excluded: Array = [], ground := false) -> Dictionary:
	var result: Dictionary={}; var nearest:=INF
	var occ: Dictionary=model.occupied()
	for room in model.rooms:
		if excluded.has(int(room.id)): continue
		var role: String=model.room_role(room)
		if role=="pole":
			var base: Vector3i=model.vec(room.cells[0])
			if base.y>level or underground: continue
			var bounds:=AABB(Vector3(base)+Vector3(0.40,0,0.40),Vector3(0.20,2.40,0.20))
			var point=bounds.intersects_ray(origin,direction)
			if point!=null and origin.distance_squared_to(point)<nearest:
				nearest=origin.distance_squared_to(point)
				result={"id":int(room.id),"cell":base,"normal":Vector3i.UP,"point":point,"surface":"equipment"}
			continue
		for raw in room.cells:
			var cell: Vector3i=model.vec(raw)
			if cell.y>level or (cell.y<0)!=underground: continue
			var faces: Array=[]
			for normal in model.DIRECTIONS:
				# Internal seams are not surfaces; roofless halls expose their floor.
				if occ.has(cell+normal) or (mode>0 and role=="hall"): continue
				faces.append({"normal":normal,"surface":"wall","height":0.28 if mode==2 else 1.0})
			var top:=mode==0
			if not top or not occ.has(cell+Vector3i.UP) or cell.y==level:
				faces.append({"normal":Vector3i.UP,"surface":"roof" if top else "floor","height":1.0 if top else 0.08})
			for face in faces:
				var normal: Vector3i=face.normal
				var center:=Vector3(cell)+Vector3.ONE*0.5+Vector3(normal)*0.5
				if normal==Vector3i.UP: center.y=cell.y+face.height
				# Interior floors are visible from above; only front-facing outer walls.
				if direction.dot(Vector3(normal))>=-0.00001: continue
				var point=Plane(Vector3(normal),center).intersects_ray(origin,direction)
				if point==null: continue
				var local: Vector3=point-Vector3(cell)
				if local.x < -0.0001 or local.x>1.0001 or local.z < -0.0001 or local.z>1.0001 or local.y < -0.0001 or local.y>float(face.height)+0.0001: continue
				var distance:=origin.distance_squared_to(point)
				if distance<nearest:
					nearest=distance; result={"id":int(room.id),"cell":cell,"normal":normal,"point":point,"surface":face.surface}
	if ground:
		var height: float=-float(model.rules().bedrock) if underground else 0.0
		var point=Plane(Vector3.UP,height).intersects_ray(origin,direction)
		if point!=null and origin.distance_squared_to(point)<nearest:
			var cell:=Vector3i(floori(point.x),int(height),floori(point.z))
			if model.owns_cell(cell) and not occ.has(cell): result={"id":-1,"cell":cell,"normal":Vector3i.UP,"point":point,"surface":"ground"}
	return result
