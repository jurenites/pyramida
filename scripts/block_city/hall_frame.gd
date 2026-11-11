extends RefCounted
## Replace hall occupancy atomically; retain uncovered fragments and load-bearing frame cells.
static func replace(model, incoming: Array) -> Dictionary:
	var covered: Dictionary={}; var affected: Array=[]; var issues: Array=[]
	for room in incoming:
		if model.room_role(room) not in ["room","stairs"]: continue
		var owners: Dictionary={}; var frame: Array=room.get("frame_cells",[]).duplicate()
		for hall in model.rooms:
			if incoming.has(hall) or model.room_role(hall)!="hall": continue
			for raw in room.cells:
				if not hall.cells.has(raw): continue
				covered[model.vec(raw)]=true
				if not frame.has(raw): frame.append(raw.duplicate())
				for brace in hall.braces:
					if brace[0]==raw and not room.braces.has(brace): room.braces.append(brace.duplicate(true))
				owners[int(hall.building_id)]=true
				if not affected.has(int(hall.id)): affected.append(int(hall.id))
		if owners.size()>1:
			for raw in room.cells:
				if covered.has(model.vec(raw)): issues.append({"cell":model.vec(raw),"kind":"building"})
		elif owners.size()==1:
			room.building_id=owners.keys()[0]; room.frame_cells=frame
	var result: Array=[]; var remnants: Array=[]; var old_ids: Dictionary={}
	for original in model.rooms:
		if not affected.has(int(original.id)):
			old_ids[int(original.id)]=result.size(); result.append(original); continue
		var remaining: Array=original.cells.filter(func(raw):return not covered.has(model.vec(raw)))
		while not remaining.is_empty():
			var component: Array=[remaining.pop_front()]; var cursor:=0
			while cursor<component.size():
				for direction in model.DIRECTIONS+[Vector3i.UP,Vector3i.DOWN]:
					var raw: Array=model.arr(model.vec(component[cursor])+direction)
					if remaining.has(raw): remaining.erase(raw); component.append(raw)
				cursor+=1
			var part: Dictionary=original.duplicate(true)
			part.cells=component
			part.braces=part.braces.filter(func(brace):return component.has(brace[0]))
			part.access_path=[]
			if not component.has(part.door): part.door=component[0].duplicate()
			# Hall entries are generated from all exposed faces; keep a valid anchor.
			for direction in model.DIRECTIONS:
				if not component.has(model.arr(model.vec(part.door)+direction)): part.normal=model.arr(direction); break
			result.append(part); remnants.append(part)
	for id in result.size(): result[id].id=id
	model.rooms=result
	return {"affected":affected,"remnants":remnants,"old_ids":old_ids,"issues":issues}

static func structure_issues(model) -> Array:
	var result: Array=[]; var occ: Dictionary=model.occupied(); var seen: Dictionary={}
	var ordered: Array=model.rooms.filter(func(room):return not room.cells.is_empty())
	ordered.sort_custom(func(a,b):return absi(int(a.cells[0][1]))<absi(int(b.cells[0][1])))
	for room in ordered:
		var cells: Array=room.cells.map(func(raw):return model.vec(raw))
		var others: Dictionary=occ.duplicate()
		for cell in cells:
			if seen.has(cell): result.append({"cell":cell,"kind":"occupied"})
			seen[cell]=true; others.erase(cell)
		result.append_array(model.fit_issues(cells,others,model.reserved(),cells[0].y<0,model.room_role(room),false))
		var support: Dictionary=model.support(cells,others,cells[0].y<0,model.room_role(room),room.get("frame_cells",[]))
		result.append_array(support.issues); room.braces=support.braces
	return result

static func plan(model,card: Dictionary,x: int,z: int,yaw: int,y: int) -> Dictionary:
	var form: Dictionary=model.oriented(card,yaw); var offset:=Vector3i(x,y,z)
	var cells: Array=form.cells.map(func(cell):return cell+offset)
	var room: Dictionary={"id":model.rooms.size(),"shape":card.shape,"color":card.color,"cells":cells.map(func(cell):return model.arr(cell)),
		"door":model.arr(form.door+offset),"normal":model.arr(form.normal),"braces":[],"access_path":[],
		"building_id":model.Buildings.assign(model,{"shape":card.shape,"cells":cells.map(func(cell):return model.arr(cell))},model.rooms)}
	var trial=model.get_script().new("",model.config)
	trial.owned_plots=model.owned_plots.duplicate(); trial.transformer_cell=model.transformer_cell
	trial.rooms=model.rooms.duplicate(true); trial.rooms.append(room)
	var cut:=replace(trial,[room])
	cut.issues.append_array(structure_issues(trial))
	return {"ok":cut.issues.is_empty(),"cells":cells,"door":form.door+offset,"normal":form.normal,"origin":offset,
		"issues":cut.issues,"braces":room.braces,"reason":"" if cut.issues.is_empty() else "Frame blocked",
		"infill":true,"carve":true,"affected":cut.affected,"remnants":cut.remnants,"proposed_rooms":trial.rooms}
