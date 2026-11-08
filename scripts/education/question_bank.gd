class_name QuestionBank
extends RefCounted

## QuestionBank — SBL-W7-001 Educational Question Catalog
## Requirements: GDD-063/067/068/069/070, FR-EDU-001, AGENTS.md Invariants.
##
## Curated senior-high competency questions covering Chapters I, II, and III:
## - Critical Thinking
## - Decision-Making
## - Perseverance
## - Resource Management

const COMP_CRITICAL_THINKING: String = "Critical Thinking"
const COMP_DECISION_MAKING: String = "Decision-Making"
const COMP_PERSEVERANCE: String = "Perseverance"
const COMP_RESOURCE_MANAGEMENT: String = "Resource Management"

const ALL_COMPETENCIES: Array[String] = [
	COMP_CRITICAL_THINKING,
	COMP_DECISION_MAKING,
	COMP_PERSEVERANCE,
	COMP_RESOURCE_MANAGEMENT
]

const QUESTIONS: Dictionary = {
	"q_crit_01": {
		"id": "q_crit_01",
		"chapter": 1,
		"competency": COMP_CRITICAL_THINKING,
		"difficulty": "Foundational",
		"prompt": "An adversary demonstrates high physical armor but exhibits zero resonance defense. Which tactical approach is optimal?",
		"options": [
			"Execute standard physical strike",
			"Channel spirit resonance spell",
			"Flee immediately",
			"Deplete stamina with rapid dodges"
		],
		"correct_index": 1,
		"explanation": "Exploiting resonance vulnerabilities bypasses physical armor ratings efficiently."
	},
	"q_dec_01": {
		"id": "q_dec_01",
		"chapter": 1,
		"competency": COMP_DECISION_MAKING,
		"difficulty": "Foundational",
		"prompt": "Your satchel holds 3 rare relics. Ren has 15% HP, and the next chamber holds an elite boss. An extraction shrine is 10 meters away. What choice minimizes total risk?",
		"options": [
			"Enter the boss room for potentially greater loot",
			"Extract immediately to bank secured items in town",
			"Discard relics to run faster",
			"Wait indefinitely in the corridor"
		],
		"correct_index": 1,
		"explanation": "Securing unbanked loot via extraction preserves value; defeat wipes all unbanked satchel items."
	},
	"q_persevere_01": {
		"id": "q_persevere_01",
		"chapter": 2,
		"competency": COMP_PERSEVERANCE,
		"difficulty": "Foundational",
		"prompt": "Following an expedition defeat where all satchel loot was lost, what is the resilient response?",
		"options": [
			"Abandon the expedition system permanently",
			"Review encounter failures, refine equipment from banked gear, and re-enter",
			"Delete the profile and restart",
			"Blame game mechanics without adjusting tactic"
		],
		"correct_index": 1,
		"explanation": "Banked gear and experience are preserved; iterative learning turns defeats into strategic insight."
	},
	"q_res_01": {
		"id": "q_res_01",
		"chapter": 2,
		"competency": COMP_RESOURCE_MANAGEMENT,
		"difficulty": "Foundational",
		"prompt": "Ren has 3 action pips remaining. The enemy charges a lethal strike. Defending costs 1 pip, healing costs 2 pips, and attacking costs 2 pips. What allocation ensures survival?",
		"options": [
			"Attack twice to attempt a desperate knockout",
			"Defend and cast heal to mitigate incoming damage and restore vitality",
			"Spend all pips taunting the enemy",
			"Do nothing to save stamina"
		],
		"correct_index": 1,
		"explanation": "Defending mitigates lethal damage, and healing restores Ren to a sustainable HP threshold."
	},
	"q_crit_02": {
		"id": "q_crit_02",
		"chapter": 3,
		"competency": COMP_CRITICAL_THINKING,
		"difficulty": "Intermediate",
		"prompt": "When analyzing conflicting scout reports of enemy patrol routes, what is the first evaluative step?",
		"options": [
			"Accept the most recent report without verification",
			"Cross-reference terrain constraints and report timestamps",
			"Assume all scouts made identical errors",
			"Abandon the route completely"
		],
		"correct_index": 1,
		"explanation": "Validating timestamps against physical terrain boundaries identifies observational discrepancies."
	},
	"q_dec_02": {
		"id": "q_dec_02",
		"chapter": 3,
		"competency": COMP_DECISION_MAKING,
		"difficulty": "Advanced",
		"prompt": "Under time-pressured expedition constraints, when two teammates propose opposing tactics with equal plausibility, a leader must:",
		"options": [
			"Delay until external authorization arrives",
			"Assess reversible vs irreversible consequences and commit decisively",
			"Flip a coin to avoid taking responsibility",
			"Order both tactics simultaneously"
		],
		"correct_index": 1,
		"explanation": "Effective decision-making prioritizes actions with reversible consequences under uncertainty."
	}
}

static func get_question(id: String) -> Dictionary:
	if QUESTIONS.has(id):
		return (QUESTIONS[id] as Dictionary).duplicate(true)
	return {}

static func get_questions_by_competency(comp: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for q_id: String in QUESTIONS.keys():
		var q: Dictionary = QUESTIONS[q_id]
		if String(q.get("competency", "")) == comp:
			result.append(q.duplicate(true))
	return result

static func get_questions_by_chapter(chapter_num: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for q_id: String in QUESTIONS.keys():
		var q: Dictionary = QUESTIONS[q_id]
		if int(q.get("chapter", 0)) == chapter_num:
			result.append(q.duplicate(true))
	return result

static func get_required_question_id_for_chapter(chapter_num: int) -> String:
	match chapter_num:
		1: return "q_dec_01"
		2: return "q_res_01"
		3: return "q_crit_02"
		_: return "q_crit_01"

static func get_all_question_ids() -> Array[String]:
	var ids: Array[String] = []
	for k: String in QUESTIONS.keys():
		ids.append(k)
	return ids
