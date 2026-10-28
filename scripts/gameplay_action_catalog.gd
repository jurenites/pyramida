class_name GameplayActionCatalog
extends RefCounted

const UIText = preload("res://scripts/ui_text_catalog.gd")

const MOVE := "move"
const CHOP_TREE := "chop"
const HARVEST_BUSH := "harvest"
const COLLECT_CACTUS := "collect_cactus"
const EXCAVATE := "excavate"
const FETCH_LOG := "fetch_log"
const DELIVER_LOG := "deliver_log"
const APPLY_BUILDING_BLOCK := "apply_building_block"
const DELIVER_FOOD := "deliver_food"
const FETCH_WORKSHOP_INPUT := "fetch_workshop_input"
const SAW_PLANK := "saw_plank"

## Every player-ordered Citizen action belongs here. The content contract tests
## require a readable English text key and at least one loadable AudioStream for
## each definition. Empty arrays deliberately identify unfinished audio work.
const DEFINITIONS := {
	MOVE: {
		"text_key": UIText.CITIZEN_WALKING_STATUS_TEXT,
		"audio_streams": ["res://assets/audio/settlement/step_01.wav", "res://assets/audio/settlement/step_02.wav", "res://assets/audio/settlement/step_03.wav", "res://assets/audio/settlement/step_04.wav", "res://assets/audio/settlement/step_05.wav", "res://assets/audio/settlement/step_06.wav"],
	},
	CHOP_TREE: {
		"text_key": UIText.CITIZEN_CUTTING_TREE_STATUS_TEXT,
		"audio_streams": ["res://assets/audio/settlement/chop_01.wav", "res://assets/audio/settlement/chop_02.wav", "res://assets/audio/settlement/chop_03.wav", "res://assets/audio/settlement/chop_04.wav", "res://assets/audio/settlement/chop_05.wav"],
	},
	HARVEST_BUSH: {
		"text_key": UIText.CITIZEN_HARVESTING_BUSH_STATUS_TEXT,
		"audio_streams": [],
	},
	COLLECT_CACTUS: {
		"text_key": UIText.CITIZEN_COLLECTING_CACTUS_STATUS_TEXT,
		"audio_streams": [],
	},
	EXCAVATE: {
		"text_key": UIText.CITIZEN_DIGGING_STATUS_TEXT,
		"audio_streams": [],
	},
	FETCH_LOG: {
		"text_key": UIText.CITIZEN_FETCHING_LOG_STATUS_TEXT,
		"audio_streams": [],
	},
	DELIVER_LOG: {
		"text_key": UIText.CITIZEN_CARRYING_LOG_STATUS_TEXT,
		"audio_streams": [],
	},
	DELIVER_FOOD: {
		"text_key": UIText.CITIZEN_CARRYING_FOOD_STATUS_TEXT,
		"audio_streams": [],
	},
	FETCH_WORKSHOP_INPUT: {
		"text_key": UIText.CITIZEN_FETCHING_LOG_STATUS_TEXT,
		"audio_streams": [],
	},
	SAW_PLANK: {
		"text_key": UIText.CITIZEN_SAWING_PLANK_STATUS_TEXT,
		"audio_streams": [],
	},
}


static func definition(action_id: String) -> Dictionary:
	if not DEFINITIONS.has(action_id):
		return {}
	return (DEFINITIONS[action_id] as Dictionary).duplicate(true)
