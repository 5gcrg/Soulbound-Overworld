extends SceneTree

## SBL-W8-003 dungeon expedition scene test suite:
## Verifies DungeonExpedition scene generation, extraction portal, and loot transfer.

const DungeonExpeditionScene: PackedScene = preload("res://scenes/dungeon/dungeon_expedition.tscn")

var _failures: int = 0

func _check(ok: bool, msg: String) -> bool:
	if not ok:
		_failures += 1
		printerr("DUNGEON SCENE TEST FAILED: ", msg)
	return ok

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("--- Running SBL-W8-003 Dungeon Scene Test Suite ---")
	var expedition: DungeonExpedition = DungeonExpeditionScene.instantiate() as DungeonExpedition
	root.add_child(expedition)

	var ok: bool = expedition.setup(1337, 6)
	_check(ok == true, "Expedition setup succeeded")
	_check(expedition.is_active == true, "Expedition is active")
	_check(expedition.rooms_container.get_child_count() == 6, "Rooms container holds 6 rooms")
	_check(expedition.extraction_portal != null, "Extraction portal spawned")

	# Check satchel gathered loot
	_check(expedition.inventory.satchel_items.has("ancient_relic_fragment"), "Satchel collected relic fragments from normal rooms")
	var fragment_count: int = expedition.inventory.satchel_items["ancient_relic_fragment"]
	_check(fragment_count > 0, "Satchel holds > 0 fragments")

	# Test Extraction
	var extracted: Dictionary = expedition.extract_now()
	_check(extracted["ancient_relic_fragment"] == fragment_count, "All fragments extracted")
	_check(expedition.inventory.satchel_items.is_empty(), "Satchel empty after extraction")
	_check(expedition.inventory.banked_items["ancient_relic_fragment"] == fragment_count, "Fragments transferred to bank")
	_check(expedition.is_active == false, "Expedition deactivated after extraction")

	# Test Defeat on second run
	expedition.setup(42, 5)
	_check(expedition.inventory.satchel_items.has("ancient_relic_fragment"), "Second run gathered new satchel loot")
	var lost: Dictionary = expedition.fail_now()
	_check(lost.size() > 0, "Defeat returned lost satchel items")
	_check(expedition.inventory.satchel_items.is_empty(), "Satchel wiped on defeat")
	_check(expedition.inventory.banked_items["ancient_relic_fragment"] == fragment_count, "Banked items strictly preserved after defeat")

	expedition.queue_free()

	if _failures > 0:
		printerr("DUNGEON SCENE TESTS FAILED: ", _failures)
		quit(1)
		return

	print("=== ALL DUNGEON SCENE TESTS PASSED SUCCESSFULLY ===")
	quit(0)
