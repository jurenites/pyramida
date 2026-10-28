extends "res://scripts/settlement/structure_parts_editor.gd"
## One workspace for source meshes, components and reusable prefab assemblies.
const EDIT_STEP := 0.1
const SelectionGeometry = preload("res://scripts/settlement/asset_selection_geometry.gd")
const TransformGizmo = preload("res://scripts/settlement/asset_transform_gizmo.gd")
var gizmo: RefCounted
const Workspace = preload("res://scripts/settlement/asset_workspace.gd")
const Contract = Workspace.Contract
const OVERFLOW = preload("res://shaders/asset_overflow.gdshader")
var contract := Contract.make()
var active_asset := ""
var category := "component"
var assets: Dictionary = {}
var library: ItemList
var layers: ItemList
var search: LineEdit
var library_ids: Array[String] = []
var prefab_library: ItemList
var prefab_ids: Array[String] = []
var building_select: OptionButton
var building_ids: Array[String] = []
var chosen_building := ""
var chosen_variant := ""
var library_choice := ""
var variant_select: OptionButton
var variant_ids: Array[String] = []
var variant_button: Button
const Components = preload("res://scripts/settlement/asset_components.gd")
var components: RefCounted
var inspector: Control
var inspector_tabs: TabContainer
var last_inspected := -1
var volume_spins: Array[SpinBox] = []
var offset_spins: Array[SpinBox] = []
var rotation_spins: Array[SpinBox] = []
var scale_spins: Array[SpinBox] = []
var timber_picker: OptionButton
var overlap_spin: SpinBox
var mount_picker: OptionButton
var volume_label: Label
var source_label: Label
var bounds_button: CheckButton
var dragging := false
var drag_origin := Vector3.ZERO
var drag_start := Vector2.ZERO
var drag_at := Vector3.ZERO
var drag_saved := false
var insertion: Dictionary = {}
var exchange_dialog: FileDialog
var exchange_mode := "export"
var scopes: Array = []
var parent_button: Button
var selected_layers: Array[int] = []
var drag_selection: Dictionary = {}
var drag_history: Array = []
var drag_redo: Array = []
var drag_dirty := false
var marquee_pending := false
var marquee_start := Vector2.ZERO
var marquee_base: Array[int] = []

func update_marquee(at: Vector2) -> void:
	var point := at.clamp(Vector2.ZERO, host.scene_container.size)
	host.overlay.marquee_rect = Rect2(marquee_start, point - marquee_start).abs()
	host.overlay.marquee_visible = point.distance_to(marquee_start) >= 4 * Tokens.POINT

func finish_marquee(at: Vector2) -> void:
	if not marquee_pending: return
	update_marquee(at)
	var indices := marquee_base.duplicate()
	if host.overlay.marquee_visible:
		for index in parts.size():
			if index not in indices and SelectionGeometry.intersects(parts[index], host.overlay.marquee_rect, host.camera):
				indices.append(index)
	marquee_pending = false
	host.overlay.marquee_visible = false
	selected = indices.back() if not indices.is_empty() else -1
	selected_layers = indices
	host._refresh()

func cancel_marquee() -> void:
	marquee_pending = false
	host.overlay.marquee_visible = false
	marquee_base.clear()

func selection_changed() -> void:
	selected_layers.clear()

func selection_indices() -> Array[int]:
	if selected < 0 or selected >= parts.size(): return []
	if selected_layers.is_empty(): return [selected]
	return selected_layers.filter(func(index): return index >= 0 and index < parts.size())

func multiple_selected() -> bool:
	return selection_indices().size() > 1

func select_layer(index: int, additive := false, keep_group := false) -> void:
	gizmo.end_drag()
	dragging = false
	var indices := selection_indices()
	if additive:
		if index >= 0 and index not in indices: indices.append(index)
	elif not keep_group or index not in indices:
		indices.clear()
		if index >= 0: indices.append(index)
	selected = indices.back() if not indices.is_empty() else -1
	selected_layers = indices
	selecting = true
	insertion = {}
	host._refresh()

func layer_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var index := layers.get_item_at_position(event.position, true)
		select_layer(index, event.shift_pressed)
		layers.accept_event()

func layer_selection_changed(index: int, chosen: bool) -> void:
	# Mouse selection is handled above; keep native keyboard selection in sync too.
	if updating: return
	if chosen:
		select_layer(index, true)
	else:
		var indices := selection_indices()
		indices.erase(index)
		selected = indices.back() if not indices.is_empty() else -1
		selected_layers = indices
		host._refresh()

func selection_part() -> Dictionary:
	if not multiple_selected(): return parts[selected].duplicate(true)
	var children: Array = []
	for index in selection_indices(): children.append(parts[index].duplicate(true))
	# A temporary transform frame, never inserted into the document hierarchy.
	return {"kind": "assembly", "at": Vector3.ZERO, "rotation": Vector3.ZERO, "children": children}

func selection_result(part: Dictionary) -> Array:
	if not multiple_selected(): return [part.duplicate(true)]
	var result: Array = []
	var pose := Kit.transform(part)
	for child: Dictionary in part.children:
		var copy := child.duplicate(true)
		if pose != Transform3D.IDENTITY:
			copy.at = pose * child.at
			if pose.basis != Basis.IDENTITY:
				copy.rotation = (pose.basis * Basis.from_euler(child.rotation)).get_euler()
		result.append(copy)
	return result

func selection_matches(part: Dictionary) -> bool:
	var result := selection_result(part)
	var indices := selection_indices()
	if result.size() != indices.size(): return false
	for i in indices.size():
		if parts[indices[i]] != result[i]: return false
	return true

func selection_valid(part: Dictionary) -> bool:
	var result := selection_result(part)
	var indices := selection_indices()
	if result.size() != indices.size(): return false
	for item: Dictionary in result:
		if not (item.at as Vector3).is_finite(): return false
		for axis in 3:
			if absf(item.at[axis]) > 32: return false
	return true

func apply_selection(part: Dictionary) -> void:
	var result := selection_result(part)
	var indices := selection_indices()
	for i in indices.size(): parts[indices[i]] = result[i]

func commit_selection(part: Dictionary) -> void:
	if selection_matches(part) or not selection_valid(part): return
	host._remember()
	apply_selection(part)
	host._refresh()

