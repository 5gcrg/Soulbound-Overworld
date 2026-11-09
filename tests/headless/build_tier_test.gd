extends SceneTree

## SBL-BLD-002: Build-Tier Marker and Config Parsing Test Suite
## Requirements: GDD-041, GDD-113, GDD-116, AGENTS.md Engineering Invariants.
##
## Verifies that:
## 1. ReleaseTier.parse_tier() handles valid and invalid tier inputs correctly.
## 2. ReleaseTier.get_tier() parses the checked-in project setting (OD-017 default full_release).
## 3. ReleaseTier.get_tier() parses res://build_tier.txt marker file when present.
## 4. Runtime tier override takes precedence over both marker file and project settings.
## 5. Deletion or absence of marker file cleanly reverts to project settings.

var _failures: int = 0

func _init() -> void:
	call_deferred("_run_tests")

func _check(condition: bool, message: String) -> void:
	if condition:
		print("  PASS: %s" % message)
	else:
		printerr("  FAIL: %s" % message)
		_failures += 1

func _run_tests() -> void:
	print("--- Running SBL-BLD-002 Build-Tier Marker & Config Parsing Test Suite ---")

	# 1. String normalization and parsing tests
	_check(ReleaseTier.parse_tier("academic_mvp") == ReleaseTier.TIER_ACADEMIC_MVP, "parse_tier('academic_mvp') == academic_mvp")
	_check(ReleaseTier.parse_tier("ACADEMIC_MVP") == ReleaseTier.TIER_ACADEMIC_MVP, "parse_tier case insensitivity: 'ACADEMIC_MVP' == academic_mvp")
	_check(ReleaseTier.parse_tier("  academic_mvp  \n") == ReleaseTier.TIER_ACADEMIC_MVP, "parse_tier whitespace trimming: '  academic_mvp  ' == academic_mvp")
	_check(ReleaseTier.parse_tier("full_release") == ReleaseTier.TIER_FULL_RELEASE, "parse_tier('full_release') == full_release")
	_check(ReleaseTier.parse_tier("FULL_RELEASE") == ReleaseTier.TIER_FULL_RELEASE, "parse_tier case insensitivity: 'FULL_RELEASE' == full_release")
	_check(ReleaseTier.parse_tier("unknown_custom_tier") == ReleaseTier.TIER_FULL_RELEASE, "parse_tier fallback for unrecognized tier is full_release")
	_check(ReleaseTier.parse_tier("") == ReleaseTier.TIER_FULL_RELEASE, "parse_tier fallback for empty string is full_release")

	# 2. Checked-in setting test (OD-017 invariant)
	_check(ReleaseTier.get_tier() == ReleaseTier.TIER_FULL_RELEASE, "Unoverridden tier matches project default (full_release)")
	_check(ReleaseTier.is_full_release() == true, "is_full_release() is true for project default")
	_check(ReleaseTier.is_academic_mvp() == false, "is_academic_mvp() is false for project default")

	# 3. Marker file parsing test
	var marker_path: String = ReleaseTier.MARKER_PATH
	# Ensure no pre-existing marker
	var marker_preexisted: bool = FileAccess.file_exists(marker_path)
	var prev_marker_content: String = ""
	if marker_preexisted:
		var f_prev: FileAccess = FileAccess.open(marker_path, FileAccess.READ)
		if f_prev != null:
			prev_marker_content = f_prev.get_as_text()
			f_prev.close()

	# 3a. Write academic_mvp marker
	var f_out: FileAccess = FileAccess.open(marker_path, FileAccess.WRITE)
	_check(f_out != null, "Successfully opened marker path for writing: %s" % marker_path)
	if f_out != null:
		f_out.store_string("academic_mvp\n")
		f_out.close()

	_check(ReleaseTier.get_tier() == ReleaseTier.TIER_ACADEMIC_MVP, "Marker file 'academic_mvp' parsed by ReleaseTier.get_tier()")
	_check(ReleaseTier.is_academic_mvp() == true, "is_academic_mvp() is true with 'academic_mvp' marker")
	_check(ReleaseTier.is_full_release() == false, "is_full_release() is false with 'academic_mvp' marker")

	# 3b. Runtime override takes precedence over marker
	ReleaseTier.set_tier_override(ReleaseTier.TIER_FULL_RELEASE)
	_check(ReleaseTier.get_tier() == ReleaseTier.TIER_FULL_RELEASE, "Runtime override takes precedence over marker file")
	ReleaseTier.clear_tier_override()
	_check(ReleaseTier.get_tier() == ReleaseTier.TIER_ACADEMIC_MVP, "Clearing override restores marker file tier")

	# 3c. Write full_release marker
	f_out = FileAccess.open(marker_path, FileAccess.WRITE)
	if f_out != null:
		f_out.store_string("full_release")
		f_out.close()
	_check(ReleaseTier.get_tier() == ReleaseTier.TIER_FULL_RELEASE, "Marker file 'full_release' parsed by ReleaseTier.get_tier()")

	# 3d. Clean up marker file and verify restoration to project settings
	var da: DirAccess = DirAccess.open("res://")
	if da != null:
		if marker_preexisted:
			var f_rest: FileAccess = FileAccess.open(marker_path, FileAccess.WRITE)
			if f_rest != null:
				f_rest.store_string(prev_marker_content)
				f_rest.close()
		else:
			da.remove(marker_path.replace("res://", ""))

	_check(ReleaseTier.get_tier() == ReleaseTier.TIER_FULL_RELEASE, "After marker removal, tier reverts cleanly to project default")

	if _failures == 0:
		print("--- SBL-BLD-002 Build-Tier Marker & Config Parsing Test Suite PASSED ---")
		quit(0)
	else:
		printerr("--- SBL-BLD-002 Build-Tier Marker & Config Parsing Test Suite FAILED with %d errors ---" % _failures)
		quit(1)
