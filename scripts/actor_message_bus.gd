class_name ActorMessageBus
extends Node

const MessageCatalog = preload("res://scripts/actor_message_catalog.gd")

signal visible_messages_changed

@export var maximum_visible_messages := 1

var _next_slot := 0.0

var _elapsed := 0.0
var _sequence := 0
var _entries: Dictionary = {}
var _visible_keys: Array[String] = []


func _process(delta: float) -> void:
	_elapsed += delta
	var changed := _remove_expired_entries()
	changed = _finish_visible_messages() or changed
	changed = _promote_ready_messages() or changed
	if changed:
		visible_messages_changed.emit()


func post_message(actor: Node3D, message_id: String, options: Dictionary = {}) -> String:
	if not is_instance_valid(actor):
		return ""
	var definition := MessageCatalog.definition(message_id)
	if definition.is_empty():
		push_warning("Unknown actor speech message: %s" % message_id)
		return ""
	for option_key in options:
		definition[option_key] = options[option_key]

	_sequence += 1
	var clusterable := bool(definition.get("clusterable", false))
	var cluster_scope := str(definition.get("cluster_scope", "world"))
	var entry_key := "%s|%s" % [message_id, cluster_scope]
	if float(definition.get("repeat_seconds", 0.0)) > 0.0:
		entry_key += "|%d" % actor.get_instance_id()
	if not clusterable:
		entry_key = "%s|%d" % [message_id, _sequence]

	var time_to_live := float(definition.get("time_to_live", 8.0))
	var actor_id := actor.get_instance_id()
	var speaker_kind := str(definition.get("speaker_kind", "utility"))
	if actor.has_method("speech_actor_kind"):
		speaker_kind = str(actor.call("speech_actor_kind"))
	if _entries.has(entry_key):
		var existing_entry: Dictionary = _entries[entry_key]
		var existing_actors: Dictionary = existing_entry.get("actors", {})
		existing_actors[actor_id] = weakref(actor)
		existing_entry["actors"] = existing_actors
		existing_entry["last_refresh"] = _elapsed
		existing_entry["expires_at"] = _elapsed + time_to_live
		_entries[entry_key] = existing_entry
		visible_messages_changed.emit()
		return entry_key

	var actors := {actor_id: weakref(actor)}
	_entries[entry_key] = {
		"key": entry_key,
		"message_id": message_id,
		"cluster_scope": cluster_scope,
		"icon": str(definition.get("icon", "ok")),
		"short_text": str(definition.get("short_text", "")),
		"speaker_kind": speaker_kind,
		"priority": int(definition.get("priority", 0)),
		"created_at": _elapsed,
		"last_refresh": _elapsed,
		"ready_at": _elapsed + float(definition.get("initial_delay", 0.0)),
		"expires_at": _elapsed + time_to_live,
		"display_seconds": float(definition.get("display_seconds", 2.0)),
		"visible_until": 0.0,
		"repeat_seconds": float(definition.get("repeat_seconds", 0.0)),
		"next_repeat_seconds": float(definition.get("repeat_seconds", 0.0)),
		"maximum_repeat_seconds": float(definition.get("maximum_repeat_seconds", 0.0)),
		"visible": false,
		"actor_cursor": 0,
		"actors": actors,
	}
	return entry_key


func clear_message(actor: Node3D, message_id: String, cluster_scope := "world") -> void:
	if not is_instance_valid(actor):
		return
	var actor_id := actor.get_instance_id()
	var keys_to_remove: Array[String] = []
	for entry_key_value in _entries:
		var entry_key := str(entry_key_value)
		var entry: Dictionary = _entries[entry_key]
		if str(entry.get("message_id", "")) != message_id:
			continue
		if str(entry.get("cluster_scope", "world")) != cluster_scope:
			continue
		var actors: Dictionary = entry.get("actors", {})
		actors.erase(actor_id)
		entry["actors"] = actors
		_entries[entry_key] = entry
		if actors.is_empty():
			keys_to_remove.append(entry_key)
	for entry_key in keys_to_remove:
		_remove_entry(entry_key)
	if not keys_to_remove.is_empty():
		visible_messages_changed.emit()


func visible_messages() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry_key in _visible_keys:
		if not _entries.has(entry_key):
			continue
		var entry: Dictionary = _entries[entry_key]
		var actors := _valid_actors(entry)
		if actors.is_empty():
			continue
		var actor_cursor := int(entry.get("actor_cursor", 0)) % actors.size()
		result.append({
			"key": entry_key,
			"message_id": str(entry.get("message_id", "")),
			"icon": str(entry.get("icon", "ok")),
			"short_text": str(entry.get("short_text", "")),
			"speaker_kind": str(entry.get("speaker_kind", "utility")),
			"priority": int(entry.get("priority", 0)),
			"actor": actors[actor_cursor],
			"actor_count": actors.size(),
		})
	return result


