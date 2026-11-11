extends HBoxContainer
## One compact material line shared by the menu and selected world buildings.
const Tokens = preload("res://scripts/ui_visual_tokens.gd")
const Icon = preload("res://scripts/settlement/build_icon.gd")
const Catalog = preload("res://data/settlement/catalog.gd")
const Economy = preload("res://scripts/settlement/economy.gd")
const Reviewed = preload("res://scripts/settlement/reviewed_balance.gd")

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 4 * Tokens.GAP_UNIT)

func display(parts: Array, ink := Color("64452f")) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	for part: Dictionary in parts:
		if part.has("icon"):
			var icon := Icon.new()
			icon.kind = part.icon
			icon.ink = ink
			add_child(icon)
		else:
			var text := Label.new()
			text.text = part.text
			text.mouse_filter = Control.MOUSE_FILTER_IGNORE
			text.add_theme_color_override("font_color", ink)
			text.add_theme_font_size_override("font_size", Tokens.UI_FONT_SIZE)
			add_child(text)

static func costs(kind: String) -> Array:
	if kind == "support": return [{"text": "−%d+" % Catalog.recipe(kind).log}, {"icon": "log"}]
	if kind == "rope_bridge": return [{"text": "−"}, {"icon": "plank"}, {"icon": "rope"}, {"text": "By span"}]
	var result: Array = []
	for resource: String in Catalog.recipe(kind):
		result.append({"text": "−%d" % Catalog.recipe(kind)[resource]})
		result.append({"icon": resource})
	if result.is_empty() and kind not in Catalog.SEEDS: result.append({"text": "Free"})
	return result

static func benefit(kind: String) -> Array:
	if Economy.RECIPES.has(kind):
		var recipe: Dictionary = Economy.RECIPES[kind]
		return [{"icon": recipe.input}, {"text": "→"}, {"icon": recipe.output}]
	match kind:
		"house": return [{"text": "+%d" % preload("res://scripts/settlement/house_groups.gd").ROOM_RESIDENTS}, {"icon": "citizens"}, {"text": "place"}]
		"well": return [{"icon":"water"},{"text":"3 droplets"}]
		"hay_field": return [{"text": "+"}, {"icon": "grain"}, {"text": "harvest"}]
		"claypit", "mine", "quarry":
			return [{"text": "+"}, {"icon": "stone" if kind == "quarry" else Economy.EXTRACTORS[kind].output}, {"text": "gather"}]
		"log_shed", "hay_barn", "stone_storage", "brickyard":
			var result: Array = [{"text": "+%d" % Reviewed.capacity(kind)}]
			for resource: String in Economy.STORAGE[kind]: result.append({"icon": resource})
			result.append({"text": "storage"})
			return result
		"support": return [{"text": "Stacking"}]
		"stair": return [{"text": "Floor access"}]
		"road": return [{"text": "+%d%%" % roundi((Economy.Balance.number("road_speed_multiplier") - 1.0) * 100.0)}, {"icon": "citizens"}, {"text": "speed"}]
		"rope_bridge": return [{"text": "Crossing"}]
	return []
