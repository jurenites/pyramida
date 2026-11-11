extends RefCounted
## A single writer owns its SaveSlots instance; foreground transitions drain it.
const Slots = preload("res://scripts/settlement/save_slots.gd")
const Codec = preload("res://scripts/settlement/save_codec.gd")
var thread: Thread

func busy() -> bool:
	return thread != null

func start(directory: String, slot: int, record: Dictionary) -> bool:
	if busy(): return false
	thread = Thread.new()
	if thread.start(_write.bind(directory, slot, record)) != OK:
		thread = null
		return false
	return true

static func _write(directory: String, slot: int, record: Dictionary) -> Dictionary:
	var storage = Slots.new()
	storage.directory = directory
	record.world = Codec.encode_capture(record.world)
	var success: bool = storage.write_snapshot(slot, record)
	return {"success": success, "error": storage.last_error}

func poll() -> Dictionary:
	if thread == null or thread.is_alive(): return {}
	return finish()

func finish() -> Dictionary:
	if thread == null: return {}
	var result: Dictionary = thread.wait_to_finish()
	thread = null
	return result
