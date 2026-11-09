extends SceneTree

func _fail(message: String) -> void:
	printerr("COMBAT TEST FAILED: ", message)
	quit(1)

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	var watchdog := create_timer(4.0)
	watchdog.timeout.connect(func() -> void: _fail("Watchdog 4.0s timeout reached"))

	var root_scene: PackedScene = load("res://scenes/main/game_root.tscn")
	if root_scene == null:
		_fail("Missing game_root.tscn")
		return
	var game_root: Node = root_scene.instantiate()
	root.add_child(game_root)
	await process_frame
	await process_frame

	var player: PlayerCharacter = game_root.get_node("Player") as PlayerCharacter
	var router: WorldRouter = game_root.get_node("WorldRouter") as WorldRouter
	var battle_layer: CanvasLayer = game_root.get_node("BattleLayer") as CanvasLayer
	if player == null or router == null or battle_layer == null:
		_fail("Required game_root child nodes missing")
		return

	var active_region: Node2D = router.active_region
	if active_region == null:
		_fail("Missing router.active_region")
		return

	var encounter: Area2D = active_region.get_node("CombatEncounter") as Area2D
	if encounter == null:
		_fail("Missing Alpha CombatEncounter")
		return

	var initial_region: Node2D = active_region
	var encounter_pos: Vector2 = encounter.global_position

	player.global_position = encounter_pos
	for i in 5:
		await physics_frame
	await process_frame

	if battle_layer.get_child_count() != 1:
		_fail("Expected 1 BattleFixture in BattleLayer")
		return
	var fixture: BattleFixture = battle_layer.get_child(0) as BattleFixture
	if fixture == null or not player.input_frozen:
		_fail("Expected fixture and player.input_frozen")
		return

	if fixture.request_action(&"invalid_action"):
		_fail("Invalid request was not rejected")
		return
	if fixture.enemy_intent != &"Strike":
		_fail("Expected opening enemy_intent Strike")
		return
	fixture.defend_button.pressed.emit()
	if fixture.request_action(&"attack"):
		_fail("Duplicate attack was not rejected")
		return
	await process_frame

	if fixture.enemy_intent != &"Recover":
		_fail("Expected round 2 enemy_intent Recover")
		return
	fixture.attack_button.pressed.emit()
	await process_frame

	if fixture.enemy_intent != &"Strike":
		_fail("Expected round 3 enemy_intent Strike")
		return
	fixture.defend_button.pressed.emit()
	await process_frame

	if fixture.enemy_intent != &"Recover":
		_fail("Expected round 4 enemy_intent Recover")
		return
	fixture.attack_button.pressed.emit()
	await process_frame

	if fixture.phase != BattleFixture.Phase.VICTORY:
		_fail("Expected VICTORY phase")
		return

	var continued_calls: Array[int] = [0]
	fixture.continued.connect(func() -> void: continued_calls[0] += 1)
	fixture.continue_button.pressed.emit()
	fixture.continue_button.pressed.emit()
	if continued_calls[0] != 1:
		_fail("Continue must emit exactly once")
		return

	for i in 5:
		await physics_frame
	await process_frame

	if battle_layer.get_child_count() != 0:
		_fail("BattleFixture was not closed")
		return
	if router.active_region != initial_region:
		_fail("Active region changed")
		return
	if player.global_position.distance_to(encounter_pos) > 1.0:
		_fail("Player position changed")
		return
	if player.input_frozen:
		_fail("Player remained frozen after continue")
		return

	for i in 5:
		await physics_frame
	await process_frame
	if battle_layer.get_child_count() != 0:
		_fail("Immediate retrigger occurred")
		return

	# Move out then reenter via physics
	player.global_position = Vector2(180, 270)
	for i in 5:
		await physics_frame
	await process_frame

	player.global_position = encounter_pos
	for i in 5:
		await physics_frame
	await process_frame

	if battle_layer.get_child_count() != 1:
		_fail("Expected fresh fixture on re-entry")
		return
	var fixture2: BattleFixture = battle_layer.get_child(0) as BattleFixture
	if fixture2.ren_pips <= 0 or fixture2.enemy_pips <= 0:
		_fail("Expected fresh initial pips")
		return
	fixture2.attack_button.pressed.emit()
	await process_frame

	if fixture2.phase != BattleFixture.Phase.DEFEAT:
		_fail("Expected DEFEAT after opening Attack")
		return
	fixture2.continue_button.pressed.emit()
	for i in 5:
		await physics_frame
	await process_frame
	if battle_layer.get_child_count() != 0 or player.input_frozen:
		_fail("Defeat continue failed to restore")
		return

	# Same-frame competition check
	var portal_beta: RegionPortal = active_region.get_node("Portals/PortalToBeta") as RegionPortal
	router.set_region_available("test_region_beta", false)
	player.global_position = encounter_pos
	encounter.body_entered.emit(player)
	router.request_transition(portal_beta, "test_region_beta", "from_alpha")
	for i in 5:
		await physics_frame
	await process_frame

	if battle_layer.get_child_count() != 1:
		_fail("Same-frame competition fixture did not open")
		return
	var fixture3: BattleFixture = battle_layer.get_child(0) as BattleFixture
	fixture3.attack_button.pressed.emit()
	await process_frame
	await process_frame

	if fixture3.phase != BattleFixture.Phase.DEFEAT:
		_fail("Expected DEFEAT after opening Attack")
		return
	fixture3.continue_button.pressed.emit()
	for i in 5:
		await physics_frame
	await process_frame
	if battle_layer.get_child_count() != 0 or player.input_frozen:
		_fail("Defeat continue failed to restore")
		return

	# Remove the trigger after acceptance but before deferred opening.
	encounter.body_entered.emit(player)
	if not player.input_frozen:
		_fail("Expected synchronous movement reservation")
		return
	encounter.queue_free()
	for i in 5:
		await physics_frame
	await process_frame
	if battle_layer.get_child_count() != 0 or player.input_frozen or router.is_transition_in_flight:
		_fail("Stale encounter did not release the reservation")
		return

	# =========================================================================
	# Part 4: Combat Item Action, Ownership Validation & Healing Cap Hardening
	# =========================================================================
	var fixture_scene: PackedScene = load("res://scenes/combat/battle_fixture.tscn")
	var item_fixture: BattleFixture = fixture_scene.instantiate() as BattleFixture
	root.add_child(item_fixture)
	await process_frame

	# 1. Reject item when 0 items owned
	if item_fixture.get_available_item_count() != 0:
		_fail("Expected 0 items available initially")
		return
	if item_fixture.request_action(&"item"):
		_fail("Item action must be rejected when 0 items owned")
		return

	# 2. Attach InventoryManager with consumable items
	var test_inv: InventoryManager = InventoryManager.new()
	test_inv.add_satchel_item("spirit_salve", 2)
	item_fixture.inventory = test_inv
	if item_fixture.get_available_item_count() != 2:
		_fail("Expected 2 spirit_salves available")
		return

	# 3. Defend against opening Strike, then use item during enemy Recover
	if item_fixture.ren_pips != 1:
		_fail("Expected ren_pips == 1 initially")
		return
	if not item_fixture.request_action(&"defend"):
		_fail("Defend action rejected")
		return
	await process_frame
	await process_frame
	if item_fixture.ren_pips != 1 or item_fixture.enemy_intent != &"Recover":
		_fail("Expected 1 pip and Recover intent after defend")
		return

	# Heal during Recover: 1 -> 2 pips, consumes 1 from inventory
	if not item_fixture.request_action(&"item"):
		_fail("Item action rejected when item owned")
		return
	if item_fixture.ren_pips != 2:
		_fail("Expected ren_pips healed to 2")
		return
	if item_fixture.get_available_item_count() != 1:
		_fail("Expected 1 spirit_salve remaining after consumption")
		return

	# Enemy recovers harmlessly, intent becomes Strike
	await process_frame
	await process_frame

	# Defend against Strike
	if not item_fixture.request_action(&"defend"):
		_fail("Second defend action rejected")
		return
	await process_frame
	await process_frame

	# 4. Use second item during Recover: heals 2 -> 3 (max_ren_pips)
	if not item_fixture.request_action(&"item"):
		_fail("Second item action rejected")
		return
	if item_fixture.ren_pips != 3:
		_fail("Expected ren_pips at max cap 3")
		return
	await process_frame
	await process_frame

	# 5. Healing Cap: When at max_ren_pips, item action must be rejected
	test_inv.add_banked_item("health_elixir", 1)
	if item_fixture.ren_pips != item_fixture.max_ren_pips:
		_fail("Expected ren_pips to equal max_ren_pips")
		return
	if item_fixture.request_action(&"item"):
		_fail("Item action must be rejected when at healing cap")
		return
	if test_inv.banked_items.get("health_elixir", 0) != 1:
		_fail("Item must not be consumed when rejected at healing cap")
		return

	# 6. Modal Hotkey Blocking
	game_root._battle = item_fixture
	if not game_root.has_blocking_modal():
		_fail("Expected has_blocking_modal() == true while BattleFixture active")
		return
	game_root._toggle_character_sheet()
	if game_root._character_sheet != null:
		_fail("Character sheet must not open over active BattleFixture")
		return
	game_root._toggle_inventory_sheet()
	if game_root._inventory_sheet != null:
		_fail("Inventory sheet must not open over active BattleFixture")
		return
	game_root._toggle_settings_sheet()
	if game_root._settings_sheet != null:
		_fail("Settings sheet must not open over active BattleFixture")
		return

	item_fixture.queue_free()
	await process_frame

	print("COMBAT TESTS PASSED")
	quit(0)
