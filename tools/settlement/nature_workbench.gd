@tool
extends Node3D
## Open NatureGenerator.tscn: tune the shared profile in Inspector, then Generate.
const Generator = preload("res://scripts/settlement/nature_generator.gd")
const Assets = preload("res://scripts/settlement/asset_library.gd")
const Bush = preload("res://scripts/settlement/bush_view.gd")
const Stone = preload("res://scripts/settlement/stone_view.gd")
const Inventory = preload("res://scripts/settlement/inventory.gd")
const Tokens = preload("res://scripts/ui_visual_tokens.gd")
@export var shape_seed := 1409
@export var profile: Resource = preload("res://data/settlement/nature_profile.tres")
@export_tool_button("Generate") var generate = rebuild
var samples: Node3D

func _ready() -> void:
	$Environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	$Sun.shadow_opacity = 0.2
	rebuild()
	if not Engine.is_editor_hint():
		controls()
		if "--capture-nature" in OS.get_cmdline_user_args():
			for frame in 15: await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var result := get_viewport().get_texture().get_image().save_png("res://artifacts/nature-generator.png")
			print("PASS: nature generator preview" if result == OK else "FAIL: nature preview capture")
			get_tree().quit(result)

func rebuild() -> void:
	if not is_inside_tree(): return
	if is_instance_valid(samples): samples.free()
	samples = Node3D.new()
	add_child(samples)
	for row in 4:
		for column in 5:
			var seed_value := shape_seed + column * 7919
			var kind: String = ["tree", "palm", "berry", "limestone"][row]
			var node := Assets.create(kind)
			if row < 2:
				Generator.populate(node, "living" if row == 0 else "palm", seed_value, profile)
				for part in ["StumpCut", "Segment1/CutFace", "Segment2/CutFace"]: node.get_node(part).hide()
			elif row == 2:
				Bush.sync(node, Vector3i(column, 0, row), shape_seed, seed_value)
			else:
				var inventory := Inventory.new()
				var cell := Vector3i(column * 7, 0, row)
				inventory.capacity = Stone.Volume.capacity(cell, shape_seed)
				inventory.store("stone", inventory.capacity)
				Stone.sync(node, cell, shape_seed, inventory)
			node.position = Vector3((column - 2) * 3.8, 0, (row - 1.5) * 4.8)
			samples.add_child(node)

func controls() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(16, 16) * Tokens.POINT
	var theme_ := Theme.new()
	theme_.default_font_size = Tokens.UI_FONT_SIZE
	panel.theme = theme_
	var style := StyleBoxFlat.new()
	style.bg_color = Color("eee1c6")
	style.border_color = Color("493b2c")
	style.set_border_width_all(int(Tokens.LINE_WIDTH))
	style.content_margin_left = Tokens.PANEL_PADDING_X
	style.content_margin_right = Tokens.PANEL_PADDING_X
	style.content_margin_top = Tokens.PANEL_PADDING_Y
	style.content_margin_bottom = Tokens.PANEL_PADDING_Y
	panel.add_theme_stylebox_override("panel", style)
	layer.add_child(panel)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 4 * Tokens.GAP_UNIT)
	panel.add_child(rows)
	var seed_row := HBoxContainer.new()
	rows.add_child(seed_row)
	var seed_label := Label.new()
	seed_label.text = "Seed"
	seed_label.add_theme_color_override("font_color", Color("493b2c"))
	seed_row.add_child(seed_label)
	var seed_input := SpinBox.new()
	seed_input.max_value = 2147480000
	seed_input.value = shape_seed
	seed_input.value_changed.connect(func(value): shape_seed = int(value))
	seed_row.add_child(seed_input)
	# A session copy keeps preview experiments out of the saved game defaults.
	profile = profile.duplicate()
	for spec in [["Trunk lean", "trunk_lean", 35], ["Joint bend", "joint_bend", 25], ["Palm lean", "palm_lean", 40], ["Branch min", "branch_angle_min", 75], ["Branch max", "branch_angle_max", 75]]:
		var row := HBoxContainer.new()
		rows.add_child(row)
		var label := Label.new()
		label.text = spec[0] + " °"
		label.custom_minimum_size.x = 170 * Tokens.POINT
		label.add_theme_color_override("font_color", Color("493b2c"))
		row.add_child(label)
		var input := SpinBox.new()
		input.max_value = spec[2]
		input.min_value = 5 if str(spec[1]).begins_with("branch") else 0
		input.value = profile.get(spec[1])
		var property: String = spec[1]
		input.value_changed.connect(func(value): profile.set(property, value))
		row.add_child(input)
	var button := Button.new()
	button.text = "Generate"
	button.pressed.connect(rebuild)
	rows.add_child(button)