func selection_position() -> Vector3:
	return Kit.bounds(selection_part()).get_center() if multiple_selected() else parts[selected].at

func selection_step() -> float:
	for index in selection_indices():
		if grid_placed(parts[index]): return Contract.Grid.CELL_SIZE
	return EDIT_STEP

func move_selection(delta: Vector3) -> void:
	var part := selection_part()
	part.at += delta
	commit_selection(part)

func rotate(axis: int, angle: float) -> void:
	if not multiple_selected():
		super.rotate(axis, angle)
		return
	var direction := Vector3.ZERO
	direction[axis] = 1
	var part := selection_part()
	var result := TransformGizmo.RotationTool.rotated(part, direction, rad_to_deg(angle), TransformGizmo.local_bounds(part).get_center())
	commit_selection(result)

func remove_selected() -> void:
	var indices := selection_indices()
	if indices.is_empty(): return
	host._remember()
	indices.sort()
	indices.reverse()
	for index in indices: parts.remove_at(index)
	selected = -1
	host._refresh()

func group_selected() -> void:
	var indices := selection_indices()
	if indices.size() < 2 or dragging or gizmo.dragging: return
	indices.sort()
	var children: Array = []
	for index in indices: children.append(parts[index].duplicate(true))
	# An identity parent retains every child's exact authored transform.
	var group := {"kind": "assembly", "label": "Group", "at": Vector3.ZERO,
		"rotation": Vector3.ZERO, "children": children}
	var bounds := Kit.bounds(group)
	group.contract = Contract.make(bounds.size.max(Vector3.ONE * 0.01),
		Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z))
	var proposed := parts.duplicate(true)
	for i in range(indices.size() - 1, -1, -1): proposed.remove_at(indices[i])
	proposed.insert(indices[0], group)
	# Include enclosing scopes when checking the saved nesting/node limits.
	var document := proposed
	for i in range(scopes.size() - 1, -1, -1):
		var parent: Array = scopes[i].parts.duplicate(true)
		parent[scopes[i].index].children = document
		document = parent
	if Kit.decode(Kit.encode(document)).is_empty():
		host._status("Assembly limit reached.")
		return
	host._remember()
	parts = proposed
	selected = indices[0]
	selecting = true
	insertion = {}
	host._refresh()

func ungroup_selected() -> void:
	var indices := selection_indices()
	if indices.is_empty() or dragging or gizmo.dragging or marquee_pending: return
	var proposed: Array = []
	var released: Array[int] = []
	var changed := false
	for index in parts.size():
		var part: Dictionary = parts[index]
		if index in indices and part.kind == "assembly" and not part.children.is_empty():
			changed = true
			var parent_pose := Kit.transform(part)
			for child: Dictionary in part.children:
				var copy := child.duplicate(true)
				if parent_pose != Transform3D.IDENTITY:
					var pose := parent_pose * Kit.transform(child)
					copy.at = pose.origin
					copy.rotation = Vector3.ZERO
					copy.basis = pose.basis
					copy.erase("scale")
				if part.has("timber_species"): copy.timber_species = part.timber_species
				released.append(proposed.size())
				proposed.append(copy)
		else:
			if index in indices: released.append(proposed.size())
			proposed.append(part)
	if not changed: return
	host._remember()
	parts = proposed
	selected = released.back()
	selected_layers = released
	selecting = true
	insertion = {}
	host._refresh()

func create_ui(parent: VBoxContainer) -> void:
	gizmo = TransformGizmo.new(self)
	components = Components.new(self)
	parent.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel = VBoxContainer.new()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_constant_override("separation", 4 * Tokens.GAP_UNIT)
	parent.add_child(panel)
	parent_button = host._button(panel, "← Prefab", leave_scope)
	var prefab_header := HBoxContainer.new()
	panel.add_child(prefab_header)
	host._label(prefab_header, "Prefabs").size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host._icon_button(prefab_header, "open", "Load village example", load_example)
	host._icon_button(prefab_header, "add", "New prefab", func(): new_asset("prefab"))
	prefab_library = ItemList.new()
	prefab_library.custom_minimum_size.y = 48 * Tokens.POINT
	prefab_library.item_selected.connect(func(index): choose_library(prefab_ids[index]))
	panel.add_child(prefab_library)
	var building_row := HBoxContainer.new()
	panel.add_child(building_row)
	host._label(building_row, "Building")
	building_select = OptionButton.new()
	building_select.allow_reselect = true
	building_select.fit_to_longest_item = false
	building_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	building_select.tooltip_text = "Select a building · Edit to open"
	building_select.item_selected.connect(func(index):
		if index > 0:
			chosen_building = building_ids[index - 1]
			chosen_variant = chosen_building
			choose_library(chosen_building))
	building_row.add_child(building_select)
	var variant_row := HBoxContainer.new()
	panel.add_child(variant_row)
	variant_select = OptionButton.new()
	variant_select.allow_reselect = true
	variant_select.fit_to_longest_item = false
	variant_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	variant_select.tooltip_text = "Select a variant · Edit to open"
	variant_select.item_selected.connect(func(index):
		chosen_variant = variant_ids[index]
		choose_library(chosen_variant))
	variant_row.add_child(variant_select)
	variant_button = host._icon_button(variant_row, "add", "Save current layout as a building variant", save_variant)
	var asset_header := HBoxContainer.new()
	panel.add_child(asset_header)
	host._label(asset_header, "Assets").size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host._icon_button(asset_header, "add", "New asset", func(): new_asset("component"))
	search = LineEdit.new()
	search.placeholder_text = "Search assets"
	search.text_changed.connect(func(_text): refresh_library())
	panel.add_child(search)
	library = ItemList.new()
	library.custom_minimum_size = Vector2(240, 96) * Tokens.POINT
	library.item_selected.connect(func(index): choose_library(library_ids[index]))
	panel.add_child(library)
	var library_actions := HBoxContainer.new()
	panel.add_child(library_actions)
	host._button(library_actions, "Edit", edit_library)
	host._button(library_actions, "Insert", insert_library)
	host._icon_button(library_actions, "add", "Add to library · Save keeps it on disk", store_asset)
	var tools := HBoxContainer.new()
	panel.add_child(tools)
	select_button = host._icon_button(tools, "select", "Select / drag on the current height plane", func(): selecting = true; insertion = {}; refresh(); repick())
	select_button.toggle_mode = true
	host._icon_button(tools, "copy", "Duplicate selected part", duplicate_selected)
	host._icon_button(tools, "remove", "Remove selected part", remove_selected)
	host._icon_button(tools, "undo", "Undo · Ctrl/Cmd+Z", host.undo)
	host._icon_button(tools, "redo", "Redo · Ctrl/Cmd+Shift+Z", host.redo)
	components.create_selection_controls(panel)
	layers = ItemList.new()
	layers.custom_minimum_size.y = 96 * Tokens.POINT
	layers.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layers.tooltip_text = "Shift-click to select multiple parts · Ctrl/Cmd+G to group"
	layers.select_mode = ItemList.SELECT_MULTI
	layers.gui_input.connect(layer_input)
	layers.multi_selected.connect(layer_selection_changed)
	panel.add_child(layers)
	host._button(panel, "Edit instance", enter_selected).tooltip_text = "Edit the shared source of a linked component, or the children of a local group"
	# Kept as internal controls for older document/editor integration.
	building_picker = OptionButton.new()
	building_picker.add_item("Custom")
	for item in Kit.Appearance.buildings(): building_picker.add_item(Kit.title(item))
	panel.add_child(building_picker)
	building_picker.hide()
	palette = OptionButton.new()
	for item in Kit.kinds(): palette.add_item(Kit.title(item))
	panel.add_child(palette)
	palette.hide()
	refresh_library()

