class_name EndingManager
extends RefCounted

## EndingManager — SBL-W11-001 Dual-Ending Narrative & Epilogue Controller
## Requirements: GDD-041/116, FR-WLD-001, AGENTS.md Invariants.
##
## Governs the two canonical endings of Soulbound's 5-chapter campaign:
## - Ending A: Spirit Transcendence (Harmonizes Physical and Spirit dimensions permanently)
## - Ending B: World Restoration (Seals the Astral Rift permanently, returning to mortal balance)

signal ending_triggered(ending_type: String, title: String)

const ENDING_A_TRANSCENDENCE: String = "transcendence"
const ENDING_B_RESTORATION: String = "restoration"

const ENDING_DETAILS: Dictionary = {
	ENDING_A_TRANSCENDENCE: {
		"title": "Ending A: Spirit Transcendence",
		"summary": "Ren channels the ancestral resonant ley-lines at the peak of the Void Citadel, harmonizing the Spirit and Physical dimensions into a single unified continuum. Mortals and spirits now walk side by side in transcendent unity.",
		"epilogue": "The dimensional boundary dissolved not in catastrophe, but in symphonic resonance. Armed with critical insight and perseverance, Ren established the Grand Academy of Resonance.",
		"badge": "Transcendence Luminary"
	},
	ENDING_B_RESTORATION: {
		"title": "Ending B: World Restoration",
		"summary": "Ren channels the secured ancient seals to permanently close the Astral Void Rift. Dimensional rifts across the five regions mend, preserving mortal life in peaceful stability.",
		"epilogue": "The rifts closed with an enduring hum. Ren returned to Dawnreach Village as the Guardian of the Threshold, ensuring that future generations maintain the balance between wisdom and caution.",
		"badge": "Restoration Sovereign"
	}
}

var chosen_ending: String = ""
var is_ending_achieved: bool = false
var timestamp: int = 0

func choose_ending(ending_type: String) -> Dictionary:
	if not ENDING_DETAILS.has(ending_type):
		return {"error": ERR_INVALID_PARAMETER}

	chosen_ending = ending_type
	is_ending_achieved = true
	timestamp = Time.get_unix_time_from_system()

	var details: Dictionary = (ENDING_DETAILS[ending_type] as Dictionary).duplicate(true)
	ending_triggered.emit(ending_type, String(details.get("title", "")))

	return {
		"error": OK,
		"ending": ending_type,
		"details": details
	}

func get_ending_details(ending_type: String = "") -> Dictionary:
	var target: String = chosen_ending if ending_type.is_empty() else ending_type
	if ENDING_DETAILS.has(target):
		return (ENDING_DETAILS[target] as Dictionary).duplicate(true)
	return {}

func serialize() -> Dictionary:
	return {
		"chosen_ending": chosen_ending,
		"is_ending_achieved": is_ending_achieved,
		"timestamp": timestamp
	}

func deserialize(data: Dictionary) -> void:
	chosen_ending = String(data.get("chosen_ending", ""))
	is_ending_achieved = bool(data.get("is_ending_achieved", false))
	timestamp = int(data.get("timestamp", 0))
