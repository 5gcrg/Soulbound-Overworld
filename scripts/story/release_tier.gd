class_name ReleaseTier
extends RefCounted

## ReleaseTier — SBL-FIX-010 Release-tier separation
## Requirements: GDD-041, GDD-113, GDD-116, AGENTS.md Engineering Invariants.
##
## Manages project release tier:
## - "academic_mvp": 3-chapter academic MVP (Dawnreach, Whispering Grove, Forgotten Shrine).
##   Void Citadel region/portal, both ending altars, the ending modal path, and the capstone
##   question are gated/locked behind full_release. Keep chapter 4 (ACADEMIC_COMPLETE) as endpoint.
## - "full_release": 5-chapter campaign with Ashen Peaks, Void Citadel, boss, and dual endings.

const TIER_ACADEMIC_MVP: String = "academic_mvp"
const TIER_FULL_RELEASE: String = "full_release"

const SETTING_PATH: String = "soulbound/release_tier"
const MARKER_PATH: String = "res://build_tier.txt"

static var _runtime_tier_override: String = ""

static func parse_tier(val: String) -> String:
	var trimmed: String = val.strip_edges().to_lower()
	if trimmed == TIER_ACADEMIC_MVP:
		return TIER_ACADEMIC_MVP
	elif trimmed == TIER_FULL_RELEASE:
		return TIER_FULL_RELEASE
	return TIER_FULL_RELEASE

static func get_tier() -> String:
	if not _runtime_tier_override.is_empty():
		return _runtime_tier_override
	if FileAccess.file_exists(MARKER_PATH):
		var f: FileAccess = FileAccess.open(MARKER_PATH, FileAccess.READ)
		if f != null:
			var marker_val: String = f.get_as_text().strip_edges()
			f.close()
			if marker_val == TIER_ACADEMIC_MVP or marker_val == TIER_FULL_RELEASE:
				return marker_val
	if ProjectSettings.has_setting(SETTING_PATH):
		var val: String = String(ProjectSettings.get_setting(SETTING_PATH)).strip_edges()
		return parse_tier(val)
	return TIER_FULL_RELEASE

static func is_full_release() -> bool:
	return get_tier() == TIER_FULL_RELEASE

static func is_academic_mvp() -> bool:
	return get_tier() == TIER_ACADEMIC_MVP

static func set_tier_override(tier: String) -> void:
	_runtime_tier_override = tier

static func clear_tier_override() -> void:
	_runtime_tier_override = ""