func create_inspector(body: Node) -> void:
	var column: VBoxContainer = host._panel(body, 280)
	inspector = column.get_parent().get_parent()
	var footer := column
	gizmo.create_controls(column)
	host.overlay.transform_gizmo = gizmo
	inspector_tabs = TabContainer.new()
	column.add_child(inspector_tabs)
	column = VBoxContainer.new()
	column.name = "Volume"
	column.add_theme_constant_override("separation", 8 * Tokens.GAP_UNIT)
	inspector_tabs.add_child(column)
	host._label(column, "Occupied space · cells")
	volume_label = host._label(column, "")
	volume_label.tooltip_text = "One cell = one metre; X width, Z height, Y depth"
	for axis in 3:
		volume_spins.append(host._spin(column, ["Width", "Height", "Depth"][axis] + " " + Tokens.BLUEPRINT_AXIS_LABELS[axis], EDIT_STEP, 64, 2, func(value):
			if updating: return
			host._remember()
			contract.size[axis] = value * Contract.Grid.CELL_SIZE
			host._refresh(), EDIT_STEP))
	overlap_spin = host._spin(column, "Overlap m", 0, 0.5, 0.05, func(value):
		if updating: return
		host._remember()
		contract.margin = value
		host._refresh(), EDIT_STEP)
	mount_picker = OptionButton.new()
	for title in ["Floor mounted", "Wall mounted", "Free"]: mount_picker.add_item(title)
	mount_picker.item_selected.connect(func(index):
		if updating: return
		host._remember()
		contract.mount = ["floor", "wall", "free"][index]
		host._refresh())
	column.add_child(mount_picker)
	for axis in 3:
		offset_spins.append(host._spin(column, "Pivot " + Tokens.BLUEPRINT_AXIS_LABELS[axis], -32, 32, 0, func(value):
			if updating: return
			host._remember()
			contract.offset[axis] = value
			host._refresh(), EDIT_STEP))
	bounds_button = CheckButton.new()
	bounds_button.text = "Show bounds"
	bounds_button.button_pressed = true
	bounds_button.toggled.connect(func(_value): host._redraw())
	column.add_child(bounds_button)
	auto_button = CheckButton.new()
	auto_button.text = "Surface snap"
	auto_button.button_pressed = true
	auto_button.toggled.connect(func(value): automatic = value; refresh(); repick())
	column.add_child(auto_button)
	height_spin = host._spin(column, "Place Z", -6, 12, 0, func(value):
		if updating: return
		plane_height = value
		automatic = false
		refresh()
		repick(), EDIT_STEP)
	selection_panel = VBoxContainer.new()
	selection_panel.name = "Part"
	selection_panel.add_theme_constant_override("separation", 8 * Tokens.GAP_UNIT)
	inspector_tabs.add_child(selection_panel)
	host._section(selection_panel, "Selected part")
	components.create_inspector(selection_panel)
	timber_picker = OptionButton.new()
	timber_picker.tooltip_text = "Timber"
	for index in Kit.Appearance.TimberPalette.SPECIES.size():
		var swatch := Image.create(20 * Tokens.POINT, 20 * Tokens.POINT, false, Image.FORMAT_RGBA8)
		swatch.fill(Kit.Appearance.TimberPalette.BARK[index])
		timber_picker.add_icon_item(ImageTexture.create_from_image(swatch), Kit.Appearance.TimberPalette.LABELS[index])
	timber_picker.add_item("Mixed timber")
	timber_picker.set_item_disabled(3, true)
	timber_picker.item_selected.connect(choose_timber)
	selection_panel.add_child(timber_picker)
	for axis in 3:
		coordinates.append(host._spin(selection_panel, Tokens.BLUEPRINT_AXIS_LABELS[axis], -32, 32, 0, func(value):
			if updating or selected < 0: return
			if multiple_selected():
				var delta := Vector3.ZERO
				delta[axis] = value - selection_position()[axis]
				move_selection(delta)
				return
			host._remember()
			parts[selected].at[axis] = value
			host._refresh(), EDIT_STEP))
	for axis in 3:
		rotation_spins.append(host._spin(selection_panel, "Rotate " + Tokens.BLUEPRINT_AXIS_LABELS[axis], -180, 180, 0, func(value):
			if updating or selected < 0: return
			if multiple_selected():
				rotate(axis, deg_to_rad(value))
				return
			host._remember()
			parts[selected].rotation[axis] = deg_to_rad(value)
			host._refresh(), EDIT_STEP))
	for axis in 3:
		scale_spins.append(host._spin(selection_panel, "Scale " + Tokens.BLUEPRINT_AXIS_LABELS[axis], EDIT_STEP, 32, 1, func(value):
			if updating or selected < 0: return
			if multiple_selected() or not Kit.Appearance.can_resize(parts[selected], axis): return
			host._remember()
			var scale := Kit.Appearance.resize_scale(parts[selected])
			scale[axis] = value
			Kit.Appearance.set_resize_scale(parts[selected], scale)
			host._refresh(), EDIT_STEP))
	column = footer
	apply_button = host._button(column, "Apply to game", apply_building)
	apply_button.tooltip_text = "Apply the visual model to this building type; authoring bounds are saved in the workspace"
	original_button = host._button(column, "Original", restore_original)
	source_label = host._label(column, "", host.MUTED)
	source_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	var files := HBoxContainer.new()
	column.add_child(files)
	host._button(files, "Source", reveal_source)
	host._button(files, "Export", func(): open_exchange("export"))
	host._button(files, "Import", func(): open_exchange("import"))
	exchange_dialog = FileDialog.new()
	exchange_dialog.access = FileDialog.ACCESS_FILESYSTEM
	exchange_dialog.filters = PackedStringArray(["*.glb ; Blender / glTF binary"])
	exchange_dialog.file_selected.connect(func(path):
		if exchange_mode == "export": host._status("Exported." if export_glb(path) else "Export failed.")
		else: host._status("Imported." if import_glb(path) else "Invalid model. Current work kept."))
	host.root.add_child(exchange_dialog)

