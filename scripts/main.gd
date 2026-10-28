extends Node3D

const Palette = preload("res://scripts/game_palette.gd")
const GrassRendererScript = preload("res://scripts/grass_renderer.gd")
const UIText = preload("res://scripts/ui_text_catalog.gd")
const MessageCatalog = preload("res://scripts/actor_message_catalog.gd")
const ActionCatalog = preload("res://scripts/gameplay_action_catalog.gd")
const ActorMessageBusScript = preload("res://scripts/actor_message_bus.gd")
const SpeechBubbleOverlayScript = preload("res://scripts/speech_bubble_overlay.gd")
const PixelUITheme = preload("res://scripts/pixel_ui.gd")
const BuildMetadata = preload("res://scripts/build_info.gd")
const ExcavationSiteScript = preload("res://scripts/excavation_site.gd")
const DeterministicRandomScript = preload("res://scripts/deterministic_random.gd")
const GridNavigationScript = preload("res://scripts/grid_navigation.gd")
const CitizenNavigationPolicyScript = preload("res://scripts/citizen_navigation_policy.gd")
const AppliedLabourScript = preload("res://scripts/applied_labour.gd")
const LabourProgressBarScript = preload("res://scripts/labour_progress_bar.gd")
const PileStorageScript = preload("res://scripts/pile_storage.gd")
const TerrainBlockScript = preload("res://scripts/terrain_block.gd")
const BuildingCatalogScript = preload("res://scripts/building_catalog.gd")
const GameplaySettingsScript = preload("res://scripts/gameplay_settings.gd")
const ObjAssetScript = preload("res://scripts/obj_asset.gd")
const CitizenCommandOverlayScript = preload("res://scripts/citizen_command_overlay.gd")
const WorldStreamerScript = preload("res://scripts/world_streamer.gd")
const WorldGenerationProfileScript = preload("res://scripts/world_generation_profile.gd")
const VisualTokens = preload("res://scripts/ui_visual_tokens.gd")
const ToolbarIcons = preload("res://scripts/toolbar_icon_renderer.gd")
const IconNumberScript = preload("res://scripts/icon_number.gd")
const ConstructionInspectorScript = preload("res://scripts/construction_inspector.gd")
const ConstructionProgressScript = preload("res://scripts/construction_progress.gd")
const CompassWidgetScript = preload("res://scripts/compass_widget.gd")
const TERRAIN_SHADER := preload("res://shaders/terrain.gdshader")
const FOG_SHADER := preload("res://shaders/fog.gdshader")
const PIXEL_FILTER_SHADER := preload("res://shaders/pixel_filter.gdshader")
const WORLD_OBJECT_OUTLINE_SHADER := preload("res://shaders/world_object_outline.gdshader")
const BACKGROUND_HALF_EXTENT := 128.0
const FOG_CELL_SIZE := 0.5
const REVEAL_RADIUS := 4.0
const CAMERA_PAN_SPEED := 8.0
const CAMERA_ROTATION_SENSITIVITY := 0.008
const CAMERA_TILT_LIMIT := 0.174532925
const DEFAULT_CAMERA_YAW := PI * 0.25
const DEFAULT_CAMERA_PITCH := 0.689775
const CAMERA_DISTANCE := 22.0
const CAMERA_MINIMUM_SIZE := 17.0
const DEFAULT_CAMERA_SIZE := 34.0
const CAMERA_MAXIMUM_SIZE := DEFAULT_CAMERA_SIZE
const CAMERA_ZOOM_STEP := 1.0
const CAMERA_TRACKPAD_ZOOM_SCALE := 0.8
const CAMERA_RESET_DURATION_SECONDS := 0.5
const CITIZEN_CAMERA_MINIMUM_DURATION_SECONDS := 0.1
const CITIZEN_CAMERA_MAXIMUM_DURATION_SECONDS := 0.5
const SELECTION_DRAG_THRESHOLD := 6.0
const PIXEL_BLOCK_SIZE := 2.0
const SHOW_DEBUG_OVERLAY := false
const CLOUDS_ENABLED := false
const HOVER_REFRESH_INTERVAL := 0.08
const HOVER_DELAY_SECONDS := 0.25
const HOVER_FADE_SPEED := 5.0
const TOOLTIP_EDGE_THRESHOLD_PIXELS := 80.0
const SIMULATION_SPEED_OPTIONS := [1.0, 2.0, 4.0]
const ONBOARDING_STATE_PATH := "user://onboarding.cfg"
const WORLD_GENERATION_PROFILE_PATH := "user://world_generation_profile.json"
const SUPPORT_CONSTRUCTION_SITE_ASSET_PATH := "res://data/buildings/support_construction_site.obj"

var _camera: Camera3D
var _support_footprint_quadrant_offsets: Array[Vector2] = []
var _day_length_seconds := WorldItem.SIMULATION_DAY_SECONDS
var _sun: DirectionalLight3D
var _environment: Environment
var _ground_material: ShaderMaterial
var _world_chunks_root: Node3D
var _world_generation_profile
var _loaded_chunks: Dictionary = {}
var _chunk_fog_images: Dictionary = {}
var _chunk_fog_textures: Dictionary = {}
var _chunk_fog_materials: Dictionary = {}
var _streamed_items_by_chunk: Dictionary = {}
var _streamed_item_states: Dictionary = {}
var _streamed_entity_tombstones: Dictionary = {}
var _discovered_fog_by_chunk: Dictionary = {}
var _citizen_command_overlay
var _selected_world_object: Node3D
var _selection_outline_root: MultiMeshInstance3D
var _selection_outline_mesh: BoxMesh
var _selection_mesh_outline_target: Node3D
var _selection_mesh_outlines: Array[MeshInstance3D] = []
var _hover_mesh_outline_target: Node3D
var _hover_mesh_outlines: Array[MeshInstance3D] = []
var _hover_ground_outline_root: MultiMeshInstance3D
var _hover_ground_outline_mesh: BoxMesh
var _mesh_outline_material: ShaderMaterial
var _selected_ground_cell := Vector2i.ZERO
var _has_selected_ground_cell := false
var _grass_renderer: Node3D
var _revealed_fog_cells: Dictionary = {}
var _occupied_bush_world_units: Dictionary = {}
var _occupied_static_world_units: Dictionary = {}
var _selected_citizen: Citizen
var _selected_citizens: Array[Citizen] = []
var _citizens: Array[Citizen] = []
var _items: Array[WorldItem] = []
var _construction_sites: Array[SupportConstructionSite] = []
var _placed_piles: Array[PileStorage] = []
var _excavation_sites: Array[ExcavationSite] = []
var _excavated_cells: Dictionary = {}
var _excavated_pit_roots: Dictionary = {}
var _terrain_blocks: Dictionary = {}
var _road_travel_costs: Dictionary = {}
var _starting_pile: PileStorage
var _build_mode := false
var _greenery_mode := false
var _selected_greenery: WorldItem
var _landscape_mode := false
var _landscape_tool := "remove"
var _placing_support := false
var _placing_building_id := "support"
var _placing_excavation := false
var _removing_buildings := false
var _selected_building: SupportConstructionSite
var _support_placement_preview: SupportConstructionSite
var _support_preview_geometry: Array[GeometryInstance3D] = []
var _support_preview_quadrants: Array[MeshInstance3D] = []
var _support_preview_allowed_material: StandardMaterial3D
var _support_preview_blocked_material: StandardMaterial3D
var _deconstruction_hover_target: Node3D
var _deconstruction_original_materials: Dictionary = {}
var _deconstruction_preview_material: StandardMaterial3D
var _calories := 0
var _water := 0
var _ui_status: Label
var _ui_resources: Label
var _ui_mode: Label
var _selection_box: Panel
var _rts_count_badge: Label
var _toolbar_tooltip: PanelContainer
var _toolbar_tooltip_label: Label
var _top_toolbar: HBoxContainer
var _population_icon_number: IconNumber
var _pile_inventory_row: HBoxContainer
var _pile_inventory_signature := ""
var _building_button: Button
var _greenery_button: Button
var _landscape_button: Button
var _simulation_speed_button: Button
var _remove_building_button: Button
var _build_menu: PanelContainer
var _build_category := BuildingCatalogScript.CATEGORY_STRUCTURE
var _build_category_buttons: Dictionary = {}
var _build_catalog_row: HBoxContainer
var _landscape_menu: PanelContainer
var _landscape_add_button: Button
var _landscape_remove_button: Button
var _hover_tooltip: Label
var _cursor_texture: ImageTexture
var _hover_refresh_remaining := 0.0
var _debug_hover_enabled := false
var _hover_candidate_key := ""
var _hover_stable_elapsed := 0.0
var _hover_target_visible := false
var _hover_alpha := 0.0
var _hover_last_mouse_position := Vector2(-1000.0, -1000.0)
var _day_label: Label
var _build_stamp_label: Label
var _building_hotkey_hint: PanelContainer
var _building_hotkey_hint_label: Label
var _building_rotation_tween: Tween
var _day_night_wheel: TextureRect
var _world_progress_layer: CanvasLayer
var _construction_inspector: ConstructionInspector
var _active_work: Dictionary = {}
var _labour_records: Dictionary = {}
var _actor_message_bus: ActorMessageBus
var _speech_bubble_overlay: SpeechBubbleOverlay
var _speech_command_sequence := 0
var _onboarding_layer: CanvasLayer
var _selection_press_active := false
var _selection_drag_start := Vector2.ZERO
var _selection_drag_current := Vector2.ZERO
var _camera_focus := Vector3.ZERO
var _camera_yaw := DEFAULT_CAMERA_YAW
var _camera_pitch := DEFAULT_CAMERA_PITCH
var _camera_size := DEFAULT_CAMERA_SIZE
var _camera_reset_tween: Tween
var _citizen_camera_tween: Tween
var _citizen_camera_cycle_index := -1
var _right_drag_active := false
var _right_dragged := false
var _right_drag_start := Vector2.ZERO
var _right_drag_last := Vector2.ZERO
var _clouds_root: Node3D
var _cloud_velocities: Dictionary = {}
var _cloud_shadow_offset := Vector2.ZERO
var _compass_widget := CompassWidgetScript.new()
var _elapsed := 0.0
var _simulation_speed := 1.0
var _citizens_are_sleeping := false


func _ready() -> void:
	_support_footprint_quadrant_offsets = ObjAssetScript.object_centres_xz(
		SUPPORT_CONSTRUCTION_SITE_ASSET_PATH,
		"placement_quadrant_"
	)
	_load_or_create_world_generation_profile()
	_create_environment()
	_create_ground()
	_create_camera()
	_create_clouds()
	_create_citizen_command_overlay()
	_create_interface()
	_create_actor_speech_system()
	_create_custom_cursor()
	_create_first_launch_onboarding()
	_create_pixel_filter()
	_seed_world()
	_create_grass_renderer()
	_update_world_streaming(true)
	_reveal_world_around_citizens()
	_apply_pixel_font_to_controls(self)
	_update_interface()


func _load_or_create_world_generation_profile() -> void:
	_world_generation_profile = WorldGenerationProfileScript.load_from_path(WORLD_GENERATION_PROFILE_PATH)
	if _world_generation_profile != null:
		return
	_world_generation_profile = WorldGenerationProfileScript.create_default()
	var save_error: Error = _world_generation_profile.save_to_path(WORLD_GENERATION_PROFILE_PATH)
	if save_error != OK:
		push_warning("World generation profile could not be persisted: %s" % error_string(save_error))


func _process(delta: float) -> void:
	var simulation_delta := delta * _simulation_speed
	_elapsed += simulation_delta
	_update_day_night()
	_update_camera_pan(delta)
	_update_clouds(simulation_delta)
	_hover_refresh_remaining -= delta
	if _hover_refresh_remaining <= 0.0:
		_hover_refresh_remaining = HOVER_REFRESH_INTERVAL
	_update_hover_target(delta)
	_update_hover_transition(delta)
	_update_mesh_outline_viewport()
	_update_world_selection_outline()
	_update_building_hotkey_hint()
	_update_support_placement_preview()
	_update_deconstruction_hover_preview()
	_update_world_streaming()
	if is_instance_valid(_grass_renderer):
		_grass_renderer.update_viewer_position(_camera_focus)
	_reveal_world_around_citizens()
	if is_instance_valid(_citizen_command_overlay):
		_citizen_command_overlay.update_citizens(_selected_citizens)
	_update_labour(simulation_delta)
	_update_selected_construction_inspector()
	_update_interface()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if not mouse_event.pressed:
			return
		if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_adjust_camera_zoom(-CAMERA_ZOOM_STEP)
			get_viewport().set_input_as_handled()
		elif mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_adjust_camera_zoom(CAMERA_ZOOM_STEP)
			get_viewport().set_input_as_handled()
	elif event is InputEventPanGesture:
		var pan_event := event as InputEventPanGesture
		if absf(pan_event.delta.y) > 0.01:
			_adjust_camera_zoom(pan_event.delta.y * CAMERA_TRACKPAD_ZOOM_SCALE)
			get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		_handle_key_input(event)
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event)
	elif event is InputEventMouseButton:
		_handle_mouse_button(event)


func _handle_key_input(event: InputEventKey) -> void:
	if not event.pressed or event.echo:
		return
	if event.keycode == KEY_F1:
		_show_onboarding()
		return
	if event.keycode == KEY_F2:
		get_tree().change_scene_to_file("res://scenes/BuildingBlueprintEditor.tscn")
		return
	if is_instance_valid(_onboarding_layer) and _onboarding_layer.visible:
		_complete_onboarding()
		return
	match event.keycode:
		KEY_BACKSPACE:
			_try_delete_selected_object()
		KEY_R:
			_rotate_selected_building(-1 if event.shift_pressed else 1)
		KEY_F3:
			_debug_hover_enabled = not _debug_hover_enabled
			_update_hover_target(0.0)
		KEY_B:
			_toggle_build_menu()
		KEY_ESCAPE:
			if _landscape_mode:
				_leave_landscape_mode()
			elif _greenery_mode:
				_leave_greenery_mode()
			elif is_instance_valid(_build_menu) and _build_menu.visible:
				_build_menu.visible = false
			else:
				_leave_build_mode()
		_:
			pass


func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	if _right_drag_active:
		_cancel_camera_reset_tween()
		_cancel_citizen_camera_tween()
		var drag_delta: Vector2 = event.position - _right_drag_last
		_right_drag_last = event.position
		if _right_drag_start.distance_to(event.position) >= SELECTION_DRAG_THRESHOLD:
			_right_dragged = true
		_camera_yaw -= drag_delta.x * CAMERA_ROTATION_SENSITIVITY
		_camera_pitch = clampf(
			_camera_pitch - drag_delta.y * CAMERA_ROTATION_SENSITIVITY,
			DEFAULT_CAMERA_PITCH - CAMERA_TILT_LIMIT,
			DEFAULT_CAMERA_PITCH + CAMERA_TILT_LIMIT
		)
		_update_camera_transform()
	elif _selection_press_active:
		_selection_drag_current = event.position
		_update_selection_box()


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_begin_selection_drag(event.position)
		else:
			_finish_selection_drag(event.position, event.alt_pressed, event.ctrl_pressed)
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		_handle_right_mouse_button(event)


func _handle_right_mouse_button(event: InputEventMouseButton) -> void:
	if event.pressed:
		_right_drag_active = true
		_right_dragged = false
		_right_drag_start = event.position
		_right_drag_last = event.position
		return
	_right_drag_active = false
	if _right_dragged:
		return
	if _build_mode:
		_leave_build_mode()
	elif _landscape_mode:
		_leave_landscape_mode()
	elif _greenery_mode:
		_leave_greenery_mode()
	else:
		_handle_command_order(event.position)


func _handle_world_click(screen_position: Vector2, exact_selection := false, keep_placing := false) -> void:
	if _removing_buildings:
		var remove_hit := _raycast(screen_position)
		if remove_hit.is_empty():
			return
		var remove_collider: Node = remove_hit.get("collider") as Node
		_remove_world_object(_world_object_for(remove_collider))
		return
	if _landscape_mode:
		_handle_landscape_click(screen_position)
		return
	if _greenery_mode:
		_handle_greenery_click(screen_position)
		return
	if not _placing_support and not exact_selection:
		var priority_citizen := _citizen_at_screen_point(screen_position)
		if priority_citizen != null:
			_select_only(priority_citizen)
			priority_citizen.status_text_key = UIText.CITIZEN_SELECTED_STATUS_TEXT
			priority_citizen.status_text_arguments.clear()
			return

	var hit: Dictionary = _raycast(screen_position)
	if hit.is_empty():
		if not _build_mode:
			_set_selected_citizens([])
			_clear_object_selection()
		return
	var collider: Node = hit.get("collider") as Node
	var world_object: Variant = _world_object_for(collider)

	if _placing_support:
		var construction_site_position := _building_placement_position(hit.position, _placing_building_id)
		var placement := _building_placement_evaluation(construction_site_position, _placing_building_id)
		if bool(placement.get("valid", false)):
			_place_building(construction_site_position, _placing_building_id, keep_placing)
		return
	if _placing_excavation:
		if collider != null and collider.get_meta("world_kind", "") == "ground":
			_place_excavation_site(_world_unit_cell(hit.position), keep_placing)
		return

	if world_object is SupportConstructionSite:
		_select_building(world_object as SupportConstructionSite)
		return
	if world_object is ExcavationSite:
		_set_selected_citizens([])
		_select_world_object(world_object as ExcavationSite)
		return
	if world_object is PileStorage:
		_set_selected_citizens([])
		_select_world_object(world_object as PileStorage)
		return

	if world_object is Citizen:
		_select_only(world_object)
		(world_object as Citizen).status_text_key = UIText.CITIZEN_SELECTED_STATUS_TEXT
		(world_object as Citizen).status_text_arguments.clear()
		return

	if world_object is WorldItem:
		_select_world_object(world_object as Node3D)
		return

	if collider != null and collider.get_meta("world_kind", "") == "ground":
		_set_selected_citizens([])
		_leave_build_mode()
		_select_ground_tile(hit.position)


func _handle_greenery_click(screen_position: Vector2) -> void:
	var hit := _raycast(screen_position)
	if hit.is_empty():
		return
	var hit_position: Vector3 = hit.get("position", Vector3.ZERO)
	if not _is_world_position_revealed(hit_position):
		return
	var collider := hit.get("collider") as Node
	var world_object: Variant = _world_object_for(collider)
	if world_object is WorldItem:
		var item := world_object as WorldItem
		if item.item_kind in ["bush", "stump"]:
			_selected_greenery = item
			_select_world_object(item)
		return
	if collider != null and collider.get_meta("world_kind", "") == "ground":
		if not is_instance_valid(_selected_greenery):
			_select_ground_tile(hit.position)
			return
		if not _try_relocate_selected_greenery(hit_position):
			_shake_world_object(_selected_greenery)


func _try_relocate_selected_greenery(destination_position: Vector3) -> bool:
	if (
		not _greenery_mode
		or not is_instance_valid(_selected_greenery)
		or _selected_greenery.item_kind not in ["bush", "stump"]
	):
		return false
	var source_cell := _world_unit_cell(_selected_greenery.global_position)
	var destination_cell := _world_unit_cell(destination_position)
	if destination_cell == source_cell:
		return true
	if not _greenery_destination_is_available(destination_cell, _selected_greenery):
		return false

	_cancel_jobs_targeting_removed_object(_selected_greenery)
	_occupied_static_world_units.erase(source_cell)
	if _selected_greenery.item_kind == "bush":
		_occupied_bush_world_units.erase(source_cell)
	for other_item in _items:
		if (
			is_instance_valid(other_item)
			and other_item != _selected_greenery
			and not other_item.is_carried
			and _world_unit_cell(other_item.global_position) == source_cell
		):
			_occupied_static_world_units[source_cell] = true
			if other_item.item_kind == "bush":
				_occupied_bush_world_units[source_cell] = true
	_detach_streamed_greenery_for_relocation(_selected_greenery)

	var within_cell_offset := Vector2(
		_selected_greenery.global_position.x - float(source_cell.x) - 0.5,
		_selected_greenery.global_position.z - float(source_cell.y) - 0.5
	)
	within_cell_offset.x = clampf(within_cell_offset.x, -0.27, 0.27)
	within_cell_offset.y = clampf(within_cell_offset.y, -0.27, 0.27)
	_selected_greenery.global_position = Vector3(
		float(destination_cell.x) + 0.5 + within_cell_offset.x,
		0.0,
		float(destination_cell.y) + 0.5 + within_cell_offset.y
	)
	_occupied_static_world_units[destination_cell] = true
	if _selected_greenery.item_kind == "bush":
		_occupied_bush_world_units[destination_cell] = true
		if is_instance_valid(_grass_renderer):
			_grass_renderer.exclude_world_unit(destination_cell)
	_update_world_selection_outline()
	return true


func _greenery_destination_is_available(destination_cell: Vector2i, moving_item: WorldItem) -> bool:
	if not _is_inside_playable_world(_cell_centre(destination_cell)):
		return false
	if _excavated_cells.has(destination_cell):
		return false
	if _occupied_static_world_units.has(destination_cell):
		return false
	if _terrain_blocks.has(Vector3i(destination_cell.x, 0, destination_cell.y)):
		return false
	for item in _items:
		if (
			is_instance_valid(item)
			and item != moving_item
			and not item.is_carried
			and _world_unit_cell(item.global_position) == destination_cell
		):
			return false
	for construction_site in _construction_sites:
		if (
			is_instance_valid(construction_site)
			and _world_unit_cell(construction_site.global_position) == destination_cell
		):
			return false
	for excavation_site in _excavation_sites:
		if (
			is_instance_valid(excavation_site)
			and _world_unit_cell(excavation_site.global_position) == destination_cell
		):
			return false
	return true


func _detach_streamed_greenery_for_relocation(item: WorldItem) -> void:
	if str(item.get_meta("stream_entity_id", "")).is_empty():
		return
	# Moving generated greenery is a player-authored world delta: suppress its
	# original seeded copy and keep this node as a runtime item at the new cell.
	_mark_streamed_entity_removed(item)
	item.remove_meta("stream_entity_id")
	item.remove_meta("stream_chunk")
	item.remove_meta("stream_dirty")


func _handle_landscape_click(screen_position: Vector2) -> void:
	var hit := _raycast(screen_position)
	if hit.is_empty():
		return
	var hit_position: Vector3 = hit.get("position", Vector3.ZERO)
	if not _is_world_position_revealed(hit_position):
		return
	var collider := hit.get("collider") as Node
	var world_object: Variant = _world_object_for(collider)
	if _landscape_tool == "remove":
		if world_object is TerrainBlock:
			_remove_terrain_block((world_object as TerrainBlock).block_coordinate)
		elif collider != null and collider.get_meta("world_kind", "") == "ground":
			_remove_base_terrain_block(_world_unit_cell(hit_position))
		return
	if _landscape_tool != "add":
		return
	if world_object is TerrainBlock:
		var source_coordinate := (world_object as TerrainBlock).block_coordinate
		var hit_normal: Vector3 = hit.get("normal", Vector3.UP)
		var face_offset := Vector3i(
			roundi(hit_normal.x),
			roundi(hit_normal.y),
			roundi(hit_normal.z)
		)
		var target_coordinate := source_coordinate + face_offset
		if target_coordinate.y == -1:
			_restore_base_terrain_block(Vector2i(target_coordinate.x, target_coordinate.z))
		else:
			_place_terrain_block(target_coordinate)
	elif collider != null and collider.get_meta("world_kind", "") == "ground":
		var ground_cell := _world_unit_cell(hit_position)
		if _excavated_cells.has(ground_cell):
			_restore_base_terrain_block(ground_cell)
		else:
			_place_terrain_block(Vector3i(ground_cell.x, 0, ground_cell.y))


func _remove_base_terrain_block(world_cell: Vector2i) -> bool:
	if (
		_excavated_cells.has(world_cell)
		or not _is_inside_playable_world(_cell_centre(world_cell))
		or _surface_cell_has_occupant(world_cell)
	):
		return false
	_excavated_cells[world_cell] = true
	_create_excavated_pit(world_cell)
	_update_excavated_ground_mask()
	if is_instance_valid(_grass_renderer):
		_grass_renderer.exclude_world_unit(world_cell)
	_select_ground_tile(_cell_centre(world_cell))
	return true


func _restore_base_terrain_block(world_cell: Vector2i) -> bool:
	if not _excavated_cells.has(world_cell):
		return false
	_excavated_cells.erase(world_cell)
	if _excavated_pit_roots.has(world_cell):
		var pit_root := _excavated_pit_roots[world_cell] as Node3D
		_excavated_pit_roots.erase(world_cell)
		if is_instance_valid(pit_root):
			pit_root.queue_free()
	_update_excavated_ground_mask()
	_select_ground_tile(_cell_centre(world_cell))
	return true


func _place_terrain_block(block_coordinate: Vector3i) -> bool:
	if block_coordinate.y < 0 or block_coordinate.y > 255:
		return false
	var horizontal_cell := Vector2i(block_coordinate.x, block_coordinate.z)
	if not _is_inside_playable_world(_cell_centre(horizontal_cell)):
		return false
	if _terrain_blocks.has(block_coordinate):
		return false
	if block_coordinate.y == 0 and _surface_cell_has_occupant(horizontal_cell):
		return false
	var terrain_block := TerrainBlockScript.new() as TerrainBlock
	terrain_block.configure(block_coordinate)
	add_child(terrain_block)
	_terrain_blocks[block_coordinate] = terrain_block
	if block_coordinate.y == 0 and is_instance_valid(_grass_renderer):
		_grass_renderer.exclude_world_unit(horizontal_cell)
	_select_world_object(terrain_block)
	return true


func _remove_terrain_block(block_coordinate: Vector3i) -> bool:
	if not _terrain_blocks.has(block_coordinate):
		return false
	var terrain_block := _terrain_blocks[block_coordinate] as TerrainBlock
	_terrain_blocks.erase(block_coordinate)
	if _selected_world_object == terrain_block:
		_clear_object_selection()
	if is_instance_valid(terrain_block):
		terrain_block.queue_free()
	return true


func _surface_cell_has_occupant(world_cell: Vector2i) -> bool:
	if _occupied_static_world_units.has(world_cell):
		return true
	if _terrain_blocks.has(Vector3i(world_cell.x, 0, world_cell.y)):
		return true
	for construction_site in _construction_sites:
		if (
			is_instance_valid(construction_site)
			and _world_unit_cell(construction_site.global_position) == world_cell
		):
			return true
	for excavation_site in _excavation_sites:
		if (
			is_instance_valid(excavation_site)
			and _world_unit_cell(excavation_site.global_position) == world_cell
		):
			return true
	for citizen in _citizens:
		if is_instance_valid(citizen) and _world_unit_cell(citizen.global_position) == world_cell:
			return true
	return false



func _handle_command_order(screen_position: Vector2) -> void:
	if _selected_citizens.is_empty():
		return
	var hit: Dictionary = _raycast(screen_position)
	if hit.is_empty():
		return
	var collider: Node = hit.get("collider") as Node
	var world_object: Variant = _world_object_for(collider)
	var hit_position: Vector3 = hit.get("position", Vector3.ZERO)
	# Fog takes priority over every contextual command. Hidden objects retain
	# collision for navigation, but clicking one must never reveal its identity
	# by assigning work. Discovery also does not mutate this MOVE task later.
	var command_is_revealed := _is_world_position_revealed(hit_position)
	if world_object is Node3D:
		command_is_revealed = command_is_revealed and _is_world_position_revealed(
			(world_object as Node3D).global_position
		)
	if not command_is_revealed:
		_issue_group_move(hit_position)
		return
	if world_object is SupportConstructionSite:
		var support := world_object as SupportConstructionSite
		if support.is_complete():
			if support.is_workshop():
				_order_process_sawmill(_selected_citizen, support)
			else:
				_order_enter_completed_building(_selected_citizen, support)
		else:
			var woke_from_sleep := _wake_for_direct_order(_selected_citizen)
			if not woke_from_sleep:
				_selected_citizen.set_work_assignment({"kind": "construction"})
			_actor_message_bus.post_message(_selected_citizen, MessageCatalog.CONFIRM_CONSTRUCTION, {
				"cluster_scope": _next_speech_command_scope(),
			})
			_continue_build(_selected_citizen, support)
		return
	if world_object is ExcavationSite:
		_order_excavate(_selected_citizen, world_object as ExcavationSite)
		return
	if world_object is WorldItem:
		var item := world_object as WorldItem
		if item.item_kind in ["tree", "dead_tree", "palm_tree"]:
			_order_group_chop(item)
		elif item.item_kind == "bush":
			_order_harvest(_selected_citizen, item)
		elif item.item_kind == "cactus":
			_order_collect_cactus(_selected_citizen, item)
		return
	if collider != null and collider.get_meta("world_kind", "") == "ground":
		_issue_group_move(hit_position)


