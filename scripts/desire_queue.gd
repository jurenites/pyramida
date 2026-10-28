extends RefCounted
## Presentation time, independent of simulation speed. Reconcile before advancing.
## One entry per owner/need; refresh never resets its place or display timer.
const INITIAL_DELAY := 2.0
const DISPLAY_SECONDS := 4.0
const GAP_SECONDS := 1.0
const REPEAT_SECONDS := 24.0
var elapsed := 0.0
var entries := {}
var active_key := ""
var visible_until := 0.0
var next_slot := 0.0
var sequence := 0

func sync(requests: Array[Dictionary]) -> void:
	var live := {}
	for request in requests:
		var key: String = request.key
		live[key] = true
		if not entries.has(key):
			sequence += 1
			entries[key] = {"ready_at": elapsed + INITIAL_DELAY, "turn": sequence}
		entries[key]["request"] = request
	for key in entries.keys():
		if not live.has(key):
			entries.erase(key)
			if active_key == key:
				active_key = ""
				next_slot = elapsed + GAP_SECONDS

func advance(delta: float) -> void:
	elapsed += maxf(0.0, delta)
	if not active_key.is_empty() and elapsed >= visible_until:
		sequence += 1
		entries[active_key].turn = sequence
		entries[active_key].ready_at = elapsed + REPEAT_SECONDS
		active_key = ""
		next_slot = elapsed + GAP_SECONDS
	if not active_key.is_empty() or elapsed < next_slot: return
	var oldest := 9223372036854775807
	for key: String in entries:
		var entry: Dictionary = entries[key]
		if entry.ready_at <= elapsed and entry.turn < oldest and entry.request.get("eligible", true):
			oldest = entry.turn
			active_key = key
	if not active_key.is_empty(): visible_until = elapsed + DISPLAY_SECONDS

func current() -> Dictionary:
	if active_key.is_empty() or not entries.has(active_key): return {}
	var request: Dictionary = entries[active_key].request
	return request if request.get("eligible", true) else {}