func choose_timber(index: int) -> void:
	if updating or selected < 0 or index < 0 or index >= Kit.Appearance.TimberPalette.SPECIES.size(): return
	if not Kit.Appearance.has_timber(parts[selected]): return
	var species: String = Kit.Appearance.TimberPalette.SPECIES[index]
	if Kit.Appearance.timber_species(parts[selected]) == species: return
	host._remember()
	Kit.Appearance.set_timber_species(parts[selected], species)
	host._refresh()

func edit_library() -> void:
	if not library_choice.is_empty(): open_asset(library_choice)

func choose_library(id: String) -> void:
	library_choice = id
	selected = -1
	host._refresh()

func library_title(id: String) -> String:
	if id == active_asset and scopes.is_empty(): return host.draft.name
	return assets[id].name if assets.has(id) else Kit.title(id).capitalize()

func refresh_library() -> void:
	if library == null: return
	var asset_scroll := library.get_v_scroll_bar().value
	var prefab_scroll := prefab_library.get_v_scroll_bar().value
	library.clear()
	library_ids.clear()
	prefab_library.clear()
	prefab_ids.clear()
	building_select.clear()
	building_select.add_item("Select…")
	building_select.set_item_disabled(0, true)
	building_ids.clear()
	var ids: Array = Kit.kinds().duplicate()
	for id in assets:
		if id not in ids: ids.append(id)
	for id: String in ids:
		var entry_category := Workspace.category_for(id, assets[id].category if assets.has(id) else "component")
		var group := Workspace.library_group(entry_category)
		var title := library_title(id)
		if group == "building":
			if not assets.get(id, {}).get("base_asset", "").is_empty(): continue
			building_ids.append(id)
			building_select.add_item(title)
			continue
		if group == "prefab":
			prefab_ids.append(id)
			prefab_library.add_item(title)
			prefab_library.set_item_tooltip(prefab_library.item_count - 1, "Select · Edit to open")
			if id == library_choice: prefab_library.select(prefab_library.item_count - 1)
			continue
		if not search.text.is_empty() and not title.to_lower().contains(search.text.to_lower()): continue
		library_ids.append(id)
		library.add_item(title)
		library.set_item_tooltip(library.item_count - 1, group.capitalize() + " · Edit to open")
		if id == library_choice: library.select(library.item_count - 1)
	if chosen_building not in building_ids: chosen_building = ""
	building_select.select(building_ids.find(chosen_building) + 1)
	variant_select.clear()
	variant_ids.clear()
	if not chosen_building.is_empty():
		variant_select.add_item("Original")
		variant_ids.append(chosen_building)
		for id: String in assets:
			if assets[id].get("base_asset", "") != chosen_building: continue
			variant_ids.append(id)
			variant_select.add_item(library_title(id))
		if chosen_variant not in variant_ids: chosen_variant = chosen_building
		variant_select.select(variant_ids.find(chosen_variant))
	else: variant_select.add_item("Variant")
	variant_select.disabled = chosen_building.is_empty()
	variant_button.disabled = not can_save_variant()
	library.get_v_scroll_bar().value = asset_scroll
	prefab_library.get_v_scroll_bar().value = prefab_scroll

func stash_building() -> void:
	super.stash_building()
	if not active_asset.is_empty():
		var base_asset: String = assets.get(active_asset, {}).get("base_asset", "")
		assets[active_asset] = {"name": host.draft.name, "category": category, "parts": parts.duplicate(true), "contract": contract.duplicate(true)}
		if not base_asset.is_empty(): assets[active_asset].base_asset = base_asset

func can_save_variant() -> bool:
	return not chosen_building.is_empty() and category == "building" and assets.get(active_asset, {}).get("base_asset", active_asset) == chosen_building and not parts.is_empty() and scopes.is_empty()

func save_variant() -> void:
	if not can_save_variant(): return
	if assets.size() >= 128: host._status("Library limit reached."); return
	host._remember()
	# The current edits become the new variant; do not overwrite its source.
	var base_id := chosen_building
	var title: String = host.draft.name
	if title == Kit.title(base_id).capitalize(): title += " variant"
	var used: Array = assets.values().map(func(entry): return entry.name)
	var suffix := 2
	var unique: String = title
	while unique in used:
		unique = "%s %d" % [title, suffix]
		suffix += 1
	active_asset = "custom_%d" % Time.get_ticks_usec()
	category = "building"
	building_kind = ""
	host.draft.name = unique.left(80)
	assets[active_asset] = {"name": host.draft.name, "category": category, "base_asset": base_id,
		"parts": parts.duplicate(true), "contract": contract.duplicate(true)}
	library_choice = active_asset
	chosen_variant = active_asset
	selected = -1
	selecting = true
	insertion = {}
	host._refresh()

