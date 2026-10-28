extends SceneTree
const Model=preload("res://scripts/block_city/model.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	for seed_value in range(1,9):
		var m=Model.new()
		var rng:=RandomNumberGenerator.new(); rng.seed=seed_value
		for i in 16:
			var options:Array=m.legal_moves(m.current())
			if options.is_empty(): break
			var p:Dictionary=options[rng.randi_range(0,options.size()-1)]
			assert(m.drop(p.x,p.z,p.yaw))
			var occ:Dictionary=m.occupied()
			var total := 0
			for room in m.rooms:
				total += room.cells.size()
				assert(room.cells.all(func(cell): return cell[1]==room.cells[0][1]))
			assert(occ.size()==total)
			for cell in occ:
				assert(cell.x>=-1 and cell.x<=3 and cell.z>=-1 and cell.z<=3 and cell.y>=0 and cell.y<9)
				if cell.y==0: assert(cell.x>=0 and cell.x<3 and cell.z>=0 and cell.z<3)
	print("PASS: eight yaw-only placement runs preserve occupancy, footprint, overhang and ceiling bounds")
	quit()
