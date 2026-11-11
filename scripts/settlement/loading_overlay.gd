extends CanvasLayer
## Temporary modal feedback. The moving bar indicates work, not a guessed ETA.
const Tokens = preload("res://scripts/ui_visual_tokens.gd")
var root: Control
var status: Label
var bar: ProgressBar

func _ready() -> void:
	layer = 90
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var backdrop := ColorRect.new()
	backdrop.color = Color("fef1cf")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(backdrop)
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(centre)
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 280 * Tokens.POINT
	column.add_theme_constant_override("separation", 12 * Tokens.GAP_UNIT)
	centre.add_child(column)
	status = Label.new()
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.add_theme_font_size_override("font_size", Tokens.UI_FONT_SIZE)
	status.add_theme_color_override("font_color", Color("64452f"))
	column.add_child(status)
	bar = ProgressBar.new()
	bar.custom_minimum_size.y = 20 * Tokens.POINT
	bar.show_percentage = false
	bar.indeterminate = true
	var background := StyleBoxFlat.new()
	background.bg_color = Color("fef1cf")
	background.border_color = Color("64452f")
	background.set_border_width_all(int(Tokens.LINE_WIDTH))
	bar.add_theme_stylebox_override("background", background)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("9c4f2f")
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		fill.set_expand_margin(side, -Tokens.LINE_WIDTH)
	bar.add_theme_stylebox_override("fill", fill)
	column.add_child(bar)
	hide()

func show_stage(text: String) -> void:
	status.text = text
	show()

func _input(_event: InputEvent) -> void:
	if visible:
		get_viewport().set_input_as_handled()