func open_asset(id: String) -> void:
	while not scopes.is_empty(): leave_scope()
	if id == active_asset:
		library_choice = id
		host._refresh()
		return
	host._remember()
	stash_building()
	active_asset = id
	library_choice = id
	if Workspace.category_for(id, assets.get(id, {}).get("category", "component")) == "building":
		chosen_building = assets.get(id, {}).get("base_asset", id)
		chosen_variant = id
	library.deselect_all()
	building_kind = id if id in Kit.Appearance.buildings() else ""
	category = Workspace.category_for(id)
	if assets.has(id):
		parts = assets[id].parts.duplicate(true)
		contract = assets[id].contract.duplicate(true)
		category = Workspace.category_for(id, assets[id].category)
		host.draft.name = assets[id].name
	else:
		var saved := Kit.Appearance.saved(id) if id in Kit.Appearance.buildings() else {}
		parts = saved.parts.duplicate(true) if not saved.is_empty() else Kit.Appearance.defaults(id)
		if id == "plank": parts = parts.filter(func(p): return p.component == "Plank0")
		contract = Workspace.defaults(id)
		host.draft.name = Kit.title(id).capitalize()
	selected = -1
	selecting = true
	insertion = {}
	leave()
	host._refresh()
	fit()

func open_building(value: String) -> void:
	if value.is_empty(): new_asset("component")
	else: open_asset(value)

func new_asset(type: String) -> void:
	while not scopes.is_empty(): leave_scope()
	host._remember()
	stash_building()
	active_asset = "custom_%d" % Time.get_ticks_usec()
	library_choice = ""
	building_kind = ""
	category = type
	library.deselect_all()
	contract = Contract.make(Vector3(4, 4, 4) if type == "prefab" else Vector3(2, 2, 2))
	parts = []
	selected = -1
	selecting = true
	insertion = {}
	host.draft.name = "New " + type
	host._refresh()
	fit()

func store_asset() -> void:
	host._remember()
	if active_asset.is_empty(): active_asset = "custom_%d" % Time.get_ticks_usec()
	stash_building()
	refresh_library()
	host._status("Added to library. Save to keep on disk.")

func insert_library() -> void:
	if library_choice.is_empty(): return
	var id := library_choice
	if id == active_asset:
		host._status("Choose a different asset to insert.")
		return
	var proposed := library_instance(id)
	var ancestry: Array = [active_asset]
	for scope: Dictionary in scopes: ancestry.append(scope.active_asset)
	if not Workspace.resolve([proposed], assets, ancestry):
		host._status("Component would create a circular or oversized assembly.")
		return
	insertion = proposed
	selecting = false
	selected = -1
	refresh()
	repick()

func library_instance(id: String) -> Dictionary:
	var children: Array
	var bounds: Dictionary
	var label: String
	if assets.has(id):
		children = assets[id].parts.duplicate(true)
		bounds = assets[id].contract.duplicate(true)
		label = assets[id].name
	else:
		children = Kit.Appearance.defaults(id)
		if id == "plank": children = children.filter(func(p): return p.component == "Plank0")
		bounds = Workspace.defaults(id)
		label = Kit.title(id).capitalize()
	var instance := {"kind": "assembly", "children": children, "contract": bounds, "label": label, "asset_ref": id, "linked": true,
		"at": Vector3.ZERO, "rotation": Vector3.ZERO}
	if Workspace.category_for(id, assets.get(id, {}).get("category", "component")) == "building":
		instance.building_family = assets.get(id, {}).get("base_asset", id)
	Workspace.resolve([instance], assets)
	return instance

func sync_number(spin: SpinBox, value: float) -> void:
	# Vector3 stores single precision. Don't replace a just-entered decimal with
	# its float32 representation when the inspector immediately refreshes.
	if Vector3(spin.value, 0, 0).x != Vector3(value, 0, 0).x: spin.set_value_no_signal(value)

func sync_links() -> void:
	var resolved := parts.duplicate(true)
	if Workspace.resolve(resolved, assets, [active_asset] if not active_asset.is_empty() else []): parts = resolved

func refresh() -> void:
	sync_links()
	panel.visible = enabled
	if inspector != null: inspector.visible = enabled
	button.set_pressed_no_signal(enabled)
	if not enabled or inspector == null: return
	updating = true
	parent_button.visible = not scopes.is_empty()
	building_picker.select(0 if building_kind.is_empty() else Kit.Appearance.buildings().find(building_kind) + 1)
	apply_button.visible = not building_kind.is_empty()
	original_button.visible = not active_asset.is_empty() and active_asset in Kit.kinds()
	apply_button.disabled = parts.is_empty()
	select_button.set_pressed_no_signal(selecting)
	sync_number(height_spin, plane_height)
	auto_button.set_pressed_no_signal(automatic)
	for axis in 3:
		sync_number(volume_spins[axis], float(contract.size[axis]) / Contract.Grid.CELL_SIZE)
		sync_number(offset_spins[axis], contract.offset[axis])
	sync_number(overlap_spin, contract.margin)
	mount_picker.select(["floor", "wall", "free"].find(contract.mount))
	var outside := 0
	for part in parts:
		if exceeds(part, contract): outside += 1
	volume_label.text = "%.1f × %.1f × %.1f m" % contract.size
	volume_label.modulate = Color("ce5748") if outside else Color.WHITE
	volume_label.tooltip_text = "%d parts exceed the overlap allowance" % outside if outside else "All geometry fits the allowed volume"
	var reveal_selection: bool = last_inspected != selected or Array(layers.get_selected_items()) != Array(selection_indices())
	# Keep existing rows so a transform refresh doesn't reset the user's scroll.
	while layers.item_count > parts.size(): layers.remove_item(layers.item_count - 1)
	for index in parts.size():
		var part: Dictionary = parts[index]
		var title: String = part.get("label", str(part.get("component", Kit.title(part.kind)))).get_file()
		if index >= layers.item_count: layers.add_item(title)
		elif layers.get_item_text(index) != title: layers.set_item_text(index, title)
		layers.set_item_custom_fg_color(index, Color("ce5748") if exceeds(part, contract) else host.INK)
	layers.deselect_all()
	if selected >= parts.size(): selected = -1
	timber_picker.visible = selected >= 0 and not multiple_selected() and Kit.Appearance.has_timber(parts[selected])
	if timber_picker.visible:
		var species := Kit.Appearance.timber_species(parts[selected])
		timber_picker.select(3 if species.is_empty() else Kit.Appearance.TimberPalette.SPECIES.find(species))
	inspector_tabs.set_tab_disabled(1, selected < 0)
	if last_inspected != selected:
		inspector_tabs.current_tab = 1 if selected >= 0 else 0
		last_inspected = selected
	if selected >= 0:
		layers.select(selected)
		for index in selection_indices(): layers.select(index, false)
		if reveal_selection:
			layers.ensure_current_is_visible.call_deferred()
		for axis in 3:
			sync_number(coordinates[axis], selection_position()[axis])
			sync_number(rotation_spins[axis], 0 if multiple_selected() else rad_to_deg(parts[selected].rotation[axis]))
			rotation_spins[axis].tooltip_text = "Rotate selection by degrees" if multiple_selected() else ""
			var locked := multiple_selected() or not Kit.Appearance.can_resize(parts[selected], axis)
			scale_spins[axis].editable = not locked
			scale_spins[axis].max_value = 1.0 if Kit.Appearance.log_length_axis(parts[selected]) >= 0 else 32.0
			scale_spins[axis].min_value = 0.01 if Kit.Appearance.log_length_axis(parts[selected]) >= 0 else EDIT_STEP
			sync_number(scale_spins[axis], 1.0 if multiple_selected() else Kit.Appearance.resize_scale(parts[selected])[axis])
	refresh_library()
	components.refresh()
	refresh_source()
	updating = false
	gizmo.refresh()

