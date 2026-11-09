extends SceneTree

class FailingStore extends ProfileStore:
	var fail_write: bool = false

	func _promote_revision(temp_path: String, final_path: String) -> Error:
		if fail_write:
			return ERR_CANT_CREATE
		return super._promote_revision(temp_path, final_path)

## SBL-W8-004 Overworld Dungeon Gateway Integration Test Suite
## Requirements: GDD-031/032/033/034/035, FR-DNG-001/002, AGENTS.md Invariants.

const GameRootScene: PackedScene = preload("res://scenes/main/game_root.tscn")

var _failures: int = 0
var _test_root: String = ""

func _check(ok: bool, msg: String) -> bool:
	if not ok:
		_failures += 1
		printerr("OVERWORLD GATEWAY TEST FAILED: ", msg)
	return ok

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("--- Running SBL-W8-004 Overworld Dungeon Gateway Test Suite ---")

	_test_root = "user://test_gateway_profiles_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	var test_store := FailingStore.new(_test_root)

	var game_root: Control = GameRootScene.instantiate() as Control
	game_root.profile_store = test_store
	root.add_child(game_root)
	game_root._init_slice_progress(test_store, "profile_01")

	# Allow 2 frames for scene ready and region bootstrap
	await process_frame
	await process_frame

	var player: PlayerCharacter = game_root.player
	_check(player != null, "Player character instantiated")

	var region: Node2D = game_root.world_router.active_region
	_check(region != null, "Active overworld region loaded")
	var gateway: Area2D = region.get_node_or_null("ExpeditionGateway") as Area2D
	_check(gateway != null, "ExpeditionGateway fixture exists in region")

	# Step 1: Trigger Gateway Entry
	gateway.body_entered.emit(player)
	await process_frame

	_check(game_root._expedition != null, "DungeonExpedition instantiated and running")
	_check(game_root._expedition.is_active == true, "Expedition is active")
	_check(player.input_frozen == true, "Player movement frozen during expedition")

	# Verify satchel items were populated by dungeon rooms
	var expedition: DungeonExpedition = game_root._expedition
	_check(expedition.inventory.satchel_items.has("ancient_relic_fragment"), "Expedition gathered satchel loot")
	var gathered_count: int = expedition.inventory.satchel_items["ancient_relic_fragment"]
	_check(gathered_count > 0, "Gathered fragment count > 0")

	# Step 2: Trigger Extraction
	for step in range(expedition.expedition_path.size()):
		if expedition.is_at_extraction_chamber():
			break
		expedition.advance_btn.pressed.emit()
	_check(expedition.is_at_extraction_chamber(), "Reached extraction before committing")
	gathered_count = expedition.inventory.satchel_items.get("ancient_relic_fragment", 0)
	test_store.fail_write = true
	_check(expedition.extract_now().is_empty(), "failed gateway extraction gives no reward")
	_check(game_root._expedition == expedition and expedition.is_active and player.input_frozen, "failed save leaves active expedition available to retry")
	_check(expedition.inventory.satchel_items.get("ancient_relic_fragment", 0) == gathered_count, "failed save preserves satchel")
	_check(game_root.inventory_manager.banked_items.is_empty(), "failed save leaves bank unchanged")
	_check(test_store.load_profile("profile_01")["error"] == ERR_FILE_NOT_FOUND, "failed save did not publish a revision")
	test_store.fail_write = false
	var extracted: Dictionary = expedition.extract_now()
	await process_frame

	_check(extracted.get("ancient_relic_fragment", 0) == gathered_count, "All satchel fragments successfully extracted")
	_check(game_root.inventory_manager.banked_items["ancient_relic_fragment"] == gathered_count, "Fragments banked in Town Bank")
	_check(game_root.inventory_manager.satchel_items.is_empty(), "Satchel empty after extraction")
	_check(game_root._expedition == null, "Expedition scene cleaned up after extraction")
	_check(player.input_frozen == false, "Player movement restored after extraction")

	# Step 3: Trigger Second Expedition for Defeat Test
	gateway.body_entered.emit(player)
	await process_frame

	_check(game_root._expedition != null, "Second expedition entered")
	var expedition2: DungeonExpedition = game_root._expedition
	_check(expedition2.inventory.satchel_items.has("ancient_relic_fragment"), "Second expedition satchel loot populated")

	# Simulate Defeat
	var lost: Dictionary = expedition2.fail_now()
	await process_frame

	_check(lost.size() > 0, "Satchel loot lost on defeat")
	_check(game_root.inventory_manager.satchel_items.is_empty(), "Satchel wiped on defeat")
	_check(game_root.inventory_manager.banked_items["ancient_relic_fragment"] == gathered_count, "INVARIANT: Town Bank preserved exactly after defeat!")
	_check(game_root._expedition == null, "Expedition scene cleaned up after defeat")
	_check(player.input_frozen == false, "Player restored to unfrozen state")

	# Step 4: Test Interactive UI Modal Controls (Step Back / Cancel & Interactive Exploration)
	gateway.body_entered.emit(player)
	await process_frame

	_check(game_root._expedition != null, "Third expedition entered")
	var expedition3: DungeonExpedition = game_root._expedition
	_check(expedition3.advance_btn != null, "Interactive UI advance button exists")
	_check(expedition3.step_back_btn != null, "Interactive UI step back button exists")
	_check(expedition3.step_back_btn.visible == true, "Step back button visible at entrance")

	# Test Step Back / Cancel
	expedition3.step_back_btn.pressed.emit()
	await process_frame

	_check(game_root._expedition == null, "Expedition cancelled cleanly via Step Back button")
	_check(player.input_frozen == false, "Player movement restored immediately after cancelling")

	# Step 5: Test Full Interactive Advance & Extraction Flow via Buttons
	gateway.body_entered.emit(player)
	await process_frame

	var expedition4: DungeonExpedition = game_root._expedition
	_check(expedition4 != null, "Fourth expedition entered for advance flow")

	# Advance room-by-room until extraction portal reached
	var safety_counter: int = 0
	while expedition4.extract_btn.disabled and safety_counter < 10:
		expedition4.advance_btn.pressed.emit()
		safety_counter += 1

	_check(expedition4.extract_btn.disabled == false, "Reached extraction portal via interactive button navigation")

	# Click Extract Button
	expedition4.extract_btn.pressed.emit()
	await process_frame

	_check(game_root._expedition == null, "Expedition cleanly extracted and closed via interactive button")
	_check(player.input_frozen == false, "Player movement restored immediately after interactive extraction")

	game_root.queue_free()

	# Cleanup temporary profile dir
	if DirAccess.dir_exists_absolute(_test_root):
		var d := DirAccess.open(_test_root)
		if d != null:
			for sub in d.get_directories():
				var sub_d := DirAccess.open(_test_root + "/" + sub)
				if sub_d != null:
					for f in sub_d.get_files():
						sub_d.remove(f)
					d.remove(sub)
			d.remove("")

	if _failures > 0:
		printerr("OVERWORLD GATEWAY TESTS FAILED: ", _failures)
		quit(1)
		return

	print("=== ALL OVERWORLD GATEWAY TESTS PASSED SUCCESSFULLY ===")
	quit(0)
