extends ScrollContainer
const Card=preload("res://scripts/block_city/shape_card.gd")
const UI=preload("res://scripts/ui_visual_tokens.gd")
signal chosen(shape_id: String)
var grid: GridContainer
var cards: Dictionary={}
func setup(model) -> void:
	horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	grid=GridContainer.new(); grid.columns=2
	grid.add_theme_constant_override("h_separation",4*UI.GAP_UNIT)
	grid.add_theme_constant_override("v_separation",4*UI.GAP_UNIT)
	add_child(grid)
	for shape in model.config.shapes:
		if shape.get("palette_hidden",false): continue
		var card:=Card.new()
		card.custom_minimum_size=Vector2(80,72)*UI.POINT
		card.palette=true
		card.cells=model.oriented({"shape":shape.id}).cells
		card.role=model.room_role({"shape":shape.id})
		var extent:=Vector3i.ZERO
		for cell in card.cells: extent=extent.max(cell+Vector3i.ONE)
		card.tooltip_text=("Hall" if card.role=="hall" else ("Stairs" if card.role=="stairs" else ("Elevator" if card.role=="elevator" else "Room")))+" · %d×%d×%d" % [extent.x,extent.z,extent.y]
		if card.role=="pole": card.tooltip_text="Pole · ½ height · 3 terminals"
		if shape.id=="flat_l": card.tooltip_text="Room · L · M to mirror"
		if shape.id=="flat_l_mirror": card.tooltip_text="Room · mirrored L"
		grid.add_child(card); card.mouse_filter=Control.MOUSE_FILTER_STOP
		card.gui_input.connect(func(event):
			if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT: chosen.emit(str(shape.id))
		)
		cards[shape.id]=card
func fit_height(height: float) -> float:
	grid.columns=3 if height<190*UI.POINT else 2
	var rows:=ceili(float(cards.size())/float(grid.columns))
	var card_height:=clampf(floorf((height-maxi(0,rows-1)*4*UI.GAP_UNIT)/maxi(1,rows)),32*UI.POINT,72*UI.POINT)
	var card_width:=clampf(card_height*1.11,48*UI.POINT,80*UI.POINT)
	for card in cards.values():
		card.custom_minimum_size=Vector2(card_width,card_height)
		card.queue_redraw()
	return card_width*grid.columns+(grid.columns-1)*4*UI.GAP_UNIT+4*UI.GAP_UNIT
func refresh(model, selected: String, underground: bool, holding := true) -> void:
	for id in cards:
		cards[id].tint=model.tint({"shape":id,"color":model.current(underground).color})
		var active: String=model.current(underground).shape if selected.is_empty() else selected
		if id=="flat_l": cards[id].cells=model.oriented({"shape":"flat_l_mirror" if active=="flat_l_mirror" else "flat_l"}).cells
		if active=="flat_l_mirror": active="flat_l"
		cards[id].selected=holding and id==active
		cards[id].queue_redraw()
func shape_at(screen: Vector2) -> String:
	if not get_global_rect().has_point(screen): return ""
	for id in cards:
		if cards[id].get_global_rect().has_point(screen): return id
	return ""
