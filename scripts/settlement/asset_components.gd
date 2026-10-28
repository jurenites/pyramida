extends RefCounted
## Named component selection and replacement share the existing assembly format.
const Kit = preload("res://scripts/settlement/structure_parts.gd")
const Workspace = preload("res://scripts/settlement/asset_workspace.gd")
const Tokens = preload("res://scripts/ui_visual_tokens.gd")
var _editor: WeakRef
var editor: RefCounted:
	get: return _editor.get_ref()
var picker: OptionButton
var group_button: Button
var name_edit: LineEdit
var store_button: Button
var replacement: OptionButton
var replace_button: Button
var groups: Dictionary = {}
var group_names: Array[String] = []
var replacement_ids: Array[String] = []
var inspected: Array[int] = []

func _init(owner: RefCounted) -> void:
	_editor = weakref(owner)

func create_selection_controls(parent: Control) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)
	picker = OptionButton.new()
	picker.fit_to_longest_item = false
	picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	picker.tooltip_text = "Select a named part or source group"
	picker.item_selected.connect(func(index):
		if index > 0: select_named(group_names[index - 1]))
	row.add_child(picker)
	group_button = editor.host._button(row, "Group", group_selection)
	group_button.tooltip_text = "Group selected parts · Ctrl/Cmd+G"

func create_inspector(parent: Control) -> void:
	name_edit = LineEdit.new()
	name_edit.placeholder_text = "Part name"
	name_edit.max_length = 80
	name_edit.text_submitted.connect(func(_text): rename_selection())
	name_edit.focus_exited.connect(rename_selection)
	parent.add_child(name_edit)
	store_button = editor.host._button(parent, "Add part to library", store_selection)
	store_button.tooltip_text = "Save this part or selection as a reusable asset"
	replacement = OptionButton.new()
	replacement.fit_to_longest_item = false
	replacement.item_selected.connect(func(_index): replace_button.disabled = replacement.selected == 0)
	parent.add_child(replacement)
	replace_button = editor.host._button(parent, "Replace", replace_selection)
	replace_button.tooltip_text = "Replace selected parts at their floor centre, keeping orientation and the new asset's dimensions"

func refresh() -> void:
	groups.clear()
	for index in editor.parts.size():
		var part: Dictionary = editor.parts[index]
		var title: String = part.get("label", "")
		var path: String = part.get("component", "")
		if title.is_empty() and path.contains("/"): title = path.get_slice("/", 0).capitalize()
		if title.is_empty() and ("wall" in path.to_lower() or "roof" in path.to_lower() or "floor" in path.to_lower()): title = path.capitalize()
		if title.is_empty(): continue
		if not groups.has(title): groups[title] = []
		groups[title].append(index)
	picker.clear()
	picker.add_item("Parts…")
	group_names.clear()
	for title: String in groups:
		group_names.append(title)
		picker.add_item(title)
	picker.disabled = groups.is_empty()
	var indices: Array[int] = editor.selection_indices()
	group_button.disabled = indices.size() < 2
	store_button.disabled = indices.is_empty()
	if indices != inspected or not name_edit.has_focus():
		name_edit.text = editor.parts[editor.selected].get("label", "") if indices.size() == 1 else ""
	inspected = indices.duplicate()
	var chosen := replacement_ids[replacement.selected - 1] if replacement.selected > 0 and replacement.selected <= replacement_ids.size() else ""
	replacement.clear()
	replacement.add_item("Replace with…")
	replacement_ids.clear()
	for id: String in editor.assets:
		if Workspace.library_group(editor.assets[id].category) != "asset" or editor.assets[id].parts.is_empty(): continue
		replacement_ids.append(id)
		replacement.add_item(editor.assets[id].name)
		if id == chosen: replacement.select(replacement_ids.size())
	replace_button.disabled = indices.is_empty() or replacement.selected == 0