func pending_message_count() -> int:
	return _entries.size()


func _remove_expired_entries() -> bool:
	var keys_to_remove: Array[String] = []
	for entry_key_value in _entries:
		var entry_key := str(entry_key_value)
		var entry: Dictionary = _entries[entry_key]
		_prune_invalid_actors(entry)
		_entries[entry_key] = entry
		if (entry.get("actors", {}) as Dictionary).is_empty() or _elapsed >= float(entry.get("expires_at", 0.0)):
			keys_to_remove.append(entry_key)
	for entry_key in keys_to_remove:
		_remove_entry(entry_key)
	return not keys_to_remove.is_empty()


func _finish_visible_messages() -> bool:
	var changed := false
	for entry_key in _visible_keys.duplicate():
		if not _entries.has(entry_key):
			_visible_keys.erase(entry_key)
			changed = true
			continue
		var entry: Dictionary = _entries[entry_key]
		if _elapsed < float(entry.get("visible_until", INF)):
			continue
		_next_slot = _elapsed + 1.0
		entry["created_at"] = _elapsed
		entry["visible"] = false
		_visible_keys.erase(entry_key)
		var repeat_seconds := float(entry.get("next_repeat_seconds", 0.0))
		if repeat_seconds <= 0.0:
			_entries.erase(entry_key)
		else:
			entry["ready_at"] = _elapsed + repeat_seconds
			entry["actor_cursor"] = int(entry.get("actor_cursor", 0)) + 1
			var maximum_repeat := float(entry.get("maximum_repeat_seconds", repeat_seconds))
			entry["next_repeat_seconds"] = minf(repeat_seconds * 2.0, maximum_repeat)
			_entries[entry_key] = entry
		changed = true
	return changed


func _promote_ready_messages() -> bool:
	if _elapsed < _next_slot: return false
	var available_slots := mini(1, maximum_visible_messages) - _visible_keys.size()
	if available_slots <= 0:
		return false
	var ready_entries: Array[Dictionary] = []
	for entry_key_value in _entries:
		var entry_key := str(entry_key_value)
		var entry: Dictionary = _entries[entry_key]
		if bool(entry.get("visible", false)) or _elapsed < float(entry.get("ready_at", INF)):
			continue
		if _valid_actors(entry).is_empty():
			continue
		ready_entries.append(entry)
	ready_entries.sort_custom(_message_precedes)
	var changed := false
	for entry in ready_entries:
		if available_slots <= 0:
			break
		var entry_key := str(entry.get("key", ""))
		entry["visible"] = true
		entry["visible_until"] = _elapsed + float(entry.get("display_seconds", 2.0))
		_entries[entry_key] = entry
		_visible_keys.append(entry_key)
		available_slots -= 1
		changed = true
	return changed


func _message_precedes(first: Dictionary, second: Dictionary) -> bool:
	var first_time := float(first.get("created_at", 0.0))
	var second_time := float(second.get("created_at", 0.0))
	if not is_equal_approx(first_time, second_time): return first_time < second_time
	var first_priority := int(first.get("priority", 0))
	var second_priority := int(second.get("priority", 0))
	if first_priority != second_priority:
		return first_priority > second_priority
	return float(first.get("created_at", 0.0)) < float(second.get("created_at", 0.0))


func _valid_actors(entry: Dictionary) -> Array[Node3D]:
	var result: Array[Node3D] = []
	var actors: Dictionary = entry.get("actors", {})
	for actor_reference_value in actors.values():
		var actor_reference := actor_reference_value as WeakRef
		var actor := actor_reference.get_ref() as Node3D if actor_reference != null else null
		if is_instance_valid(actor):
			result.append(actor)
	return result


func _prune_invalid_actors(entry: Dictionary) -> void:
	var actors: Dictionary = entry.get("actors", {})
	for actor_id in actors.keys():
		var actor_reference := actors[actor_id] as WeakRef
		if actor_reference == null or not is_instance_valid(actor_reference.get_ref()):
			actors.erase(actor_id)
	entry["actors"] = actors


func _remove_entry(entry_key: String) -> void:
	if entry_key in _visible_keys: _next_slot = _elapsed + 1.0
	_entries.erase(entry_key)
	_visible_keys.erase(entry_key)
