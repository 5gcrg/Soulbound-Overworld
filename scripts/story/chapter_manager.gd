class_name ChapterManager
extends RefCounted

## ChapterManager — SBL-W9-001 Three-Chapter Academic Story Progression Controller
## Requirements: GDD-041/063/070/116, FR-WLD-001, FR-EDU-003, AGENTS.md Invariants.
##
## Manages progression across the 3 academic story chapters:
## - Chapter I: Dawnreach Village
## - Chapter II: Whispering Grove
## - Chapter III: Forgotten Shrine (Academic MVP Completion Point)

signal chapter_advanced(from_chapter: int, to_chapter: int)
signal academic_mvp_achieved

const CHAPTER_1: int = 1
const CHAPTER_2: int = 2
const CHAPTER_3: int = 3
const ACADEMIC_COMPLETE: int = 4

const CHAPTER_NAMES: Dictionary = {
	CHAPTER_1: "Chapter I: Dawnreach Village",
	CHAPTER_2: "Chapter II: Whispering Grove",
	CHAPTER_3: "Chapter III: Forgotten Shrine",
	ACADEMIC_COMPLETE: "Academic MVP Complete"
}

const CHAPTER_REGIONS: Dictionary = {
	CHAPTER_1: "dawnreach_village",
	CHAPTER_2: "whispering_grove",
	CHAPTER_3: "forgotten_shrine"
}

var current_chapter: int = CHAPTER_1
var unlocked_chapters: Array[int] = [CHAPTER_1]
var is_academic_complete: bool = false
var chapter_flags: Dictionary = {}

func get_chapter_title(chapter_num: int = -1) -> String:
	var ch: int = current_chapter if chapter_num < 0 else chapter_num
	return String(CHAPTER_NAMES.get(ch, "Unknown Chapter"))

func get_chapter_region(chapter_num: int = -1) -> String:
	var ch: int = current_chapter if chapter_num < 0 else chapter_num
	return String(CHAPTER_REGIONS.get(ch, "test_region_alpha"))

func can_advance_chapter(assessment: AssessmentController) -> bool:
	if is_academic_complete:
		return false
	if assessment == null:
		return false
	# Completion-gated: requires completion of chapter educational activity
	return assessment.is_chapter_activity_completed(current_chapter)

func try_advance_chapter(assessment: AssessmentController) -> bool:
	if not can_advance_chapter(assessment):
		return false

	var from_ch: int = current_chapter
	if current_chapter == CHAPTER_1:
		current_chapter = CHAPTER_2
		if not unlocked_chapters.has(CHAPTER_2):
			unlocked_chapters.append(CHAPTER_2)
		chapter_advanced.emit(from_ch, CHAPTER_2)
		return true
	elif current_chapter == CHAPTER_2:
		current_chapter = CHAPTER_3
		if not unlocked_chapters.has(CHAPTER_3):
			unlocked_chapters.append(CHAPTER_3)
		chapter_advanced.emit(from_ch, CHAPTER_3)
		return true
	elif current_chapter == CHAPTER_3:
		current_chapter = ACADEMIC_COMPLETE
		is_academic_complete = true
		academic_mvp_achieved.emit()
		chapter_advanced.emit(from_ch, ACADEMIC_COMPLETE)
		return true
	return false

func is_chapter_unlocked(chapter_num: int) -> bool:
	return unlocked_chapters.has(chapter_num)

func set_chapter_flag(key: String, val: Variant) -> void:
	chapter_flags[key] = val

func get_chapter_flag(key: String, default_val: Variant = null) -> Variant:
	return chapter_flags.get(key, default_val)

# ==============================================================================
# Serialization & ProfileStore Integration
# ==============================================================================

func serialize() -> Dictionary:
	return {
		"current_chapter": current_chapter,
		"unlocked_chapters": unlocked_chapters.duplicate(),
		"is_academic_complete": is_academic_complete,
		"chapter_flags": chapter_flags.duplicate(true)
	}

func deserialize(data: Dictionary) -> Error:
	if not data.has("current_chapter"):
		return ERR_INVALID_DATA
	current_chapter = int(data.get("current_chapter", CHAPTER_1))
	is_academic_complete = bool(data.get("is_academic_complete", false))
	unlocked_chapters = []
	for c in data.get("unlocked_chapters", [CHAPTER_1]):
		unlocked_chapters.append(int(c))
	chapter_flags = (data.get("chapter_flags", {}) as Dictionary).duplicate(true)
	return OK

func load_from_store(store: ProfileStore, slot: String = "profile_01") -> Error:
	if store == null:
		return ERR_INVALID_PARAMETER
	var res: Dictionary = store.load_profile(slot)
	if res["error"] != OK:
		return res["error"]
	var prof: Dictionary = res["profile"]
	var world_data: Dictionary = prof.get("world", {})
	if not world_data.has("chapter_progress") or typeof(world_data["chapter_progress"]) != TYPE_DICTIONARY:
		return ERR_DOES_NOT_EXIST
	return deserialize(world_data["chapter_progress"])

func save_to_store(store: ProfileStore, slot: String = "profile_01") -> Error:
	if store == null:
		return ERR_INVALID_PARAMETER
	var res: Dictionary = store.load_profile(slot)
	var prof: Dictionary = {}
	if res["error"] == ERR_FILE_NOT_FOUND:
		prof = store.new_profile(slot)
	elif res["error"] == OK:
		prof = (res["profile"] as Dictionary).duplicate(true)
	else:
		return res["error"]
	var world_data: Dictionary = prof.get("world", {})
	world_data["chapter_progress"] = serialize()
	prof["world"] = world_data
	return store.save_profile(slot, prof)
