extends "res://scripts/block_city/model.gd"
## Shared construction editor coordinates: one cell = exactly 2 × 2 × 2 metres.
func owns_cell(cell: Vector3i, _margin := 0) -> bool:
	return abs(cell.x)<=64 and abs(cell.z)<=64 and cell.y>=0 and cell.y<9
func tint(_card: Dictionary) -> Color: return preload("res://scripts/game_palette.gd").SAND_SURFACE
func land_bounds() -> Rect2i: return Rect2i(-64,-64,129,129)
func street(cell: Vector3i) -> bool: return cell.y==0 and not occupied().has(cell)
func transformer_plan(at: Vector3i) -> Dictionary:
	return {"ok":true,"issues":[],"cells":[at],"origin":at}
func landing(card: Dictionary,x: int,z: int,yaw:=0,underground:=false,target_y:=-100,carve:=false) -> Dictionary:
	if target_y!=-100 and room_role(card)=="stairs":
		var occ:=occupied()
		var cells: Array=oriented(card,yaw).cells.map(func(cell):return cell+Vector3i(x,target_y,z))
		if cells.any(func(cell):return occ.has(cell) and room_role(rooms[occ[cell]])=="hall"):
			return Frame.plan(self,card,x,z,yaw,target_y)
	return super.landing(card,x,z,yaw,underground,target_y,carve)