func select_named(title: String) -> void:
	if not groups.has(title): return
	editor.gizmo.end_drag()
	editor.dragging = false
	var indices: Array[int] = []
	indices.assign(groups[title])
	editor.selected = indices.back()
	editor.selected_layers = indices
	editor.selecting = true
	editor.insertion = {}
	editor.host._refresh()

func group_selection() -> void:
	editor.group_selected()
	if editor.selected >= 0:
		name_edit.grab_focus()
		name_edit.select_all()

func rename_selection() -> void:
	if editor.updating or editor.selection_indices() != inspected or inspected.size() != 1: return
	var title := name_edit.text.strip_edges()
	if title.is_empty() or title == editor.parts[editor.selected].get("label", ""): return
	editor.host._remember()
	editor.parts[editor.selected].label = title
	editor.host._refresh()

static func floor_centre(bounds: AABB) -> Vector3:
	return Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z)

func frame() -> Transform3D:
	var part: Dictionary = editor.selection_part()
	var pose := Kit.transform(part)
	var anchor: Vector3 = pose * floor_centre(editor.gizmo.local_bounds(part))
	return Transform3D(pose.basis.orthonormalized(), anchor)

func store_selection() -> void:
	if editor.selection_indices().is_empty(): return
	if editor.assets.size() >= 128: editor.host._status("Library limit reached."); return
	var title := name_edit.text.strip_edges()
	if title.is_empty(): title = "Component"
	var parent_frame := frame()
	var children: Array = []
	for index in editor.selection_indices():
		var child: Dictionary = editor.parts[index].duplicate(true)
		var pose := parent_frame.affine_inverse() * Kit.transform(child)
		child.at = pose.origin
		child.rotation = Vector3.ZERO
		child.basis = pose.basis
		child.erase("scale")
		children.append(child)
	var group := {"kind": "assembly", "at": Vector3.ZERO, "rotation": Vector3.ZERO, "children": children}
	if Kit.decode(Kit.encode([group])).is_empty(): return
	var bounds := Kit.bounds(group)
	var volume := Workspace.Contract.make(bounds.size.max(Vector3.ONE * 0.01), floor_centre(bounds))
	if not editor.multiple_selected(): volume.mount = editor.parts[editor.selected].get("contract", {}).get("mount", "floor")
	var id := "custom_%d" % Time.get_ticks_usec()
	editor.host._remember()
	editor.assets[id] = {"name": title, "category": "component", "parts": children, "contract": volume}
	editor.library_choice = id
	editor.host._refresh()

func replace_selection() -> void:
	var indices: Array[int] = editor.selection_indices()
	if indices.is_empty() or replacement.selected <= 0: return
	var id := replacement_ids[replacement.selected - 1]
	var item: Dictionary = editor.library_instance(id)
	var target := frame()
	var anchor := floor_centre(Kit.bounds(item))
	item.at = target.origin - target.basis * anchor
	item.basis = target.basis
	if indices.size() == 1 and editor.parts[editor.selected].has("label"): item.label = editor.parts[editor.selected].label
	indices.sort()
	var proposed: Array = editor.parts.duplicate(true)
	for i in range(indices.size() - 1, -1, -1): proposed.remove_at(indices[i])
	proposed.insert(indices[0], item)
	var document := proposed
	for i in range(editor.scopes.size() - 1, -1, -1):
		var parent: Array = editor.scopes[i].parts.duplicate(true)
		parent[editor.scopes[i].index].children = document
		document = parent
	if Kit.decode(Kit.encode(document)).is_empty() or not Workspace.resolve(document.duplicate(true), editor.assets, [editor.scopes[0].active_asset if not editor.scopes.is_empty() else editor.active_asset]):
		editor.host._status("Component would create a circular or oversized assembly.")
		return
	editor.gizmo.end_drag()
	editor.dragging = false
	editor.host._remember()
	editor.parts = proposed
	editor.selected = indices[0]
	editor.selecting = true
	editor.insertion = {}
	editor.host._refresh()
