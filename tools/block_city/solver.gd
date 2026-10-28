extends RefCounted
static func build(model, underground := false) -> bool:
	var best := {}
	var score := -1e9
	for p in model.legal_moves(model.current(underground),underground):
		var value: float = -abs(p.origin.y)*20-p.x*0.1-p.z*0.1
		if value>score: best=p; score=value
	if best.is_empty(): return false
	return model.drop(best.x,best.z,best.yaw,underground)
