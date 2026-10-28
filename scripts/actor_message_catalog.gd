class_name ActorMessageCatalog
extends RefCounted

## One table controls how citizens and future world actors communicate through
## compact icon speech bubbles. Persistent needs are refreshed by the owning
## simulation system; if refresh stops, their queue entry expires by itself.

const CONFIRM_LOG := "confirm_log"
const CONFIRM_PLANK := "confirm_plank"
const CONFIRM_FOOD := "confirm_food"
const CONFIRM_WATER := "confirm_water"
const CONFIRM_CONSTRUCTION := "confirm_construction"
const NEED_WATER := "need_water"
const NEED_FOOD := "need_food"
const NEED_COOL_AIR := "need_cool_air"
const NEED_FRESH_AIR := "need_fresh_air"
const DOOR_BLOCKED := "door_blocked"
const NEED_ELECTRICITY := "need_electricity"
const UTILITY_DISCONNECTED := "utility_disconnected"

const DEFINITIONS := {
	DOOR_BLOCKED: {"icon": "door_blocked", "priority": 82, "initial_delay": 2.0, "display_seconds": 4.0, "time_to_live": 12.0, "repeat_seconds": 24.0, "maximum_repeat_seconds": 64.0, "clusterable": true},
	NEED_ELECTRICITY: {"icon": "electricity", "priority": 60, "initial_delay": 2.0, "display_seconds": 4.0, "time_to_live": 12.0, "repeat_seconds": 24.0, "maximum_repeat_seconds": 64.0, "clusterable": true},
	CONFIRM_LOG: {
		"icon": "log",
		"short_text": "",
		"priority": 76,
		"initial_delay": 0.05,
		"display_seconds": 1.8,
		"time_to_live": 6.0,
		"repeat_seconds": 0.0,
		"maximum_repeat_seconds": 0.0,
		"clusterable": true,
	},
	CONFIRM_PLANK: {
		"icon": "plank",
		"short_text": "",
		"priority": 76,
		"initial_delay": 0.05,
		"display_seconds": 1.8,
		"time_to_live": 6.0,
		"repeat_seconds": 0.0,
		"maximum_repeat_seconds": 0.0,
		"clusterable": true,
	},
	CONFIRM_FOOD: {
		"icon": "food",
		"short_text": "",
		"priority": 76,
		"initial_delay": 0.05,
		"display_seconds": 1.8,
		"time_to_live": 6.0,
		"repeat_seconds": 0.0,
		"maximum_repeat_seconds": 0.0,
		"clusterable": true,
	},
	CONFIRM_WATER: {
		"icon": "water",
		"short_text": "",
		"priority": 76,
		"initial_delay": 0.05,
		"display_seconds": 1.8,
		"time_to_live": 6.0,
		"repeat_seconds": 0.0,
		"maximum_repeat_seconds": 0.0,
		"clusterable": true,
	},
	CONFIRM_CONSTRUCTION: {
		"icon": "construction",
		"short_text": "",
		"priority": 78,
		"initial_delay": 0.05,
		"display_seconds": 2.0,
		"time_to_live": 7.0,
		"repeat_seconds": 0.0,
		"maximum_repeat_seconds": 0.0,
		"clusterable": true,
	},
	NEED_WATER: {
		"icon": "water",
		"short_text": "",
		"priority": 60,
		"initial_delay": 2.0,
		"display_seconds": 4.0,
		"time_to_live": 12.0,
		"repeat_seconds": 24.0,
		"maximum_repeat_seconds": 64.0,
		"clusterable": true,
	},
	NEED_FOOD: {
		"icon": "food",
		"short_text": "",
		"priority": 64,
		"initial_delay": 2.0,
		"display_seconds": 4.0,
		"time_to_live": 12.0,
		"repeat_seconds": 24.0,
		"maximum_repeat_seconds": 64.0,
		"clusterable": true,
	},
	NEED_COOL_AIR: {
		"icon": "heat",
		"short_text": "",
		"priority": 48,
		"initial_delay": 2.0,
		"display_seconds": 4.0,
		"time_to_live": 12.0,
		"repeat_seconds": 24.0,
		"maximum_repeat_seconds": 64.0,
		"clusterable": true,
	},
	NEED_FRESH_AIR: {
		"icon": "air",
		"short_text": "",
		"priority": 52,
		"initial_delay": 2.0,
		"display_seconds": 4.0,
		"time_to_live": 12.0,
		"repeat_seconds": 24.0,
		"maximum_repeat_seconds": 64.0,
		"clusterable": true,
	},
	UTILITY_DISCONNECTED: {
		"icon": "connection",
		"short_text": "",
		"priority": 82,
		"initial_delay": 2.0,
		"display_seconds": 4.0,
		"time_to_live": 12.0,
		"repeat_seconds": 24.0,
		"maximum_repeat_seconds": 64.0,
		"clusterable": true,
	},
}


static func definition(message_id: String) -> Dictionary:
	if not DEFINITIONS.has(message_id):
		return {}
	return (DEFINITIONS[message_id] as Dictionary).duplicate(true)