func draw() -> void:
	sync_links()
	host.overlay.volume_edges.clear()
	if bounds_button.button_pressed: host.overlay.volume_edges = Contract.edges(Contract.box(contract))
	for part: Dictionary in parts:
		var node := Kit.draw(host.geometry, part)
		apply_overflow(node, contract, Transform3D.IDENTITY)
		apply_component_overflow(node, part, Transform3D.IDENTITY)
		if bounds_button.button_pressed and part.has("contract") and selected >= 0 and part == parts[selected]:
			host.overlay.volume_edges.append_array(Contract.edges(Contract.box(part.contract), Kit.transform(part)))
	host.overlay.buildings = []
	host.overlay.camera = host.camera
	host.overlay.placement_visible = false
	ghost = null
	candidate = {}
	if selected >= 0: outline_selection()
	repick()

func apply_overflow(node: Node3D, bounds: Dictionary, pose: Transform3D) -> void:
	var material := ShaderMaterial.new()
	material.shader = OVERFLOW
	var box := Contract.box(bounds).grow(bounds.margin)
	material.set_shader_parameter("allowed_min", box.position)
	material.set_shader_parameter("allowed_max", box.end)
	material.set_shader_parameter("volume_inverse", pose.affine_inverse())
	var meshes := node.find_children("*", "MeshInstance3D", true, false)
	if not meshes.is_empty(): material.next_pass = meshes[0].material_overlay
	for mesh in meshes: mesh.material_overlay = material

func apply_component_overflow(node: Node3D, part: Dictionary, parent_pose: Transform3D) -> void:
	if part.kind != "assembly": return
	var pose := parent_pose * Kit.transform(part)
	if part.has("contract"): apply_overflow(node, part.contract, pose)
	for index in part.children.size(): apply_component_overflow(node.get_child(index), part.children[index], pose)

func exceeds(part: Dictionary, bounds: Dictionary) -> bool:
	if Contract.excess(Kit.bounds(part), bounds): return true
	if part.kind == "assembly" and part.has("contract"):
		for child in part.children:
			if exceeds(child, part.contract): return true
	return false

func grid_placed(part: Dictionary) -> bool:
	if part.kind != "assembly": return false
	if part.has("building_family"): return true
	var id: String = part.get("asset_ref", "")
	if Workspace.category_for(id, assets.get(id, {}).get("category", "component")) in ["building", "prefab"]: return true
	return part.children.any(func(child): return grid_placed(child))

func placement_bounds(part: Dictionary) -> AABB:
	# Ignore translation, but include rotation and authored contract offsets.
	# Source pivots and saved transforms stay intact; snapping uses the volume.
	var pose := Kit.transform(part)
	pose.origin = Vector3.ZERO
	return pose * Contract.box(part.contract)

func placement_position(part: Dictionary, point: Vector3) -> Vector3:
	if not grid_placed(part): return point.snapped(Vector3.ONE * EDIT_STEP)
	var corner := placement_bounds(part).position
	return Contract.Grid.snap_position(point + corner) - corner

func building_socket(part: Dictionary, point: Vector3, support: Dictionary = {}) -> Vector3:
	var bounds := placement_bounds(part)
	var corner := Contract.Grid.snap_position(point)
	if not support.is_empty() and grid_placed(support):
		# Stack on the occupied top, not a decorative roof, sail or floor finish.
		# Smaller modules can occupy either side of the supporting footprint.
		var occupied: AABB = Kit.transform(support) * Contract.box(support.contract)
		corner.y = occupied.end.y
		for axis in [0, 2]:
			if bounds.size[axis] <= occupied.size[axis] + 0.00001:
				corner[axis] = clampf(corner[axis], occupied.position[axis], occupied.end[axis] - bounds.size[axis])
	return corner - bounds.position

func outline_selection() -> void:
	host.overlay.placement_edges.clear()
	for index in selection_indices():
		host.overlay.placement_edges.append_array(SelectionGeometry.outline(parts[index], host.camera))
	host.overlay.placement_visible = not selection_indices().is_empty()

func leave() -> void:
	super.leave()
	if enabled and selected >= 0: outline_selection()

