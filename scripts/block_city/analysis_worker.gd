extends RefCounted
const Model=preload("res://scripts/block_city/model.gd")
## Only value data crosses the worker boundary; never touch scene nodes/resources.
static func calculate(config: Dictionary,state: Dictionary,paths: Dictionary,revision: int) -> Dictionary:
	var model=Model.new("",config)
	model.restore(state)
	model.cached_cable_paths=paths
	var supply: Array=[]
	for underground in [false,true]:
		var cards: Array=model.basement_queue if underground else model.queue
		cards.pop_back()
		var card: Dictionary=model.choose_card(underground)
		cards.append(card); supply.append(card)
	return {"supply":supply,"revision":revision,"colors":model.connection_colors(),"reached":model.accessible_rooms(),"powered":model.powered_cells()}
