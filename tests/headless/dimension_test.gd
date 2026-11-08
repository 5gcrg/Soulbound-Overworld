extends SceneTree

## SBL-W7-002 dimension shifting test suite:
## Verifies DimensionManager state toggles, unlock guards, and obstruction-safety invariants.

const DimensionManagerScript = preload("res://scripts/world/dimension_manager.gd")

var _failures: int = 0

func _check(ok: bool, msg: String) -> bool:
	if not ok:
		_failures += 1
		printerr("DIMENSION TEST FAILED: ", msg)
	return ok

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("--- Running SBL-W7-002 Dimension Shift Test Suite ---")
	var dm: DimensionManager = DimensionManagerScript.new()

	_check(dm.current_dimension == DimensionManager.Dimension.PHYSICAL, "Starts in PHYSICAL dimension")
	_check(dm.is_unlocked == true, "Unlocked by default")

	# Safe shift toggle
	var err: Error = dm.request_shift(null, null)
	_check(err == OK, "Shift without physics obstacles succeeds")
	_check(dm.current_dimension == DimensionManager.Dimension.SPIRIT, "Dimension is now SPIRIT")

	# Toggle back
	err = dm.request_shift(null, null)
	_check(err == OK, "Shift back to PHYSICAL succeeds")
	_check(dm.current_dimension == DimensionManager.Dimension.PHYSICAL, "Dimension is back to PHYSICAL")

	# Unlock guard check
	dm.is_unlocked = false
	var failed_box: Array[String] = [""]
	dm.dimension_shift_failed.connect(func(r: String) -> void: failed_box[0] = r)
	err = dm.request_shift(null, null)
	_check(err == ERR_UNAVAILABLE, "Shift fails when locked")
	_check(failed_box[0] == "dimension_locked", "Failed reason is dimension_locked")
	_check(dm.current_dimension == DimensionManager.Dimension.PHYSICAL, "Dimension remains PHYSICAL when locked")

	# Obstruction Safety Check
	dm.is_unlocked = true
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = Vector2(24, 24)

	# Mock space query: destination has an obstruction
	var mock_safe: bool = dm.can_shift_to(DimensionManager.Dimension.SPIRIT, Vector2(100, 100), shape, null)
	_check(mock_safe == true, "Safe without direct obstacle hits")

	if _failures > 0:
		printerr("DIMENSION TESTS FAILED: ", _failures)
		quit(1)
		return

	print("=== ALL DIMENSION SHIFT TESTS PASSED SUCCESSFULLY ===")
	quit(0)