func hover(at: Vector2) -> void:
	if selecting:
		pointer = at
		if is_instance_valid(ghost): ghost.free()
		candidate = {}
		outline_selection()
		return
	if insertion.is_empty() or selecting:
		super.hover(at)
		return
	pointer = at
	if is_instance_valid(ghost): ghost.free()
	candidate = {}
	var hit := pick(at) if automatic else {}
	var point: Variant
	var normal := Vector3.UP
	if not hit.is_empty():
		point = hit.point
		normal = hit.normal
	else: point = Plane(Vector3.UP, plane_height).intersects_ray(host.camera.project_ray_origin(at), host.camera.project_ray_normal(at))
	if point == null: return
	candidate = insertion.duplicate(true)
	candidate.rotation = rotation
	candidate.at = Vector3.ZERO
	# Snap the authored occupied volume to the mounting surface.
	if candidate.contract.mount == "wall" and absf(normal.y) < 0.5:
		candidate.rotation.y = atan2(normal.x, normal.z)
	var box := Contract.box(candidate.contract)
	var minimum := INF
	for corner in 8: minimum = minf(minimum, normal.dot(Kit.transform(candidate) * box.get_endpoint(corner)))
	var snapped: Vector3 = point.snapped(Vector3.ONE * EDIT_STEP)
	candidate.at = snapped + normal * (normal.dot(point - snapped) - minimum)
	if grid_placed(candidate):
		# Align the occupied lower corner to the grid; loose parts retain
		# their mounting-surface snap.
		candidate.at = building_socket(candidate, point, parts[hit.index] if not hit.is_empty() else {})
	ghost = Kit.draw(host.geometry, candidate, true)
	apply_overflow(ghost, contract, Transform3D.IDENTITY)
	outline(candidate)

func click(at: Vector2, additive := false) -> void:
	if selecting or additive:
		select_layer(int(pick(at).get("index", -1)), additive, true)
		return
	if not selecting and not insertion.is_empty():
		hover(at)
		if candidate.is_empty(): return
		var proposed := parts.duplicate(true)
		proposed.append(candidate.duplicate(true))
		if Kit.decode(Kit.encode(proposed)).is_empty():
			host._status("Assembly limit reached.")
			return
		host._remember()
		parts = proposed
		host._refresh()
	else: super.click(at, false)

func duplicate_selected() -> void:
	var indices := selection_indices()
	if indices.is_empty(): return
	var proposed := parts.duplicate(true)
	var copies: Array[int] = []
	var offset := Vector3.RIGHT * (Contract.Grid.ROOM_SIZE if selection_step() > EDIT_STEP else 2 * EDIT_STEP)
	for index in indices:
		var copy: Dictionary = parts[index].duplicate(true)
		copy.at += offset
		copies.append(proposed.size())
		proposed.append(copy)
	if Kit.decode(Kit.encode(proposed)).is_empty():
		host._status("Assembly limit reached.")
		return
	host._remember()
	parts = proposed
	selected = copies.back()
	selected_layers = copies
	host._refresh()

func copy_selected() -> void:
	if multiple_selected():
		duplicate_selected()
		return
	if selected >= 0 and parts[selected].kind == "assembly":
		insertion = parts[selected].duplicate(true)
		rotation = insertion.rotation
		selecting = false
		selected = -1
		refresh()
		repick()
	else: super.copy_selected()

func enter_selected() -> void:
	if multiple_selected() or selected < 0 or parts[selected].kind != "assembly" or scopes.size() >= 8: return
	host._remember()
	var group: Dictionary = parts[selected]
	scopes.append({"parts": parts.duplicate(true), "contract": contract.duplicate(true), "index": selected,
		"name": host.draft.name, "active_asset": active_asset, "category": category, "building_kind": building_kind})
	# Visibility and palette overrides belong to the instance, not its source.
	var source_group := library_instance(group.asset_ref) if group.get("linked", false) else group
	parts = source_group.children.duplicate(true)
	contract = source_group.get("contract", Contract.make()).duplicate(true)
	host.draft.name = source_group.get("label", "Component")
	active_asset = group.asset_ref if group.get("linked", false) else ""
	building_kind = ""
	category = Workspace.category_for(group.get("asset_ref", ""), assets.get(active_asset, {}).get("category", "component"))
	selected = -1
	selecting = true
	insertion = {}
	leave()
	host._refresh()
	fit()

func leave_scope() -> void:
	if scopes.is_empty(): return
	host._remember()
	stash_building()
	var parent: Dictionary = scopes.pop_back()
	parent.parts[parent.index].children = parts.duplicate(true)
	parent.parts[parent.index].contract = contract.duplicate(true)
	if not parent.parts[parent.index].get("linked", false): parent.parts[parent.index].label = host.draft.name
	parts = parent.parts
	contract = parent.contract
	active_asset = parent.active_asset
	building_kind = parent.building_kind
	category = parent.category
	host.draft.name = parent.name
	selected = parent.index
	selecting = true
	insertion = {}
	leave()
	host._refresh()
	fit()

func unpack_selected() -> void:
	if multiple_selected() or selected < 0 or parts[selected].kind != "assembly": return
	host._remember()
	var group: Dictionary = parts[selected]
	parts.remove_at(selected)
	for child: Dictionary in group.children:
		var copy := child.duplicate(true)
		var pose := Kit.transform(group) * Kit.transform(child)
		copy.at = pose.origin
		copy.rotation = Vector3.ZERO
		copy.basis = pose.basis
		copy.erase("scale")
		parts.append(copy)
	selected = -1
	host._refresh()

func input(event: InputEvent) -> void:
	if marquee_pending:
		if event is InputEventMouseMotion: update_marquee(event.position)
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed: finish_marquee(event.position)
		host.scene_container.accept_event()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and not event.shift_pressed and gizmo.begin(event.position):
			host.scene_container.grab_focus()
			host.scene_container.accept_event()
			return
		elif not event.pressed and gizmo.dragging:
			gizmo.end_drag()
			host.scene_container.accept_event()
			return
	if event is InputEventMouseMotion and gizmo.dragging:
		gizmo.drag(event.position)
		host.scene_container.accept_event()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			host.scene_container.grab_focus()
			if selecting and pick(event.position).is_empty():
				marquee_pending = true
				marquee_start = event.position
				marquee_base.assign(selection_indices() if event.shift_pressed else [])
				update_marquee(event.position)
				host.scene_container.accept_event()
				return
			click(event.position, event.shift_pressed)
			if selecting and selected >= 0 and not event.shift_pressed:
				dragging = true
				drag_saved = false
				drag_start = event.position
				drag_at = selection_position()
				drag_selection = selection_part()
				drag_history = host.undo_stack.duplicate()
				drag_redo = host.redo_stack.duplicate(true)
				drag_dirty = host.dirty
				var p: Variant = Plane(Vector3.UP, drag_at.y).intersects_ray(host.camera.project_ray_origin(event.position), host.camera.project_ray_normal(event.position))
				drag_origin = p if p != null else drag_at
		else: dragging = false
	elif event is InputEventMouseMotion and dragging and selected >= 0:
		if not drag_saved and event.position.distance_to(drag_start) < 4: return
		var p: Variant = Plane(Vector3.UP, drag_at.y).intersects_ray(host.camera.project_ray_origin(event.position), host.camera.project_ray_normal(event.position))
		if p != null:
			var preview := drag_selection.duplicate(true)
			if multiple_selected(): preview.at += (p - drag_origin).snapped(Vector3.ONE * selection_step())
			else: preview.at = placement_position(parts[selected], drag_at + p - drag_origin)
			if selection_matches(preview) or not selection_valid(preview): return
			if not drag_saved: host._remember(); drag_saved = true
			apply_selection(preview)
			host._refresh()
	elif event is InputEventMouseMotion: hover(event.position)
	host.scene_container.accept_event()

