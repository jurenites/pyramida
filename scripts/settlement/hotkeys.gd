extends RefCounted
## Settlement bindings; menu navigation and Blueprint editing keep their own keys.
const DEFAULTS := {
	"pan_forward": KEY_W, "pan_back": KEY_S, "pan_left": KEY_A, "pan_right": KEY_D,
	"move": KEY_M, "rotate_remove": KEY_R, "floor_down": KEY_Q, "floor_up": KEY_E,
	"remove": KEY_BACKSPACE,
	"copy_cutaway": KEY_C, "build": KEY_B, "inspect": KEY_V, "blueprints": KEY_F2,
}
const LABELS := {
	"pan_forward": "Camera forward", "pan_back": "Camera backward",
	"pan_left": "Camera left", "pan_right": "Camera right",
	"move": "Move / replant selection", "rotate_remove": "Rotate placement / remove selection",
	"remove": "Remove selection",
	"floor_down": "View floor below", "floor_up": "View floor above",
	"copy_cutaway": "Copy selection / toggle cutaway",
	"build": "Open / close build menu", "inspect": "Return to inspect", "blueprints": "Open Blueprints",
}
var values: Dictionary = DEFAULTS.duplicate()

static func keycode(event: InputEventKey) -> int:
	return event.physical_keycode if event.physical_keycode != 0 else event.keycode

static func allowed(key: int) -> bool:
	return key > 0 and key < KEY_MODIFIER_MASK and key not in [KEY_ESCAPE, KEY_TAB, KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META, KEY_CAPSLOCK, KEY_NONE, KEY_UNKNOWN] and not OS.get_keycode_string(key).is_empty()

func load_values(saved: Variant) -> void:
	values = DEFAULTS.duplicate()
	if not saved is Dictionary:
		return
	var candidate := DEFAULTS.duplicate()
	for action: String in DEFAULTS:
		var key: Variant = saved.get(action, DEFAULTS[action])
		if not key is int or not allowed(key):
			return
		candidate[action] = key
	var used: Array = []
	for key: int in candidate.values():
		if key in used:
			return
		used.append(key)
	values = candidate

func conflict(action: String, key: int) -> String:
	for other: String in values:
		if other != action and values[other] == key:
			return other
	return ""

func matches(event: InputEvent, action: String) -> bool:
	return event is InputEventKey and event.pressed and not event.echo and not event.ctrl_pressed and not event.meta_pressed and not event.alt_pressed and not event.shift_pressed and keycode(event) == values[action]

func held(action: String) -> bool:
	return Input.is_physical_key_pressed(values[action]) and not Input.is_key_pressed(KEY_CTRL) and not Input.is_key_pressed(KEY_META) and not Input.is_key_pressed(KEY_ALT)

func key_text(action: String) -> String:
	var physical: int = values[action]
	var local_key := physical if DisplayServer.get_name() == "headless" else DisplayServer.keyboard_get_keycode_from_physical(physical)
	return OS.get_keycode_string(local_key if local_key != 0 else physical)

func hint(text: String, action: String) -> String:
	return text.get_slice(" · ", 0) + " · " + key_text(action)