func _issue_group_move(world_target: Vector3) -> void:
	if _selected_citizens.is_empty():
		return
	var target_cell := _world_unit_cell(world_target)
	var citizen_count := _selected_citizens.size()
	for citizen_index in citizen_count:
		var citizen := _selected_citizens[citizen_index]
		if not is_instance_valid(citizen):
			continue
		_wake_for_direct_order(citizen)
		citizen.clear_work_assignment()
		# Every selected Citizen converges into the clicked World Unit. Separate
		# compact slots prevent overlap without preserving a parallel formation.
		var target_offset := _group_target_offset(citizen_index, citizen_count)
		var citizen_target := Vector3(
			float(target_cell.x) + 0.5 + target_offset.x,
			0.0,
			float(target_cell.y) + 0.5 + target_offset.y
		)
		_assign_group_navigation_task(citizen, citizen_target, target_offset)
		# Movement is confirmed by the selected Citizen's outlined contact shadow and
		# route preview. Movement orders deliberately produce no speech bubble.


func _group_target_offset(citizen_index: int, citizen_count: int) -> Vector2:
	if citizen_count <= 1:
		return Vector2.ZERO
	var column_count := mini(3, ceili(sqrt(float(citizen_count))))
	var row_count := ceili(float(citizen_count) / float(column_count))
	var spacing := 0.5 if maxi(column_count, row_count) <= 2 else 0.32
	var column := citizen_index % column_count
	var row := floori(float(citizen_index) / float(column_count))
	return Vector2(
		(float(column) - float(column_count - 1) * 0.5) * spacing,
		(float(row) - float(row_count - 1) * 0.5) * spacing
	)


func _wake_for_direct_order(citizen: Citizen) -> bool:
	if not is_instance_valid(citizen) or not citizen.is_sleeping():
		return false
	# A player order overrides sleep and the old assignment. Clearing the task
	# before waking avoids resuming its route through Citizen.set_sleeping(false).
	_cancel_active_work(citizen)
	citizen.finish_task()
	citizen.clear_work_assignment()
	citizen.set_sleeping(false)
	return true


func _assign_group_navigation_task(
	citizen: Citizen,
	target_position: Vector3,
	lane_offset: Vector2
) -> bool:
	_cancel_active_work(citizen)
	target_position = _clamp_to_playable_world(target_position)
	var route_plan := _navigation_route_plan(citizen.global_position, target_position, false)
	var route: Array[Vector3] = []
	route.assign(route_plan.get("route", []))
	if route.is_empty():
		citizen.finish_task(UIText.CITIZEN_NO_ROUTE_STATUS_TEXT)
		return false
	# A* owns the World-Unit sequence. The compact lane offset is applied to its
	# intermediate centres so group members do not walk through one coordinate.
	for route_index in maxi(0, route.size() - 1):
		var route_point := route[route_index]
		route[route_index] = _clamp_to_playable_world(Vector3(
			route_point.x + lane_offset.x,
			route_point.y,
			route_point.z + lane_offset.y
		))
	var is_emergency_escape := bool(route_plan.get("emergency_escape", false))
	var escape_delay := (
		CitizenNavigationPolicyScript.EMERGENCY_ESCAPE_DELAY_SECONDS
		if is_emergency_escape else 0.0
	)
	citizen.assign_route(
		route,
		{
			"kind": ActionCatalog.MOVE,
			"status_text_key": UIText.CITIZEN_WALKING_STATUS_TEXT,
			"emergency_escape": is_emergency_escape,
		},
		_road_travel_costs,
		escape_delay
	)
	return true


func _begin_selection_drag(screen_position: Vector2) -> void:
	_selection_press_active = true
	_selection_drag_start = screen_position
	_selection_drag_current = screen_position
	if _selection_box != null:
		_selection_box.visible = false


func _finish_selection_drag(screen_position: Vector2, exact_selection := false, keep_placing := false) -> void:
	if not _selection_press_active:
		return
	_selection_drag_current = screen_position
	_selection_press_active = false
	var drag_distance := _selection_drag_start.distance_to(_selection_drag_current)
	if _selection_box != null:
		_selection_box.visible = false
	if (
		drag_distance >= SELECTION_DRAG_THRESHOLD
		and not _build_mode
		and not _greenery_mode
		and not _landscape_mode
	):
		_select_citizens_in_screen_rect(_selection_screen_rect())
	else:
		_handle_world_click(screen_position, exact_selection, keep_placing)


func _update_selection_box() -> void:
	if _selection_box == null:
		return
	if _selection_drag_start.distance_to(_selection_drag_current) < SELECTION_DRAG_THRESHOLD:
		_selection_box.visible = false
		return
	var selection_rect := _selection_screen_rect()
	_selection_box.position = selection_rect.position
	_selection_box.size = selection_rect.size
	_selection_box.visible = not _build_mode and not _greenery_mode and not _landscape_mode


func _selection_screen_rect() -> Rect2:
	var minimum := Vector2(
		minf(_selection_drag_start.x, _selection_drag_current.x),
		minf(_selection_drag_start.y, _selection_drag_current.y)
	)
	var maximum := Vector2(
		maxf(_selection_drag_start.x, _selection_drag_current.x),
		maxf(_selection_drag_start.y, _selection_drag_current.y)
	)
	return Rect2(minimum, maximum - minimum)


func _select_citizens_in_screen_rect(selection_rect: Rect2) -> void:
	var next_selection: Array[Citizen] = []
	for citizen in _citizens:
		if not is_instance_valid(citizen):
			continue
		var selection_point := citizen.selection_world_position()
		if _camera.is_position_behind(selection_point):
			continue
		if selection_rect.has_point(_camera.unproject_position(selection_point)):
			next_selection.append(citizen)
	_set_selected_citizens(next_selection)


func _citizen_at_screen_point(screen_position: Vector2) -> Citizen:
	var closest: Citizen
	var closest_distance := 24.0
	for citizen in _citizens:
		if not is_instance_valid(citizen):
			continue
		var selection_point := citizen.selection_world_position()
		if _camera.is_position_behind(selection_point):
			continue
		var screen_distance := screen_position.distance_to(_camera.unproject_position(selection_point))
		if screen_distance < closest_distance:
			closest = citizen
			closest_distance = screen_distance
	return closest


func _set_selected_citizens(next_selection: Array[Citizen]) -> void:
	_selected_citizens = next_selection.duplicate()
	_selected_citizen = _selected_citizens[0] if not _selected_citizens.is_empty() else null
	if not _selected_citizens.is_empty():
		_clear_deconstruction_hover_preview()
		_clear_object_selection()
		_build_mode = false
		_greenery_mode = false
		_selected_greenery = null
		_landscape_mode = false
		_placing_support = false
		_placing_excavation = false
		_removing_buildings = false
		_selected_building = null
		if is_instance_valid(_build_menu):
			_build_menu.visible = false
		if is_instance_valid(_landscape_menu):
			_landscape_menu.visible = false
		_refresh_planned_building_visibility()


func _select_only(citizen: Citizen) -> void:
	var next_selection: Array[Citizen] = [citizen]
	_set_selected_citizens(next_selection)


func _select_building(building: SupportConstructionSite) -> void:
	_set_selected_citizens([])
	_greenery_mode = false
	_selected_greenery = null
	_landscape_mode = false
	_selected_building = building
	_select_world_object(building)
	_build_mode = true
	_placing_support = false
	_placing_excavation = false
	_removing_buildings = false
	if is_instance_valid(_build_menu):
		_build_menu.visible = true
	if is_instance_valid(_landscape_menu):
		_landscape_menu.visible = false
	_refresh_planned_building_visibility()


func _enter_build_mode(place_support: bool) -> void:
	_set_selected_citizens([])
	_clear_object_selection()
	_greenery_mode = false
	_selected_greenery = null
	_landscape_mode = false
	_selected_building = null
	_build_mode = true
	_placing_support = place_support
	_placing_excavation = false
	_removing_buildings = false
	if is_instance_valid(_build_menu):
		_build_menu.visible = true
	if is_instance_valid(_landscape_menu):
		_landscape_menu.visible = false
	_refresh_planned_building_visibility()


func _enter_building_placement(building_id: String) -> void:
	_placing_building_id = building_id
	_enter_build_mode(true)


func _leave_build_mode() -> void:
	_clear_deconstruction_hover_preview()
	_build_mode = false
	_placing_support = false
	_placing_excavation = false
	_removing_buildings = false
	_selected_building = null
	if is_instance_valid(_build_menu):
		_build_menu.visible = false
	_clear_object_selection()
	_refresh_planned_building_visibility()


func _enter_excavation_mode() -> void:
	_set_selected_citizens([])
	_clear_object_selection()
	_selected_building = null
	_build_mode = true
	_greenery_mode = false
	_landscape_mode = false
	_placing_support = false
	_placing_excavation = true
	_removing_buildings = false
	if is_instance_valid(_build_menu):
		_build_menu.visible = true
	if is_instance_valid(_landscape_menu):
		_landscape_menu.visible = false
	_refresh_planned_building_visibility()


func _select_world_object(world_object: Node3D) -> void:
	_selected_world_object = world_object
	_has_selected_ground_cell = false
	if not is_instance_valid(_selection_outline_root):
		_create_world_selection_outline()
	_clear_mesh_outlines(_selection_mesh_outlines)
	_selection_mesh_outline_target = null
	_update_world_selection_outline()


func _select_ground_tile(world_position: Vector3) -> void:
	_selected_world_object = null
	_selected_ground_cell = _world_unit_cell(world_position)
	_has_selected_ground_cell = true
	if not is_instance_valid(_selection_outline_root):
		_create_world_selection_outline()
	_clear_mesh_outlines(_selection_mesh_outlines)
	_selection_mesh_outline_target = null
	_update_world_selection_outline()


func _clear_object_selection() -> void:
	_selected_world_object = null
	_has_selected_ground_cell = false
	if is_instance_valid(_selection_outline_root):
		_selection_outline_root.visible = false
	_clear_mesh_outlines(_selection_mesh_outlines)
	_selection_mesh_outline_target = null


func _try_delete_selected_object() -> void:
	if not is_instance_valid(_selected_world_object):
		return
	if _remove_world_object(_selected_world_object):
		return
	# Naturally generated resources require Citizen work; Backspace only gives
	# refusal feedback and never bypasses that work.
	if _selected_world_object is WorldItem:
		_shake_world_object(_selected_world_object)


func _remove_world_object(world_object: Variant) -> bool:
	if world_object is SupportConstructionSite:
		var support := world_object as SupportConstructionSite
		_clear_deconstruction_hover_preview()
		_cancel_jobs_targeting_removed_object(support)
		_drop_deconstructed_resources(support)
		_construction_sites.erase(support)
		if _selected_building == support:
			_selected_building = null
		if _selected_world_object == support:
			_clear_object_selection()
		# Removal is immediate. It creates no deconstruction marker, site, or
		# collapse animation that could be mistaken for another world object.
		support.visible = false
		support.queue_free()
		_refresh_planned_building_visibility()
		return true
	if world_object is PileStorage and world_object != _starting_pile:
		var pile := world_object as PileStorage
		_clear_deconstruction_hover_preview()
		for pile_cell in pile.world_footprint_cells():
			_occupied_static_world_units.erase(pile_cell)
		_placed_piles.erase(pile)
		if _selected_world_object == pile:
			_clear_object_selection()
		pile.visible = false
		pile.queue_free()
		return true
	if world_object is ExcavationSite:
		var excavation_site := world_object as ExcavationSite
		_clear_deconstruction_hover_preview()
		_cancel_jobs_targeting_removed_object(excavation_site)
		_excavation_sites.erase(excavation_site)
		if _selected_world_object == excavation_site:
			_clear_object_selection()
		excavation_site.visible = false
		excavation_site.queue_free()
		return true
	return false


func _drop_deconstructed_resources(building: Node3D) -> void:
	if not building.has_method("deconstruction_resource_snapshot"):
		return
	var resource_snapshot_value: Variant = building.call("deconstruction_resource_snapshot")
	if not resource_snapshot_value is Dictionary:
		return
	var resource_snapshot := resource_snapshot_value as Dictionary
	var dropped_resource_index := 0
	for resource_kind_value in resource_snapshot:
		var resource_kind := str(resource_kind_value)
		var resource_count := maxi(0, int(resource_snapshot[resource_kind_value]))
		for resource_index in resource_count:
			if resource_kind != "log":
				continue
			var stack_layer := floori(float(dropped_resource_index) / 2.0)
			var stack_side := -1.0 if dropped_resource_index % 2 == 0 else 1.0
			var drop_position := building.global_position + Vector3(
				stack_side * 0.075,
				float(stack_layer) * 0.24,
				-0.075 if stack_layer % 2 == 0 else 0.075
			)
			var detail_seed := _coordinate_seed(
				floori(building.global_position.x * 10.0) + resource_index,
				floori(building.global_position.z * 10.0) + dropped_resource_index,
				431
			)
			# Alternate cardinal axes so several returned Logs read as a loose
			# physical stack while remaining inside the removed World Unit.
			if detail_seed % 2 != dropped_resource_index % 2:
				detail_seed += 1
			_spawn_item("log", drop_position, maxi(1, detail_seed))
			dropped_resource_index += 1


func _cancel_jobs_targeting_removed_object(world_object: Node3D) -> void:
	for citizen in _citizens:
		if not is_instance_valid(citizen):
			continue
		var citizen_task := citizen.task
		if (
			citizen_task.get("target") != world_object
			and citizen_task.get("construction_site") != world_object
			and citizen_task.get("sawmill") != world_object
		):
			continue
		var was_active := _active_work.has(citizen)
		_cancel_active_work(citizen)
		if not was_active and citizen_task.get("construction_site") == world_object:
			_return_unapplied_building_block(citizen, citizen_task)
		elif not was_active and citizen_task.get("sawmill") == world_object and bool(citizen_task.get("resource_kind", "") == "log"):
			_return_sawmill_input(citizen, citizen_task)
		citizen.clear_work_assignment()
		citizen.finish_task(UIText.CITIZEN_IDLE_STATUS_TEXT)


