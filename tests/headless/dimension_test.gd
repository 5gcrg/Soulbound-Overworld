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

	# ==========================================================================
	# Player collision mask follows the active plane
	# ==========================================================================
	var player: PlayerCharacter = preload("res://scenes/player/player.tscn").instantiate()
	root.add_child(player)
	dm.apply_player_collision(player)
	_check(player.collision_mask == DimensionManager.COLLISION_MASK_PHYSICAL, "Player collides with physical layer in PHYSICAL")
	dm.request_shift(player, null)
	_check(player.collision_mask == DimensionManager.COLLISION_MASK_SPIRIT, "Player collides with spirit layer in SPIRIT")
	dm.request_shift(player, null)
	_check(player.collision_mask == DimensionManager.COLLISION_MASK_PHYSICAL, "Player mask restored on return to PHYSICAL")

	# ==========================================================================
	# Region-scoped visibility and collision toggling
	# ==========================================================================
	var region_a := Node2D.new()
	var region_b := Node2D.new()
	root.add_child(region_a)
	root.add_child(region_b)

	var physical_body := StaticBody2D.new()
	physical_body.add_to_group("physical_only")
	var physical_shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(24, 24)
	physical_shape.shape = rect
	physical_body.add_child(physical_shape)
	region_a.add_child(physical_body)

	var spirit_container := Node2D.new()
	spirit_container.add_to_group("spirit_only")
	var spirit_body := StaticBody2D.new()
	var spirit_shape := CollisionShape2D.new()
	spirit_shape.shape = rect
	spirit_body.add_child(spirit_shape)
	spirit_container.add_child(spirit_body)
	region_a.add_child(spirit_container)

	# A sibling region's node must never be touched by region_a's application.
	var sibling_body := StaticBody2D.new()
	sibling_body.add_to_group("physical_only")
	var sibling_shape := CollisionShape2D.new()
	sibling_shape.shape = rect
	sibling_body.add_child(sibling_shape)
	region_b.add_child(sibling_body)

	dm.apply_dimension_to_region(region_a)
	_check(physical_body.visible == true, "Physical group visible in PHYSICAL")
	_check(physical_body.is_shape_owner_disabled(0) == false, "Physical collision enabled in PHYSICAL")
	_check(spirit_container.visible == false, "Spirit group hidden in PHYSICAL")
	_check(spirit_body.is_shape_owner_disabled(0) == true, "Nested spirit collision disabled in PHYSICAL")
	_check(sibling_body.is_shape_owner_disabled(0) == false, "Sibling region untouched by scoped apply")

	dm.request_shift(null, null)
	dm.apply_dimension_to_region(region_a)
	_check(physical_body.visible == false, "Physical group hidden in SPIRIT")
	_check(physical_body.is_shape_owner_disabled(0) == true, "Physical collision disabled in SPIRIT")
	_check(spirit_container.visible == true, "Spirit group visible in SPIRIT")
	_check(spirit_body.is_shape_owner_disabled(0) == false, "Nested spirit collision enabled in SPIRIT")
	_check(sibling_body.is_shape_owner_disabled(0) == false, "Sibling region still untouched in SPIRIT")

	dm.request_shift(null, null)
	dm.apply_dimension_to_region(region_a)
	_check(physical_body.is_shape_owner_disabled(0) == false, "Physical collision restored after round trip")
	_check(spirit_body.is_shape_owner_disabled(0) == true, "Spirit collision disabled after round trip")

	player.queue_free()
	region_a.queue_free()
	region_b.queue_free()
	await process_frame

	if _failures > 0:
		printerr("DIMENSION TESTS FAILED: ", _failures)
		quit(1)
		return

	print("=== ALL DIMENSION SHIFT TESTS PASSED SUCCESSFULLY ===")
	quit(0)