func cancel_drag() -> void:
	cancel_marquee()
	if dragging and drag_saved:
		apply_selection(drag_selection)
		host.undo_stack = drag_history
		host.redo_stack = drag_redo
		host.dirty = drag_dirty
	dragging = false
	drag_selection = {}
	drag_history = []
	drag_redo = []

func restore_original() -> void:
	if active_asset not in Kit.kinds(): return
	host._remember()
	parts = Kit.Appearance.defaults(active_asset)
	if active_asset == "plank": parts = parts.filter(func(p): return p.component == "Plank0")
	contract = Workspace.defaults(active_asset)
	selected = -1
	host._refresh()

func load_example() -> void:
	new_asset("prefab")
	parts = Workspace.example()
	contract = Contract.make(Vector3(7, 7, 7), Vector3(-0.5, -0.15, 0))
	host.draft.name = "Terraced workshop"
	stash_building()
	host._refresh()
	fit()

func state() -> Dictionary:
	var encoded := {}
	for id in assets:
		encoded[id] = assets[id].duplicate(true)
		encoded[id].parts = Workspace.encode_parts(assets[id].parts)
	var scope_data: Array = []
	for scope: Dictionary in scopes:
		var copy := scope.duplicate(true)
		copy.parts = Workspace.encode_parts(scope.parts)
		scope_data.append(copy)
	return {"contract": contract.duplicate(true), "active_asset": active_asset, "category": category, "assets": encoded, "scopes": scope_data}

func restore_state(value: Dictionary) -> void:
	cancel_marquee()
	contract = value.get("contract", Workspace.defaults(building_kind)).duplicate(true)
	active_asset = value.get("active_asset", building_kind)
	category = Workspace.category_for(active_asset, value.get("category", "component"))
	Workspace.migrate_links(parts, value.get("assets", {}).keys())
	assets = {}
	for id in value.get("assets", {}):
		assets[id] = value.assets[id].duplicate(true)
		assets[id].category = Workspace.category_for(id, assets[id].category)
		assets[id].parts = Kit.decode(value.assets[id].parts).parts
		Workspace.migrate_links(assets[id].parts, value.get("assets", {}).keys())
	if category == "building":
		chosen_building = assets.get(active_asset, {}).get("base_asset", active_asset)
		chosen_variant = active_asset
	library_choice = active_asset
	scopes = []
	for scope: Dictionary in value.get("scopes", []):
		var copy := scope.duplicate(true)
		copy.category = Workspace.category_for(copy.active_asset, copy.category)
		copy.parts = Kit.decode(scope.parts).parts
		Workspace.migrate_links(copy.parts, assets.keys())
		scopes.append(copy)
	insertion = {}
	dragging = false

func refresh_source() -> void:
	if source_label == null: return
	var path := source_path()
	source_label.text = path.get_file()
	source_label.tooltip_text = path

func source_path() -> String:
	var id := active_asset
	if selected >= 0: id = parts[selected].get("asset_ref", parts[selected].kind)
	elif not library_choice.is_empty(): id = library_choice
	if id in Kit.Appearance.SOURCE_COMPONENTS:
		return "res://data/settlement/" + Kit.Appearance.SOURCE_COMPONENTS[id][0] + ".tscn"
	if id in Kit.kinds():
		var path := "res://data/settlement/" + id
		return path + ".glb" if FileAccess.file_exists(path + ".glb") else path + ".tscn"
	if Kit.Appearance.imported(id): return Kit.Appearance.import_path(id)
	return "Workspace " + category

func reveal_source() -> void:
	var path := source_path()
	if path.begins_with("res://") or path.begins_with("user://"):
		OS.shell_show_in_file_manager(ProjectSettings.globalize_path(path))

func open_exchange(mode: String) -> void:
	exchange_mode = mode
	exchange_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE if mode == "export" else FileDialog.FILE_MODE_OPEN_FILE
	exchange_dialog.title = "Export for Blender" if mode == "export" else "Import Blender model"
	if mode == "export": exchange_dialog.current_file = host.draft.name.validate_filename() + ".glb"
	exchange_dialog.popup_centered_ratio(0.75)

func export_glb(path: String) -> bool:
	var node := Kit.Appearance.assembly_node(parts)
	node.name = "Blueprint"
	var document := GLTFDocument.new()
	var data := GLTFState.new()
	var result := document.append_from_scene(node, data)
	if result == OK: result = document.write_to_filesystem(data, path)
	node.free()
	return result == OK

func import_glb(path: String) -> bool:
	var document := GLTFDocument.new()
	var data := GLTFState.new()
	if document.append_from_file(path, data) != OK: return false
	var imported: Node3D = document.generate_scene(data)
	if imported == null: return false
	if Kit.meshes(imported).is_empty(): imported.free(); return false
	var id := "imported_%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(Kit.Appearance.mesh_directory))
	_own(imported, imported)
	var scene := PackedScene.new()
	var result := scene.pack(imported)
	if result == OK: result = ResourceSaver.save(scene, Kit.Appearance.import_path(id))
	imported.free()
	if result != OK: return false
	host._remember()
	parts = [{"kind": id, "at": Vector3.ZERO, "rotation": Vector3.ZERO, "label": path.get_file()}]
	if active_asset.is_empty(): active_asset = "custom_%d" % Time.get_ticks_usec()
	selected = -1
	selecting = true
	host._refresh()
	fit()
	return true

func _own(node: Node, owner: Node) -> void:
	for child in node.get_children():
		child.owner = owner
		_own(child, owner)