func _rotate_selected_building(direction: int) -> void:
	if (
		not is_instance_valid(_selected_building)
		or _selected_world_object != _selected_building
		or not _selected_building.is_planned()
	):
		return
	var rotation_quarters := int(_selected_building.get_meta(
		"rotation_quarters",
		roundi(_selected_building.rotation.y / (PI * 0.5))
	))
	rotation_quarters += direction
	_selected_building.set_meta("rotation_quarters", rotation_quarters)
	if _building_rotation_tween != null and _building_rotation_tween.is_valid():
		_building_rotation_tween.kill()
	_building_rotation_tween = create_tween()
	_building_rotation_tween.tween_property(
		_selected_building,
		"rotation:y",
		float(rotation_quarters) * PI * 0.5,
		0.16
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _collapse_world_object(world_object: Node3D) -> void:
	var original_position := world_object.position
	var collapse_tween := create_tween()
	collapse_tween.set_parallel(true)
	collapse_tween.tween_property(world_object, "scale", Vector3(1.08, 0.04, 1.08), 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	collapse_tween.tween_property(world_object, "position", original_position - Vector3.UP * 0.18, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	collapse_tween.chain().tween_callback(world_object.queue_free)


func _shake_world_object(world_object: Node3D) -> void:
	var original_position := world_object.position
	var shake_tween := create_tween()
	shake_tween.tween_property(world_object, "position", original_position + Vector3(0.07, 0.0, 0.0), 0.045)
	shake_tween.tween_property(world_object, "position", original_position - Vector3(0.07, 0.0, 0.0), 0.07)
	shake_tween.tween_property(world_object, "position", original_position + Vector3(0.04, 0.0, 0.0), 0.06)
	shake_tween.tween_property(world_object, "position", original_position, 0.045)


func _create_world_selection_outline() -> void:
	_selection_outline_mesh = BoxMesh.new()
	_selection_outline_mesh.size = Vector3(0.035, 0.035, 1.0)
	var outline_multimesh := MultiMesh.new()
	outline_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	outline_multimesh.mesh = _selection_outline_mesh
	_selection_outline_root = MultiMeshInstance3D.new()
	_selection_outline_root.name = "SelectedWorldOutline"
	_selection_outline_root.multimesh = outline_multimesh
	var outline_material := _material(Color.WHITE)
	outline_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	outline_material.no_depth_test = true
	outline_material.render_priority = 2
	_selection_outline_root.material_override = outline_material
	_selection_outline_root.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_selection_outline_root)
	_hover_ground_outline_mesh = BoxMesh.new()
	_hover_ground_outline_mesh.size = Vector3(0.035, 0.035, 1.0)
	var hover_multimesh := MultiMesh.new()
	hover_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	hover_multimesh.mesh = _hover_ground_outline_mesh
	_hover_ground_outline_root = MultiMeshInstance3D.new()
	_hover_ground_outline_root.name = "HoveredGroundOutline"
	_hover_ground_outline_root.multimesh = hover_multimesh
	_hover_ground_outline_root.material_override = outline_material
	_hover_ground_outline_root.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_hover_ground_outline_root.visible = false
	add_child(_hover_ground_outline_root)
	_mesh_outline_material = ShaderMaterial.new()
	_mesh_outline_material.shader = WORLD_OBJECT_OUTLINE_SHADER
	_mesh_outline_material.set_shader_parameter("outline_pixels", VisualTokens.OUTLINE_PIXELS)
	_mesh_outline_material.set_shader_parameter("outline_color", Color.WHITE)
	_update_mesh_outline_viewport()


func _update_world_selection_outline() -> void:
	if not is_instance_valid(_selection_outline_root):
		return
	if _has_selected_ground_cell:
		_clear_mesh_outlines(_selection_mesh_outlines)
		_selection_mesh_outline_target = null
		_update_ground_selection_outline()
		return
	if not is_instance_valid(_selected_world_object) or not _selected_world_object.visible:
		_selection_outline_root.visible = false
		_clear_mesh_outlines(_selection_mesh_outlines)
		_selection_mesh_outline_target = null
		return
	_selection_outline_root.visible = false
	if _selected_world_object is Citizen:
		_clear_mesh_outlines(_selection_mesh_outlines)
		_selection_mesh_outline_target = null
		return
	if (
		_selection_mesh_outline_target != _selected_world_object
		or not _mesh_outlines_are_valid(_selection_mesh_outlines)
	):
		_clear_mesh_outlines(_selection_mesh_outlines)
		_selection_mesh_outline_target = _selected_world_object
		_selection_mesh_outlines = _create_mesh_outlines(_selected_world_object, "Selected")


func _update_ground_selection_outline() -> void:
	# Sit above the 0.025 fog plane with enough separation to avoid depth loss
	# while remaining visually attached to the selected surface tile.
	var cell_origin := Vector3(float(_selected_ground_cell.x), 0.065, float(_selected_ground_cell.y))
	var selection_centre := cell_origin + Vector3(0.5, 0.0, 0.5)
	var line_width := _selection_world_line_width(selection_centre)
	var inset := line_width * 0.5
	var transforms: Array[Transform3D] = []
	transforms.append(_box_segment_transform(
		cell_origin + Vector3(0.0, 0.0, inset),
		cell_origin + Vector3(1.0, 0.0, inset)
	))
	transforms.append(_box_segment_transform(
		cell_origin + Vector3(0.0, 0.0, 1.0 - inset),
		cell_origin + Vector3(1.0, 0.0, 1.0 - inset)
	))
	transforms.append(_box_segment_transform(
		cell_origin + Vector3(inset, 0.0, 0.0),
		cell_origin + Vector3(inset, 0.0, 1.0)
	))
	transforms.append(_box_segment_transform(
		cell_origin + Vector3(1.0 - inset, 0.0, 0.0),
		cell_origin + Vector3(1.0 - inset, 0.0, 1.0)
	))
	_apply_selection_outline_transforms(transforms, line_width)


func _set_hover_outline_target(
	world_object: Variant,
	hit_position: Vector3,
	is_ground: bool
) -> void:
	if is_ground:
		_clear_mesh_outlines(_hover_mesh_outlines)
		_hover_mesh_outline_target = null
		_update_ground_outline_at(_hover_ground_outline_root, _hover_ground_outline_mesh, hit_position)
		return
	if is_instance_valid(_hover_ground_outline_root):
		_hover_ground_outline_root.visible = false
	var next_target := world_object as Node3D if world_object is Node3D else null
	if next_target == _selected_world_object:
		next_target = null
	if next_target == _hover_mesh_outline_target and _mesh_outlines_are_valid(_hover_mesh_outlines):
		return
	_clear_mesh_outlines(_hover_mesh_outlines)
	_hover_mesh_outline_target = next_target
	if is_instance_valid(next_target) and next_target.visible:
		_hover_mesh_outlines = _create_mesh_outlines(next_target, "Hovered")


func _clear_hover_outline() -> void:
	_clear_mesh_outlines(_hover_mesh_outlines)
	_hover_mesh_outline_target = null
	if is_instance_valid(_hover_ground_outline_root):
		_hover_ground_outline_root.visible = false


func _create_mesh_outlines(world_object: Node3D, outline_prefix: String) -> Array[MeshInstance3D]:
	var outlines: Array[MeshInstance3D] = []
	for mesh_instance in _outline_source_meshes(world_object):
		if (
			mesh_instance == null
			or mesh_instance.mesh == null
			or not mesh_instance.is_visible_in_tree()
			or bool(mesh_instance.get_meta("is_world_object_outline", false))
		):
			continue
		var outline := MeshInstance3D.new()
		outline.name = "%sOutline_%s" % [outline_prefix, mesh_instance.name]
		outline.mesh = mesh_instance.mesh
		outline.material_override = _mesh_outline_material
		outline.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		outline.extra_cull_margin = 0.25
		outline.set_meta("is_world_object_outline", true)
		outline.set_meta("outline_source_id", mesh_instance.get_instance_id())
		mesh_instance.add_child(outline)
		outlines.append(outline)
	return outlines


func _outline_source_meshes(world_object: Node3D) -> Array[MeshInstance3D]:
	if world_object.has_method("outline_source_meshes"):
		var supplied_meshes: Variant = world_object.call("outline_source_meshes")
		if supplied_meshes is Array:
			var result: Array[MeshInstance3D] = []
			for supplied_mesh in supplied_meshes:
				if (
					supplied_mesh is MeshInstance3D
					and not bool((supplied_mesh as MeshInstance3D).get_meta("is_world_object_outline", false))
				):
					result.append(supplied_mesh)
			return result
	var result: Array[MeshInstance3D] = []
	for mesh_value in world_object.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := mesh_value as MeshInstance3D
		if not bool(mesh_instance.get_meta("is_world_object_outline", false)):
			result.append(mesh_instance)
	return result


func _clear_mesh_outlines(outlines: Array[MeshInstance3D]) -> void:
	for outline in outlines:
		if is_instance_valid(outline):
			outline.visible = false
			outline.queue_free()
	outlines.clear()


func _mesh_outlines_are_valid(outlines: Array[MeshInstance3D]) -> bool:
	if outlines.is_empty():
		return false
	for outline in outlines:
		if not is_instance_valid(outline):
			return false
	return true


func _update_mesh_outline_viewport() -> void:
	if not is_instance_valid(_mesh_outline_material):
		return
	_mesh_outline_material.set_shader_parameter(
		"viewport_size",
		Vector2(get_viewport().get_visible_rect().size).max(Vector2.ONE)
	)


func _update_ground_outline_at(
	outline_root: MultiMeshInstance3D,
	outline_mesh: BoxMesh,
	world_position: Vector3
) -> void:
	if not is_instance_valid(outline_root) or outline_mesh == null:
		return
	var ground_cell := _world_unit_cell(world_position)
	var cell_origin := Vector3(float(ground_cell.x), 0.065, float(ground_cell.y))
	var line_width := _selection_world_line_width(cell_origin + Vector3(0.5, 0.0, 0.5))
	var inset := line_width * 0.5
	var transforms: Array[Transform3D] = [
		_box_segment_transform(cell_origin + Vector3(0.0, 0.0, inset), cell_origin + Vector3(1.0, 0.0, inset)),
		_box_segment_transform(cell_origin + Vector3(0.0, 0.0, 1.0 - inset), cell_origin + Vector3(1.0, 0.0, 1.0 - inset)),
		_box_segment_transform(cell_origin + Vector3(inset, 0.0, 0.0), cell_origin + Vector3(inset, 0.0, 1.0)),
		_box_segment_transform(cell_origin + Vector3(1.0 - inset, 0.0, 0.0), cell_origin + Vector3(1.0 - inset, 0.0, 1.0)),
	]
	outline_mesh.size = Vector3(line_width, line_width, 1.0)
	outline_root.multimesh.instance_count = transforms.size()
	for transform_index in transforms.size():
		outline_root.multimesh.set_instance_transform(transform_index, transforms[transform_index])
	outline_root.visible = true


func _apply_selection_outline_transforms(
	transforms: Array[Transform3D],
	line_width: float
) -> void:
	_selection_outline_mesh.size = Vector3(line_width, line_width, 1.0)
	var multimesh := _selection_outline_root.multimesh
	multimesh.instance_count = transforms.size()
	for transform_index in transforms.size():
		multimesh.set_instance_transform(transform_index, transforms[transform_index])
	_selection_outline_root.visible = true


func _selection_outline_local_boxes(world_object: Node3D) -> Array[AABB]:
	if world_object.has_method("selection_outline_local_boxes"):
		var supplied_boxes: Variant = world_object.call("selection_outline_local_boxes")
		if supplied_boxes is Array:
			var result: Array[AABB] = []
			for supplied_box in supplied_boxes:
				if supplied_box is AABB:
					var occupied_box: AABB = supplied_box
					if occupied_box.has_volume():
						result.append(occupied_box)
			return result
	return []


func _contained_box_edge_transforms(
	local_bounds: AABB,
	object_transform: Transform3D,
	line_width: float,
	include_vertical_edges: bool
) -> Array[Transform3D]:
	var minimum := local_bounds.position
	var maximum := local_bounds.end
	var x_inset := minf(line_width * 0.5, local_bounds.size.x * 0.5)
	var y_inset := minf(line_width * 0.5, local_bounds.size.y * 0.5)
	var z_inset := minf(line_width * 0.5, local_bounds.size.z * 0.5)
	var x_sides := [minimum.x + x_inset, maximum.x - x_inset]
	var y_sides := [minimum.y + y_inset, maximum.y - y_inset]
	var z_sides := [minimum.z + z_inset, maximum.z - z_inset]
	var transforms: Array[Transform3D] = []
	for y_value in y_sides:
		for z_value in z_sides:
			transforms.append(_oriented_box_segment_transform(
				object_transform * Vector3(minimum.x, y_value, z_value),
				object_transform * Vector3(maximum.x, y_value, z_value),
				object_transform.basis * Vector3.UP,
				object_transform.basis * Vector3.FORWARD
			))
	for y_value in y_sides:
		for x_value in x_sides:
			transforms.append(_oriented_box_segment_transform(
				object_transform * Vector3(x_value, y_value, minimum.z),
				object_transform * Vector3(x_value, y_value, maximum.z),
				object_transform.basis * Vector3.RIGHT,
				object_transform.basis * Vector3.UP
			))
	if include_vertical_edges:
		for x_value in x_sides:
			for z_value in z_sides:
				transforms.append(_oriented_box_segment_transform(
					object_transform * Vector3(x_value, minimum.y, z_value),
					object_transform * Vector3(x_value, maximum.y, z_value),
					object_transform.basis * Vector3.RIGHT,
					object_transform.basis * Vector3.FORWARD
				))
	# Degenerate dimensions can collapse both inset sides onto the same line.
	# Physical occupancy boxes are volumetric, but this keeps the helper safe.
	if local_bounds.size.x <= 0.0 or local_bounds.size.y <= 0.0 or local_bounds.size.z <= 0.0:
		return []
	return transforms


func _oriented_box_segment_transform(
	segment_start: Vector3,
	segment_end: Vector3,
	cross_axis_x: Vector3,
	cross_axis_y: Vector3
) -> Transform3D:
	var offset := segment_end - segment_start
	var length := offset.length()
	var direction := offset / length if length > 0.0 else Vector3.FORWARD
	var segment_basis := Basis(
		cross_axis_x.normalized(),
		cross_axis_y.normalized(),
		direction * length
	)
	return Transform3D(segment_basis, segment_start.lerp(segment_end, 0.5))


func _selection_world_line_width(world_position: Vector3) -> float:
	var viewport_height := maxf(1.0, get_viewport().get_visible_rect().size.y)
	var visible_world_height := _camera.size
	if _camera.projection != Camera3D.PROJECTION_ORTHOGONAL:
		var camera_depth := maxf(0.1, _camera.global_position.distance_to(world_position))
		visible_world_height = 2.0 * camera_depth * tan(deg_to_rad(_camera.fov) * 0.5)
	return clampf(
		visible_world_height / viewport_height * VisualTokens.OUTLINE_PIXELS,
		0.025,
		0.09
	)


func _local_visual_bounds(world_object: Node3D) -> AABB:
	var bounds := AABB(Vector3.ZERO, Vector3.ZERO)
	var found_mesh := false
	var to_object_local := world_object.global_transform.affine_inverse()
	var mesh_nodes := world_object.find_children("*", "MeshInstance3D", true, false)
	for mesh_node in mesh_nodes:
		var mesh_instance := mesh_node as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null or not mesh_instance.visible:
			continue
		var mesh_bounds := mesh_instance.get_aabb()
		for x_side in 2:
			for y_side in 2:
				for z_side in 2:
					var mesh_corner := mesh_bounds.position + mesh_bounds.size * Vector3(
						float(x_side), float(y_side), float(z_side)
					)
					var object_corner := to_object_local * (mesh_instance.global_transform * mesh_corner)
					if found_mesh:
						bounds = bounds.expand(object_corner)
					else:
						bounds = AABB(object_corner, Vector3.ZERO)
						found_mesh = true
	if not found_mesh or not bounds.has_volume():
		return AABB(Vector3(-0.5, 0.0, -0.5), Vector3.ONE)
	return bounds


func _world_visual_bounds(world_object: Node3D) -> AABB:
	var bounds := AABB(world_object.global_position, Vector3.ZERO)
	var found_mesh := false
	var mesh_nodes := world_object.find_children("*", "MeshInstance3D", true, false)
	for mesh_node in mesh_nodes:
		var mesh_instance := mesh_node as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null or not mesh_instance.visible:
			continue
		var local_bounds := mesh_instance.get_aabb()
		for x_side in 2:
			for y_side in 2:
				for z_side in 2:
					var local_corner := local_bounds.position + local_bounds.size * Vector3(
						float(x_side), float(y_side), float(z_side)
					)
					var world_corner := mesh_instance.global_transform * local_corner
					if found_mesh:
						bounds = bounds.expand(world_corner)
					else:
						bounds = AABB(world_corner, Vector3.ZERO)
						found_mesh = true
	if not found_mesh:
		bounds = AABB(world_object.global_position - Vector3.ONE * 0.5, Vector3.ONE)
	return bounds


func _box_segment_transform(segment_start: Vector3, segment_end: Vector3) -> Transform3D:
	var offset := segment_end - segment_start
	var length := offset.length()
	var direction := offset / length if length > 0.0 else Vector3.FORWARD
	var reference := Vector3.UP if absf(direction.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
	var basis_x := reference.cross(direction).normalized()
	var basis_y := direction.cross(basis_x).normalized()
	var segment_basis := Basis(basis_x, basis_y, direction).scaled(Vector3(1.0, 1.0, length))
	return Transform3D(segment_basis, segment_start.lerp(segment_end, 0.5))


func _refresh_planned_building_visibility() -> void:
	for construction_site in _construction_sites:
		if not is_instance_valid(construction_site):
			continue
		var revealed := _is_world_position_revealed(construction_site.global_position)
		construction_site.visible = revealed
		construction_site.set_planning_visible(_build_mode and revealed)


func _world_unit_cell(world_position: Vector3) -> Vector2i:
	return GridNavigationScript.world_cell(world_position)


func _cell_centre(cell: Vector2i) -> Vector3:
	return GridNavigationScript.cell_centre(cell)


func _clamp_to_playable_world(world_position: Vector3) -> Vector3:
	return world_position


func _is_inside_playable_world(world_position: Vector3) -> bool:
	return _loaded_chunks.has(WorldStreamerScript.chunk_for_world_position(world_position))


func _assign_navigation_task(
	citizen: Citizen,
	target_position: Vector3,
	next_task: Dictionary,
	approach_solid_target: bool
) -> bool:
	_cancel_active_work(citizen)
	target_position = _clamp_to_playable_world(target_position)
	var route_plan := _navigation_route_plan(
		citizen.global_position,
		target_position,
		approach_solid_target
	)
	var route: Array[Vector3] = []
	route.assign(route_plan.get("route", []))
	if route.is_empty():
		citizen.finish_task(UIText.CITIZEN_NO_ROUTE_STATUS_TEXT)
		return false
	var assigned_task := next_task.duplicate(true)
	var is_emergency_escape := bool(route_plan.get("emergency_escape", false))
	assigned_task["emergency_escape"] = is_emergency_escape
	citizen.assign_route(
		route,
		assigned_task,
		_road_travel_costs,
		CitizenNavigationPolicyScript.EMERGENCY_ESCAPE_DELAY_SECONDS if is_emergency_escape else 0.0
	)
	return true


func _build_navigation_route(
	start_position: Vector3,
	target_position: Vector3,
	approach_solid_target: bool
) -> Array[Vector3]:
	var plan := _navigation_route_plan(start_position, target_position, approach_solid_target)
	var route: Array[Vector3] = []
	route.assign(plan.get("route", []))
	return route


func _navigation_route_plan(
	start_position: Vector3,
	target_position: Vector3,
	approach_solid_target: bool
) -> Dictionary:
	var loaded_component := _loaded_chunk_component(
		WorldStreamerScript.chunk_for_world_position(start_position)
	)
	if not loaded_component.has(WorldStreamerScript.chunk_for_world_position(target_position)):
		return {"route": [], "emergency_escape": false}
	var navigation_region := _loaded_navigation_region(loaded_component)
	if navigation_region.size == Vector2i.ZERO:
		return {"route": [], "emergency_escape": false}
	var blocked_cells := _navigation_blocked_cells(loaded_component, navigation_region)
	var route := GridNavigationScript.build_route_in_region(
		start_position,
		target_position,
		blocked_cells,
		navigation_region,
		approach_solid_target,
		_navigation_travel_costs()
	)
	var target_is_elsewhere := (
		GridNavigationScript.world_cell(start_position)
		!= GridNavigationScript.world_cell(target_position)
	)
	var route_makes_progress := (
		not route.is_empty()
		and Vector2(route[-1].x - start_position.x, route[-1].z - start_position.z).length_squared()
			> 0.0025
	)
	if (
		target_is_elsewhere
		and not route_makes_progress
		and GridNavigationScript.is_locally_enclosed(start_position, blocked_cells, navigation_region)
	):
		route = GridNavigationScript.build_emergency_route_in_region(
			start_position,
			target_position,
			blocked_cells,
			navigation_region,
			approach_solid_target
		)
		return {"route": route, "emergency_escape": not route.is_empty()}
	return {"route": route, "emergency_escape": false}


func _set_road_travel_cell(world_cell: Vector2i, enabled: bool) -> void:
	if enabled:
		var road_definition := BuildingCatalogScript.entry("road")
		_road_travel_costs[world_cell] = float(
			road_definition.get("travel_cost", GridNavigationScript.ROAD_TRAVEL_COST)
		)
	else:
		_road_travel_costs.erase(world_cell)


func _navigation_travel_costs() -> Dictionary:
	var travel_costs := _road_travel_costs.duplicate()
	for item in _items:
		if not is_instance_valid(item) or item.is_carried:
			continue
		var item_cost := CitizenNavigationPolicyScript.world_item_travel_cost(item.item_kind)
		if item_cost > 0.0:
			travel_costs[_world_unit_cell(item.global_position)] = item_cost
	return travel_costs


func _loaded_chunk_component(start_chunk: Vector2i) -> Dictionary:
	if not _loaded_chunks.has(start_chunk):
		return {}
	var component: Dictionary = {start_chunk: true}
	var frontier: Array[Vector2i] = [start_chunk]
	var frontier_index := 0
	while frontier_index < frontier.size():
		var current: Vector2i = frontier[frontier_index]
		frontier_index += 1
		for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var neighbour: Vector2i = current + offset
			if _loaded_chunks.has(neighbour) and not component.has(neighbour):
				component[neighbour] = true
				frontier.append(neighbour)
	return component


func _loaded_navigation_region(loaded_component: Dictionary) -> Rect2i:
	if loaded_component.is_empty():
		return Rect2i()
	var first := true
	var minimum := Vector2i.ZERO
	var maximum := Vector2i.ZERO
	for chunk_value in loaded_component:
		var chunk: Vector2i = chunk_value
		var bounds := WorldStreamerScript.chunk_world_bounds(chunk)
		if first:
			minimum = bounds.position
			maximum = bounds.end
			first = false
		else:
			minimum.x = mini(minimum.x, bounds.position.x)
			minimum.y = mini(minimum.y, bounds.position.y)
			maximum.x = maxi(maximum.x, bounds.end.x)
			maximum.y = maxi(maximum.y, bounds.end.y)
	return Rect2i(minimum, maximum - minimum)


func _navigation_blocked_cells(loaded_component: Dictionary, navigation_region: Rect2i) -> Dictionary:
	var blocked: Dictionary = _excavated_cells.duplicate()
	for world_x in range(navigation_region.position.x, navigation_region.end.x):
		for world_z in range(navigation_region.position.y, navigation_region.end.y):
			var world_unit := Vector2i(world_x, world_z)
			if not loaded_component.has(WorldStreamerScript.chunk_for_world_unit(world_unit)):
				blocked[world_unit] = true
	if is_instance_valid(_starting_pile):
		for pile_cell in _starting_pile.world_footprint_cells():
			blocked[pile_cell] = true
	for placed_pile in _placed_piles:
		if not is_instance_valid(placed_pile):
			continue
		for pile_cell in placed_pile.world_footprint_cells():
			blocked[pile_cell] = true
	for item in _items:
		if not is_instance_valid(item) or item.is_carried:
			continue
		if CitizenNavigationPolicyScript.world_item_blocks(item.item_kind):
			blocked[_world_unit_cell(item.global_position)] = true
	for terrain_coordinate_value in _terrain_blocks:
		var terrain_coordinate: Vector3i = terrain_coordinate_value
		if terrain_coordinate.y == 0:
			blocked[Vector2i(terrain_coordinate.x, terrain_coordinate.z)] = true
	return blocked


func _order_group_chop(clicked_tree: WorldItem) -> void:
	if _selected_citizens.is_empty() or not is_instance_valid(clicked_tree):
		return
	# Release this group's previous commands before calculating Tree capacity.
	# Interrupted applied labour remains on its segment slot and can be resumed.
	for citizen in _selected_citizens:
		if not is_instance_valid(citizen):
			continue
		var woke_from_sleep := _wake_for_direct_order(citizen)
		if not woke_from_sleep:
			citizen.set_work_assignment({"kind": ActionCatalog.CHOP_TREE})
		_cancel_active_work(citizen)
		citizen.finish_task()
	var candidates := _tree_chop_candidates(clicked_tree)
	var command_scope := _next_speech_command_scope()
	for citizen in _selected_citizens:
		if not is_instance_valid(citizen):
			continue
		var assigned := false
		for tree in candidates:
			var work_slot := _next_available_tree_work_slot(tree)
			if work_slot < 0:
				continue
			if _order_chop(citizen, tree, work_slot, command_scope):
				assigned = true
				break
		if not assigned:
			citizen.finish_task(UIText.CITIZEN_TREE_UNAVAILABLE_STATUS_TEXT)


func _tree_chop_candidates(clicked_tree: WorldItem) -> Array[WorldItem]:
	var candidates: Array[WorldItem] = []
	for item in _items:
		if (
			is_instance_valid(item)
			and item.visible
			and item.tree_log_count > 0
			and item.item_kind in ["tree", "dead_tree", "palm_tree"]
		):
			candidates.append(item)
	if not candidates.has(clicked_tree) and clicked_tree.tree_log_count > 0:
		candidates.append(clicked_tree)
	candidates.sort_custom(func(first: WorldItem, second: WorldItem) -> bool:
		return clicked_tree.global_position.distance_squared_to(first.global_position) < clicked_tree.global_position.distance_squared_to(second.global_position)
	)
	return candidates


func _next_available_tree_work_slot(tree: WorldItem) -> int:
	if not is_instance_valid(tree) or tree.tree_log_count <= 0:
		return -1
	var assigned_slots: Dictionary = {}
	for citizen in _citizens:
		if not is_instance_valid(citizen):
			continue
		if (
			str(citizen.task.get("kind", "")) == ActionCatalog.CHOP_TREE
			and citizen.task.get("target") == tree
		):
			assigned_slots[int(citizen.task.get("tree_work_slot", -1))] = true
	var recorded_slots: Dictionary = {}
	var resumable_slots: Array[int] = []
	for labour_key_value in _labour_records:
		var record: Dictionary = _labour_records[labour_key_value]
		if (
			record.get("target") != tree
			or str(record.get("kind", "")) != ActionCatalog.CHOP_TREE
		):
			continue
		var work_slot := int(record.get("work_slot", -1))
		if work_slot < 0:
			continue
		recorded_slots[work_slot] = true
		var labour := record.get("labour") as AppliedLabour
		if not assigned_slots.has(work_slot) and labour != null and not labour.is_being_applied():
			resumable_slots.append(work_slot)
	resumable_slots.sort()
	if not resumable_slots.is_empty():
		return resumable_slots[0]
	var reserved_slots := recorded_slots.duplicate()
	for assigned_slot in assigned_slots:
		reserved_slots[assigned_slot] = true
	if reserved_slots.size() >= tree.tree_log_count:
		return -1
	var next_slot := 0
	while reserved_slots.has(next_slot):
		next_slot += 1
	return next_slot


func _order_chop(
	citizen: Citizen,
	tree: WorldItem,
	work_slot := -1,
	command_scope := "",
	is_continuation := false
) -> bool:
	if work_slot < 0:
		work_slot = _next_available_tree_work_slot(tree)
	if work_slot < 0:
		citizen.finish_task(UIText.CITIZEN_TREE_UNAVAILABLE_STATUS_TEXT)
		return false
	var next_task := {
		"kind": ActionCatalog.CHOP_TREE,
		"status_text_key": UIText.CITIZEN_WALKING_TO_TREE_STATUS_TEXT,
		"target": tree,
		"tree_work_slot": work_slot,
	}
	var accepted := _assign_tree_work_position(citizen, tree, work_slot, next_task)
	if accepted and not is_continuation:
		_actor_message_bus.post_message(citizen, MessageCatalog.CONFIRM_LOG, {
			"cluster_scope": command_scope if not command_scope.is_empty() else _next_speech_command_scope(),
		})
	return accepted


func _assign_tree_work_position(
	citizen: Citizen,
	tree: WorldItem,
	work_slot: int,
	next_task: Dictionary
) -> bool:
	var tree_cell := _world_unit_cell(tree.global_position)
	var loaded_component := _loaded_chunk_component(
		WorldStreamerScript.chunk_for_world_position(citizen.global_position)
	)
	var navigation_region := _loaded_navigation_region(loaded_component)
	var blocked_cells := _navigation_blocked_cells(loaded_component, navigation_region)
	for attempt_index in GridNavigationScript.NEIGHBOUR_OFFSETS.size():
		var offset_index := (work_slot + attempt_index) % GridNavigationScript.NEIGHBOUR_OFFSETS.size()
		var candidate_cell := tree_cell + GridNavigationScript.NEIGHBOUR_OFFSETS[offset_index]
		if blocked_cells.has(candidate_cell):
			continue
		if _assign_navigation_task(citizen, _cell_centre(candidate_cell), next_task, false):
			return true
	return false


func _order_harvest(citizen: Citizen, bush: WorldItem, is_continuation := false) -> void:
	if not is_continuation:
		var woke_from_sleep := _wake_for_direct_order(citizen)
		if not woke_from_sleep:
			citizen.set_work_assignment({"kind": ActionCatalog.HARVEST_BUSH})
	var accepted := _assign_navigation_task(citizen, bush.global_position, {
		"kind": ActionCatalog.HARVEST_BUSH,
		"status_text_key": UIText.CITIZEN_WALKING_TO_BUSH_STATUS_TEXT,
		"target": bush,
	}, true)
	if accepted and not is_continuation:
		_actor_message_bus.post_message(citizen, MessageCatalog.CONFIRM_FOOD, {
			"cluster_scope": _next_speech_command_scope(),
		})


func _order_collect_cactus(citizen: Citizen, cactus: WorldItem) -> void:
	_wake_for_direct_order(citizen)
	citizen.clear_work_assignment()
	if is_instance_valid(_starting_pile) and not _starting_pile.can_store_resource("water"):
		citizen.finish_task(UIText.CITIZEN_WATER_NEEDS_VESSEL_STATUS_TEXT)
		return
	var accepted := _assign_navigation_task(citizen, cactus.global_position, {
		"kind": ActionCatalog.COLLECT_CACTUS,
		"status_text_key": UIText.CITIZEN_WALKING_TO_CACTUS_STATUS_TEXT,
		"target": cactus,
	}, true)
	if accepted:
		_actor_message_bus.post_message(citizen, MessageCatalog.CONFIRM_WATER, {
			"cluster_scope": _next_speech_command_scope(),
		})


func _place_support_construction_site(world_position: Vector3, keep_placing := false) -> void:
	_place_building(world_position, "support", keep_placing)


func _place_building(
	world_position: Vector3,
	building_id: String,
	keep_placing := false
) -> void:
	if building_id == "pile":
		var pile := PileStorageScript.new() as PileStorage
		pile.configure_footprint(PileStorage.DEFAULT_FOOTPRINT)
		add_child(pile)
		pile.global_position = world_position
		_placed_piles.append(pile)
		for pile_cell in pile.world_footprint_cells():
			_occupied_static_world_units[pile_cell] = true
		_select_world_object(pile)
		if not keep_placing:
			_placing_support = false
		return
	var construction_site := SupportConstructionSite.new()
	construction_site.configure(building_id)
	add_child(construction_site)
	construction_site.global_position = world_position
	_construction_sites.append(construction_site)
	if keep_placing:
		_selected_building = construction_site
		_build_mode = true
		_placing_support = true
		_refresh_planned_building_visibility()
	else:
		_select_building(construction_site)


func _ensure_support_placement_preview() -> void:
	if (
		is_instance_valid(_support_placement_preview)
		and str(_support_placement_preview.get_meta("building_id", "")) == _placing_building_id
	):
		return
	if is_instance_valid(_support_placement_preview):
		_support_placement_preview.queue_free()
	_support_preview_geometry.clear()
	_support_preview_quadrants.clear()
	_support_preview_allowed_material = _placement_preview_material(Palette.PLACEMENT_ALLOWED)
	_support_preview_blocked_material = _placement_preview_material(Palette.PLACEMENT_BLOCKED)
	_support_placement_preview = SupportConstructionSite.new()
	_support_placement_preview.name = "SupportPlacementPreview"
	_support_placement_preview.configure(_placing_building_id)
	_support_placement_preview.set_meta("building_id", _placing_building_id)
	add_child(_support_placement_preview)
	for resource_kind_value in _support_placement_preview.construction_recipe():
		var resource_kind := str(resource_kind_value)
		for resource_index in int(_support_placement_preview.construction_recipe()[resource_kind]):
			_support_placement_preview.deliver_resource(resource_kind)
	for body_node in _support_placement_preview.find_children("*", "StaticBody3D", true, false):
		var body := body_node as StaticBody3D
		body.collision_layer = 0
		body.collision_mask = 0
	for mesh_node in _support_placement_preview.find_children("*", "GeometryInstance3D", true, false):
		var geometry := mesh_node as GeometryInstance3D
		geometry.material_override = _support_preview_allowed_material
		geometry.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_support_preview_geometry.append(geometry)
	var site_objects := ObjAssetScript.load_objects(SUPPORT_CONSTRUCTION_SITE_ASSET_PATH)
	for quadrant_index in _support_footprint_quadrant_offsets.size():
		var quadrant := MeshInstance3D.new()
		quadrant.name = "PlacementQuadrant%d" % (quadrant_index + 1)
		quadrant.mesh = site_objects.get(
			"placement_quadrant_%02d" % (quadrant_index + 1)
		) as Mesh
		quadrant.material_override = _support_preview_allowed_material
		quadrant.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_support_placement_preview.add_child(quadrant)
		_support_preview_quadrants.append(quadrant)
	_support_placement_preview.visible = false


func _placement_preview_material(colour: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(colour.r, colour.g, colour.b, 0.5)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.roughness = 1.0
	return material


func _update_support_placement_preview() -> void:
	if not _placing_support or not _build_mode or not is_instance_valid(_camera):
		if is_instance_valid(_support_placement_preview):
			_support_placement_preview.visible = false
		return
	_ensure_support_placement_preview()
	var hovered_control := get_viewport().gui_get_hovered_control()
	if hovered_control != null:
		_support_placement_preview.visible = false
		return
	var hit := _raycast(get_viewport().get_mouse_position())
	if hit.is_empty():
		_support_placement_preview.visible = false
		return
	var preview_position := _building_placement_position(hit.position, _placing_building_id)
	var placement := _building_placement_evaluation(preview_position, _placing_building_id)
	_support_placement_preview.global_position = preview_position
	_support_placement_preview.visible = true
	_apply_support_preview_evaluation(placement)


func _building_placement_position(world_position: Vector3, building_id: String) -> Vector3:
	if building_id == "pile":
		return _cell_centre(_world_unit_cell(world_position))
	return _snap_to_world_unit(world_position)


func _building_placement_evaluation(preview_position: Vector3, building_id: String) -> Dictionary:
	if building_id != "pile":
		return _support_placement_evaluation(preview_position)
	var valid := true
	var origin := _world_unit_cell(preview_position)
	for local_cell in PileStorage.DEFAULT_FOOTPRINT:
		var world_cell := origin + local_cell
		if (
			not _is_inside_playable_world(_cell_centre(world_cell))
			or _excavated_cells.has(world_cell)
			or _surface_cell_has_occupant(world_cell)
		):
			valid = false
	return {"valid": valid, "invalid_quadrants": [not valid, not valid, not valid, not valid]}


func _support_placement_evaluation(preview_position: Vector3) -> Dictionary:
	var invalid_quadrants: Array[bool] = [false, false, false, false]
	for quadrant_index in _support_footprint_quadrant_offsets.size():
		var quadrant_offset := _support_footprint_quadrant_offsets[quadrant_index]
		var quadrant_centre := preview_position + Vector3(quadrant_offset.x, 0.0, quadrant_offset.y)
		if not _is_inside_playable_world(quadrant_centre):
			invalid_quadrants[quadrant_index] = true
			continue
		var quadrant_cell := _world_unit_cell(quadrant_centre)
		if _excavated_cells.has(quadrant_cell):
			invalid_quadrants[quadrant_index] = true

	if is_instance_valid(_starting_pile):
		for pile_cell in _starting_pile.world_footprint_cells():
			_mark_support_blocked_by_cell(
				preview_position,
				pile_cell,
				invalid_quadrants
			)
	for placed_pile in _placed_piles:
		if not is_instance_valid(placed_pile):
			continue
		for pile_cell in placed_pile.world_footprint_cells():
			_mark_support_blocked_by_cell(preview_position, pile_cell, invalid_quadrants)
	for item in _items:
		if not is_instance_valid(item) or item.is_carried:
			continue
		_mark_support_blocked_by_cell(
			preview_position,
			_world_unit_cell(item.global_position),
			invalid_quadrants
		)
	for construction_site in _construction_sites:
		if not is_instance_valid(construction_site):
			continue
		_mark_support_blocked_by_footprint(
			preview_position,
			construction_site.global_position,
			invalid_quadrants
		)
	for excavation_site in _excavation_sites:
		if not is_instance_valid(excavation_site):
			continue
		_mark_support_blocked_by_cell(
			preview_position,
			_world_unit_cell(excavation_site.global_position),
			invalid_quadrants
		)
	for terrain_coordinate_value in _terrain_blocks:
		var terrain_coordinate: Vector3i = terrain_coordinate_value
		if terrain_coordinate.y != 0:
			continue
		_mark_support_blocked_by_cell(
			preview_position,
			Vector2i(terrain_coordinate.x, terrain_coordinate.z),
			invalid_quadrants
		)

	var valid := not invalid_quadrants.has(true)
	return {
		"valid": valid,
		"invalid_quadrants": invalid_quadrants,
	}


func _mark_support_blocked_by_cell(
	preview_position: Vector3,
	blocked_cell: Vector2i,
	invalid_quadrants: Array[bool]
) -> void:
	for quadrant_index in _support_footprint_quadrant_offsets.size():
		var quadrant_offset := _support_footprint_quadrant_offsets[quadrant_index]
		var quadrant_centre := preview_position + Vector3(quadrant_offset.x, 0.0, quadrant_offset.y)
		if _world_unit_cell(quadrant_centre) == blocked_cell:
			invalid_quadrants[quadrant_index] = true


func _mark_support_blocked_by_footprint(
	preview_position: Vector3,
	blocker_position: Vector3,
	invalid_quadrants: Array[bool]
) -> void:
	var blocker_rect := Rect2(
		Vector2(blocker_position.x - 0.5, blocker_position.z - 0.5),
		Vector2.ONE
	)
	for quadrant_index in _support_footprint_quadrant_offsets.size():
		var quadrant_offset := _support_footprint_quadrant_offsets[quadrant_index]
		var quadrant_rect := Rect2(
			Vector2(
				preview_position.x + quadrant_offset.x - 0.24,
				preview_position.z + quadrant_offset.y - 0.24
			),
			Vector2(0.48, 0.48)
		)
		if quadrant_rect.intersects(blocker_rect, false):
			invalid_quadrants[quadrant_index] = true


func _apply_support_preview_evaluation(placement: Dictionary) -> void:
	var placement_is_valid := bool(placement.get("valid", false))
	var preview_material := (
		_support_preview_allowed_material
		if placement_is_valid
		else _support_preview_blocked_material
	)
	for geometry in _support_preview_geometry:
		if is_instance_valid(geometry):
			geometry.material_override = preview_material
	var invalid_quadrants: Array = placement.get("invalid_quadrants", [])
	for quadrant_index in _support_preview_quadrants.size():
		var quadrant := _support_preview_quadrants[quadrant_index]
		if not is_instance_valid(quadrant):
			continue
		var quadrant_is_invalid := (
			quadrant_index < invalid_quadrants.size()
			and bool(invalid_quadrants[quadrant_index])
		)
		quadrant.material_override = (
			_support_preview_blocked_material
			if quadrant_is_invalid
			else _support_preview_allowed_material
		)
func _update_deconstruction_hover_preview() -> void:
	if not _removing_buildings or not _build_mode or not is_instance_valid(_camera):
		_clear_deconstruction_hover_preview()
		return
	if get_viewport().gui_get_hovered_control() != null:
		_clear_deconstruction_hover_preview()
		return
	var hover_hit := _raycast(get_viewport().get_mouse_position())
	if hover_hit.is_empty():
		_clear_deconstruction_hover_preview()
		return
	var hover_collider := hover_hit.get("collider") as Node
	var hover_world_object: Variant = _world_object_for(hover_collider)
	if not _is_deconstructable_world_object(hover_world_object):
		_clear_deconstruction_hover_preview()
		return
	var next_target := hover_world_object as Node3D
	if _deconstruction_hover_target == next_target:
		return
	_clear_deconstruction_hover_preview()
	_deconstruction_hover_target = next_target
	if _deconstruction_preview_material == null:
		_deconstruction_preview_material = StandardMaterial3D.new()
		_deconstruction_preview_material.albedo_color = Color(
			Palette.DECONSTRUCTION_PREVIEW.r,
			Palette.DECONSTRUCTION_PREVIEW.g,
			Palette.DECONSTRUCTION_PREVIEW.b,
			0.5
		)
		_deconstruction_preview_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_deconstruction_preview_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_deconstruction_preview_material.roughness = 1.0
	for mesh_node in next_target.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := mesh_node as MeshInstance3D
		if not is_instance_valid(mesh_instance) or not mesh_instance.visible:
			continue
		_deconstruction_original_materials[mesh_instance] = {
			"material_override": mesh_instance.material_override,
			"cast_shadow": mesh_instance.cast_shadow,
		}
		mesh_instance.material_override = _deconstruction_preview_material
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _clear_deconstruction_hover_preview() -> void:
	for mesh_value in _deconstruction_original_materials:
		var mesh_instance := mesh_value as MeshInstance3D
		if not is_instance_valid(mesh_instance):
			continue
		var original_state: Dictionary = _deconstruction_original_materials[mesh_value]
		mesh_instance.material_override = original_state.get("material_override") as Material
		mesh_instance.set("cast_shadow", original_state.get(
			"cast_shadow",
			GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		))
	_deconstruction_original_materials.clear()
	_deconstruction_hover_target = null


func _is_deconstructable_world_object(world_object: Variant) -> bool:
	return (
		world_object is SupportConstructionSite
		or world_object is ExcavationSite
		or (world_object is PileStorage and world_object != _starting_pile)
	)


func _place_excavation_site(world_cell: Vector2i, keep_placing := false) -> void:
	if _excavated_cells.has(world_cell):
		return
	for existing_site in _excavation_sites:
		if is_instance_valid(existing_site) and _world_unit_cell(existing_site.global_position) == world_cell:
			_select_world_object(existing_site)
			return
	var excavation_site := ExcavationSiteScript.new() as ExcavationSite
	add_child(excavation_site)
	excavation_site.global_position = Vector3(
		float(world_cell.x) + 0.5,
		0.0,
		float(world_cell.y) + 0.5
	)
	_excavation_sites.append(excavation_site)
	_select_world_object(excavation_site)
	_build_mode = true
	_placing_excavation = keep_placing
	_placing_support = false


func _order_excavate(citizen: Citizen, excavation_site: ExcavationSite) -> void:
	_wake_for_direct_order(citizen)
	citizen.clear_work_assignment()
	_assign_navigation_task(citizen, excavation_site.global_position, {
		"kind": ActionCatalog.EXCAVATE,
		"status_text_key": UIText.CITIZEN_WALKING_TO_EXCAVATION_STATUS_TEXT,
		"target": excavation_site,
	}, true)


func _order_enter_completed_building(
	citizen: Citizen,
	building: SupportConstructionSite
) -> void:
	_wake_for_direct_order(citizen)
	citizen.clear_work_assignment()
	_assign_navigation_task(citizen, building.global_position, {
		"kind": ActionCatalog.MOVE,
		"status_text_key": UIText.CITIZEN_WALKING_STATUS_TEXT,
		"target": building,
	}, false)


func _order_process_sawmill(citizen: Citizen, sawmill: SupportConstructionSite) -> void:
	_wake_for_direct_order(citizen)
	citizen.clear_work_assignment()
	if not is_instance_valid(_starting_pile) or _starting_pile.resource_count("log") <= 0:
		citizen.finish_task(UIText.CITIZEN_SAWMILL_NEEDS_LOG_STATUS_TEXT)
		return
	_assign_navigation_task(
		citizen,
		_starting_pile.nearest_delivery_world_position(citizen.global_position),
		{
			"kind": ActionCatalog.FETCH_WORKSHOP_INPUT,
			"status_text_key": UIText.CITIZEN_FETCHING_LOG_STATUS_TEXT,
			"sawmill": sawmill,
			"source_pile": _starting_pile,
		},
		true
	)


func _continue_build(citizen: Citizen, construction_site: SupportConstructionSite) -> void:
	if not is_instance_valid(construction_site) or not construction_site.is_planned():
		construction_site = _nearest_incomplete_construction_site(citizen.global_position)
	if construction_site == null:
		citizen.clear_work_assignment()
		citizen.finish_task(UIText.CITIZEN_SUPPORT_COMPLETE_STATUS_TEXT)
		return
	var resource_kind := construction_site.next_required_resource()
	if (
		resource_kind.is_empty()
		or not is_instance_valid(_starting_pile)
		or _starting_pile.resource_count(resource_kind) <= 0
	):
		citizen.clear_work_assignment()
		citizen.finish_task(UIText.CITIZEN_SUPPORT_NEEDS_LOG_STATUS_TEXT)
		return
	_assign_navigation_task(citizen, _starting_pile.nearest_delivery_world_position(citizen.global_position), {
		"kind": ActionCatalog.FETCH_LOG,
		"status_text_key": UIText.CITIZEN_FETCHING_LOG_STATUS_TEXT,
		"source_pile": _starting_pile,
		"construction_site": construction_site,
		"resource_kind": resource_kind,
	}, true)


func _nearest_incomplete_construction_site(from_position: Vector3) -> SupportConstructionSite:
	var nearest: SupportConstructionSite
	var nearest_distance := INF
	for construction_site in _construction_sites:
		if (
			not is_instance_valid(construction_site)
			or not construction_site.is_planned()
			or not construction_site.visible
		):
			continue
		var distance := from_position.distance_squared_to(construction_site.global_position)
		if distance < nearest_distance:
			nearest = construction_site
			nearest_distance = distance
	return nearest


func _on_citizen_arrived(citizen: Citizen) -> void:
	var task := citizen.task
	match str(task.get("kind", "")):
		ActionCatalog.MOVE:
			citizen.finish_task(UIText.CITIZEN_IDLE_STATUS_TEXT)
		ActionCatalog.CHOP_TREE:
			_handle_chop_arrival(citizen, task)
		ActionCatalog.HARVEST_BUSH:
			_handle_harvest_arrival(citizen, task)
		ActionCatalog.COLLECT_CACTUS:
			_handle_cactus_arrival(citizen, task)
		ActionCatalog.EXCAVATE:
			_handle_excavation_arrival(citizen, task)
		ActionCatalog.FETCH_LOG:
			_handle_fetch_log_arrival(citizen, task)
		ActionCatalog.DELIVER_LOG:
			_handle_deliver_log_arrival(citizen, task)
		ActionCatalog.APPLY_BUILDING_BLOCK:
			_resume_construction_work(citizen, task)
		ActionCatalog.DELIVER_FOOD:
			_handle_deliver_food_arrival(citizen, task)
		ActionCatalog.FETCH_WORKSHOP_INPUT:
			_handle_fetch_workshop_input_arrival(citizen, task)
		ActionCatalog.SAW_PLANK:
			_handle_sawmill_arrival(citizen, task)


func _handle_chop_arrival(citizen: Citizen, task: Dictionary) -> void:
	var tree: Variant = task.get("target")
	if is_instance_valid(tree):
		_start_tree_cut_work(citizen, tree as WorldItem)
	else:
		citizen.finish_task(UIText.CITIZEN_TREE_UNAVAILABLE_STATUS_TEXT)


func _handle_harvest_arrival(citizen: Citizen, task: Dictionary) -> void:
	var bush: Variant = task.get("target")
	if is_instance_valid(bush) and (bush as WorldItem).can_harvest():
		_start_resource_work(
			citizen,
			bush as WorldItem,
			ActionCatalog.HARVEST_BUSH,
			UIText.CITIZEN_HARVESTING_BUSH_STATUS_TEXT
		)
	else:
		citizen.finish_task(UIText.CITIZEN_BUSH_REGROWING_STATUS_TEXT)


func _handle_cactus_arrival(citizen: Citizen, task: Dictionary) -> void:
	var cactus: Variant = task.get("target")
	if is_instance_valid(cactus) and (cactus as WorldItem).has_collectable_water():
		_start_resource_work(
			citizen,
			cactus as WorldItem,
			ActionCatalog.COLLECT_CACTUS,
			UIText.CITIZEN_COLLECTING_CACTUS_STATUS_TEXT
		)
	else:
		citizen.finish_task(UIText.CITIZEN_CACTUS_UNAVAILABLE_STATUS_TEXT)


func _handle_excavation_arrival(citizen: Citizen, task: Dictionary) -> void:
	var excavation_target: Variant = task.get("target")
	if is_instance_valid(excavation_target):
		_start_excavation_work(citizen, excavation_target as ExcavationSite)
	else:
		citizen.finish_task(UIText.CITIZEN_EXCAVATION_UNAVAILABLE_STATUS_TEXT)


func _handle_fetch_log_arrival(citizen: Citizen, task: Dictionary) -> void:
	var source_pile: Variant = task.get("source_pile")
	if is_instance_valid(source_pile):
		var pile := source_pile as PileStorage
		var pile_construction_site: Variant = task.get("construction_site")
		var resource_kind := str(task.get("resource_kind", "log"))
		var pile_contributor_id := citizen.get_instance_id()
		var pile_reservation_slot := -1
		if is_instance_valid(pile_construction_site):
			pile_reservation_slot = (pile_construction_site as SupportConstructionSite).reserve_resource(
				pile_contributor_id,
				resource_kind
			)
		if pile_reservation_slot < 0 or not pile.take_resource(resource_kind, 1):
			if is_instance_valid(pile_construction_site):
				(pile_construction_site as SupportConstructionSite).release_log_reservation(pile_contributor_id)
			citizen.clear_work_assignment()
			citizen.finish_task(UIText.CITIZEN_SUPPORT_NEEDS_LOG_STATUS_TEXT)
			return
		citizen.set_carrying_resource(resource_kind, true)
		_assign_navigation_task(citizen, (pile_construction_site as SupportConstructionSite).global_position, {
			"kind": ActionCatalog.DELIVER_LOG,
			"status_text_key": UIText.CITIZEN_CARRYING_LOG_STATUS_TEXT,
			"construction_site": pile_construction_site,
			"stored_log": true,
			"resource_kind": resource_kind,
			"reservation_slot": pile_reservation_slot,
		}, true)
		return
	var source_log: Variant = task.get("log")
	var construction_site: Variant = task.get("construction_site")
	var pile_storage: Variant = task.get("pile_storage")
	if is_instance_valid(source_log) and is_instance_valid(pile_storage) and source_log.take_for_carry():
		citizen.set_carrying_log(true)
		var pickup_position := citizen.global_position
		var delivery_plan := _nearest_reachable_pile_delivery(pickup_position, "log")
		var destination_pile := delivery_plan.get("pile") as PileStorage
		if not is_instance_valid(destination_pile):
			citizen.set_carrying_log(false)
			(source_log as WorldItem).release_from_carry(citizen.global_position)
			citizen.finish_task(UIText.CITIZEN_IDLE_STATUS_TEXT)
			return
		_assign_navigation_task(citizen, delivery_plan.get("target", pickup_position), {
			"kind": ActionCatalog.DELIVER_LOG,
			"status_text_key": UIText.CITIZEN_CARRYING_LOG_STATUS_TEXT,
			"log": source_log,
			"pile_storage": destination_pile,
			"pickup_position": pickup_position,
		}, false)
		return
	var contributor_id := citizen.get_instance_id()
	var reservation_slot := -1
	if is_instance_valid(construction_site):
		reservation_slot = (construction_site as SupportConstructionSite).reserve_log(contributor_id)
	if (
		reservation_slot < 0
		or not is_instance_valid(source_log)
		or not source_log.take_for_carry()
	):
		if is_instance_valid(construction_site):
			(construction_site as SupportConstructionSite).release_log_reservation(contributor_id)
		citizen.finish_task(UIText.CITIZEN_LOG_UNAVAILABLE_STATUS_TEXT)
		return
	citizen.set_carrying_log(true)
	_assign_navigation_task(citizen, construction_site.global_position, {
		"kind": ActionCatalog.DELIVER_LOG,
		"status_text_key": UIText.CITIZEN_CARRYING_LOG_STATUS_TEXT,
		"log": source_log,
		"construction_site": construction_site,
		"reservation_slot": reservation_slot,
	}, false)


func _handle_deliver_log_arrival(citizen: Citizen, task: Dictionary) -> void:
	var construction_site: Variant = task.get("construction_site")
	var pile_storage: Variant = task.get("pile_storage")
	if is_instance_valid(pile_storage):
		_start_storage_delivery_labour(citizen, task)
		return
	if not is_instance_valid(construction_site):
		_return_unapplied_building_block(citizen, task)
		citizen.finish_task(UIText.CITIZEN_CONSTRUCTION_SITE_UNAVAILABLE_STATUS_TEXT)
		return
	_start_construction_work(citizen, construction_site as SupportConstructionSite, task)


func _start_construction_work(
	citizen: Citizen,
	construction_site: SupportConstructionSite,
	material_task: Dictionary
) -> void:
	var contributor_id := citizen.get_instance_id()
	var reservation_slot := int(material_task.get("reservation_slot", -1))
	var resource_kind := str(material_task.get("resource_kind", "log"))
	if not construction_site.has_log_reservation(contributor_id) or reservation_slot < 0:
		_return_unapplied_building_block(citizen, material_task)
		citizen.finish_task(UIText.CITIZEN_CONSTRUCTION_SITE_UNAVAILABLE_STATUS_TEXT)
		return
	citizen.task = {
		"kind": ActionCatalog.APPLY_BUILDING_BLOCK,
		"construction_site": construction_site,
		"log": material_task.get("log"),
		"stored_log": bool(material_task.get("stored_log", false)),
		"resource_kind": resource_kind,
		"reservation_slot": reservation_slot,
	}
	_begin_labour(
		citizen,
		construction_site,
		ActionCatalog.APPLY_BUILDING_BLOCK,
		UIText.CITIZEN_BUILDING_STATUS_TEXT,
		float(construction_site.labour_seconds_by_resource().get(
			resource_kind,
			GameplaySettingsScript.CONSTRUCTION_BLOCK_LABOUR_SECONDS
		)),
		reservation_slot
	)
	var active_work: Dictionary = _active_work.get(citizen, {})
	active_work["log"] = citizen.task.get("log")
	active_work["stored_log"] = bool(citizen.task.get("stored_log", false))
	active_work["resource_kind"] = resource_kind
	active_work["construction_site"] = construction_site
	_active_work[citizen] = active_work


func _resume_construction_work(citizen: Citizen, task: Dictionary) -> void:
	var construction_site := task.get("construction_site") as SupportConstructionSite
	if not is_instance_valid(construction_site):
		_return_unapplied_building_block(citizen, task)
		citizen.finish_task(UIText.CITIZEN_CONSTRUCTION_SITE_UNAVAILABLE_STATUS_TEXT)
		return
	_start_construction_work(citizen, construction_site, task)


func _handle_deliver_food_arrival(citizen: Citizen, task: Dictionary) -> void:
	if is_instance_valid(task.get("pile_storage")):
		_start_storage_delivery_labour(citizen, task)
		return
	_reroute_or_release_storage_delivery(citizen, task)


func _all_piles() -> Array[PileStorage]:
	var piles: Array[PileStorage] = []
	if is_instance_valid(_starting_pile):
		piles.append(_starting_pile)
	for placed_pile in _placed_piles:
		if is_instance_valid(placed_pile):
			piles.append(placed_pile)
	return piles


func _nearest_reachable_pile_delivery(
	from_position: Vector3,
	resource_kind: String,
	excluded_pile: PileStorage = null
) -> Dictionary:
	var nearest_plan: Dictionary = {}
	var nearest_route_length := INF
	for pile in _all_piles():
		if pile == excluded_pile or not pile.visible or not pile.can_store_resource(resource_kind):
			continue
		for target_position in pile.delivery_approach_world_positions():
			if from_position.distance_to(target_position) + 0.0001 < GameplaySettingsScript.MINIMUM_DELIVERY_TRAVEL_DISTANCE:
				continue
			var route := _build_navigation_route(from_position, target_position, false)
			if route.is_empty():
				continue
			var route_length := 0.0
			var previous_position := from_position
			for route_position in route:
				route_length += previous_position.distance_to(route_position)
				previous_position = route_position
			if route_length < nearest_route_length:
				nearest_plan = {"pile": pile, "target": target_position}
				nearest_route_length = route_length
	return nearest_plan


func _start_storage_delivery_labour(citizen: Citizen, delivery_task: Dictionary) -> void:
	var pile := delivery_task.get("pile_storage") as PileStorage
	if not is_instance_valid(pile):
		_reroute_or_release_storage_delivery(citizen, delivery_task)
		return
	var resource_kind := "log" if str(delivery_task.get("kind", "")) == ActionCatalog.DELIVER_LOG else "calories"
	if not pile.can_store_resource(resource_kind):
		_reroute_or_release_storage_delivery(citizen, delivery_task, pile)
		return
	var pickup_position: Vector3 = delivery_task.get("pickup_position", citizen.global_position)
	if citizen.global_position.distance_to(pickup_position) + 0.0001 < GameplaySettingsScript.MINIMUM_DELIVERY_TRAVEL_DISTANCE:
		_reroute_or_release_storage_delivery(citizen, delivery_task)
		return
	citizen.task = delivery_task.duplicate(true)
	_begin_labour(
		citizen,
		pile,
		str(delivery_task.get("kind", "")),
		str(delivery_task.get("status_text_key", UIText.CITIZEN_IDLE_STATUS_TEXT)),
		GameplaySettingsScript.STORAGE_DELIVERY_LABOUR_SECONDS,
		citizen.get_instance_id(),
		true
	)


func _reroute_or_release_storage_delivery(
	citizen: Citizen,
	delivery_task: Dictionary,
	excluded_pile: PileStorage = null
) -> void:
	var resource_kind := "log" if str(delivery_task.get("kind", "")) == ActionCatalog.DELIVER_LOG else "calories"
	var pickup_position: Vector3 = delivery_task.get("pickup_position", citizen.global_position)
	var delivery_plan := _nearest_reachable_pile_delivery(pickup_position, resource_kind, excluded_pile)
	var alternate_pile := delivery_plan.get("pile") as PileStorage
	if is_instance_valid(alternate_pile):
		var rerouted_task := delivery_task.duplicate(true)
		rerouted_task["pile_storage"] = alternate_pile
		rerouted_task["pickup_position"] = pickup_position
		_assign_navigation_task(
			citizen,
			delivery_plan.get("target", citizen.global_position),
			rerouted_task,
			false
		)
		return
	if resource_kind == "log":
		citizen.set_carrying_log(false)
		var carried_log := delivery_task.get("log") as WorldItem
		if is_instance_valid(carried_log):
			carried_log.release_from_carry(citizen.global_position)
	else:
		citizen.set_carrying_food(false)
	citizen.clear_work_assignment()
	citizen.finish_task(UIText.CITIZEN_IDLE_STATUS_TEXT)


func _total_stored_resource(resource_kind: String) -> int:
	var total := 0
	for pile in _all_piles():
		total += pile.resource_count(resource_kind)
	return total


func _handle_fetch_workshop_input_arrival(citizen: Citizen, task: Dictionary) -> void:
	var source_pile := task.get("source_pile") as PileStorage
	var sawmill := task.get("sawmill") as SupportConstructionSite
	if (
		not is_instance_valid(source_pile)
		or not is_instance_valid(sawmill)
		or not sawmill.is_complete()
		or not source_pile.take_resource("log", 1)
	):
		citizen.finish_task(UIText.CITIZEN_SAWMILL_NEEDS_LOG_STATUS_TEXT)
		return
	citizen.set_carrying_resource("log", true)
	_assign_navigation_task(citizen, sawmill.global_position, {
		"kind": ActionCatalog.SAW_PLANK,
		"status_text_key": UIText.CITIZEN_WALKING_STATUS_TEXT,
		"sawmill": sawmill,
		"source_pile": source_pile,
		"resource_kind": "log",
	}, true)


func _handle_sawmill_arrival(citizen: Citizen, task: Dictionary) -> void:
	var sawmill := task.get("sawmill") as SupportConstructionSite
	if not is_instance_valid(sawmill) or not sawmill.is_complete():
		_return_sawmill_input(citizen, task)
		citizen.finish_task(UIText.CITIZEN_CONSTRUCTION_SITE_UNAVAILABLE_STATUS_TEXT)
		return
	citizen.task = task.duplicate(true)
	_begin_labour(
		citizen,
		sawmill,
		ActionCatalog.SAW_PLANK,
		UIText.CITIZEN_SAWING_PLANK_STATUS_TEXT,
		GameplaySettingsScript.SAWMILL_PLANK_LABOUR_SECONDS,
		citizen.get_instance_id()
	)
	var active_work: Dictionary = _active_work.get(citizen, {})
	active_work["source_pile"] = task.get("source_pile")
	active_work["sawmill"] = sawmill
	active_work["resource_kind"] = "log"
	_active_work[citizen] = active_work


func _start_tree_cut_work(citizen: Citizen, tree: WorldItem) -> void:
	if tree.item_kind not in ["tree", "dead_tree", "palm_tree"] or tree.tree_log_count <= 0:
		citizen.finish_task(UIText.CITIZEN_TREE_UNAVAILABLE_STATUS_TEXT)
		return
	_begin_labour(
		citizen,
		tree,
		ActionCatalog.CHOP_TREE,
		UIText.CITIZEN_CUTTING_TREE_STATUS_TEXT,
		GameplaySettingsScript.TREE_CUT_LABOUR_SECONDS,
		int(citizen.task.get("tree_work_slot", 0))
	)
	citizen.set_chopping(true, tree.global_position)


func _start_excavation_work(citizen: Citizen, excavation_site: ExcavationSite) -> void:
	_begin_labour(
		citizen,
		excavation_site,
		ActionCatalog.EXCAVATE,
		UIText.CITIZEN_DIGGING_STATUS_TEXT,
		GameplaySettingsScript.EXCAVATION_LABOUR_SECONDS
	)


func _start_resource_work(
	citizen: Citizen,
	target: WorldItem,
	work_kind: String,
	status_text_key: String
) -> void:
	_begin_labour(
		citizen,
		target,
		work_kind,
		status_text_key,
		GameplaySettingsScript.RESOURCE_GATHER_LABOUR_SECONDS
	)


func _begin_labour(
	citizen: Citizen,
	target: Node3D,
	work_kind: String,
	status_text_key: String,
	required_seconds: float,
	work_slot := -1,
	hide_progress_bar := false
) -> void:
	_cancel_active_work(citizen)
	var labour_key := _labour_key(target, work_kind, work_slot)
	var record := _labour_record_for(target, work_kind, required_seconds, work_slot, hide_progress_bar)
	var labour := record.get("labour") as AppliedLabour
	var contributor_id := citizen.get_instance_id()
	labour.resume(contributor_id)
	var progress_bar := record.get("bar") as LabourProgressBar
	if is_instance_valid(progress_bar):
		progress_bar.visible = not hide_progress_bar and not _is_selected_construction_total_progress_target(
			target,
			work_kind
		)
	_active_work[citizen] = {
		"kind": work_kind,
		"target": target,
		"labour_key": labour_key,
		"contributor_id": contributor_id,
		"work_slot": work_slot,
	}
	citizen.status_text_key = status_text_key
	citizen.status_text_arguments.clear()


func _labour_key(target: Node3D, work_kind: String, work_slot := -1) -> String:
	if work_slot >= 0 and work_kind in [
		ActionCatalog.CHOP_TREE,
		ActionCatalog.APPLY_BUILDING_BLOCK,
		ActionCatalog.SAW_PLANK,
		ActionCatalog.DELIVER_LOG,
		ActionCatalog.DELIVER_FOOD,
	]:
		return "%d:%s:%d" % [target.get_instance_id(), work_kind, work_slot]
	return "%d:%s" % [target.get_instance_id(), work_kind]


func _labour_record_for(
	target: Node3D,
	work_kind: String,
	required_seconds: float,
	work_slot := -1,
	hide_progress_bar := false
) -> Dictionary:
	var labour_key := _labour_key(target, work_kind, work_slot)
	if _labour_records.has(labour_key):
		return _labour_records[labour_key] as Dictionary
	var record := {
		"kind": work_kind,
		"target": target,
		"labour": AppliedLabourScript.new(required_seconds),
		"bar": _create_labour_progress_bar(required_seconds),
		"work_slot": work_slot,
		"hide_progress_bar": hide_progress_bar,
	}
	_labour_records[labour_key] = record
	return record


func _update_labour(delta: float) -> void:
	var completed_labour: Dictionary = {}
	var cancelled_citizens: Array[Citizen] = []
	for citizen_value in _active_work:
		var citizen := citizen_value as Citizen
		var work: Dictionary = _active_work[citizen]
		var target := work.get("target") as Node3D
		var labour_key := str(work.get("labour_key", ""))
		var record: Dictionary = _labour_records.get(labour_key, {})
		var labour := record.get("labour") as AppliedLabour
		if not is_instance_valid(citizen) or not is_instance_valid(target) or labour == null:
			cancelled_citizens.append(citizen)
			continue
		var contributor_id := int(work.get("contributor_id", 0))
		var completed := labour.apply(contributor_id, delta)
		var progress := labour.progress_ratio()
		if str(work.get("kind", "")) == ActionCatalog.CHOP_TREE:
			citizen.set_chop_progress(progress)
		if completed:
			completed_labour[labour_key] = citizen
	for citizen in cancelled_citizens:
		var cancelled_work: Dictionary = _active_work.get(citizen, {})
		var cancelled_kind := str(cancelled_work.get("kind", ""))
		var cancelled_target := cancelled_work.get("target") as Node3D
		var cancelled_labour_key := str(cancelled_work.get("labour_key", ""))
		_cancel_active_work(citizen)
		if not is_instance_valid(cancelled_target):
			_remove_labour_record(cancelled_labour_key)
		if is_instance_valid(citizen):
			var unavailable_status := UIText.CITIZEN_TREE_UNAVAILABLE_STATUS_TEXT
			match cancelled_kind:
				ActionCatalog.APPLY_BUILDING_BLOCK:
					unavailable_status = UIText.CITIZEN_CONSTRUCTION_SITE_UNAVAILABLE_STATUS_TEXT
				ActionCatalog.EXCAVATE:
					unavailable_status = UIText.CITIZEN_EXCAVATION_UNAVAILABLE_STATUS_TEXT
				ActionCatalog.HARVEST_BUSH:
					unavailable_status = UIText.CITIZEN_BUSH_REGROWING_STATUS_TEXT
				ActionCatalog.COLLECT_CACTUS:
					unavailable_status = UIText.CITIZEN_CACTUS_UNAVAILABLE_STATUS_TEXT
			citizen.finish_task(unavailable_status)
	for labour_key_value in completed_labour:
		var labour_key := str(labour_key_value)
		if _labour_records.has(labour_key):
			_complete_labour_job(labour_key, completed_labour[labour_key] as Citizen)
	_update_labour_records(delta)


func _update_labour_records(delta: float) -> void:
	for labour_key_value in _labour_records.keys():
		var labour_key := str(labour_key_value)
		var record: Dictionary = _labour_records[labour_key]
		var target := record.get("target") as Node3D
		var labour := record.get("labour") as AppliedLabour
		var progress_bar := record.get("bar") as LabourProgressBar
		if not is_instance_valid(target) or labour == null:
			_remove_labour_record(labour_key)
			continue
		labour.update_interruption(delta)
		if not is_instance_valid(progress_bar):
			continue
		progress_bar.set_progress_ratio(labour.progress_ratio())
		progress_bar.set_sun_screen_side(_sun_screen_side())
		var world_anchor := target.global_position + Vector3.UP * 0.18
		progress_bar.visible = (
			not bool(record.get("hide_progress_bar", false))
			and labour.should_be_visible()
			and not _camera.is_position_behind(world_anchor)
			and not _is_selected_construction_total_progress_target(
				target,
				str(record.get("kind", ""))
			)
		)
		if progress_bar.visible:
			var work_slot := int(record.get("work_slot", -1))
			var slot_screen_offset := Vector2(0.0, -float(maxi(0, work_slot)) * 10.0)
			progress_bar.position = _camera.unproject_position(world_anchor) - Vector2(
				progress_bar.size.x * 0.5,
				progress_bar.size.y
			) + slot_screen_offset


func _sun_screen_side() -> float:
	if not is_instance_valid(_sun) or not is_instance_valid(_camera):
		return 0.0
	var direction_to_sun := _sun.global_transform.basis.z.normalized()
	var camera_right := _camera.global_transform.basis.x.normalized()
	return clampf(direction_to_sun.dot(camera_right), -1.0, 1.0)


func _complete_labour_job(labour_key: String, completing_citizen: Citizen) -> void:
	var record: Dictionary = _labour_records.get(labour_key, {})
	if record.is_empty():
		return
	var work_kind := str(record.get("kind", ""))
	var target := record.get("target") as Node3D
	for citizen_value in _active_work.keys():
		var citizen := citizen_value as Citizen
		var work: Dictionary = _active_work[citizen]
		if str(work.get("labour_key", "")) != labour_key:
			continue
		_active_work.erase(citizen)
		if is_instance_valid(citizen):
			citizen.set_chopping(false)
			if citizen != completing_citizen:
				citizen.finish_task()
	_remove_labour_record(labour_key)
	match work_kind:
		ActionCatalog.DELIVER_LOG, ActionCatalog.DELIVER_FOOD:
			_complete_storage_delivery_work(completing_citizen)
		ActionCatalog.APPLY_BUILDING_BLOCK:
			_complete_construction_work(completing_citizen, target as SupportConstructionSite)
		ActionCatalog.EXCAVATE:
			_complete_excavation_work(completing_citizen, target as ExcavationSite)
		ActionCatalog.HARVEST_BUSH:
			_complete_bush_harvest_work(completing_citizen, target as WorldItem)
		ActionCatalog.COLLECT_CACTUS:
			_complete_cactus_collection_work(completing_citizen, target as WorldItem)
		ActionCatalog.SAW_PLANK:
			_complete_sawmill_work(completing_citizen, target as SupportConstructionSite)
		_:
			_complete_tree_cut_work(completing_citizen, target as WorldItem)


func _complete_storage_delivery_work(citizen: Citizen) -> void:
	if not is_instance_valid(citizen):
		return
	var delivery_task := citizen.task.duplicate(true)
	var pile := delivery_task.get("pile_storage") as PileStorage
	var resource_kind := "log" if str(delivery_task.get("kind", "")) == ActionCatalog.DELIVER_LOG else "calories"
	var amount := 1 if resource_kind == "log" else int(delivery_task.get("amount", 0))
	if not is_instance_valid(pile) or not pile.store_resource(resource_kind, amount):
		_reroute_or_release_storage_delivery(citizen, delivery_task, pile)
		return
	if resource_kind == "log":
		citizen.set_carrying_log(false)
		var carried_log := delivery_task.get("log") as WorldItem
		if is_instance_valid(carried_log):
			_items.erase(carried_log)
			carried_log.queue_free()
	else:
		citizen.set_carrying_food(false)
		_calories = _total_stored_resource("calories")
	_continue_persistent_assignment(citizen)


func _complete_construction_work(
	citizen: Citizen,
	construction_site: SupportConstructionSite
) -> void:
	if not is_instance_valid(citizen) or not is_instance_valid(construction_site):
		return
	var material_task := citizen.task.duplicate()
	var contributor_id := citizen.get_instance_id()
	if not construction_site.apply_reserved_resource(contributor_id):
		_return_unapplied_building_block(citizen, material_task)
		citizen.finish_task(UIText.CITIZEN_CONSTRUCTION_SITE_UNAVAILABLE_STATUS_TEXT)
		return
	_consume_applied_building_block(citizen, material_task)
	if str(citizen.work_assignment.get("kind", "")) == "construction":
		_continue_build(citizen, construction_site)
	else:
		citizen.finish_task(UIText.CITIZEN_IDLE_STATUS_TEXT)


func _consume_applied_building_block(citizen: Citizen, material_task: Dictionary) -> void:
	var resource_kind := str(material_task.get("resource_kind", "log"))
	citizen.set_carrying_resource(resource_kind, false)
	var carried_log := material_task.get("log") as WorldItem
	if is_instance_valid(carried_log):
		_items.erase(carried_log)
		carried_log.queue_free()


func _return_unapplied_building_block(citizen: Citizen, material_task: Dictionary) -> void:
	if not is_instance_valid(citizen):
		return
	var construction_site := material_task.get("construction_site") as SupportConstructionSite
	if is_instance_valid(construction_site):
		construction_site.release_log_reservation(citizen.get_instance_id())
	var resource_kind := str(material_task.get("resource_kind", "log"))
	citizen.set_carrying_resource(resource_kind, false)
	if bool(material_task.get("stored_log", false)):
		if is_instance_valid(_starting_pile):
			if not _starting_pile.store_resource(resource_kind, 1) and resource_kind == "log":
				_spawn_item("log", citizen.global_position)
		return
	var carried_log := material_task.get("log") as WorldItem
	if is_instance_valid(carried_log):
		carried_log.release_from_carry(citizen.global_position)


func _complete_sawmill_work(citizen: Citizen, sawmill: SupportConstructionSite) -> void:
	if not is_instance_valid(citizen) or not is_instance_valid(sawmill):
		return
	citizen.set_carrying_resource("log", false)
	if is_instance_valid(_starting_pile):
		_starting_pile.store_resource("plank", 1)
	citizen.finish_task(UIText.CITIZEN_PLANK_COMPLETE_STATUS_TEXT)


func _return_sawmill_input(citizen: Citizen, material_task: Dictionary) -> void:
	if not is_instance_valid(citizen):
		return
	citizen.set_carrying_resource("log", false)
	var source_pile := material_task.get("source_pile") as PileStorage
	if is_instance_valid(source_pile):
		source_pile.store_resource("log", 1)


func _complete_bush_harvest_work(citizen: Citizen, bush: WorldItem) -> void:
	if not is_instance_valid(citizen) or not is_instance_valid(bush):
		return
	_mark_streamed_entity_dirty(bush)
	if bush.harvest():
		var pickup_position := citizen.global_position
		var delivery_plan := _nearest_reachable_pile_delivery(pickup_position, "calories")
		var destination_pile := delivery_plan.get("pile") as PileStorage
		if is_instance_valid(destination_pile):
			citizen.set_carrying_food(true)
			_assign_navigation_task(citizen, delivery_plan.get("target", pickup_position), {
				"kind": ActionCatalog.DELIVER_FOOD,
				"status_text_key": UIText.CITIZEN_CARRYING_FOOD_STATUS_TEXT,
				"pile_storage": destination_pile,
				"amount": 1,
				"pickup_position": pickup_position,
			}, false)
		else:
			citizen.finish_task(UIText.CITIZEN_HARVESTED_CALORIE_STATUS_TEXT)
	else:
		citizen.finish_task(UIText.CITIZEN_BUSH_REGROWING_STATUS_TEXT)


func _complete_cactus_collection_work(citizen: Citizen, cactus: WorldItem) -> void:
	if not is_instance_valid(citizen) or not is_instance_valid(cactus):
		return
	if not is_instance_valid(_starting_pile) or not _starting_pile.can_store_resource("water"):
		citizen.finish_task(UIText.CITIZEN_WATER_NEEDS_VESSEL_STATUS_TEXT)
		return
	_mark_streamed_entity_removed(cactus)
	var cactus_world_unit := _world_unit_cell(cactus.global_position)
	_occupied_static_world_units.erase(cactus_world_unit)
	_items.erase(cactus)
	var collected_water := cactus.collect_water()
	if collected_water > 0:
		_water += collected_water
		citizen.finish_task(UIText.CITIZEN_COLLECTED_WATER_STATUS_TEXT)
	else:
		citizen.finish_task(UIText.CITIZEN_CACTUS_UNAVAILABLE_STATUS_TEXT)


func _mark_streamed_entity_removed(item: WorldItem) -> void:
	var entity_id := str(item.get_meta("stream_entity_id", ""))
	if not entity_id.is_empty():
		_streamed_entity_tombstones[entity_id] = true
		_streamed_item_states.erase(entity_id)
	var stream_chunk: Variant = item.get_meta("stream_chunk", null)
	if stream_chunk is Vector2i and _streamed_items_by_chunk.has(stream_chunk):
		var streamed_items: Array = _streamed_items_by_chunk[stream_chunk]
		streamed_items.erase(item)


func _mark_streamed_entity_dirty(item: WorldItem) -> void:
	if not str(item.get_meta("stream_entity_id", "")).is_empty():
		item.set_meta("stream_dirty", true)


func _complete_excavation_work(citizen: Citizen, excavation_site: ExcavationSite) -> void:
	if not is_instance_valid(citizen) or not is_instance_valid(excavation_site):
		return
	var world_cell := _world_unit_cell(excavation_site.global_position)
	_excavated_cells[world_cell] = true
	_excavation_sites.erase(excavation_site)
	if _selected_world_object == excavation_site:
		_clear_object_selection()
	_create_excavated_pit(world_cell)
	_update_excavated_ground_mask()
	excavation_site.queue_free()
	citizen.finish_task(UIText.CITIZEN_EXCAVATION_COMPLETE_STATUS_TEXT)


func _complete_tree_cut_work(citizen: Citizen, tree: WorldItem) -> void:
	if not is_instance_valid(citizen) or not is_instance_valid(tree):
		return
	_mark_streamed_entity_dirty(tree)
	var tree_position := tree.global_position
	var cut_result: Dictionary = tree.cut_top_log()
	if cut_result.is_empty():
		citizen.finish_task(UIText.CITIZEN_TREE_UNAVAILABLE_STATUS_TEXT)
		return
	var dropped_log := _spawn_item(
		"log",
		cut_result.get("drop_position", tree_position),
		int(cut_result.get("log_detail_seed", 1))
	)
	var destination_plan := _nearest_reachable_pile_delivery(citizen.global_position, "log")
	var destination_pile := destination_plan.get("pile") as PileStorage
	if is_instance_valid(dropped_log) and is_instance_valid(destination_pile):
		_assign_navigation_task(citizen, dropped_log.global_position, {
			"kind": ActionCatalog.FETCH_LOG,
			"status_text_key": UIText.CITIZEN_FETCHING_LOG_STATUS_TEXT,
			"log": dropped_log,
			"pile_storage": destination_pile,
		}, false)
	else:
		citizen.finish_task(UIText.CITIZEN_CUT_LOG_STATUS_TEXT)


func _continue_persistent_assignment(citizen: Citizen) -> void:
	if not is_instance_valid(citizen) or citizen.is_sleeping():
		return
	match str(citizen.work_assignment.get("kind", "")):
		ActionCatalog.CHOP_TREE:
			var tree_and_slot := _nearest_available_tree_work(citizen.global_position)
			var next_tree := tree_and_slot.get("tree") as WorldItem
			if is_instance_valid(next_tree):
				_order_chop(
					citizen,
					next_tree,
					int(tree_and_slot.get("work_slot", -1)),
					"",
					true
				)
				return
		ActionCatalog.HARVEST_BUSH:
			var next_bush := _nearest_available_bush(citizen.global_position)
			if is_instance_valid(next_bush):
				_order_harvest(citizen, next_bush, true)
				return
		"construction":
			_continue_build(citizen, _nearest_incomplete_construction_site(citizen.global_position))
			return
	citizen.finish_task(UIText.CITIZEN_IDLE_STATUS_TEXT)


func _nearest_available_tree_work(from_position: Vector3) -> Dictionary:
	var nearest_tree: WorldItem
	var nearest_slot := -1
	var nearest_distance := INF
	for item in _items:
		if (
			not is_instance_valid(item)
			or not item.visible
			or item.item_kind not in ["tree", "dead_tree", "palm_tree"]
			or item.tree_log_count <= 0
		):
			continue
		var work_slot := _next_available_tree_work_slot(item)
		if work_slot < 0:
			continue
		var distance := from_position.distance_squared_to(item.global_position)
		if distance < nearest_distance:
			nearest_tree = item
			nearest_slot = work_slot
			nearest_distance = distance
	return {"tree": nearest_tree, "work_slot": nearest_slot}


func _nearest_available_bush(from_position: Vector3) -> WorldItem:
	var reserved_bushes: Dictionary = {}
	for citizen in _citizens:
		if is_instance_valid(citizen) and str(citizen.task.get("kind", "")) == ActionCatalog.HARVEST_BUSH:
			var reserved_target: Variant = citizen.task.get("target")
			if is_instance_valid(reserved_target):
				reserved_bushes[reserved_target] = true
	var nearest: WorldItem
	var nearest_distance := INF
	for item in _items:
		if (
			not is_instance_valid(item)
			or not item.visible
			or item.item_kind != "bush"
			or not item.can_harvest()
			or reserved_bushes.has(item)
		):
			continue
		var distance := from_position.distance_squared_to(item.global_position)
		if distance < nearest_distance:
			nearest = item
			nearest_distance = distance
	return nearest


func _cancel_active_work(citizen: Citizen, preserve_carried_material := false) -> void:
	if not _active_work.has(citizen):
		return
	var work: Dictionary = _active_work[citizen]
	var labour_key := str(work.get("labour_key", ""))
	var record: Dictionary = _labour_records.get(labour_key, {})
	var labour := record.get("labour") as AppliedLabour
	if labour != null:
		labour.interrupt(int(work.get("contributor_id", 0)))
	if (
		str(work.get("kind", "")) == ActionCatalog.APPLY_BUILDING_BLOCK
		and not preserve_carried_material
	):
		_return_unapplied_building_block(citizen, work)
		_remove_labour_record(labour_key)
	elif str(work.get("kind", "")) == ActionCatalog.SAW_PLANK and not preserve_carried_material:
		_return_sawmill_input(citizen, work)
		_remove_labour_record(labour_key)
	elif str(work.get("kind", "")) in [ActionCatalog.DELIVER_LOG, ActionCatalog.DELIVER_FOOD]:
		_remove_labour_record(labour_key)
	_active_work.erase(citizen)
	if is_instance_valid(citizen):
		citizen.set_chopping(false)


func _create_labour_progress_bar(required_seconds: float) -> LabourProgressBar:
	var progress_bar := LabourProgressBarScript.new() as LabourProgressBar
	progress_bar.configure(required_seconds, VisualTokens.OUTLINE_PIXELS, Palette.WOMAN_CLOTHING)
	_world_progress_layer.add_child(progress_bar)
	return progress_bar


func _is_selected_construction_total_progress_target(
	target: Node3D,
	work_kind: String
) -> bool:
	return (
		work_kind == ActionCatalog.APPLY_BUILDING_BLOCK
		and is_instance_valid(_selected_building)
		and target == _selected_building
		and _selected_world_object == _selected_building
		and _selected_building.is_planned()
	)


func _remove_labour_record(labour_key: String) -> void:
	if not _labour_records.has(labour_key):
		return
	var record: Dictionary = _labour_records[labour_key]
	var progress_bar := record.get("bar") as LabourProgressBar
	if is_instance_valid(progress_bar):
		progress_bar.queue_free()
	_labour_records.erase(labour_key)


func _raycast(screen_position: Vector2) -> Dictionary:
	var origin := _camera.project_ray_origin(screen_position)
	var end := origin + _camera.project_ray_normal(screen_position) * 100.0
	var query := PhysicsRayQueryParameters3D.create(origin, end)
	return get_world_3d().direct_space_state.intersect_ray(query)


func _world_object_for(node: Node) -> Variant:
	var current := node
	while current != null:
		if current.has_meta("world_object"):
			return current.get_meta("world_object")
		current = current.get_parent()
	return null


func _update_hover_target(delta: float) -> void:
	if not is_instance_valid(_hover_tooltip) or not is_instance_valid(_camera):
		return
	var hovered_control: Control = get_viewport().gui_get_hovered_control()
	if hovered_control != null and hovered_control != _hover_tooltip:
		_clear_hover_outline()
		_reset_hover_candidate()
		return
	var mouse_position: Vector2 = get_viewport().get_mouse_position()
	if mouse_position.distance_to(_hover_last_mouse_position) > 3.0:
		_hover_last_mouse_position = mouse_position
		_reset_hover_candidate()
		return
	var hit: Dictionary = _raycast(mouse_position)
	if hit.is_empty():
		_clear_hover_outline()
		_reset_hover_candidate()
		return
	var collider: Node = hit.get("collider") as Node
	var world_object: Variant = _world_object_for(collider)
	if not _hover_target_is_revealed(hit, world_object):
		_clear_hover_outline()
		_hide_hover_tooltip_behind_fog()
		return
	var is_ground: bool = collider != null and str(collider.get_meta("world_kind", "")) == "ground"
	_set_hover_outline_target(world_object, hit.get("position", Vector3.ZERO), is_ground)
	var display_name: String = _hover_display_name(world_object, collider)
	if display_name.is_empty():
		_clear_hover_outline()
		_reset_hover_candidate()
		return
	var candidate_key := "%d:%s" % [collider.get_instance_id(), display_name]
	if candidate_key != _hover_candidate_key:
		_hover_candidate_key = candidate_key
		_hover_stable_elapsed = 0.0
		_hover_target_visible = false
		return
	_hover_stable_elapsed += delta
	if _hover_stable_elapsed < HOVER_DELAY_SECONDS:
		_hover_target_visible = false
		return
	var tooltip_text: String = display_name
	if _debug_hover_enabled:
		var debug_text: String = _hover_debug_text(world_object, collider, hit)
		if not debug_text.is_empty():
			tooltip_text += "\n" + debug_text
	_hover_tooltip.text = tooltip_text
	_hover_tooltip.reset_size()
	var tooltip_size := _hover_tooltip.get_combined_minimum_size()
	_hover_tooltip.size = tooltip_size
	var viewport_size := Vector2(get_viewport().get_visible_rect().size)
	_hover_tooltip.position = _world_tooltip_position(
		mouse_position,
		tooltip_size,
		viewport_size
	)
	_hover_target_visible = true


func _hover_target_is_revealed(hit: Dictionary, world_object: Variant) -> bool:
	var hit_position: Vector3 = hit.get("position", Vector3.ZERO)
	if not _is_world_position_revealed(hit_position):
		return false
	if world_object is Node3D:
		return _is_world_position_revealed((world_object as Node3D).global_position)
	return true


func _hide_hover_tooltip_behind_fog() -> void:
	_reset_hover_candidate()
	_hover_alpha = 0.0
	if is_instance_valid(_hover_tooltip):
		_hover_tooltip.modulate.a = 0.0
		_hover_tooltip.visible = false


func _world_tooltip_position(
	pointer_position: Vector2,
	tooltip_size: Vector2,
	viewport_size: Vector2
) -> Vector2:
	var horizontal_offset := 18.0
	var vertical_offset := -tooltip_size.y - 18.0
	var horizontal_threshold := maxf(
		TOOLTIP_EDGE_THRESHOLD_PIXELS,
		tooltip_size.x + 26.0
	)
	var vertical_threshold := maxf(
		TOOLTIP_EDGE_THRESHOLD_PIXELS,
		tooltip_size.y + 26.0
	)
	# Every edge points the label back towards the screen centre. At corners the
	# horizontal and vertical decisions combine, keeping the custom cursor and
	# its label together without clipping either one.
	if pointer_position.x >= viewport_size.x - horizontal_threshold:
		horizontal_offset = -tooltip_size.x - 18.0
	if pointer_position.y <= vertical_threshold:
		vertical_offset = 18.0
	elif pointer_position.y >= viewport_size.y - vertical_threshold:
		vertical_offset = -tooltip_size.y - 18.0
	var resolved_position := pointer_position + Vector2(horizontal_offset, vertical_offset)
	resolved_position.x = clampf(
		resolved_position.x,
		8.0,
		maxf(8.0, viewport_size.x - tooltip_size.x - 8.0)
	)
	resolved_position.y = clampf(
		resolved_position.y,
		8.0,
		maxf(8.0, viewport_size.y - tooltip_size.y - 8.0)
	)
	return resolved_position


func _reset_hover_candidate() -> void:
	_hover_candidate_key = ""
	_hover_stable_elapsed = 0.0
	_hover_target_visible = false


func _update_hover_transition(delta: float) -> void:
	if not is_instance_valid(_hover_tooltip):
		return
	var target_alpha := 1.0 if _hover_target_visible else 0.0
	_hover_alpha = move_toward(_hover_alpha, target_alpha, HOVER_FADE_SPEED * delta)
	_hover_tooltip.modulate.a = _hover_alpha
	_hover_tooltip.visible = _hover_alpha > 0.01


func _hover_display_name(world_object: Variant, collider: Node) -> String:
	if world_object is Citizen:
		var person := world_object as Citizen
		var work: String = person.work_assignment.get("kind", person.task.get("kind", ""))
		var role := "idle"
		match work:
			ActionCatalog.CHOP_TREE: role = "woodcutter"
			ActionCatalog.HARVEST_BUSH, ActionCatalog.DELIVER_FOOD: role = "forager"
			ActionCatalog.COLLECT_CACTUS: role = "hauler"
			ActionCatalog.EXCAVATE: role = "miner"
			ActionCatalog.FETCH_WORKSHOP_INPUT, ActionCatalog.SAW_PLANK: role = "sawyer"
			"construction", ActionCatalog.FETCH_LOG, ActionCatalog.DELIVER_LOG, ActionCatalog.APPLY_BUILDING_BLOCK: role = "builder"
		return UIText.text("person_job_%s_text" % role)
	if world_object is SupportConstructionSite:
		return (world_object as SupportConstructionSite).hover_text()
	if world_object is ExcavationSite:
		return UIText.text(UIText.EXCAVATION_NAME_TEXT)
	if world_object is PileStorage:
		return UIText.text(UIText.PILE_NAME_TEXT)
	if world_object is TerrainBlock:
		return UIText.text(UIText.SOIL_BLOCK_NAME_TEXT)
	if world_object is WorldItem:
		var item := world_object as WorldItem
		if item.item_kind in ["tree", "dead_tree", "palm_tree"]:
			var tree_resource_text_keys := {
				"tree": UIText.TREE_RESOURCE_NAME_TEXT,
				"dead_tree": UIText.DEAD_TREE_RESOURCE_NAME_TEXT,
				"palm_tree": UIText.PALM_RESOURCE_NAME_TEXT,
			}
			return UIText.text(
				tree_resource_text_keys[item.item_kind],
				[item.tree_log_count, WorldItem.TREE_MAX_LOG_COUNT]
			)
		var world_item_text_keys := {
			"bush": UIText.BUSH_NAME_TEXT,
			"cactus": UIText.CACTUS_NAME_TEXT,
			"stone": UIText.LIMESTONE_NAME_TEXT,
			"log": UIText.LOG_NAME_TEXT,
			"stump": UIText.STUMP_NAME_TEXT,
		}
		var world_item_text_key: String = world_item_text_keys.get(item.item_kind, "")
		return UIText.text(world_item_text_key) if not world_item_text_key.is_empty() else ""
	if collider != null and collider.get_meta("world_kind", "") == "ground":
		return UIText.text(UIText.SAND_NAME_TEXT)
	return ""


func _hover_debug_text(world_object: Variant, collider: Node, hit: Dictionary) -> String:
	var hit_position: Vector3 = hit.get("position", Vector3.ZERO)
	if world_object is Citizen:
		var citizen := world_object as Citizen
		return UIText.text(UIText.CITIZEN_DEBUG_HOVER_TEXT, [
			citizen.visual_variant,
			citizen.get_status_text(),
			citizen.global_position.x,
			citizen.global_position.z,
		])
	if world_object is SupportConstructionSite:
		var support := world_object as SupportConstructionSite
		return UIText.text(UIText.SUPPORT_DEBUG_HOVER_TEXT, [
			support.delivered_logs,
			int(support.construction_recipe().get("log", 0)),
			support.global_position.x,
			support.global_position.z,
		])
	if world_object is PileStorage:
		var pile := world_object as PileStorage
		return UIText.text(UIText.PILE_DEBUG_HOVER_TEXT, [
			pile.stored_logs,
			pile.stored_calories,
		])
	if world_object is WorldItem:
		var item := world_object as WorldItem
		return UIText.text(UIText.WORLD_ITEM_DEBUG_HOVER_TEXT, [
			item.permanent_detail_seed, item.tree_log_count, item.water_stored
		])
	if collider != null and collider.get_meta("world_kind", "") == "ground":
		var cell := _world_unit_cell(hit_position)
		return UIText.text(UIText.WORLD_UNIT_DEBUG_HOVER_TEXT, [cell.x, cell.y])
	return ""


func _snap_to_world_unit(world_position: Vector3) -> Vector3:
	return Vector3(round(world_position.x), 0.0, round(world_position.z))


func _seed_world() -> void:
	_spawn_starting_pile()
	_seed_bush_patches()
	_seed_desert_resource_patches()
	_seed_tree_distribution()

	_spawn_citizen(Vector3(-1.5, 0.0, 0.5))
	_spawn_citizen(Vector3(0.5, 0.0, 1.5))
	_select_only(_citizens[0])
	_selected_citizen.status_text_key = UIText.CITIZEN_SELECTED_STATUS_TEXT
	_selected_citizen.status_text_arguments.clear()
	_camera_focus = _selected_citizen.global_position
	_update_camera_transform()


func _spawn_starting_pile() -> void:
	_starting_pile = PileStorageScript.new() as PileStorage
	_starting_pile.configure_footprint([
		Vector2i(0, 0), Vector2i(1, 0),
		Vector2i(0, 1), Vector2i(1, 1),
	])
	_starting_pile.configure_starting_inventory(6)
	add_child(_starting_pile)
	_starting_pile.global_position = Vector3(1.5, 0.0, 3.5)
	for pile_cell in _starting_pile.world_footprint_cells():
		_occupied_static_world_units[pile_cell] = true


func _spawn_tree_in_tile(tile: Vector2i, seed_value: int, slot: int) -> void:
	var x_offset := _seeded_offset(seed_value + slot * 43, 0.27)
	var z_offset := _seeded_offset(seed_value + slot * 71 + 11, 0.27)
	if slot == 1:
		x_offset = -x_offset
		z_offset = -z_offset
	var tree_kind := "dead_tree" if seed_value % 9 == 0 and slot == 0 else "tree"
	_spawn_item(tree_kind, Vector3(tile.x + 0.5 + x_offset, 0.0, tile.y + 0.5 + z_offset))


func _seed_tree_distribution() -> void:
	# Trees form irregular forests separated by clear land, with a smaller set
	# of standalone specimens between them. This avoids a repeating global
	# scatter while preserving approximately the previous overall density.
	var forest_centres := [
		Vector2i(-5, -4), Vector2i(-20, 15), Vector2i(17, -17),
		Vector2i(20, 19), Vector2i(-17, -21), Vector2i(2, 24),
	]
	var forest_radii := [4, 5, 5, 4, 4, 3]
	for forest_index in forest_centres.size():
		var forest_centre: Vector2i = forest_centres[forest_index]
		var forest_radius: int = forest_radii[forest_index]
		for offset_x in range(-forest_radius, forest_radius + 1):
			for offset_z in range(-forest_radius, forest_radius + 1):
				var tile := forest_centre + Vector2i(offset_x, offset_z)
				if _occupied_static_world_units.has(tile):
					continue
				var distance := Vector2(float(offset_x), float(offset_z)).length()
				if distance > float(forest_radius) + 0.25:
					continue
				var forest_seed := _coordinate_seed(tile.x, tile.y, 311 + forest_index)
				var centre_weight := 1.0 - distance / float(forest_radius + 1)
				var density_threshold := int(18.0 + centre_weight * 34.0)
				if forest_seed % 100 >= density_threshold:
					continue
				_occupied_static_world_units[tile] = true
				_spawn_tree_in_tile(tile, forest_seed, 0)
				if forest_seed % 11 == 0:
					_spawn_tree_in_tile(tile, forest_seed + 43, 1)

	var standalone_tiles := [
		Vector2i(7, 5), Vector2i(11, 1), Vector2i(-12, 2), Vector2i(4, -12),
		Vector2i(-2, 13), Vector2i(26, -3), Vector2i(-27, 6), Vector2i(10, 27),
		Vector2i(-8, -28), Vector2i(28, 8), Vector2i(-27, -8),
	]
	for standalone_index in standalone_tiles.size():
		var tile: Vector2i = standalone_tiles[standalone_index]
		if _occupied_static_world_units.has(tile):
			continue
		_occupied_static_world_units[tile] = true
		_spawn_tree_in_tile(tile, _coordinate_seed(tile.x, tile.y, 401 + standalone_index), 0)


func _seed_bush_patches() -> void:
	# Bushes now grow as recognizable colonies rather than independent random
	# points. Reusing three irregular footprints gives each patch a different
	# outline while keeping generation deterministic.
	var patch_shapes := [
		[
			Vector2i(0, 0), Vector2i(1, 0), Vector2i(-1, 0),
			Vector2i(0, 1), Vector2i(1, 1), Vector2i(-1, -1), Vector2i(0, -1),
		],
		[
			Vector2i(-2, 0), Vector2i(-1, 0), Vector2i(0, 0), Vector2i(1, 0),
			Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, -1), Vector2i(2, -1),
		],
		[
			Vector2i(0, -2), Vector2i(0, -1), Vector2i(0, 0), Vector2i(0, 1),
			Vector2i(1, -1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(-1, 1),
			Vector2i(2, 0),
		],
	]
	var patch_centres := [
		Vector2i(-2, -1), Vector2i(2, 2), Vector2i(-12, 8),
		Vector2i(13, -8), Vector2i(-22, -16), Vector2i(22, 18),
		Vector2i(-18, 24), Vector2i(17, 25), Vector2i(25, -23),
		Vector2i(-25, 3), Vector2i(3, -20),
	]
	for patch_index in patch_centres.size():
		var patch_centre: Vector2i = patch_centres[patch_index]
		var patch_shape: Array = patch_shapes[patch_index % patch_shapes.size()]
		for offset_value in patch_shape:
			var patch_offset: Vector2i = offset_value
			var bush_world_unit := patch_centre + patch_offset
			var bush_seed := _coordinate_seed(bush_world_unit.x, bush_world_unit.y, patch_index + 101)
			_spawn_bush_in_world_unit(bush_world_unit, bush_seed)


func _spawn_bush_in_world_unit(world_unit: Vector2i, seed_value: int) -> void:
	if _occupied_static_world_units.has(world_unit):
		return
	if is_instance_valid(_grass_renderer) and _grass_renderer.has_grass_in_world_unit(world_unit):
		return
	_occupied_bush_world_units[world_unit] = true
	_occupied_static_world_units[world_unit] = true
	var offset := Vector2(
		_seeded_offset(seed_value + 19, 0.075),
		_seeded_offset(seed_value + 47, 0.075)
	)
	_spawn_item(
		"bush",
		Vector3(float(world_unit.x) + 0.5 + offset.x, 0.0, float(world_unit.y) + 0.5 + offset.y)
	)


func _seed_desert_resource_patches() -> void:
	var compact_patch := [
		Vector2i(0, 0), Vector2i(1, 0), Vector2i(-1, 0),
		Vector2i(0, 1), Vector2i(1, 1), Vector2i(0, -1),
	]
	var long_patch := [
		Vector2i(-2, 0), Vector2i(-1, 0), Vector2i(0, 0),
		Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1),
	]
	_spawn_resource_patch("stone", Vector2i(5, -5), compact_patch, 211)
	_spawn_resource_patch("stone", Vector2i(-14, -9), long_patch, 223)
	_spawn_resource_patch("stone", Vector2i(18, 12), compact_patch, 227)
	_spawn_resource_patch("cactus", Vector2i(4, 1), compact_patch, 229)
	_spawn_resource_patch("cactus", Vector2i(-10, 15), long_patch, 233)
	_spawn_resource_patch("cactus", Vector2i(21, -14), compact_patch, 239)
	_spawn_resource_patch("palm_tree", Vector2i(-6, 6), compact_patch, 241)
	_spawn_resource_patch("palm_tree", Vector2i(15, 20), long_patch, 251)


func _spawn_resource_patch(kind: String, centre: Vector2i, shape: Array, salt: int) -> void:
	for offset_value in shape:
		var patch_offset: Vector2i = offset_value
		var world_unit := centre + patch_offset
		if _occupied_static_world_units.has(world_unit):
			continue
		_occupied_static_world_units[world_unit] = true
		var detail_seed := _coordinate_seed(world_unit.x, world_unit.y, salt)
		var offset := Vector2(
			_seeded_offset(detail_seed + 31, 0.11),
			_seeded_offset(detail_seed + 59, 0.11)
		)
		_spawn_item(
			kind,
			Vector3(float(world_unit.x) + 0.5 + offset.x, 0.0, float(world_unit.y) + 0.5 + offset.y)
		)


func _coordinate_seed(x_coordinate: int, z_coordinate: int, salt: int) -> int:
	return DeterministicRandomScript.coordinate_seed(x_coordinate, z_coordinate, salt)


func _seeded_offset(seed_value: int, maximum: float) -> float:
	return DeterministicRandomScript.signed_offset(seed_value, maximum)


func _spawn_item(kind: String, world_position: Vector3, explicit_detail_seed := 0) -> WorldItem:
	var item := WorldItem.new()
	item.set_simulation_speed(_simulation_speed)
	var detail_seed := explicit_detail_seed if explicit_detail_seed != 0 else _coordinate_seed(
		floori(world_position.x * 100.0),
		floori(world_position.z * 100.0),
		kind.length() * 19
	)
	item.configure(kind, detail_seed)
	add_child(item)
	item.global_position = world_position
	_items.append(item)
	if not _chunk_fog_images.is_empty():
		item.visible = _is_world_position_revealed(item.global_position)
	return item


func _spawn_citizen(world_position: Vector3) -> void:
	var citizen := Citizen.new()
	citizen.set_simulation_speed(_simulation_speed)
	citizen.configure_visual_variant("woman" if _citizens.size() % 2 == 0 else "man")
	add_child(citizen)
	citizen.global_position = world_position
	citizen.arrived.connect(_on_citizen_arrived)
	_citizens.append(citizen)


func _create_ground() -> void:
	_ground_material = _terrain_material(Palette.SAND_SURFACE)
	_world_chunks_root = Node3D.new()
	_world_chunks_root.name = "StreamedWorldChunks"
	add_child(_world_chunks_root)
	_update_excavated_ground_mask()


func _update_world_streaming(force := false) -> void:
	if not is_instance_valid(_world_chunks_root):
		return
	var required_chunks := WorldStreamerScript.required_chunks(
		_streaming_anchor_positions(),
		WorldStreamerScript.PRESENTATION_RADIUS_CHUNKS
	)
	for chunk_value in required_chunks:
		var chunk: Vector2i = chunk_value
		if force or not _loaded_chunks.has(chunk):
			_load_world_chunk(chunk)
	var unload_candidates: Array[Vector2i] = []
	for chunk_value in _loaded_chunks:
		var loaded_chunk: Vector2i = chunk_value
		if not required_chunks.has(loaded_chunk):
			unload_candidates.append(loaded_chunk)
	for chunk in unload_candidates:
		_unload_world_chunk(chunk)


func _streaming_anchor_positions() -> Array[Vector3]:
	var anchors: Array[Vector3] = [_camera_focus]
	for citizen in _citizens:
		if is_instance_valid(citizen):
			anchors.append(citizen.global_position)
	if is_instance_valid(_selected_world_object):
		anchors.append(_selected_world_object.global_position)
	for work_value in _active_work.values():
		var target := (work_value as Dictionary).get("target") as Node3D
		if is_instance_valid(target):
			anchors.append(target.global_position)
	return anchors


func _load_world_chunk(chunk: Vector2i) -> void:
	if _loaded_chunks.has(chunk):
		return
	var chunk_root := Node3D.new()
	chunk_root.name = "WorldChunk_%d_%d" % [chunk.x, chunk.y]
	_world_chunks_root.add_child(chunk_root)
	_create_ground_chunk(chunk, chunk_root)
	_create_fog_chunk(chunk, chunk_root)
	_loaded_chunks[chunk] = chunk_root

	var streamed_items: Array[WorldItem] = []
	for entity_definition in WorldStreamerScript.generated_surface_entities(
		chunk,
		_world_generation_profile.world_seed,
		_world_generation_profile.generator_version
	):
		var world_unit: Vector2i = entity_definition["world_unit"]
		var item_kind := str(entity_definition["kind"])
		var entity_id := str(entity_definition["id"])
		if _streamed_entity_tombstones.has(entity_id):
			continue
		if item_kind == "bush" and GrassRendererScript.generated_grass_at(world_unit):
			continue
		if _occupied_static_world_units.has(world_unit):
			continue
		_occupied_static_world_units[world_unit] = true
		if item_kind == "bush":
			_occupied_bush_world_units[world_unit] = true
		var detail_seed := int(entity_definition["detail_seed"])
		var offset := Vector2(
			_seeded_offset(detail_seed + 31, 0.11),
			_seeded_offset(detail_seed + 59, 0.11)
		)
		var item := _spawn_item(
			item_kind,
			Vector3(world_unit.x + 0.5 + offset.x, 0.0, world_unit.y + 0.5 + offset.y),
			detail_seed
		)
		item.set_meta("stream_chunk", chunk)
		item.set_meta("stream_entity_id", entity_id)
		item.set_meta("stream_dirty", false)
		if _streamed_item_states.has(entity_id):
			var saved_record := _streamed_item_states[entity_id] as Dictionary
			item.restore_stream_state(saved_record.get("state", {}))
			item.advance_stream_time(maxf(0.0, _elapsed - float(saved_record.get("saved_at", _elapsed))))
			item.set_meta("stream_dirty", true)
		else:
			item.advance_generated_age(_elapsed)
		streamed_items.append(item)
	_streamed_items_by_chunk[chunk] = streamed_items
	if is_instance_valid(_grass_renderer):
		_grass_renderer.load_world_chunk(chunk, _grass_exclusions_in_chunk(chunk))


func _create_ground_chunk(chunk: Vector2i, parent: Node3D) -> void:
	var chunk_origin := WorldStreamerScript.chunk_origin(chunk)
	var chunk_centre := Vector3(
		chunk_origin.x + WorldStreamerScript.CHUNK_SIZE * 0.5,
		0.0,
		chunk_origin.y + WorldStreamerScript.CHUNK_SIZE * 0.5
	)
	var ground_mesh := MeshInstance3D.new()
	ground_mesh.name = "Ground"
	var plane := PlaneMesh.new()
	plane.size = Vector2(WorldStreamerScript.CHUNK_SIZE, WorldStreamerScript.CHUNK_SIZE)
	ground_mesh.mesh = plane
	ground_mesh.position = chunk_centre
	ground_mesh.material_override = _ground_material
	parent.add_child(ground_mesh)

	var ground_body := StaticBody3D.new()
	ground_body.name = "GroundCollision"
	ground_body.position = chunk_centre
	ground_body.set_meta("world_kind", "ground")
	ground_body.set_meta("world_chunk", chunk)
	var ground_shape := CollisionShape3D.new()
	var ground_box := BoxShape3D.new()
	ground_box.size = Vector3(WorldStreamerScript.CHUNK_SIZE, 0.1, WorldStreamerScript.CHUNK_SIZE)
	ground_shape.shape = ground_box
	ground_shape.position.y = -0.05
	ground_body.add_child(ground_shape)
	parent.add_child(ground_body)


func _unload_world_chunk(chunk: Vector2i) -> void:
	if not _loaded_chunks.has(chunk):
		return
	var streamed_items: Array = _streamed_items_by_chunk.get(chunk, [])
	for item_value in streamed_items:
		if not is_instance_valid(item_value):
			continue
		var item := item_value as WorldItem
		var entity_id := str(item.get_meta("stream_entity_id", ""))
		if not entity_id.is_empty() and bool(item.get_meta("stream_dirty", false)):
			_streamed_item_states[entity_id] = {
				"state": item.stream_state(),
				"saved_at": _elapsed,
			}
		var world_unit := _world_unit_cell(item.global_position)
		_occupied_static_world_units.erase(world_unit)
		if item.item_kind == "bush":
			_occupied_bush_world_units.erase(world_unit)
		_items.erase(item)
		item.queue_free()
	_streamed_items_by_chunk.erase(chunk)
	if is_instance_valid(_grass_renderer):
		_grass_renderer.unload_world_chunk(chunk)
	_chunk_fog_images.erase(chunk)
	_chunk_fog_textures.erase(chunk)
	_chunk_fog_materials.erase(chunk)
	var chunk_root := _loaded_chunks[chunk] as Node3D
	_loaded_chunks.erase(chunk)
	if is_instance_valid(chunk_root):
		chunk_root.queue_free()


func _grass_excluded_world_units() -> Dictionary:
	var exclusions := _occupied_bush_world_units.duplicate()
	if is_instance_valid(_starting_pile):
		for pile_cell in _starting_pile.world_footprint_cells():
			exclusions[pile_cell] = true
	return exclusions


func _grass_exclusions_in_chunk(chunk: Vector2i) -> Dictionary:
	var exclusions: Dictionary = {}
	var bounds := WorldStreamerScript.chunk_world_bounds(chunk)
	for world_unit_value in _grass_excluded_world_units():
		var world_unit: Vector2i = world_unit_value
		if bounds.has_point(world_unit):
			exclusions[world_unit] = true
	return exclusions


func _update_excavated_ground_mask() -> void:
	if not is_instance_valid(_ground_material):
		return
	var shader_cells := PackedVector2Array()
	shader_cells.resize(64)
	var cell_index := 0
	for cell_value in _excavated_cells:
		if cell_index >= 64:
			break
		var world_cell: Vector2i = cell_value
		shader_cells[cell_index] = Vector2(world_cell)
		cell_index += 1
	_ground_material.set_shader_parameter("excavated_cell_count", cell_index)
	_ground_material.set_shader_parameter("excavated_cells", shader_cells)


func _create_excavated_pit(world_cell: Vector2i) -> void:
	if _excavated_pit_roots.has(world_cell):
		return
	var pit_root := Node3D.new()
	pit_root.name = "ExcavatedCell_%d_%d" % [world_cell.x, world_cell.y]
	pit_root.position = Vector3(float(world_cell.x) + 0.5, 0.0, float(world_cell.y) + 0.5)
	add_child(pit_root)
	var pit_material := _material(Palette.SAND_SURFACE.darkened(0.42))
	_create_pit_piece(pit_root, Vector3(0.94, 0.06, 0.94), Vector3(0.0, -0.48, 0.0), pit_material)
	_create_pit_piece(pit_root, Vector3(0.94, 0.46, 0.06), Vector3(0.0, -0.24, -0.47), pit_material)
	_create_pit_piece(pit_root, Vector3(0.94, 0.46, 0.06), Vector3(0.0, -0.24, 0.47), pit_material)
	_create_pit_piece(pit_root, Vector3(0.06, 0.46, 0.94), Vector3(-0.47, -0.24, 0.0), pit_material)
	_create_pit_piece(pit_root, Vector3(0.06, 0.46, 0.94), Vector3(0.47, -0.24, 0.0), pit_material)
	_excavated_pit_roots[world_cell] = pit_root


func _create_pit_piece(
	parent: Node3D,
	size: Vector3,
	local_position: Vector3,
	material: Material
) -> void:
	var piece := MeshInstance3D.new()
	var piece_mesh := BoxMesh.new()
	piece_mesh.size = size
	piece.mesh = piece_mesh
	piece.position = local_position
	piece.material_override = material
	piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(piece)

func _create_camera() -> void:
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = _camera_size
	_camera.position = _camera_focus + _current_camera_offset()
	_camera.near = 0.1
	_camera.far = 400.0
	_camera.current = true
	add_child(_camera)
	# Cameras look along their negative Z axis. Character meshes use the
	# opposite convention, so this must not use the model-front option.
	_camera.look_at(_camera_focus, Vector3.UP)


func _update_camera_pan(delta: float) -> void:
	var horizontal := float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A))
	var vertical := float(Input.is_key_pressed(KEY_W)) - float(Input.is_key_pressed(KEY_S))
	var input_length := Vector2(horizontal, vertical).length()
	if input_length <= 0.0:
		return
	_cancel_camera_reset_tween()
	_cancel_citizen_camera_tween()
	var camera_offset := _current_camera_offset()
	var forward := Vector3(-camera_offset.x, 0.0, -camera_offset.z).normalized()
	var right := Vector3(-forward.z, 0.0, forward.x)
	var movement := (right * horizontal + forward * vertical).normalized()
	var zoom_scale := _camera_size / CAMERA_MINIMUM_SIZE
	_camera_focus += movement * CAMERA_PAN_SPEED * zoom_scale * delta
	_update_camera_transform()


func _update_camera_transform() -> void:
	if _camera == null:
		return
	_camera.global_position = _camera_focus + _current_camera_offset()
	_camera.size = _camera_size
	_camera.look_at(_camera_focus, Vector3.UP)
	_compass_widget.update_camera(_current_camera_offset())


func _adjust_camera_zoom(size_delta: float) -> void:
	_cancel_camera_reset_tween()
	_cancel_citizen_camera_tween()
	_camera_size = clampf(
		_camera_size + size_delta,
		CAMERA_MINIMUM_SIZE,
		CAMERA_MAXIMUM_SIZE
	)
	_update_camera_transform()


func _current_camera_offset() -> Vector3:
	var camera_distance := CAMERA_DISTANCE * (_camera_size / CAMERA_MINIMUM_SIZE)
	var horizontal_distance := cos(_camera_pitch) * camera_distance
	return Vector3(
		sin(_camera_yaw) * horizontal_distance,
		sin(_camera_pitch) * camera_distance,
		cos(_camera_yaw) * horizontal_distance
	)


func _create_clouds() -> void:
	_clouds_root = Node3D.new()
	_clouds_root.name = "CloudLayer"
	_clouds_root.visible = CLOUDS_ENABLED
	add_child(_clouds_root)
	for cloud_index in 8:
		var cloud := Node3D.new()
		cloud.name = "Cloud_%d" % cloud_index
		cloud.position = Vector3(
			-90.0 + float((cloud_index * 29) % 180),
			295.0 + float(cloud_index % 3) * 2.0,
			-80.0 + float((cloud_index * 47) % 160)
		)
		_clouds_root.add_child(cloud)
		var block_count := 3 + cloud_index % 5
		for block_index in block_count:
			var block_mesh := BoxMesh.new()
			block_mesh.size = Vector3(
				5.0 + float((cloud_index + block_index * 3) % 7),
				1.5 + float(block_index % 2),
				4.0 + float((cloud_index * 2 + block_index) % 6)
			)
			var block := MeshInstance3D.new()
			block.mesh = block_mesh
			block.position = Vector3(float(block_index) * 4.5, float(block_index % 2), float((block_index * 5) % 9) - 4.0)
			block.material_override = _material(Palette.CLOUD)
			# High-altitude geometry cannot cast the gameplay shadow directly: a
			# rotating sun would sweep that projection across the ground too fast.
			block.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			cloud.add_child(block)
		_cloud_velocities[cloud] = Vector3(
			0.34 + float(cloud_index % 3) * 0.055,
			0.0,
			0.075
		)


func _update_clouds(delta: float) -> void:
	if not CLOUDS_ENABLED:
		return
	for cloud_value in _cloud_velocities:
		var cloud := cloud_value as Node3D
		if not is_instance_valid(cloud):
			continue
		var velocity: Vector3 = _cloud_velocities[cloud]
		cloud.position += velocity * delta
		var cloud_wrap_extent := BACKGROUND_HALF_EXTENT + 20.0
		if cloud.position.x > _camera_focus.x + cloud_wrap_extent:
			cloud.position.x = _camera_focus.x - cloud_wrap_extent
		elif cloud.position.x < _camera_focus.x - cloud_wrap_extent:
			cloud.position.x = _camera_focus.x + cloud_wrap_extent
		if cloud.position.z > _camera_focus.z + cloud_wrap_extent:
			cloud.position.z = _camera_focus.z - cloud_wrap_extent
		elif cloud.position.z < _camera_focus.z - cloud_wrap_extent:
			cloud.position.z = _camera_focus.z + cloud_wrap_extent
	_cloud_shadow_offset += Vector2(0.42, 0.105) * delta
	if is_instance_valid(_ground_material):
		_ground_material.set_shader_parameter("cloud_shadow_offset", _cloud_shadow_offset)
		var visible_citizen_positions := PackedVector2Array()
		var visible_citizen_count := 0
		for citizen in _citizens:
			if is_instance_valid(citizen) and visible_citizen_count < 32:
				visible_citizen_positions.append(Vector2(citizen.global_position.x, citizen.global_position.z))
				visible_citizen_count += 1
		while visible_citizen_positions.size() < 32:
			visible_citizen_positions.append(Vector2.ZERO)
		_ground_material.set_shader_parameter("citizen_count", visible_citizen_count)
		_ground_material.set_shader_parameter("citizen_positions", visible_citizen_positions)


func _create_fog_chunk(chunk: Vector2i, parent: Node3D) -> void:
	var fog_resolution := int(WorldStreamerScript.CHUNK_SIZE / FOG_CELL_SIZE)
	var fog_image := Image.create(fog_resolution, fog_resolution, false, Image.FORMAT_R8)
	fog_image.fill(Color.BLACK)
	var fog_cell_origin := WorldStreamerScript.chunk_origin(chunk) * int(1.0 / FOG_CELL_SIZE)
	for local_x in fog_resolution:
		for local_z in fog_resolution:
			if _revealed_fog_cells.has(fog_cell_origin + Vector2i(local_x, local_z)):
				fog_image.set_pixel(local_x, local_z, Color.WHITE)
	var fog_texture := ImageTexture.create_from_image(fog_image)
	var fog_material := ShaderMaterial.new()
	fog_material.shader = FOG_SHADER
	fog_material.set_shader_parameter("fog_mask", fog_texture)
	fog_material.set_shader_parameter("fog_color", Palette.FOG_AND_SHADOW)

	var fog_plane := PlaneMesh.new()
	fog_plane.size = Vector2(WorldStreamerScript.CHUNK_SIZE, WorldStreamerScript.CHUNK_SIZE)
	var fog_instance := MeshInstance3D.new()
	fog_instance.name = "Fog"
	fog_instance.mesh = fog_plane
	var chunk_origin := WorldStreamerScript.chunk_origin(chunk)
	fog_instance.position = Vector3(
		chunk_origin.x + WorldStreamerScript.CHUNK_SIZE * 0.5,
		0.025,
		chunk_origin.y + WorldStreamerScript.CHUNK_SIZE * 0.5
	)
	fog_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fog_instance.material_override = fog_material
	parent.add_child(fog_instance)
	_chunk_fog_images[chunk] = fog_image
	_chunk_fog_textures[chunk] = fog_texture
	_chunk_fog_materials[chunk] = fog_material


func _create_grass_renderer() -> void:
	_grass_renderer = GrassRendererScript.new()
	_grass_renderer.name = "GrassRenderer"
	add_child(_grass_renderer)
	# A zero extent selects streaming mode; candidates are built only for loaded
	# 16×16 world chunks instead of preallocating a world-sized rectangle.
	_grass_renderer.setup(0.0, FOG_CELL_SIZE, _grass_excluded_world_units())


func _reveal_world_around_citizens() -> void:
	var changed := false
	var newly_revealed_cells: Array[Vector2i] = []
	for citizen in _citizens:
		if not is_instance_valid(citizen):
			continue
		var added := preload("res://scripts/exploration_mask.gd").reveal(_revealed_fog_cells, citizen.global_position, REVEAL_RADIUS)
		newly_revealed_cells.append_array(added)
		changed = changed or not added.is_empty()
	if changed:
		_fill_enclosed_world_unit_holes(newly_revealed_cells)
		_paint_revealed_fog_cells(newly_revealed_cells)
		_update_revealed_entity_visibility()
		if is_instance_valid(_grass_renderer):
			_grass_renderer.reveal_fog_cells(newly_revealed_cells)


func _paint_revealed_fog_cells(newly_revealed_cells: Array[Vector2i]) -> void:
	var changed_chunks: Dictionary = {}
	var fog_cells_per_world_unit := int(1.0 / FOG_CELL_SIZE)
	var fog_resolution := WorldStreamerScript.CHUNK_SIZE * fog_cells_per_world_unit
	for fog_cell in newly_revealed_cells:
		var world_unit := Vector2i(
			floori(float(fog_cell.x) * FOG_CELL_SIZE),
			floori(float(fog_cell.y) * FOG_CELL_SIZE)
		)
		var chunk := WorldStreamerScript.chunk_for_world_unit(world_unit)
		if not _chunk_fog_images.has(chunk):
			continue
		var fog_origin := WorldStreamerScript.chunk_origin(chunk) * fog_cells_per_world_unit
		var local_cell := fog_cell - fog_origin
		if local_cell.x < 0 or local_cell.x >= fog_resolution or local_cell.y < 0 or local_cell.y >= fog_resolution:
			continue
		var chunk_image := _chunk_fog_images[chunk] as Image
		chunk_image.set_pixel(local_cell.x, local_cell.y, Color.WHITE)
		changed_chunks[chunk] = true
		if not _discovered_fog_by_chunk.has(chunk):
			_discovered_fog_by_chunk[chunk] = {}
		(_discovered_fog_by_chunk[chunk] as Dictionary)[local_cell] = true
	for chunk_value in changed_chunks:
		var chunk: Vector2i = chunk_value
		var chunk_texture := _chunk_fog_textures[chunk] as ImageTexture
		chunk_texture.update(_chunk_fog_images[chunk] as Image)


func _fill_enclosed_world_unit_holes(newly_revealed_cells: Array[Vector2i]) -> bool:
	var candidates: Dictionary = {}
	for fog_cell in newly_revealed_cells:
		var changed_world_unit := Vector2i(
			floori(float(fog_cell.x) * FOG_CELL_SIZE),
			floori(float(fog_cell.y) * FOG_CELL_SIZE)
		)
		for offset_x in range(-1, 2):
			for offset_z in range(-1, 2):
				candidates[changed_world_unit + Vector2i(offset_x, offset_z)] = true

	var filled_hole := false
	for candidate_value in candidates:
		var candidate: Vector2i = candidate_value
		if _world_unit_fully_revealed(candidate):
			continue
		var surrounded := true
		for neighbour_offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			if not _world_unit_fully_revealed(candidate + neighbour_offset):
				surrounded = false
				break
		if not surrounded:
			continue
		_reveal_world_unit(candidate, newly_revealed_cells)
		filled_hole = true
	return filled_hole


func _world_unit_fully_revealed(world_unit: Vector2i) -> bool:
	var base_cell := world_unit * 2
	return (
		_revealed_fog_cells.has(base_cell)
		and _revealed_fog_cells.has(base_cell + Vector2i(1, 0))
		and _revealed_fog_cells.has(base_cell + Vector2i(0, 1))
		and _revealed_fog_cells.has(base_cell + Vector2i(1, 1))
	)


func _reveal_world_unit(world_unit: Vector2i, newly_revealed_cells: Array[Vector2i]) -> void:
	var base_cell := world_unit * 2
	for sub_x in 2:
		for sub_z in 2:
			var fog_cell := base_cell + Vector2i(sub_x, sub_z)
			if _revealed_fog_cells.has(fog_cell):
				continue
			_revealed_fog_cells[fog_cell] = true
			newly_revealed_cells.append(fog_cell)


func _update_revealed_entity_visibility() -> void:
	for item in _items:
		if is_instance_valid(item):
			item.visible = not item.is_carried and _is_world_position_revealed(item.global_position)
	if is_instance_valid(_starting_pile):
		_starting_pile.visible = _is_world_position_revealed(_starting_pile.global_position)
	_refresh_planned_building_visibility()


func _is_world_position_revealed(world_position: Vector3) -> bool:
	var fog_cell := Vector2i(
		floori(world_position.x / FOG_CELL_SIZE),
		floori(world_position.z / FOG_CELL_SIZE)
	)
	return _revealed_fog_cells.has(fog_cell)


func _create_citizen_command_overlay() -> void:
	_citizen_command_overlay = CitizenCommandOverlayScript.new()
	_citizen_command_overlay.configure(_camera)
	add_child(_citizen_command_overlay)


func _create_environment() -> void:
	_environment = Environment.new()
	_environment.background_mode = Environment.BG_COLOR
	_environment.background_color = Color("80b9d6")
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_environment.ambient_light_color = Palette.FOG_AND_SHADOW
	_environment.ambient_light_energy = 0.55
	var world_environment := WorldEnvironment.new()
	world_environment.environment = _environment
	add_child(world_environment)

	_sun = DirectionalLight3D.new()
	_sun.rotation_degrees = Vector3(-52.0, -35.0, 0.0)
	_sun.light_energy = 1.15
	_sun.shadow_enabled = true
	# Keep flat sand and Building surfaces from self-shadowing at the steep
	# midday sun angle. This is deliberately only slightly above Godot's 0.1
	# default so contact shadows do not visibly detach from their casters.
	_sun.shadow_bias = 0.14
	_sun.shadow_opacity = 1.0
	_sun.shadow_blur = 0.0
	# Clouds use their own overlay and do not cast directional shadows. Limiting
	# this range to the playable surface gives ordinary shadows much more shadow-
	# map precision and prevents granular midday sand.
	_sun.directional_shadow_max_distance = 48.0
	_sun.directional_shadow_blend_splits = false
	add_child(_sun)


func _update_day_night() -> void:
	var day_phase := fmod(_elapsed, _day_length_seconds) / _day_length_seconds
	var sun_height := sin(day_phase * TAU)
	_set_citizens_sleeping(day_phase >= 0.5)
	var daylight := smoothstep(-0.2, 0.2, sun_height)
	var surface_colour := _day_cycle_colour(
		day_phase,
		Palette.MORNING_SURFACE,
		Palette.SAND_SURFACE,
		Palette.EVENING_SURFACE,
		Palette.NIGHT_SURFACE
	)
	var shadow_colour := _day_cycle_colour(
		day_phase,
		Palette.MORNING_SHADOW,
		Palette.FOG_AND_SHADOW,
		Palette.EVENING_SHADOW,
		Palette.NIGHT_FOG_AND_SHADOW
	)
	for citizen in _citizens:
		if is_instance_valid(citizen):
			citizen.set_contact_shadow_colour(shadow_colour)
	var light_colour := _day_cycle_colour(
		day_phase,
		Palette.MORNING_LIGHT,
		Palette.SUN,
		Palette.EVENING_LIGHT,
		Palette.NIGHT_LIGHT
	)
	var sky_colour := _day_cycle_colour(
		day_phase,
		Palette.MORNING_SKY,
		Color("80b9d6"),
		Palette.EVENING_SKY,
		Palette.NIGHT_SKY
	)
	# Rotation around X carries the light from the eastern horizon, overhead,
	# to the western horizon, then beneath the world during the night half.
	_sun.rotation_degrees = Vector3(-day_phase * 360.0, -90.0, 0.0)
	_sun.light_color = light_colour
	_sun.light_energy = 1.15 * daylight
	_environment.background_color = sky_colour
	_environment.ambient_light_color = light_colour
	_environment.ambient_light_energy = lerpf(0.12, 0.55, daylight)
	if is_instance_valid(_ground_material):
		_ground_material.set_shader_parameter("daylight", daylight)
		_ground_material.set_shader_parameter("surface_color", surface_colour)
		_ground_material.set_shader_parameter("shadow_color", shadow_colour)
	for item in _items:
		if is_instance_valid(item) and item.item_kind == "stone":
			item.set_limestone_cycle(
				daylight,
				surface_colour,
				_sun.global_transform.basis.z.normalized()
			)
	for terrain_block_value in _terrain_blocks.values():
		var terrain_block := terrain_block_value as TerrainBlock
		if is_instance_valid(terrain_block):
			terrain_block.set_day_cycle(
				daylight,
				surface_colour,
				_sun.global_transform.basis.z.normalized()
			)
	for fog_material_value in _chunk_fog_materials.values():
		var fog_material := fog_material_value as ShaderMaterial
		if is_instance_valid(fog_material):
			fog_material.set_shader_parameter("fog_color", shadow_colour)
	if is_instance_valid(_day_night_wheel):
		_day_night_wheel.rotation = day_phase * TAU


func _set_citizens_sleeping(should_sleep: bool) -> void:
	if _citizens_are_sleeping == should_sleep:
		return
	_citizens_are_sleeping = should_sleep
	for citizen in _citizens:
		if not is_instance_valid(citizen):
			continue
		if should_sleep:
			_cancel_active_work(citizen, true)
			citizen.set_sleeping(true)
		else:
			citizen.set_sleeping(false)
			if citizen.task.is_empty() and not citizen.work_assignment.is_empty():
				_continue_persistent_assignment(citizen)


func _day_cycle_colour(
	day_phase: float,
	morning: Color,
	day: Color,
	evening: Color,
	night: Color
) -> Color:
	if day_phase < 0.12:
		return morning.lerp(day, smoothstep(0.0, 0.12, day_phase))
	if day_phase < 0.38:
		return day
	if day_phase < 0.5:
		return day.lerp(evening, smoothstep(0.38, 0.5, day_phase))
	if day_phase < 0.62:
		return evening.lerp(night, smoothstep(0.5, 0.62, day_phase))
	if day_phase < 0.86:
		return night
	return night.lerp(morning, smoothstep(0.86, 1.0, day_phase))


func request_actor_message(
	actor: Node3D,
	message_id: String,
	cluster_scope := "world",
	options: Dictionary = {}
) -> String:
	## Public bridge for citizens, buildings, and future Utility simulations.
	## Reposting a persistent need refreshes its TTL; stopping the refresh lets
	## the stale request remove itself from the queue.
	if not is_instance_valid(_actor_message_bus):
		return ""
	var resolved_options := options.duplicate(true)
	resolved_options["cluster_scope"] = cluster_scope
	return _actor_message_bus.post_message(actor, message_id, resolved_options)


func clear_actor_message(actor: Node3D, message_id: String, cluster_scope := "world") -> void:
	if is_instance_valid(_actor_message_bus):
		_actor_message_bus.clear_message(actor, message_id, cluster_scope)


func _create_actor_speech_system() -> void:
	_actor_message_bus = ActorMessageBusScript.new() as ActorMessageBus
	_actor_message_bus.name = "ActorMessageBus"
	add_child(_actor_message_bus)
	_speech_bubble_overlay = SpeechBubbleOverlayScript.new() as SpeechBubbleOverlay
	add_child(_speech_bubble_overlay)
	_speech_bubble_overlay.configure(_camera, self, _actor_message_bus)


func _next_speech_command_scope() -> String:
	_speech_command_sequence += 1
	return "command:%d" % _speech_command_sequence


func _create_interface() -> void:
	var selection_layer := CanvasLayer.new()
	selection_layer.layer = 50
	add_child(selection_layer)
	_selection_box = Panel.new()
	_selection_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_selection_box.visible = false
	var selection_style := StyleBoxFlat.new()
	selection_style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	selection_style.border_color = Color.WHITE
	selection_style.border_width_left = 1
	selection_style.border_width_top = 1
	selection_style.border_width_right = 1
	selection_style.border_width_bottom = 1
	_selection_box.add_theme_stylebox_override("panel", selection_style)
	selection_layer.add_child(_selection_box)
	_rts_count_badge = _create_count_badge(
		selection_layer,
		Vector2.ZERO,
		Vector2(18.0, 18.0),
		9,
		Palette.HOME_DOORWAY
	)
	_rts_count_badge.name = "CitizenSelectionCountBadge"
	_rts_count_badge.custom_minimum_size = Vector2(18.0, 18.0)
	_rts_count_badge.clip_text = true
	_rts_count_badge.add_theme_font_size_override("font_size", VisualTokens.SELECTION_COUNT_FONT_SIZE)
	_day_label = Label.new()
	_day_label.name = "DayCount"
	_day_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_day_label.position = Vector2(-27.0, 50.0)
	_day_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_day_label.add_theme_font_size_override("font_size", VisualTokens.DAY_COUNT_FONT_SIZE)
	_day_label.add_theme_color_override("font_color", Color.BLACK)
	selection_layer.add_child(_day_label)
	_create_day_night_wheel(selection_layer)
	_create_compass(selection_layer)
	_create_build_stamp(selection_layer)
	_create_building_hotkey_hint(selection_layer)
	_create_world_progress_layer()
	_create_top_toolbar()
	_create_hover_tooltip()

	var layer := CanvasLayer.new()
	layer.visible = SHOW_DEBUG_OVERLAY
	add_child(layer)

	var title := Label.new()
	title.text = UIText.text(UIText.PROTOTYPE_TITLE_TEXT)
	title.position = Vector2(18, 16)
	title.add_theme_font_size_override("font_size", VisualTokens.DEBUG_TITLE_FONT_SIZE)
	layer.add_child(title)

	var instructions := Label.new()
	instructions.text = UIText.text(UIText.PROTOTYPE_INSTRUCTIONS_TEXT)
	instructions.position = Vector2(18, 52)
	instructions.add_theme_font_size_override("font_size", VisualTokens.DEBUG_INSTRUCTIONS_FONT_SIZE)
	layer.add_child(instructions)

	_ui_mode = Label.new()
	_ui_mode.position = Vector2(18, 104)
	_ui_mode.add_theme_font_size_override("font_size", VisualTokens.DEBUG_READOUT_FONT_SIZE)
	layer.add_child(_ui_mode)

	_ui_status = Label.new()
	_ui_status.position = Vector2(18, 132)
	_ui_status.add_theme_font_size_override("font_size", VisualTokens.DEBUG_READOUT_FONT_SIZE)
	layer.add_child(_ui_status)

	_ui_resources = Label.new()
	_ui_resources.position = Vector2(18, 160)
	_ui_resources.add_theme_font_size_override("font_size", VisualTokens.DEBUG_READOUT_FONT_SIZE)
	layer.add_child(_ui_resources)


func _create_day_night_wheel(parent: Node) -> void:
	_day_night_wheel = preload("res://scripts/day_night_widget.gd").mount(parent)

func _create_compass(parent: Node) -> void:
	_compass_widget.mount(self, parent, _reset_camera_from_compass)
	_compass_widget.update_camera(_current_camera_offset())


func _create_build_stamp(parent: Node) -> void:
	const EDGE_GAP := 11.0
	const STAMP_SIZE := Vector2(420.0, 18.0)
	_build_stamp_label = Label.new()
	_build_stamp_label.name = "BuildStamp"
	_build_stamp_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_build_stamp_label.offset_left = -STAMP_SIZE.x - EDGE_GAP
	_build_stamp_label.offset_top = -STAMP_SIZE.y - EDGE_GAP
	_build_stamp_label.offset_right = -EDGE_GAP
	_build_stamp_label.offset_bottom = -EDGE_GAP
	_build_stamp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_stamp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_build_stamp_label.text = BuildMetadata.inline_label()
	_build_stamp_label.add_theme_font_size_override("font_size", VisualTokens.BUILD_STAMP_FONT_SIZE)
	_build_stamp_label.add_theme_color_override("font_color", Color.WHITE)
	parent.add_child(_build_stamp_label)


func _create_building_hotkey_hint(parent: Node) -> void:
	_building_hotkey_hint = PanelContainer.new()
	_building_hotkey_hint.name = "BuildingHotkeyHint"
	_building_hotkey_hint.visible = false
	_building_hotkey_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hint_style := StyleBoxFlat.new()
	hint_style.bg_color = Color(0.02, 0.02, 0.02, 0.84)
	hint_style.border_color = Color.WHITE
	hint_style.set_border_width_all(int(VisualTokens.OUTLINE_PIXELS))
	hint_style.set_corner_radius_all(0)
	hint_style.content_margin_left = 7.0
	hint_style.content_margin_right = 7.0
	hint_style.content_margin_top = 4.0
	hint_style.content_margin_bottom = 4.0
	_building_hotkey_hint.add_theme_stylebox_override("panel", hint_style)
	parent.add_child(_building_hotkey_hint)
	_building_hotkey_hint_label = Label.new()
	_building_hotkey_hint_label.name = "RotateHotkey"
	_building_hotkey_hint_label.text = UIText.text(UIText.BUILDING_ROTATE_HOTKEY_TEXT)
	_building_hotkey_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_building_hotkey_hint_label.add_theme_font_size_override("font_size", VisualTokens.BUILDING_HOTKEY_FONT_SIZE)
	_building_hotkey_hint_label.add_theme_color_override("font_color", Color.WHITE)
	_building_hotkey_hint.add_child(_building_hotkey_hint_label)


func _update_building_hotkey_hint() -> void:
	if not is_instance_valid(_building_hotkey_hint) or not is_instance_valid(_camera):
		return
	if (
		not is_instance_valid(_selected_building)
		or _selected_world_object != _selected_building
		or not _selected_building.is_planned()
		or _camera.is_position_behind(_selected_building.global_position)
	):
		_building_hotkey_hint.visible = false
		return
	_building_hotkey_hint.reset_size()
	var hint_size := _building_hotkey_hint.get_combined_minimum_size()
	_building_hotkey_hint.size = hint_size
	var screen_base := _camera.unproject_position(_selected_building.global_position)
	var viewport_size := Vector2(get_viewport().get_visible_rect().size)
	_building_hotkey_hint.position = Vector2(
		clampf(screen_base.x - hint_size.x * 0.5, 6.0, viewport_size.x - hint_size.x - 6.0),
		clampf(screen_base.y + 18.0, 6.0, viewport_size.y - hint_size.y - 6.0)
	)
	_building_hotkey_hint.visible = true


func _reset_camera_from_compass() -> void:
	_cancel_camera_reset_tween()
	_cancel_citizen_camera_tween()
	var reset_start_yaw := _camera_yaw
	var shortest_yaw_delta := wrapf(DEFAULT_CAMERA_YAW - reset_start_yaw, -PI, PI)
	var reset_target_yaw := reset_start_yaw + shortest_yaw_delta
	var reset_start_pitch := _camera_pitch
	var reset_start_size := _camera_size
	_camera_reset_tween = create_tween()
	_camera_reset_tween.tween_method(
		_apply_camera_reset_progress.bind(
			reset_start_yaw,
			reset_target_yaw,
			reset_start_pitch,
			reset_start_size
		),
		0.0,
		1.0,
		CAMERA_RESET_DURATION_SECONDS
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_camera_reset_tween.tween_callback(_finish_camera_reset)


func _apply_camera_reset_progress(
	progress: float,
	start_yaw: float,
	target_yaw: float,
	start_pitch: float,
	start_size: float
) -> void:
	_camera_yaw = lerpf(start_yaw, target_yaw, progress)
	_camera_pitch = lerpf(start_pitch, DEFAULT_CAMERA_PITCH, progress)
	_camera_size = lerpf(start_size, DEFAULT_CAMERA_SIZE, progress)
	_update_camera_transform()


func _finish_camera_reset() -> void:
	_camera_yaw = DEFAULT_CAMERA_YAW
	_camera_pitch = DEFAULT_CAMERA_PITCH
	_camera_size = DEFAULT_CAMERA_SIZE
	_camera_reset_tween = null
	_update_camera_transform()


func _cancel_camera_reset_tween() -> void:
	if _camera_reset_tween != null and _camera_reset_tween.is_valid():
		_camera_reset_tween.kill()
	_camera_reset_tween = null


func _focus_next_citizen_from_population() -> void:
	var available_citizens: Array[Citizen] = []
	for citizen in _citizens:
		if is_instance_valid(citizen):
			available_citizens.append(citizen)
	if available_citizens.is_empty():
		_citizen_camera_cycle_index = -1
		return
	_citizen_camera_cycle_index = (_citizen_camera_cycle_index + 1) % available_citizens.size()
	var target_citizen := available_citizens[_citizen_camera_cycle_index]
	_start_citizen_camera_transition(target_citizen)


func _start_citizen_camera_transition(target_citizen: Citizen) -> void:
	if not is_instance_valid(target_citizen):
		return
	_cancel_camera_reset_tween()
	_cancel_citizen_camera_tween()
	var start_focus := _camera_focus
	var start_size := _camera_size
	var flat_offset := target_citizen.global_position - start_focus
	flat_offset.y = 0.0
	var duration := _citizen_camera_transition_duration(flat_offset.length())
	_citizen_camera_tween = create_tween()
	_citizen_camera_tween.tween_method(
		_apply_citizen_camera_transition.bind(start_focus, start_size, target_citizen),
		0.0,
		1.0,
		duration
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_citizen_camera_tween.tween_callback(
		_finish_citizen_camera_transition.bind(target_citizen)
	)


func _apply_citizen_camera_transition(
	progress: float,
	start_focus: Vector3,
	start_size: float,
	target_citizen: Citizen
) -> void:
	if not is_instance_valid(target_citizen):
		_cancel_citizen_camera_tween()
		return
	_camera_focus = start_focus.lerp(target_citizen.global_position, progress)
	_camera_size = lerpf(start_size, CAMERA_MINIMUM_SIZE, progress)
	_update_camera_transform()


func _finish_citizen_camera_transition(target_citizen: Citizen) -> void:
	if is_instance_valid(target_citizen):
		_camera_focus = target_citizen.global_position
		_camera_size = CAMERA_MINIMUM_SIZE
	_citizen_camera_tween = null
	_update_camera_transform()


func _citizen_camera_transition_duration(world_distance: float) -> float:
	var viewport_size := get_viewport().get_visible_rect().size
	var aspect_ratio := 1.0
	if viewport_size.y > 0.0:
		aspect_ratio = maxf(1.0, viewport_size.x / viewport_size.y)
	var one_screen_distance := CAMERA_MINIMUM_SIZE * aspect_ratio
	var distance_ratio := clampf(world_distance / maxf(one_screen_distance, 0.001), 0.0, 1.0)
	return lerpf(
		CITIZEN_CAMERA_MINIMUM_DURATION_SECONDS,
		CITIZEN_CAMERA_MAXIMUM_DURATION_SECONDS,
		distance_ratio
	)


func _cancel_citizen_camera_tween() -> void:
	if _citizen_camera_tween != null and _citizen_camera_tween.is_valid():
		_citizen_camera_tween.kill()
	_citizen_camera_tween = null


func _create_world_progress_layer() -> void:
	_world_progress_layer = CanvasLayer.new()
	_world_progress_layer.name = "WorldProgressBars"
	_world_progress_layer.layer = 105
	add_child(_world_progress_layer)
	_construction_inspector = ConstructionInspectorScript.new() as ConstructionInspector
	_construction_inspector.configure()
	_world_progress_layer.add_child(_construction_inspector)


func _update_selected_construction_inspector() -> void:
	if not is_instance_valid(_construction_inspector) or not is_instance_valid(_camera):
		return
	if (
		not is_instance_valid(_selected_building)
		or _selected_world_object != _selected_building
		or not _selected_building.is_planned()
		or not _selected_building.visible
	):
		_construction_inspector.visible = false
		return
	var world_anchor := _selected_building.global_position + Vector3.UP * 1.48
	if _camera.is_position_behind(world_anchor):
		_construction_inspector.visible = false
		return
	var recipe := _selected_building.construction_recipe()
	var installed_materials := _selected_building.installed_resource_counts()
	var labour_seconds_by_resource := _selected_building.labour_seconds_by_resource()
	var total_seconds := ConstructionProgressScript.total_required_seconds(
		recipe,
		labour_seconds_by_resource
	)
	var applied_seconds := ConstructionProgressScript.installed_seconds(
		installed_materials,
		labour_seconds_by_resource
	)
	for record_value in _labour_records.values():
		var record := record_value as Dictionary
		if (
			record.get("target") != _selected_building
			or str(record.get("kind", "")) != ActionCatalog.APPLY_BUILDING_BLOCK
		):
			continue
		var labour := record.get("labour") as AppliedLabour
		if labour != null:
			applied_seconds += labour.applied_seconds
	_construction_inspector.present(
		_selected_building.display_name(),
		total_seconds,
		clampf(applied_seconds, 0.0, total_seconds),
		recipe,
		installed_materials,
		_camera_size,
		CAMERA_MINIMUM_SIZE,
		CAMERA_MAXIMUM_SIZE
	)
	_construction_inspector.reset_size()
	var inspector_size := _construction_inspector.get_combined_minimum_size()
	_construction_inspector.size = inspector_size
	var screen_anchor := _camera.unproject_position(world_anchor)
	var viewport_size := Vector2(get_viewport().get_visible_rect().size)
	_construction_inspector.position = Vector2(
		clampf(
			screen_anchor.x - inspector_size.x * 0.5,
			6.0,
			maxf(6.0, viewport_size.x - inspector_size.x - 6.0)
		),
		clampf(
			screen_anchor.y - inspector_size.y - 6.0,
			6.0,
			maxf(6.0, viewport_size.y - inspector_size.y - 6.0)
		)
	)


func _create_top_toolbar() -> void:
	var toolbar_layer := CanvasLayer.new()
	toolbar_layer.name = "TopToolbar"
	toolbar_layer.layer = 110
	add_child(toolbar_layer)
	_create_toolbar_tooltip(toolbar_layer)
	_create_population_indicator(toolbar_layer)
	_create_selected_pile_inventory(toolbar_layer)
	_top_toolbar = HBoxContainer.new()
	_top_toolbar.name = "TransparentTopToolbar"
	_top_toolbar.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	# Keep the right edge fixed and let the toolbar grow towards the left. This
	# avoids losing the final buttons when optional controls become visible.
	_top_toolbar.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_top_toolbar.offset_right = -10.0
	_top_toolbar.offset_top = 10.0
	_top_toolbar.add_theme_constant_override("separation", 8)
	toolbar_layer.add_child(_top_toolbar)

	_simulation_speed_button = _create_simulation_speed_button()
	_top_toolbar.add_child(_simulation_speed_button)

	_building_button = _create_toolbar_button(
		_create_toolbar_icon("building"),
		UIText.text(UIText.BUILD_BUTTON_TOOLTIP_TEXT),
		false,
		_create_toolbar_icon("building_hover")
	)
	_building_button.name = "BuildingModeButton"
	_building_button.toggle_mode = true
	_building_button.set_meta("pressed_icon", _create_toolbar_icon("building_active"))
	_building_button.pressed.connect(_toggle_build_menu)
	_top_toolbar.add_child(_building_button)
	_create_build_menu(toolbar_layer)

	_greenery_button = _create_toolbar_button(
		_create_toolbar_icon("greenery"),
		UIText.text(UIText.GREENERY_BUTTON_TOOLTIP_TEXT),
		false,
		_create_toolbar_icon("greenery_hover")
	)
	_greenery_button.name = "GreeneryModeButton"
	_greenery_button.toggle_mode = true
	_greenery_button.set_meta("pressed_icon", _create_toolbar_icon("greenery_active"))
	_greenery_button.pressed.connect(_toggle_greenery_mode)
	_top_toolbar.add_child(_greenery_button)

	_landscape_button = _create_toolbar_button(
		_create_toolbar_icon("landscape"),
		UIText.text(UIText.LANDSCAPE_BUTTON_TOOLTIP_TEXT),
		false,
		_create_toolbar_icon("landscape_hover")
	)
	_landscape_button.name = "LandscapeModeButton"
	_landscape_button.toggle_mode = true
	_landscape_button.set_meta("pressed_icon", _create_toolbar_icon("landscape_active"))
	_landscape_button.pressed.connect(_toggle_landscape_mode)
	_top_toolbar.add_child(_landscape_button)
	_create_landscape_menu(toolbar_layer)

	var save_quit_icon := _create_toolbar_icon("save_quit")
	var save_quit_hover_icon := _create_toolbar_icon("save_quit_hover")
	var save_quit_button := _create_toolbar_button(
		save_quit_icon,
		UIText.text(UIText.EXIT_BUTTON_TOOLTIP_TEXT),
		false,
		save_quit_hover_icon
	)
	save_quit_button.name = "SaveQuitButton"
	save_quit_button.pressed.connect(_close_game)
	_top_toolbar.add_child(save_quit_button)


func _close_game() -> void:
	get_tree().quit()


func _create_population_indicator(toolbar_layer: CanvasLayer) -> void:
	_population_icon_number = IconNumberScript.new() as IconNumber
	_population_icon_number.name = "PopulationIndicator"
	_population_icon_number.position = Vector2(10.0, 10.0)
	_population_icon_number.configure(
		_create_toolbar_icon("population"),
		_create_toolbar_icon("population_hover"),
		_population_count(),
		IconNumber.ScaleMode.STANDARD,
		Vector2.ONE * VisualTokens.TOOLBAR_BUTTON_PIXELS,
		VisualTokens.POPULATION_COUNT_FONT_SIZE,
		true,
		"PopulationIcon",
		"PopulationCount",
		Vector2(28.0, VisualTokens.TOOLBAR_BUTTON_PIXELS)
	)
	toolbar_layer.add_child(_population_icon_number)
	var population_icon := _population_icon_number.icon_button()
	population_icon.focus_mode = Control.FOCUS_NONE
	population_icon.pressed.connect(_focus_next_citizen_from_population)
	population_icon.mouse_entered.connect(
		_show_toolbar_tooltip.bind(population_icon, UIText.text(UIText.POPULATION_TOOLTIP_TEXT))
	)
	population_icon.mouse_exited.connect(_hide_toolbar_tooltip)
	population_icon.focus_entered.connect(
		_show_toolbar_tooltip.bind(population_icon, UIText.text(UIText.POPULATION_TOOLTIP_TEXT))
	)
	population_icon.focus_exited.connect(_hide_toolbar_tooltip)


func _create_selected_pile_inventory(toolbar_layer: CanvasLayer) -> void:
	_pile_inventory_row = HBoxContainer.new()
	_pile_inventory_row.name = "SelectedPileInventory"
	_pile_inventory_row.position = Vector2(10.0, 58.0)
	_pile_inventory_row.add_theme_constant_override("separation", 4)
	_pile_inventory_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pile_inventory_row.visible = false
	toolbar_layer.add_child(_pile_inventory_row)
	_update_icon_number_layout()


func _update_icon_number_layout() -> void:
	if not is_instance_valid(_population_icon_number) or not is_instance_valid(_pile_inventory_row):
		return
	var population_height := maxf(
		VisualTokens.TOOLBAR_BUTTON_PIXELS,
		_population_icon_number.current_icon_size().y
	)
	_pile_inventory_row.position = Vector2(10.0, 10.0 + population_height + 4.0)


func _update_selected_pile_inventory() -> void:
	if not is_instance_valid(_pile_inventory_row):
		return
	if not is_instance_valid(_selected_world_object) or not _selected_world_object is PileStorage:
		_pile_inventory_row.visible = false
		_pile_inventory_signature = ""
		return
	var selected_pile := _selected_world_object as PileStorage
	var inventory := selected_pile.inventory_snapshot()
	var signature_parts: Array[String] = []
	for resource_kind_value in inventory:
		var resource_kind := str(resource_kind_value)
		signature_parts.append("%s:%d" % [resource_kind, int(inventory[resource_kind])])
	var next_signature := "%d|%s" % [selected_pile.get_instance_id(), ",".join(signature_parts)]
	_pile_inventory_row.visible = true
	if next_signature == _pile_inventory_signature:
		return
	_pile_inventory_signature = next_signature
	for old_card in _pile_inventory_row.get_children():
		_pile_inventory_row.remove_child(old_card)
		old_card.queue_free()
	for resource_kind_value in inventory:
		var resource_kind := str(resource_kind_value)
		_pile_inventory_row.add_child(
			_create_pile_resource_card(resource_kind, int(inventory[resource_kind]))
		)


func _create_pile_resource_card(resource_kind: String, amount: int) -> PanelContainer:
	var card := PanelContainer.new()
	card.name = "ResourceCard_%s" % resource_kind
	card.custom_minimum_size = Vector2(38.0, 24.0)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(1.0, 1.0, 1.0, 0.82)
	card_style.border_color = Color.BLACK
	card_style.set_border_width_all(int(VisualTokens.OUTLINE_PIXELS))
	card_style.set_corner_radius_all(0)
	card_style.content_margin_left = 4.0
	card_style.content_margin_right = 4.0
	card_style.content_margin_top = 2.0
	card_style.content_margin_bottom = 2.0
	card.add_theme_stylebox_override("panel", card_style)

	var contents := IconNumberScript.new() as IconNumber
	contents.name = "CardContents"
	contents.configure(
		ToolbarIcons.create_resource_icon(
			resource_kind,
			int(VisualTokens.ICON_NUMBER_COMPACT_ICON_PIXELS)
		),
		null,
		amount,
		IconNumber.ScaleMode.COMPACT,
		Vector2.ONE * VisualTokens.ICON_NUMBER_COMPACT_ICON_PIXELS,
		VisualTokens.PILE_RESOURCE_COUNT_FONT_SIZE,
		false,
		"ResourceIcon",
		"ResourceCount"
	)
	card.add_child(contents)
	return card


func _create_simulation_speed_button() -> Button:
	var button := Button.new()
	button.name = "SimulationSpeedButton"
	button.custom_minimum_size = Vector2(52.0, 44.0)
	button.size = Vector2(52.0, 44.0)
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.flat = true
	button.icon = _simulation_speed_icon()
	button.expand_icon = false
	button.tooltip_text = ""
	button.theme = PixelUITheme.tooltip_theme()
	button.add_theme_color_override("icon_normal_color", Color.BLACK)
	button.add_theme_color_override("icon_hover_color", Palette.HOME_DOORWAY)
	button.add_theme_color_override("icon_focus_color", Palette.HOME_DOORWAY)
	button.add_theme_color_override("icon_pressed_color", Color.BLACK)
	var empty_style := StyleBoxEmpty.new()
	for style_name in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(style_name, empty_style)
	var hover_text := UIText.text(UIText.SIMULATION_SPEED_TOOLTIP_TEXT)
	button.mouse_entered.connect(_show_toolbar_tooltip.bind(button, hover_text))
	button.mouse_exited.connect(_hide_toolbar_tooltip)
	button.focus_entered.connect(_show_toolbar_tooltip.bind(button, hover_text))
	button.focus_exited.connect(_hide_toolbar_tooltip)
	button.pressed.connect(_cycle_simulation_speed)
	return button


func _simulation_speed_icon() -> ImageTexture:
	return ToolbarIcons.create_icon("simulation_speed_%d" % int(_simulation_speed))


func _cycle_simulation_speed() -> void:
	var current_index := SIMULATION_SPEED_OPTIONS.find(_simulation_speed)
	var next_index := (current_index + 1) % SIMULATION_SPEED_OPTIONS.size()
	_set_simulation_speed(float(SIMULATION_SPEED_OPTIONS[next_index]))


func _set_simulation_speed(next_speed: float) -> void:
	if next_speed not in SIMULATION_SPEED_OPTIONS:
		return
	_simulation_speed = next_speed
	if is_instance_valid(_simulation_speed_button):
		_simulation_speed_button.icon = _simulation_speed_icon()
	for citizen in _citizens:
		if is_instance_valid(citizen):
			citizen.set_simulation_speed(_simulation_speed)
	for item in _items:
		if is_instance_valid(item):
			item.set_simulation_speed(_simulation_speed)


func _create_toolbar_button(
	icon_texture: ImageTexture,
	hover_text: String,
	is_disabled: bool,
	hover_icon: ImageTexture = null
) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2.ONE * VisualTokens.TOOLBAR_BUTTON_PIXELS
	button.size = Vector2.ONE * VisualTokens.TOOLBAR_BUTTON_PIXELS
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.icon = icon_texture
	button.set_meta("normal_icon", icon_texture)
	button.expand_icon = true
	button.flat = true
	# A dedicated tooltip is anchored beneath the complete rectangular hit area;
	# native pointer-relative placement could cover the icon itself.
	button.tooltip_text = ""
	button.theme = PixelUITheme.tooltip_theme()
	button.disabled = is_disabled
	button.add_theme_color_override("icon_disabled_color", Color.WHITE)
	var empty_style := StyleBoxEmpty.new()
	for style_name in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(style_name, empty_style)
	button.mouse_entered.connect(_show_toolbar_tooltip.bind(button, hover_text))
	button.mouse_exited.connect(_hide_toolbar_tooltip)
	button.focus_entered.connect(_show_toolbar_tooltip.bind(button, hover_text))
	button.focus_exited.connect(_hide_toolbar_tooltip)
	if hover_icon != null:
		button.set_meta("active_icon", hover_icon)
		button.mouse_entered.connect(_set_toolbar_button_icon.bind(button, hover_icon))
		button.mouse_exited.connect(_set_toolbar_button_icon.bind(button, icon_texture))
		button.focus_entered.connect(_set_toolbar_button_icon.bind(button, hover_icon))
		button.focus_exited.connect(_set_toolbar_button_icon.bind(button, icon_texture))
	return button


func _set_toolbar_button_icon(button: Button, next_icon: ImageTexture) -> void:
	if button.toggle_mode and button.button_pressed and button.has_meta("pressed_icon"):
		button.icon = button.get_meta("pressed_icon") as ImageTexture
	elif button.toggle_mode and button.button_pressed and button.has_meta("active_icon"):
		button.icon = button.get_meta("active_icon") as ImageTexture
	else:
		button.icon = next_icon


func _create_toolbar_tooltip(toolbar_layer: CanvasLayer) -> void:
	_toolbar_tooltip = PanelContainer.new()
	_toolbar_tooltip.name = "ToolbarTooltip"
	_toolbar_tooltip.visible = false
	_toolbar_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toolbar_tooltip.z_index = 20
	var tooltip_style := StyleBoxFlat.new()
	tooltip_style.bg_color = Color.BLACK
	tooltip_style.border_color = Color.WHITE
	tooltip_style.set_border_width_all(int(VisualTokens.OUTLINE_PIXELS))
	tooltip_style.set_corner_radius_all(0)
	tooltip_style.set_content_margin_all(4.0)
	_toolbar_tooltip.add_theme_stylebox_override("panel", tooltip_style)
	toolbar_layer.add_child(_toolbar_tooltip)
	_toolbar_tooltip_label = Label.new()
	_toolbar_tooltip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toolbar_tooltip_label.add_theme_font_size_override("font_size", VisualTokens.TOOLTIP_FONT_SIZE)
	_toolbar_tooltip_label.add_theme_color_override("font_color", Color.WHITE)
	_toolbar_tooltip.add_child(_toolbar_tooltip_label)


func _show_toolbar_tooltip(button: Button, tooltip_text: String) -> void:
	if not is_instance_valid(_toolbar_tooltip) or tooltip_text.is_empty():
		return
	_toolbar_tooltip_label.text = tooltip_text
	_toolbar_tooltip.reset_size()
	var tooltip_size := _toolbar_tooltip.get_combined_minimum_size()
	_toolbar_tooltip.size = tooltip_size
	var button_rect := button.get_global_rect()
	var viewport_size := Vector2(get_viewport().get_visible_rect().size)
	var tooltip_y := button_rect.end.y + 5.0
	if tooltip_y + tooltip_size.y > viewport_size.y - 4.0:
		tooltip_y = button_rect.position.y - tooltip_size.y - 5.0
	_toolbar_tooltip.position = Vector2(
		clampf(
			button_rect.get_center().x - tooltip_size.x * 0.5,
			4.0,
			maxf(4.0, viewport_size.x - tooltip_size.x - 4.0)
		),
		clampf(tooltip_y, 4.0, maxf(4.0, viewport_size.y - tooltip_size.y - 4.0))
	)
	_toolbar_tooltip.visible = true


func _hide_toolbar_tooltip() -> void:
	if is_instance_valid(_toolbar_tooltip):
		_toolbar_tooltip.visible = false


func _apply_pixel_font_to_controls(parent: Node) -> void:
	if parent is Control:
		PixelUITheme.apply(parent as Control)
	for child in parent.get_children():
		_apply_pixel_font_to_controls(child)


func _toggle_build_menu() -> void:
	if _build_mode:
		_leave_build_mode()
		return
	_enter_build_mode(false)
	if is_instance_valid(_build_menu):
		_build_menu.visible = true


func _toggle_greenery_mode() -> void:
	if _greenery_mode:
		_leave_greenery_mode()
		return
	_enter_greenery_mode()


func _enter_greenery_mode() -> void:
	_set_selected_citizens([])
	_clear_deconstruction_hover_preview()
	_build_mode = false
	_placing_support = false
	_placing_excavation = false
	_removing_buildings = false
	_selected_building = null
	_landscape_mode = false
	_greenery_mode = true
	_selected_greenery = null
	_clear_object_selection()
	if is_instance_valid(_build_menu):
		_build_menu.visible = false
	if is_instance_valid(_landscape_menu):
		_landscape_menu.visible = false
	_refresh_planned_building_visibility()


func _leave_greenery_mode() -> void:
	_greenery_mode = false
	_selected_greenery = null
	_clear_object_selection()


func _toggle_landscape_mode() -> void:
	if _landscape_mode:
		_leave_landscape_mode()
		return
	_enter_landscape_mode()


func _enter_landscape_mode() -> void:
	_set_selected_citizens([])
	_clear_deconstruction_hover_preview()
	_build_mode = false
	_greenery_mode = false
	_selected_greenery = null
	_placing_support = false
	_placing_excavation = false
	_removing_buildings = false
	_selected_building = null
	_landscape_mode = true
	_landscape_tool = "remove"
	_clear_object_selection()
	if is_instance_valid(_build_menu):
		_build_menu.visible = false
	if is_instance_valid(_landscape_menu):
		_landscape_menu.visible = true
	_refresh_planned_building_visibility()


func _leave_landscape_mode() -> void:
	_landscape_mode = false
	_clear_object_selection()
	if is_instance_valid(_landscape_menu):
		_landscape_menu.visible = false


func _set_landscape_tool(next_tool: String) -> void:
	if next_tool not in ["add", "remove"]:
		return
	_landscape_tool = next_tool
	_update_toolbar_mode_state()


func _toggle_remove_building_tool() -> void:
	_clear_deconstruction_hover_preview()
	_removing_buildings = not _removing_buildings
	_placing_support = false
	_placing_excavation = false
	_selected_building = null
	_clear_object_selection()
	_refresh_planned_building_visibility()


func _create_build_menu(toolbar_layer: CanvasLayer) -> void:
	_build_menu = PanelContainer.new()
	_build_menu.name = "BottomConstructionCatalog"
	_build_menu.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	# Path is the widest family: four entries plus Remove building. Reserve that
	# width so changing category does not make the menu jump beneath the cursor.
	_build_menu.custom_minimum_size = Vector2(252.0, 102.0)
	_build_menu.position = Vector2(-126.0, -116.0)
	_build_menu.visible = false
	_build_menu.theme = PixelUITheme.tooltip_theme()
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color.BLACK
	panel_style.border_color = Color.WHITE
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(0)
	panel_style.set_content_margin_all(4.0)
	_build_menu.add_theme_stylebox_override("panel", panel_style)
	toolbar_layer.add_child(_build_menu)
	var menu_columns := VBoxContainer.new()
	menu_columns.name = "ConstructionMenuColumns"
	menu_columns.add_theme_constant_override("separation", 6)
	_build_menu.add_child(menu_columns)

	var category_row := HBoxContainer.new()
	category_row.name = "ConstructionCategoryRow"
	category_row.alignment = BoxContainer.ALIGNMENT_CENTER
	category_row.add_theme_constant_override("separation", 6)
	menu_columns.add_child(category_row)
	for category_id in BuildingCatalogScript.CATEGORY_ORDER:
		var category_button := _create_toolbar_button(
			_create_toolbar_icon("category_%s" % category_id),
			UIText.text(BuildingCatalogScript.category_label_key(category_id)),
			false,
			_create_toolbar_icon("category_%s_hover" % category_id)
		)
		category_button.name = "%sCategoryButton" % category_id.capitalize()
		category_button.toggle_mode = true
		category_button.set_meta(
			"pressed_icon",
			_create_toolbar_icon("category_%s_active" % category_id)
		)
		category_button.pressed.connect(_select_build_category.bind(category_id))
		category_row.add_child(category_button)
		_build_category_buttons[category_id] = category_button

	_build_catalog_row = HBoxContainer.new()
	_build_catalog_row.name = "ConstructionCatalogRow"
	_build_catalog_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_build_catalog_row.add_theme_constant_override("separation", 6)
	menu_columns.add_child(_build_catalog_row)
	_refresh_build_catalog()


func _select_build_category(category_id: String) -> void:
	if category_id not in BuildingCatalogScript.CATEGORY_ORDER:
		return
	_build_category = category_id
	_placing_support = false
	_placing_excavation = false
	_removing_buildings = false
	_refresh_build_catalog()
	_update_toolbar_mode_state()


func _refresh_build_catalog() -> void:
	if not is_instance_valid(_build_catalog_row):
		return
	for previous_button in _build_catalog_row.get_children():
		_build_catalog_row.remove_child(previous_button)
		previous_button.queue_free()
	_remove_building_button = null
	for entry_value in BuildingCatalogScript.entries_for(_build_category):
		var definition := entry_value as Dictionary
		var entry_id := str(definition.get("id", ""))
		var icon_kind := str(definition.get("icon", ""))
		var implemented := bool(definition.get("implemented", false))
		var entry_button := _create_toolbar_button(
			_create_toolbar_icon(icon_kind),
			UIText.text(str(definition.get("label_key", ""))),
			not implemented,
			_create_toolbar_icon("%s_hover" % icon_kind)
		)
		entry_button.name = "%sButton" % entry_id.to_pascal_case()
		if entry_id == "support":
			entry_button.name = "PlaceSupportButton"
		if implemented:
			entry_button.pressed.connect(_enter_building_placement.bind(entry_id))
		_build_catalog_row.add_child(entry_button)

	_remove_building_button = _create_toolbar_button(
		_create_toolbar_icon("remove_building"),
		UIText.text(UIText.REMOVE_BUILDING_TOOLTIP_TEXT),
		false,
		_create_toolbar_icon("remove_building_hover")
	)
	_remove_building_button.name = "RemoveBuildingButton"
	_remove_building_button.toggle_mode = true
	_remove_building_button.pressed.connect(_toggle_remove_building_tool)
	_build_catalog_row.add_child(_remove_building_button)


func _create_landscape_menu(toolbar_layer: CanvasLayer) -> void:
	_landscape_menu = PanelContainer.new()
	_landscape_menu.name = "BottomLandscapeMenu"
	_landscape_menu.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_landscape_menu.position = Vector2(-51.0, -62.0)
	_landscape_menu.visible = false
	_landscape_menu.theme = PixelUITheme.tooltip_theme()
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color.BLACK
	panel_style.border_color = Color.WHITE
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(0)
	panel_style.set_content_margin_all(4.0)
	_landscape_menu.add_theme_stylebox_override("panel", panel_style)
	toolbar_layer.add_child(_landscape_menu)

	var tool_row := HBoxContainer.new()
	tool_row.name = "LandscapeToolRow"
	tool_row.add_theme_constant_override("separation", 6)
	_landscape_menu.add_child(tool_row)
	_landscape_remove_button = _create_toolbar_button(
		_create_toolbar_icon("terrain_remove"),
		UIText.text(UIText.REMOVE_SOIL_TOOL_TOOLTIP_TEXT),
		false,
		_create_toolbar_icon("terrain_remove_hover")
	)
	_landscape_remove_button.name = "RemoveSoilButton"
	_landscape_remove_button.toggle_mode = true
	_landscape_remove_button.pressed.connect(_set_landscape_tool.bind("remove"))
	tool_row.add_child(_landscape_remove_button)
	_landscape_add_button = _create_toolbar_button(
		_create_toolbar_icon("terrain_add"),
		UIText.text(UIText.ADD_SOIL_TOOL_TOOLTIP_TEXT),
		false,
		_create_toolbar_icon("terrain_add_hover")
	)
	_landscape_add_button.name = "AddSoilButton"
	_landscape_add_button.toggle_mode = true
	_landscape_add_button.pressed.connect(_set_landscape_tool.bind("add"))
	tool_row.add_child(_landscape_add_button)


func _create_toolbar_icon(icon_kind: String) -> ImageTexture:
	return ToolbarIcons.create_icon(icon_kind)


func _create_hover_tooltip() -> void:
	var tooltip_layer := CanvasLayer.new()
	tooltip_layer.name = "WorldHoverTooltip"
	tooltip_layer.layer = 120
	add_child(tooltip_layer)
	_hover_tooltip = Label.new()
	_hover_tooltip.name = "HoverName"
	_hover_tooltip.visible = false
	_hover_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hover_tooltip.add_theme_font_size_override("font_size", VisualTokens.WORLD_TOOLTIP_FONT_SIZE)
	_hover_tooltip.add_theme_color_override("font_color", Color.BLACK)
	_hover_tooltip.add_theme_constant_override("outline_size", 0)
	var tooltip_style := StyleBoxEmpty.new()
	tooltip_style.content_margin_left = 2.0
	tooltip_style.content_margin_right = 2.0
	tooltip_style.content_margin_top = 2.0
	tooltip_style.content_margin_bottom = 2.0
	_hover_tooltip.add_theme_stylebox_override("normal", tooltip_style)
	tooltip_layer.add_child(_hover_tooltip)


func _create_custom_cursor() -> void:
	var cursor_image := Image.create(12, 12, false, Image.FORMAT_RGBA8)
	cursor_image.fill(Color.TRANSPARENT)
	# The cursor keeps a hard-pixel black-and-white treatment, but its core
	# polygons are expanded by a circular radius so the tip, tail, and joints
	# feel friendly instead of knife-sharp. No fractional alpha is introduced.
	var outer_core := PackedVector2Array([
		Vector2(1.25, 1), Vector2(1.25, 8.5), Vector2(3, 7), Vector2(5.25, 11),
		Vector2(6.5, 10.25), Vector2(4.5, 6.5), Vector2(8, 6.5),
	])
	var inner_core := PackedVector2Array([
		Vector2(2, 2.25), Vector2(2, 7.25), Vector2(3.25, 6.25), Vector2(5.25, 9.75),
		Vector2(5.5, 9.5), Vector2(3.75, 6), Vector2(6.75, 6),
	])
	for pixel_x in 12:
		for pixel_y in 12:
			var pixel_centre := Vector2(float(pixel_x) + 0.5, float(pixel_y) + 0.5)
			if _is_point_in_rounded_polygon(pixel_centre, outer_core, 0.6875):
				cursor_image.set_pixel(pixel_x, pixel_y, Color.WHITE)
			if _is_point_in_rounded_polygon(pixel_centre, inner_core, 0.375):
				cursor_image.set_pixel(pixel_x, pixel_y, Color.BLACK)
	_cursor_texture = ImageTexture.create_from_image(cursor_image)
	Input.set_custom_mouse_cursor(_cursor_texture, Input.CURSOR_ARROW, Vector2(1.25, 1.0))


func _is_point_in_rounded_polygon(
	point: Vector2,
	polygon: PackedVector2Array,
	radius: float
) -> bool:
	if Geometry2D.is_point_in_polygon(point, polygon):
		return true
	var radius_squared := radius * radius
	for point_index in polygon.size():
		var edge_start := polygon[point_index]
		var edge_end := polygon[(point_index + 1) % polygon.size()]
		if _distance_squared_to_segment(point, edge_start, edge_end) <= radius_squared:
			return true
	return false


func _distance_squared_to_segment(point: Vector2, edge_start: Vector2, edge_end: Vector2) -> float:
	var edge := edge_end - edge_start
	var edge_length_squared := edge.length_squared()
	if edge_length_squared <= 0.0001:
		return point.distance_squared_to(edge_start)
	var edge_progress := clampf((point - edge_start).dot(edge) / edge_length_squared, 0.0, 1.0)
	return point.distance_squared_to(edge_start + edge * edge_progress)


func _create_first_launch_onboarding() -> void:
	_onboarding_layer = CanvasLayer.new()
	_onboarding_layer.name = "FirstLaunchOnboarding"
	_onboarding_layer.layer = 140
	_onboarding_layer.visible = false
	add_child(_onboarding_layer)

	var panel := Panel.new()
	panel.name = "KeyboardLesson"
	panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	panel.position = Vector2(-260.0, -270.0)
	panel.size = Vector2(520.0, 245.0)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.03, 0.03, 0.03, 0.78)
	panel_style.corner_radius_top_left = 18
	panel_style.corner_radius_top_right = 18
	panel_style.corner_radius_bottom_left = 18
	panel_style.corner_radius_bottom_right = 18
	panel.add_theme_stylebox_override("panel", panel_style)
	_onboarding_layer.add_child(panel)

	var title := Label.new()
	title.text = UIText.text(UIText.ONBOARDING_TITLE_TEXT)
	title.position = Vector2(22.0, 14.0)
	title.add_theme_font_size_override("font_size", VisualTokens.ONBOARDING_TITLE_FONT_SIZE)
	title.add_theme_color_override("font_color", Color.WHITE)
	panel.add_child(title)
	var explanation := Label.new()
	explanation.text = UIText.text(UIText.ONBOARDING_EXPLANATION_TEXT)
	explanation.position = Vector2(22.0, 42.0)
	explanation.add_theme_font_size_override("font_size", VisualTokens.ONBOARDING_BODY_FONT_SIZE)
	explanation.add_theme_color_override("font_color", Color.WHITE)
	panel.add_child(explanation)

	_create_blank_keyboard_row(panel, [31.0, 31.0, 31.0, 31.0, 31.0, 31.0, 31.0, 31.0, 31.0, 31.0], Vector2(22.0, 73.0))
	_create_blank_keyboard_row(panel, [31.0, 31.0, 31.0, 31.0, 31.0, 31.0, 31.0, 31.0, 31.0], Vector2(39.0, 111.0))
	_create_blank_keyboard_row(panel, [31.0, 31.0, 31.0, 31.0, 31.0, 31.0, 31.0], Vector2(56.0, 149.0))
	# Wider blank modifiers and the long Space shape remain recognizable without
	# prescribing key bindings before the player needs them.
	_create_blank_keyboard_row(panel, [46.0, 46.0, 170.0, 46.0, 46.0], Vector2(39.0, 187.0))

	var dismiss_button := Button.new()
	dismiss_button.text = UIText.text(UIText.ONBOARDING_DISMISS_BUTTON_TEXT)
	dismiss_button.position = Vector2(426.0, 199.0)
	dismiss_button.size = Vector2(72.0, 32.0)
	dismiss_button.pressed.connect(_complete_onboarding)
	panel.add_child(dismiss_button)

	var onboarding_state := ConfigFile.new()
	var has_completed := false
	if onboarding_state.load(ONBOARDING_STATE_PATH) == OK:
		has_completed = bool(onboarding_state.get_value("onboarding", "wasd_complete", false))
	if not has_completed:
		_show_onboarding()


func _create_blank_keyboard_row(parent: Control, key_widths: Array[float], row_position: Vector2) -> void:
	var row := HBoxContainer.new()
	row.name = "BlankKeyboardRow"
	row.position = row_position
	row.add_theme_constant_override("separation", 5)
	parent.add_child(row)
	for key_width in key_widths:
		var key := Label.new()
		key.name = "BlankKey"
		key.custom_minimum_size = Vector2(key_width, 31.0)
		key.text = ""
		key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		key.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		key.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var key_style := StyleBoxFlat.new()
		key_style.bg_color = Color(0.34, 0.34, 0.34, 0.62)
		key_style.border_color = Color.WHITE
		key_style.border_width_left = 1
		key_style.border_width_top = 1
		key_style.border_width_right = 1
		key_style.border_width_bottom = 1
		key_style.corner_radius_top_left = 5
		key_style.corner_radius_top_right = 5
		key_style.corner_radius_bottom_left = 5
		key_style.corner_radius_bottom_right = 5
		key.add_theme_stylebox_override("normal", key_style)
		row.add_child(key)


func _show_onboarding() -> void:
	if is_instance_valid(_onboarding_layer):
		_onboarding_layer.visible = true


func _complete_onboarding() -> void:
	if is_instance_valid(_onboarding_layer):
		_onboarding_layer.visible = false
	var onboarding_state := ConfigFile.new()
	onboarding_state.set_value("onboarding", "wasd_complete", true)
	onboarding_state.save(ONBOARDING_STATE_PATH)


func _create_count_badge(
	parent: Node,
	screen_position: Vector2,
	badge_size: Vector2,
	corner_radius: int,
	background_colour: Color
) -> Label:
	var badge := Label.new()
	badge.position = screen_position
	badge.size = badge_size
	badge.custom_minimum_size = badge_size
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_theme_font_size_override("font_size", VisualTokens.COUNT_BADGE_FONT_SIZE)
	badge.add_theme_color_override("font_color", Color.WHITE)
	var badge_style := StyleBoxFlat.new()
	badge_style.bg_color = background_colour
	badge_style.corner_radius_top_left = corner_radius
	badge_style.corner_radius_top_right = corner_radius
	badge_style.corner_radius_bottom_left = corner_radius
	badge_style.corner_radius_bottom_right = corner_radius
	badge_style.content_margin_left = 3.0
	badge_style.content_margin_right = 3.0
	badge.add_theme_stylebox_override("normal", badge_style)
	parent.add_child(badge)
	return badge


func _create_pixel_filter() -> void:
	var pixel_layer := CanvasLayer.new()
	pixel_layer.name = "PixelFilter"
	pixel_layer.layer = 100
	add_child(pixel_layer)

	var pixel_rect := ColorRect.new()
	pixel_rect.name = "NearestPixelFilter"
	pixel_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pixel_layer.add_child(pixel_rect)
	pixel_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var pixel_material := ShaderMaterial.new()
	pixel_material.shader = PIXEL_FILTER_SHADER
	pixel_material.set_shader_parameter("pixel_block_size", PIXEL_BLOCK_SIZE)
	pixel_rect.material = pixel_material


func _update_interface() -> void:
	if _ui_mode == null:
		return
	if _build_mode:
		_ui_mode.text = UIText.text(UIText.BUILDING_MODE_LABEL_TEXT)
	elif _landscape_mode:
		_ui_mode.text = UIText.text(UIText.LANDSCAPE_MODE_LABEL_TEXT)
	elif _greenery_mode:
		_ui_mode.text = UIText.text(UIText.GREENERY_MODE_LABEL_TEXT)
	elif not _selected_citizens.is_empty():
		_ui_mode.text = UIText.text(UIText.CITIZEN_MODE_LABEL_TEXT)
	else:
		_ui_mode.text = UIText.text(UIText.COMMAND_MODE_LABEL_TEXT)
	_rts_count_badge.visible = not _build_mode and _selected_citizens.size() > 1
	_rts_count_badge.text = str(_selected_citizens.size())
	_update_rts_count_badge_geometry()
	if is_instance_valid(_population_icon_number):
		_population_icon_number.set_number(_population_count())
	_update_selected_pile_inventory()
	_update_toolbar_mode_state()
	_day_label.text = UIText.text(
		UIText.DAY_COUNT_TEXT,
		[int(floor(_elapsed / _day_length_seconds)) + 1]
	)
	var selected_text := UIText.text(UIText.NO_CITIZEN_SELECTED_TEXT)
	if _selected_citizens.size() > 1:
		selected_text = UIText.text(
			UIText.MULTIPLE_CITIZENS_SELECTED_TEXT,
			[_selected_citizens.size()]
		)
	elif is_instance_valid(_selected_citizen):
		selected_text = UIText.text(
			UIText.SINGLE_CITIZEN_SELECTED_TEXT,
			[_selected_citizen.get_status_text()]
		)
	_ui_status.text = selected_text
	_ui_resources.text = UIText.text(UIText.RESOURCES_SUMMARY_TEXT, [
		_calories,
		_water,
		_count_available_logs(),
		_construction_sites.size(),
	])


func _update_toolbar_mode_state() -> void:
	if not is_instance_valid(_building_button):
		return
	_building_button.set_pressed_no_signal(_build_mode)
	_set_toolbar_button_icon(
		_building_button,
		_building_button.get_meta("normal_icon") as ImageTexture
	)
	if is_instance_valid(_remove_building_button):
		_remove_building_button.set_pressed_no_signal(_removing_buildings)
		_set_toolbar_button_icon(
			_remove_building_button,
			_remove_building_button.get_meta("normal_icon") as ImageTexture
		)
	for category_id in _build_category_buttons:
		var category_button := _build_category_buttons[category_id] as Button
		if not is_instance_valid(category_button):
			continue
		category_button.set_pressed_no_signal(str(category_id) == _build_category)
		_set_toolbar_button_icon(
			category_button,
			category_button.get_meta("normal_icon") as ImageTexture
		)
	if is_instance_valid(_greenery_button):
		_greenery_button.set_pressed_no_signal(_greenery_mode)
		_set_toolbar_button_icon(
			_greenery_button,
			_greenery_button.get_meta("normal_icon") as ImageTexture
		)
	if is_instance_valid(_landscape_button):
		_landscape_button.set_pressed_no_signal(_landscape_mode)
		_set_toolbar_button_icon(
			_landscape_button,
			_landscape_button.get_meta("normal_icon") as ImageTexture
		)
	if is_instance_valid(_landscape_remove_button):
		_landscape_remove_button.set_pressed_no_signal(_landscape_tool == "remove")
		_set_toolbar_button_icon(
			_landscape_remove_button,
			_landscape_remove_button.get_meta("normal_icon") as ImageTexture
		)
	if is_instance_valid(_landscape_add_button):
		_landscape_add_button.set_pressed_no_signal(_landscape_tool == "add")
		_set_toolbar_button_icon(
			_landscape_add_button,
			_landscape_add_button.get_meta("normal_icon") as ImageTexture
		)


func _population_count() -> int:
	var count := 0
	for citizen in _citizens:
		if is_instance_valid(citizen):
			count += 1
	return count


func _update_rts_count_badge_geometry() -> void:
	const BADGE_DIAMETER := 18.0
	var badge_font := _rts_count_badge.get_theme_font("font")
	var badge_font_size := _rts_count_badge.get_theme_font_size("font_size")
	var text_width := badge_font.get_string_size(
		_rts_count_badge.text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		badge_font_size
	).x
	# One digit remains a true circle. Larger counts may extend only sideways,
	# retaining circular end caps and the same 18-pixel vertical diameter.
	var badge_width := maxf(BADGE_DIAMETER, ceilf(text_width + 6.0))
	_rts_count_badge.custom_minimum_size = Vector2(BADGE_DIAMETER, BADGE_DIAMETER)
	_rts_count_badge.size = Vector2(badge_width, BADGE_DIAMETER)
	_rts_count_badge.position = get_viewport().get_mouse_position() + Vector2(19.0, 18.0)


func _count_available_logs() -> int:
	var count := _starting_pile.stored_logs if is_instance_valid(_starting_pile) else 0
	for item in _items:
		if is_instance_valid(item) and item.is_available_log():
			count += 1
	return count


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	return material


func _terrain_material(surface_colour: Color) -> ShaderMaterial:
	var terrain_material := ShaderMaterial.new()
	terrain_material.shader = TERRAIN_SHADER
	terrain_material.set_shader_parameter("surface_color", surface_colour)
	terrain_material.set_shader_parameter("shadow_color", Palette.FOG_AND_SHADOW)
	terrain_material.set_shader_parameter("daylight", 1.0)
	terrain_material.set_shader_parameter("cloud_shadow_offset", Vector2.ZERO)
	terrain_material.set_shader_parameter("cloud_shadows_enabled", CLOUDS_ENABLED)
	terrain_material.set_shader_parameter("citizen_clear_radius", REVEAL_RADIUS + 0.4)
	terrain_material.set_shader_parameter("cloud_shadow_cell_size", FOG_CELL_SIZE)
	terrain_material.set_shader_parameter("cloud_cell_coverage_threshold", 0.5)
	terrain_material.set_shader_parameter("excavated_cell_count", 0)
	return terrain_material
