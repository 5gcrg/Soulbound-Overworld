extends Control

const EXPECTED_BOOTSTRAP_STAGE: String = "Overworld Active"
const DEFAULT_START_REGION: String = "test_region_alpha"
const DEFAULT_START_SPAWN: String = "default"

const BATTLE_FIXTURE_SCENE: PackedScene = preload("res://scenes/combat/battle_fixture.tscn")
const QUEST_DIALOG_SCENE: PackedScene = preload("res://scenes/vertical_slice/quest_dialog.tscn")
const DUNGEON_EXPEDITION_SCENE: PackedScene = preload("res://scenes/dungeon/dungeon_expedition.tscn")
const CHARACTER_SHEET_SCENE: PackedScene = preload("res://scenes/ui/character_sheet.tscn")
const INVENTORY_SHEET_SCENE: PackedScene = preload("res://scenes/ui/inventory_sheet.tscn")
const ACADEMIC_COMPLETION_SCENE: PackedScene = preload("res://scenes/ui/academic_completion_modal.tscn")
const SETTINGS_SHEET_SCENE: PackedScene = preload("res://scenes/ui/settings_sheet.tscn")
const EVALUATOR_DEBUG_BAR_SCENE: PackedScene = preload("res://scenes/ui/evaluator_debug_bar.tscn")
const TITLE_SCREEN_SCENE: PackedScene = preload("res://scenes/ui/title_screen.tscn")

const EXPECTED_ENCOUNTER_ID: StringName = &"combat_alpha_fixture"
const EXPECTED_NPC_ID: StringName = &"quest_guide_alpha"
const EXPECTED_GATEWAY_ID: StringName = &"expedition_shrine_alpha"
const EXPECTED_ACADEMIC_PORTAL_ID: StringName = &"academic_mvp_sanctum"

var _battle: Control = null
var _battle_pending: bool = false
var _dialog: Control = null
var _dialog_pending: bool = false
var _chapter_dialog: Control = null
var _chapter_dialog_pending: bool = false
var _current_region_id: String = DEFAULT_START_REGION
var _expedition: DungeonExpedition = null
var _expedition_pending: bool = false
var _suspended_expedition: Dictionary = {}
var _character_sheet: CharacterSheet = null
var _inventory_sheet: InventorySheet = null
var _academic_modal: AcademicCompletionModal = null
var _settings_sheet: SettingsSheet = null
var _debug_bar: EvaluatorDebugBar = null
var _title_screen: TitleScreen = null
var audio_manager: AudioManager = null
var _previous_input_frozen: bool = false
var _pending_return_to_alpha: bool = false
var _chapter_baseline: String = "{}"
var _profile_slot: String = "profile_01"

var profile_store: ProfileStore = null
var slice_progress: SliceProgress = null
var dimension_manager: DimensionManager = DimensionManager.new()
var inventory_manager: InventoryManager = InventoryManager.new()
var character_stats: CharacterStats = CharacterStats.new()
var chapter_manager: ChapterManager = ChapterManager.new()
var assessment_controller: AssessmentController = AssessmentController.new()
var settings_manager: SettingsManager = SettingsManager.new()

@onready var world_container: Node2D = $WorldContainer
@onready var player: PlayerCharacter = $Player
@onready var world_router: WorldRouter = $WorldRouter
@onready var status_label: Label = $UIOverlay/VBoxContainer/StatusLabel
@onready var title_label: Label = $UIOverlay/VBoxContainer/TitleLabel
@onready var objective_label: Label = $UIOverlay/ObjectivePanel/Margin/VBox/ObjectiveLabel
@onready var _battle_layer: CanvasLayer = $BattleLayer
@onready var _dialog_layer: CanvasLayer = $DialogLayer
@onready var _expedition_layer: CanvasLayer = $ExpeditionLayer
@onready var _sheet_layer: CanvasLayer = $SheetLayer
@onready var _title_layer: CanvasLayer = $TitleLayer
@onready var _debug_layer: CanvasLayer = $DebugLayer

func _ready() -> void:
	if status_label != null:
		status_label.text = ""

	audio_manager = AudioManager.new()
	audio_manager.name = "AudioManager"
	add_child(audio_manager)

	if settings_manager != null:
		settings_manager.load_settings()
		settings_manager.settings_changed.connect(_apply_runtime_settings)
		_apply_runtime_settings()

	_init_slice_progress()
	_init_debug_bar()

	if DisplayServer.get_name() != "headless":
		open_title_screen()

	if world_router != null and world_container != null and player != null:
		world_router.setup(world_container, player)
		world_router.region_transition_completed.connect(_on_region_transition_completed)
		world_router.region_transition_failed.connect(_on_region_transition_failed)

		# Boot into starting test region
		var booted: bool = world_router.initialize_starting_region(DEFAULT_START_REGION, DEFAULT_START_SPAWN)
		if booted:
			_current_region_id = DEFAULT_START_REGION
			_bind_region_fixtures()
			_sync_chapter_gates()
			if status_label != null:
				status_label.text = EXPECTED_BOOTSTRAP_STAGE
		else:
			push_error("Failed to initialize starting region: %s at spawn %s" % [DEFAULT_START_REGION, DEFAULT_START_SPAWN])

func _init_slice_progress(store: ProfileStore = null, slot: String = "profile_01") -> void:
	_profile_slot = slot
	if store != null:
		profile_store = store
	elif profile_store == null:
		profile_store = ProfileStore.new()
	if slice_progress == null:
		slice_progress = SliceProgress.new()
	var err: Error = slice_progress.configure(profile_store, _profile_slot)
	if err != OK:
		push_warning("Failed to configure SliceProgress: %s" % error_string(err))

	character_stats = CharacterStats.new()
	inventory_manager = InventoryManager.new()
	chapter_manager = ChapterManager.new()
	assessment_controller = AssessmentController.new()
	character_stats.load_from_store(profile_store, _profile_slot)
	inventory_manager.load_from_store(profile_store, _profile_slot)
	chapter_manager.load_from_store(profile_store, _profile_slot)
	assessment_controller.load_from_store(profile_store, _profile_slot)

	_validate_and_clamp_progress()
	_sync_chapter_gates()
	_update_objective()

	var loaded := profile_store.load_profile(_profile_slot)
	_chapter_baseline = JSON.stringify(loaded.get("profile", {}).get("world", {}).get("chapter_progress", {}))

func _on_region_transition_completed(region_id: String, spawn_id: String) -> void:
	_current_region_id = region_id
	_bind_region_fixtures()
	_sync_chapter_gates()
	if audio_manager != null:
		audio_manager.play_cue("portal")
	if status_label != null:
		status_label.text = "Region: %s (Spawn: %s)" % [region_id, spawn_id]

func _on_region_transition_failed(reason: String, from_id: String, to_id: String) -> void:
	if status_label != null:
		status_label.text = "Transition failed (%s): %s -> %s" % [reason, from_id, to_id]

func _bind_region_fixtures() -> void:
	_bind_combat_encounter()
	_bind_quest_npc()
	_bind_expedition_gateway()
	_bind_academic_portal()
	_bind_story_fixtures()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("shift_dimension"):
		if player != null and not player.input_frozen and world_router != null and world_router.active_region != null:
			var space: PhysicsDirectSpaceState2D = player.get_world_2d().direct_space_state if player.get_world_2d() != null else null
			var err: Error = dimension_manager.request_shift(player, space)
			if err == OK:
				dimension_manager.apply_dimension_to_region(world_router.active_region)
				if audio_manager != null:
					audio_manager.play_cue("shift")
				if status_label != null:
					var dim_name: String = "Spirit Dimension" if dimension_manager.current_dimension == DimensionManager.Dimension.SPIRIT else "Physical Dimension"
					status_label.text = "Shifted to %s" % dim_name
	elif event.is_action_pressed("toggle_character"):
		if not has_blocking_modal():
			if audio_manager != null:
				audio_manager.play_cue("button")
			_toggle_character_sheet()
	elif event.is_action_pressed("toggle_inventory"):
		if not has_blocking_modal():
			if audio_manager != null:
				audio_manager.play_cue("button")
			_toggle_inventory_sheet()
	elif event.is_action_pressed("toggle_settings"):
		if not has_blocking_modal():
			if audio_manager != null:
				audio_manager.play_cue("button")
			_toggle_settings_sheet()

func has_blocking_modal() -> bool:
	return (_battle != null and is_instance_valid(_battle)) \
		or (_dialog != null and is_instance_valid(_dialog)) \
		or (_expedition != null and is_instance_valid(_expedition)) \
		or (_academic_modal != null and is_instance_valid(_academic_modal)) \
		or (_chapter_dialog != null and is_instance_valid(_chapter_dialog)) \
		or (_title_screen != null and is_instance_valid(_title_screen)) \
		or _chapter_dialog_pending

# ==============================================================================
# Combat Encounter Binding & Handling
# ==============================================================================

func _bind_combat_encounter() -> void:
	if world_router == null or world_router.active_region == null or not is_instance_valid(world_router.active_region):
		return
	var encounter: Area2D = world_router.active_region.get_node_or_null("CombatEncounter") as Area2D
	if encounter == null:
		return
	var callback: Callable = _on_encounter_body_entered.bind(encounter.get_instance_id())
	if not encounter.body_entered.is_connected(callback):
		encounter.body_entered.connect(callback)

func _on_encounter_body_entered(body: Node2D, encounter_id: int) -> void:
	if body != player or player == null:
		return
	if _battle_pending or (_battle != null and is_instance_valid(_battle)):
		return
	if _dialog_pending or (_dialog != null and is_instance_valid(_dialog)):
		return
	if _expedition_pending or (_expedition != null and is_instance_valid(_expedition)):
		return
	if world_router == null or world_router.is_transition_in_flight:
		return
	_battle_pending = true
	_previous_input_frozen = player.input_frozen
	player.input_frozen = true
	_open_combat.call_deferred(encounter_id)

func _open_combat(id: int) -> void:
	if not _try_open_combat(id):
		_restore_combat_movement()
	_battle_pending = false

func _try_open_combat(encounter_id: int) -> bool:
	var encounter: Area2D = instance_from_id(encounter_id) as Area2D
	if encounter == null or not is_instance_valid(encounter) or encounter.is_queued_for_deletion():
		return false
	if world_router == null or world_router.active_region == null or not is_instance_valid(world_router.active_region) or world_router.active_region.is_queued_for_deletion():
		return false
	if not world_router.active_region.is_ancestor_of(encounter):
		return false
	if not encounter.has_meta("encounter_id") or StringName(encounter.get_meta("encounter_id")) != EXPECTED_ENCOUNTER_ID:
		return false
	if world_router.is_transition_in_flight:
		return false
	if _battle != null and is_instance_valid(_battle):
		return false
	if player == null or _battle_layer == null:
		return false

	var instance: BattleFixture = BATTLE_FIXTURE_SCENE.instantiate() as BattleFixture
	if instance == null:
		return false
	instance.inventory = inventory_manager
	instance.action_performed.connect(_on_combat_action_performed)
	_battle = instance
	player.freeze_movement()
	if not _battle.is_connected("continued", _close_combat):
		_battle.connect("continued", _close_combat, CONNECT_ONE_SHOT)
	_battle_layer.add_child(_battle)
	return true

func _restore_combat_movement() -> void:
	if player != null and is_instance_valid(player):
		player.input_frozen = false

func _close_combat() -> void:
	var won: bool = false
	if _battle != null and is_instance_valid(_battle) and _battle is BattleFixture:
		won = (_battle.phase == BattleFixture.Phase.VICTORY)
	_restore_combat_movement()
	if _battle != null and is_instance_valid(_battle):
		_battle.hide()
		_battle.queue_free()
	_battle = null

	if won and slice_progress != null and slice_progress.stage == SliceProgress.Stage.BATTLE:
		var err: Error = slice_progress.record_victory()
		if err == OK:
			if status_label != null:
				status_label.text = "Victory! Return to Spirit Guide to turn in quest"
			_update_objective()

func _on_combat_action_performed(act: StringName) -> void:
	if audio_manager == null:
		return
	match act:
		&"attack":
			audio_manager.play_cue("strike")
		&"defend":
			audio_manager.play_cue("defend")
		&"item":
			audio_manager.play_cue("heal")
		&"spell":
			audio_manager.play_cue("spell_cast")

# ==============================================================================
# Quest Guide NPC Binding & Handling
# ==============================================================================

func _bind_quest_npc() -> void:
	if world_router == null or world_router.active_region == null or not is_instance_valid(world_router.active_region):
		return
	var npc: Area2D = world_router.active_region.get_node_or_null("QuestNpc") as Area2D
	if npc == null:
		return
	var callback: Callable = _on_npc_body_entered.bind(npc.get_instance_id())
	if not npc.body_entered.is_connected(callback):
		npc.body_entered.connect(callback)

func _on_npc_body_entered(body: Node2D, npc_id: int) -> void:
	if body != player or player == null:
		return
	if _dialog_pending or (_dialog != null and is_instance_valid(_dialog)):
		return
	if _battle_pending or (_battle != null and is_instance_valid(_battle)):
		return
	if _expedition_pending or (_expedition != null and is_instance_valid(_expedition)):
		return
	if world_router == null or world_router.is_transition_in_flight:
		return
	_dialog_pending = true
	_previous_input_frozen = player.input_frozen
	player.input_frozen = true
	_open_quest_dialog.call_deferred(npc_id)

func _open_quest_dialog(id: int) -> void:
	if not _try_open_quest_dialog(id):
		_restore_combat_movement()
	_dialog_pending = false

func _try_open_quest_dialog(npc_id: int) -> bool:
	var npc: Area2D = instance_from_id(npc_id) as Area2D
	if npc == null or not is_instance_valid(npc) or npc.is_queued_for_deletion():
		return false
	if world_router == null or world_router.active_region == null or not is_instance_valid(world_router.active_region) or world_router.active_region.is_queued_for_deletion():
		return false
	if not world_router.active_region.is_ancestor_of(npc):
		return false
	if not npc.has_meta("npc_id") or StringName(npc.get_meta("npc_id")) != EXPECTED_NPC_ID:
		return false
	if world_router.is_transition_in_flight:
		return false
	if _dialog != null and is_instance_valid(_dialog):
		return false
	if player == null:
		return false

	var target_layer: CanvasLayer = _dialog_layer if _dialog_layer != null else _battle_layer
	if target_layer == null:
		return false

	var instance: QuestDialog = QUEST_DIALOG_SCENE.instantiate() as QuestDialog
	if instance == null:
		return false
	_dialog = instance
	player.freeze_movement()
	instance.set_progress(slice_progress)
	instance.quest_accepted.connect(_on_quest_accepted)
	instance.practice_completed.connect(_on_practice_completed)
	instance.quest_turned_in.connect(_on_quest_turned_in)
	instance.closed.connect(_close_quest_dialog)
	target_layer.add_child(_dialog)
	return true

func _close_quest_dialog() -> void:
	_restore_combat_movement()
	if _dialog != null and is_instance_valid(_dialog):
		_dialog.hide()
		_dialog.queue_free()
	_dialog = null

func _on_quest_accepted() -> void:
	if status_label != null:
		status_label.text = "Quest Accepted: Complete Practice Task"
	_update_objective()

func _on_practice_completed(_choice: String, is_correct: bool) -> void:
	if status_label != null:
		var tag: String = "Passed" if is_correct else "Completed (Review)"
		status_label.text = "Practice %s: Proceed to Combat Field" % tag
	_update_objective()

func _on_quest_turned_in() -> void:
	if status_label != null:
		status_label.text = "Vertical Slice Complete: Record Saved!"
	_update_objective()

# ==============================================================================
# Dungeon Expedition Gateway Binding & Handling
# ==============================================================================

func _bind_expedition_gateway() -> void:
	if world_router == null or world_router.active_region == null or not is_instance_valid(world_router.active_region):
		return
	var gateway: Area2D = world_router.active_region.get_node_or_null("ExpeditionGateway") as Area2D
	if gateway == null:
		return
	var callback: Callable = _on_gateway_body_entered.bind(gateway.get_instance_id())
	if not gateway.body_entered.is_connected(callback):
		gateway.body_entered.connect(callback)

func _on_gateway_body_entered(body: Node2D, gateway_id: int) -> void:
	if body != player or player == null:
		return
	if _expedition_pending or (_expedition != null and is_instance_valid(_expedition)):
		return
	if _dialog_pending or (_dialog != null and is_instance_valid(_dialog)):
		return
	if _battle_pending or (_battle != null and is_instance_valid(_battle)):
		return
	if world_router == null or world_router.is_transition_in_flight:
		return
	_expedition_pending = true
	_previous_input_frozen = player.input_frozen
	player.input_frozen = true
	_open_expedition.call_deferred(gateway_id)

func _open_expedition(gateway_id: int) -> void:
	if not _try_open_expedition(gateway_id):
		_restore_combat_movement()
	_expedition_pending = false

func _try_open_expedition(gateway_id: int) -> bool:
	var gateway: Area2D = instance_from_id(gateway_id) as Area2D
	if gateway == null or not is_instance_valid(gateway) or gateway.is_queued_for_deletion():
		return false
	if world_router == null or world_router.active_region == null or not is_instance_valid(world_router.active_region) or world_router.active_region.is_queued_for_deletion():
		return false
	if not world_router.active_region.is_ancestor_of(gateway):
		return false
	if not gateway.has_meta("gateway_id") or StringName(gateway.get_meta("gateway_id")) != EXPECTED_GATEWAY_ID:
		return false
	if world_router.is_transition_in_flight:
		return false
	if _expedition != null and is_instance_valid(_expedition):
		return false
	if player == null:
		return false

	var target_layer: CanvasLayer = _expedition_layer if _expedition_layer != null else _battle_layer
	if target_layer == null:
		return false

	var instance: DungeonExpedition = DUNGEON_EXPEDITION_SCENE.instantiate() as DungeonExpedition
	if instance == null:
		return false
	_expedition = instance
	player.freeze_movement()
	instance.inventory = inventory_manager
	instance.commit_extraction = _commit_extraction
	instance.expedition_completed.connect(_on_expedition_completed)
	instance.expedition_failed.connect(_on_expedition_failed)
	instance.expedition_cancelled.connect(_on_expedition_cancelled)
	instance.expedition_suspended.connect(_on_expedition_suspended)
	target_layer.add_child(_expedition)
	if not _suspended_expedition.is_empty() and _suspended_expedition.get("is_active", false):
		instance.restore_expedition(_suspended_expedition)
		if status_label != null:
			status_label.text = "Expedition resumed at chamber %d: Reach Extraction Portal" % (instance.current_step + 1)
	else:
		instance.setup(1337, 6)
		if status_label != null:
			status_label.text = "Expedition active: Reach Extraction Portal"
	return true

func _commit_extraction(candidate: InventoryManager) -> Error:
	if profile_store == null or candidate == null:
		return ERR_UNCONFIGURED
	var err: Error = candidate.save_to_store(profile_store, _profile_slot)
	if err == OK:
		inventory_manager.load_from_store(profile_store, _profile_slot)
	return err

func _on_expedition_completed(extracted_items: Dictionary) -> void:
	_suspended_expedition.clear()
	if status_label != null:
		status_label.text = "Expedition Cleared! Extracted %d item types to Bank." % extracted_items.size()
	_close_expedition()

func _on_expedition_failed(lost_items: Dictionary) -> void:
	_suspended_expedition.clear()
	if profile_store != null:
		inventory_manager.save_to_store(profile_store, _profile_slot)
	if status_label != null:
		status_label.text = "Expedition Defeat! Satchel lost (%d items); bank secured." % lost_items.size()
	_close_expedition()

func _on_expedition_cancelled() -> void:
	if status_label != null:
		status_label.text = "Expedition cancelled. Returned to overworld."
	_close_expedition()

func _on_expedition_suspended(state: Dictionary) -> void:
	_suspended_expedition = state.duplicate(true)
	if status_label != null:
		status_label.text = "Expedition suspended. Satchel preserved."
	_close_expedition()

func _close_expedition() -> void:
	if player != null and is_instance_valid(player):
		player.position = Vector2(600, 220)
	_restore_combat_movement()
	if _expedition != null and is_instance_valid(_expedition):
		_expedition.queue_free()
	_expedition = null

# ==============================================================================
# UI Sheet Toggling (Character & Inventory)
# ==============================================================================

func _toggle_character_sheet() -> void:
	if has_blocking_modal():
		return
	if _pending_return_to_alpha:
		if _settings_sheet != null:
			_close_settings_sheet()
		return

	if _character_sheet != null and is_instance_valid(_character_sheet):
		_close_character_sheet()
		return

	if _inventory_sheet != null and is_instance_valid(_inventory_sheet):
		_close_inventory_sheet()
	if _settings_sheet != null and is_instance_valid(_settings_sheet):
		_close_settings_sheet()

	var target_layer: CanvasLayer = _sheet_layer if _sheet_layer != null else _dialog_layer
	if target_layer == null:
		return

	_previous_input_frozen = player.input_frozen if player != null else false
	if player != null:
		player.freeze_movement()

	var sheet: CharacterSheet = CHARACTER_SHEET_SCENE.instantiate() as CharacterSheet
	if sheet == null:
		return
	_character_sheet = sheet
	sheet.set_stats(character_stats)
	sheet.closed.connect(_close_character_sheet)
	target_layer.add_child(sheet)

func _close_character_sheet() -> void:
	if _character_sheet != null and is_instance_valid(_character_sheet):
		_character_sheet.closed.disconnect(_close_character_sheet)
		_character_sheet.queue_free()
		_character_sheet = null

	if profile_store != null:
		character_stats.save_to_store(profile_store, _profile_slot)

	if _inventory_sheet == null and _settings_sheet == null and _battle == null and _dialog == null and _expedition == null and _academic_modal == null and _chapter_dialog == null:
		_restore_combat_movement()

func _toggle_inventory_sheet() -> void:
	if has_blocking_modal():
		return
	if _pending_return_to_alpha:
		if _settings_sheet != null:
			_close_settings_sheet()
		return

	if _inventory_sheet != null and is_instance_valid(_inventory_sheet):
		_close_inventory_sheet()
		return

	if _character_sheet != null and is_instance_valid(_character_sheet):
		_close_character_sheet()
	if _settings_sheet != null and is_instance_valid(_settings_sheet):
		_close_settings_sheet()

	var target_layer: CanvasLayer = _sheet_layer if _sheet_layer != null else _dialog_layer
	if target_layer == null:
		return

	_previous_input_frozen = player.input_frozen if player != null else false
	if player != null:
		player.freeze_movement()

	var sheet: InventorySheet = INVENTORY_SHEET_SCENE.instantiate() as InventorySheet
	if sheet == null:
		return
	_inventory_sheet = sheet
	sheet.set_inventory(inventory_manager)
	sheet.equipment_changed.connect(_on_equipment_changed)
	sheet.closed.connect(_close_inventory_sheet)
	target_layer.add_child(sheet)

func _close_inventory_sheet() -> void:
	if _inventory_sheet != null and is_instance_valid(_inventory_sheet):
		if _inventory_sheet.equipment_changed.is_connected(_on_equipment_changed):
			_inventory_sheet.equipment_changed.disconnect(_on_equipment_changed)
		_inventory_sheet.closed.disconnect(_close_inventory_sheet)
		_inventory_sheet.queue_free()
		_inventory_sheet = null

	if profile_store != null:
		inventory_manager.save_to_store(profile_store, _profile_slot)

	if _character_sheet == null and _settings_sheet == null and _battle == null and _dialog == null and _expedition == null and _academic_modal == null and _chapter_dialog == null:
		_restore_combat_movement()

func _on_equipment_changed(_slot: StringName, _item_id: String) -> void:
	if profile_store != null:
		inventory_manager.save_to_store(profile_store, _profile_slot)

func _toggle_settings_sheet() -> void:
	if has_blocking_modal():
		return
	if _pending_return_to_alpha:
		if _settings_sheet != null:
			_close_settings_sheet()
		return

	if _settings_sheet != null and is_instance_valid(_settings_sheet):
		_close_settings_sheet()
		return

	if _character_sheet != null and is_instance_valid(_character_sheet):
		_close_character_sheet()
	if _inventory_sheet != null and is_instance_valid(_inventory_sheet):
		_close_inventory_sheet()

	var target_layer: CanvasLayer = _sheet_layer if _sheet_layer != null else _dialog_layer
	if target_layer == null:
		return

	_previous_input_frozen = player.input_frozen if player != null else false
	if player != null:
		player.freeze_movement()

	var sheet: SettingsSheet = SETTINGS_SHEET_SCENE.instantiate() as SettingsSheet
	if sheet == null:
		return
	_settings_sheet = sheet
	sheet.set_settings(settings_manager)
	sheet.set_profile_context(profile_store, _profile_slot)
	sheet.backup_imported.connect(_reload_imported_profile)
	sheet.closed.connect(_close_settings_sheet)
	target_layer.add_child(sheet)

func _close_settings_sheet() -> void:
	if _settings_sheet != null and is_instance_valid(_settings_sheet):
		if _settings_sheet.backup_imported.is_connected(_reload_imported_profile):
			_settings_sheet.backup_imported.disconnect(_reload_imported_profile)
		_settings_sheet.closed.disconnect(_close_settings_sheet)
		_settings_sheet.queue_free()
		_settings_sheet = null

	if settings_manager != null:
		settings_manager.save_settings()

	if _pending_return_to_alpha:
		_defer_return_to_alpha.call_deferred()

	if _character_sheet == null and _inventory_sheet == null and _battle == null and _dialog == null and _expedition == null and _academic_modal == null and _chapter_dialog == null:
		_restore_combat_movement()

func _apply_runtime_settings() -> void:
	if settings_manager == null:
		return
	settings_manager.apply_all_settings()
	if world_container != null:
		if settings_manager.high_contrast:
			world_container.modulate = Color(1.15, 1.15, 1.15, 1.0)
		else:
			world_container.modulate = Color(1.0, 1.0, 1.0, 1.0)

func _reload_imported_profile() -> void:
	_init_slice_progress(profile_store, _profile_slot)
	_pending_return_to_alpha = _is_current_location_locked()

func _defer_return_to_alpha() -> void:
	if not _is_current_location_locked():
		_pending_return_to_alpha = false
		return
	if world_router.active_region == null:
		return
	for child in world_router.active_region.portals_container.get_children():
		var portal := child as RegionPortal
		if portal != null:
			world_router.request_transition(portal, DEFAULT_START_REGION, DEFAULT_START_SPAWN)
			if world_router.is_transition_in_flight:
				_pending_return_to_alpha = false
			return

# ==============================================================================
# Academic Completion Portal (Chapter III Sanctum)
# ==============================================================================

func _bind_academic_portal() -> void:
	if world_router == null or world_router.active_region == null or not is_instance_valid(world_router.active_region):
		return
	var portal: Area2D = world_router.active_region.get_node_or_null("AcademicPortal") as Area2D
	if portal == null:
		return
	var callback: Callable = _on_academic_portal_entered.bind(portal.get_instance_id())
	if not portal.body_entered.is_connected(callback):
		portal.body_entered.connect(callback)

func _on_academic_portal_entered(body: Node2D, portal_id: int) -> void:
	if body != player or player.input_frozen or _academic_modal != null or world_router.is_transition_in_flight:
		return
	var portal := instance_from_id(portal_id) as Area2D
	if world_router.active_region_id != chapter_manager.get_chapter_region(ChapterManager.CHAPTER_3) or portal == null or portal.is_queued_for_deletion() or portal != world_router.active_region.get_node_or_null("AcademicPortal"):
		return
	if not chapter_manager.is_academic_complete and not _can_complete_academic():
		status_label.text = "Complete the required chapter practice before entering."
		return
	player.freeze_movement()
	_open_academic_modal.call_deferred()

func _open_academic_modal() -> void:
	if _academic_modal != null:
		return
	if not chapter_manager.is_academic_complete:
		var candidate := ChapterManager.new()
		candidate.deserialize(chapter_manager.serialize())
		if not _can_complete_academic() or not candidate.try_advance_chapter(assessment_controller):
			_restore_combat_movement()
			return
		var error := _commit_chapter(candidate)
		if error != OK:
			status_label.text = "Could not save completion. Re-enter the portal to retry."
			_restore_combat_movement()
			return
	var modal := ACADEMIC_COMPLETION_SCENE.instantiate() as AcademicCompletionModal
	_academic_modal = modal
	modal.configure(chapter_manager, assessment_controller, character_stats, inventory_manager)
	modal.closed.connect(_close_academic_modal)
	_sheet_layer.add_child(modal)
	status_label.text = "Soulbound Academic MVP Cleared! Congratulations!"
	_update_objective()

func _close_academic_modal() -> void:
	_restore_combat_movement()
	if _academic_modal != null and is_instance_valid(_academic_modal):
		_academic_modal.queue_free()
	_academic_modal = null

# ==============================================================================
# Objective Tracking
# ==============================================================================

func _update_objective() -> void:
	if objective_label == null:
		return
	if chapter_manager != null and chapter_manager.is_academic_complete:
		objective_label.text = "Academic MVP Complete! Free exploration active across all chapters and modular dungeons."
		return
	if slice_progress == null or not slice_progress.ready:
		objective_label.text = "Initializing spirit resonance..."
		return
	match slice_progress.stage:
		SliceProgress.Stage.OFFERED:
			objective_label.text = "Approach the Spirit Guide (northeast) to begin trial."
		SliceProgress.Stage.PRACTICE:
			objective_label.text = "Complete the resonant practice evaluation with the Spirit Guide."
		SliceProgress.Stage.BATTLE:
			objective_label.text = "Confront and defeat the Corrupted Sentinel in south field."
		SliceProgress.Stage.TURN_IN:
			objective_label.text = "Return to the Spirit Guide to turn in your quest."
		SliceProgress.Stage.COMPLETE:
			if chapter_manager != null:
				match chapter_manager.current_chapter:
					ChapterManager.CHAPTER_1:
						objective_label.text = "Chapter I: Consult Elder Kael in Dawnreach Village."
					ChapterManager.CHAPTER_2:
						objective_label.text = "Chapter II: Use Dimension Shift [Q] to navigate Whispering Grove."
					ChapterManager.CHAPTER_3:
						objective_label.text = "Chapter III: Step into Academic Sanctum in Forgotten Shrine."
					_:
						objective_label.text = "Vertical slice trial complete. Profile safely archived."
			else:
				objective_label.text = "Vertical slice trial complete. Profile safely archived."

const CHAPTER_NPCS: Array[String] = ["ElderKael", "ScoutLyra", "AwakeningAltar"]
const SHRINE_FEEDBACK: String = "chapter_3_feedback"

func _validate_and_clamp_progress() -> void:
	var supported: int = ChapterManager.CHAPTER_1
	while supported <= ChapterManager.CHAPTER_3 and assessment_controller.is_chapter_activity_completed(supported):
		supported += 1
	chapter_manager.current_chapter = clampi(chapter_manager.current_chapter, ChapterManager.CHAPTER_1, supported)
	chapter_manager.is_academic_complete = chapter_manager.current_chapter == ChapterManager.ACADEMIC_COMPLETE
	chapter_manager.unlocked_chapters.clear()
	for chapter in range(ChapterManager.CHAPTER_1, mini(chapter_manager.current_chapter, ChapterManager.CHAPTER_3) + 1):
		chapter_manager.unlocked_chapters.append(chapter)
	if supported <= ChapterManager.CHAPTER_3:
		chapter_manager.chapter_flags.erase(SHRINE_FEEDBACK)

func _sync_chapter_gates() -> void:
	for chapter in range(ChapterManager.CHAPTER_1, ChapterManager.CHAPTER_3 + 1):
		world_router.set_region_available(chapter_manager.get_chapter_region(chapter), chapter_manager.is_chapter_unlocked(chapter))

func _is_current_location_locked() -> bool:
	return not world_router.active_region_id.is_empty() and not world_router.is_region_available(world_router.active_region_id)

func _bind_story_fixtures() -> void:
	for chapter in range(ChapterManager.CHAPTER_1, ChapterManager.CHAPTER_3 + 1):
		if world_router.active_region_id != chapter_manager.get_chapter_region(chapter):
			continue
		var npc := world_router.active_region.get_node_or_null(CHAPTER_NPCS[chapter - 1]) as Area2D
		if npc != null:
			var callback := _on_chapter_npc_entered.bind(chapter, npc.get_instance_id())
			if not npc.body_entered.is_connected(callback):
				npc.body_entered.connect(callback)

func _on_chapter_npc_entered(body: Node2D, chapter: int, npc_id: int) -> void:
	if body != player or player.input_frozen or _chapter_dialog_pending or _chapter_dialog != null or world_router.is_transition_in_flight:
		return
	if chapter_manager.current_chapter != chapter:
		return
	_chapter_dialog_pending = true
	player.freeze_movement()
	_open_chapter_dialog.call_deferred(chapter, npc_id)

func _open_chapter_dialog(chapter: int, npc_id: int) -> void:
	_chapter_dialog_pending = false
	var npc := instance_from_id(npc_id) as Area2D
	if npc == null or npc.is_queued_for_deletion() or not world_router.active_region.is_ancestor_of(npc) or chapter_manager.current_chapter != chapter:
		_restore_combat_movement()
		return
	var question_id := QuestionBank.get_required_question_id_for_chapter(chapter)
	var dialog := ChapterActivityDialog.new()
	dialog.name = "ChapterActivityDialog"
	dialog.configure(QuestionBank.get_question(question_id), assessment_controller.records.get(question_id, {}))
	dialog.answer_selected.connect(_on_chapter_answer.bind(question_id))
	dialog.feedback_acknowledged.connect(_on_chapter_feedback.bind(chapter))
	dialog.closed.connect(_close_chapter_dialog)
	_chapter_dialog = dialog
	_dialog_layer.add_child(dialog)

func _on_chapter_answer(index: int, question_id: String) -> void:
	var dialog := _chapter_dialog as ChapterActivityDialog
	var candidate := AssessmentController.new()
	var error := candidate.deserialize(assessment_controller.serialize())
	if error != OK:
		dialog.show_save_error(error)
		return
	var result := candidate.submit_answer(question_id, index)
	error = result["error"]
	if error == OK:
		error = candidate.save_to_store(profile_store, _profile_slot)
	if error != OK:
		dialog.show_save_error(error)
		return
	assessment_controller.records = candidate.records
	if audio_manager != null:
		audio_manager.play_cue("correct" if result.get("correct", false) else "wrong")
	dialog.set_feedback(result)

func _on_chapter_feedback(chapter: int) -> void:
	if chapter != chapter_manager.current_chapter or not assessment_controller.is_chapter_activity_completed(chapter):
		return
	var candidate := ChapterManager.new()
	candidate.deserialize(chapter_manager.serialize())
	if chapter == ChapterManager.CHAPTER_3:
		candidate.set_chapter_flag(SHRINE_FEEDBACK, true)
	elif not candidate.try_advance_chapter(assessment_controller):
		return
	var error := _commit_chapter(candidate)
	if error != OK:
		(_chapter_dialog as ChapterActivityDialog).show_save_error(error)
		return
	_close_chapter_dialog()

func _commit_chapter(candidate: ChapterManager) -> Error:
	var loaded := profile_store.load_profile(_profile_slot)
	if loaded["error"] != OK:
		return loaded["error"]
	var profile: Dictionary = loaded["profile"]
	if JSON.stringify(profile["world"].get("chapter_progress", {})) != _chapter_baseline:
		return ERR_BUSY
	profile["world"]["chapter_progress"] = candidate.serialize()
	var persisted := AssessmentController.new()
	var evidence_error := persisted.deserialize(profile["education"])
	if evidence_error != OK:
		return evidence_error
	var required_until := candidate.current_chapter - 1
	if candidate.get_chapter_flag(SHRINE_FEEDBACK, false) == true:
		required_until = ChapterManager.CHAPTER_3
	for chapter in range(ChapterManager.CHAPTER_1, required_until + 1):
		if not persisted.is_chapter_activity_completed(chapter):
			return ERR_BUSY
	var error := profile_store.save_profile(_profile_slot, profile)
	if error != OK:
		return error
	_chapter_baseline = JSON.stringify(JSON.parse_string(JSON.stringify(candidate.serialize())))
	chapter_manager.deserialize(candidate.serialize())
	_sync_chapter_gates()
	_update_objective()
	return OK

func _close_chapter_dialog() -> void:
	_chapter_dialog.hide()
	_chapter_dialog.queue_free()
	_chapter_dialog = null
	_restore_combat_movement()

func _can_complete_academic() -> bool:
	if chapter_manager.current_chapter != ChapterManager.CHAPTER_3 or chapter_manager.get_chapter_flag(SHRINE_FEEDBACK, false) != true:
		return false
	for chapter in range(ChapterManager.CHAPTER_1, ChapterManager.CHAPTER_3 + 1):
		if not assessment_controller.is_chapter_activity_completed(chapter):
			return false
	return true

# ==============================================================================
# Evaluator Debug Bar Integration
# ==============================================================================

func _init_debug_bar() -> void:
	if _debug_layer == null:
		return
	var bar := EVALUATOR_DEBUG_BAR_SCENE.instantiate() as EvaluatorDebugBar
	if bar == null:
		return
	_debug_bar = bar
	_debug_layer.add_child(_debug_bar)
	_debug_bar.region_warp_requested.connect(_on_debug_region_warp)
	_debug_bar.combat_requested.connect(_on_debug_combat)
	_debug_bar.dungeon_requested.connect(_on_debug_dungeon)
	_debug_bar.chapter_dialog_requested.connect(_on_debug_chapter_dialog)
	_debug_bar.academic_modal_requested.connect(_on_debug_academic_modal)
	_debug_bar.dimension_shift_requested.connect(_on_debug_dimension_shift)
	_debug_bar.grant_items_requested.connect(_on_debug_grant_items)
	_debug_bar.complete_activities_requested.connect(_on_debug_complete_activities)
	_debug_bar.max_stats_requested.connect(_on_debug_max_stats)
	_debug_bar.title_screen_requested.connect(open_title_screen)
	_sync_debug_bar()

func _sync_debug_bar() -> void:
	if _debug_bar == null:
		return
	var dim_str: String = "Spirit" if dimension_manager != null and dimension_manager.current_dimension == DimensionManager.Dimension.SPIRIT else "Physical"
	var max_hp_val: int = character_stats.get_max_hp() if character_stats != null else 100
	_debug_bar.update_status({
		"region": _current_region_id,
		"dimension": dim_str,
		"chapter": chapter_manager.current_chapter if chapter_manager != null else 1,
		"level": character_stats.level if character_stats != null else 1,
		"hp": max_hp_val,
		"max_hp": max_hp_val,
		"pips": 3,
		"max_pips": 3
	})

func _on_debug_region_warp(region_id: String) -> void:
	if has_blocking_modal():
		return
	if world_router != null:
		world_router.debug_warp(region_id, "default")
		_sync_debug_bar()

func _on_debug_combat() -> void:
	if has_blocking_modal():
		return
	var instance: BattleFixture = BATTLE_FIXTURE_SCENE.instantiate() as BattleFixture
	if instance == null:
		return
	instance.inventory = inventory_manager
	instance.action_performed.connect(_on_combat_action_performed)
	_battle = instance
	if player != null:
		player.freeze_movement()
	if not _battle.is_connected("continued", _close_combat):
		_battle.connect("continued", _close_combat, CONNECT_ONE_SHOT)
	_battle_layer.add_child(_battle)

func _on_debug_dungeon() -> void:
	if has_blocking_modal():
		return
	var target_layer: CanvasLayer = _expedition_layer if _expedition_layer != null else _battle_layer
	if target_layer == null:
		return
	var instance: DungeonExpedition = DUNGEON_EXPEDITION_SCENE.instantiate() as DungeonExpedition
	if instance == null:
		return
	_expedition = instance
	if player != null:
		player.freeze_movement()
	instance.inventory = inventory_manager
	instance.commit_extraction = _commit_extraction
	instance.expedition_completed.connect(_on_expedition_completed)
	instance.expedition_failed.connect(_on_expedition_failed)
	instance.expedition_cancelled.connect(_on_expedition_cancelled)
	instance.expedition_suspended.connect(_on_expedition_suspended)
	target_layer.add_child(_expedition)
	instance.setup(1337, 6)

func _on_debug_chapter_dialog() -> void:
	if has_blocking_modal():
		return
	var q_id := QuestionBank.get_required_question_id_for_chapter(chapter_manager.current_chapter)
	var dialog := ChapterActivityDialog.new()
	dialog.name = "ChapterActivityDialog"
	dialog.configure(QuestionBank.get_question(q_id), assessment_controller.records.get(q_id, {}))
	dialog.answer_selected.connect(_on_chapter_answer.bind(q_id))
	dialog.feedback_acknowledged.connect(_on_chapter_feedback.bind(chapter_manager.current_chapter))
	dialog.closed.connect(_close_chapter_dialog)
	_chapter_dialog = dialog
	if player != null:
		player.freeze_movement()
	_dialog_layer.add_child(dialog)

func _on_debug_academic_modal() -> void:
	if _academic_modal != null:
		return
	var modal := ACADEMIC_COMPLETION_SCENE.instantiate() as AcademicCompletionModal
	_academic_modal = modal
	modal.configure(chapter_manager, assessment_controller, character_stats, inventory_manager)
	modal.closed.connect(_close_academic_modal)
	_sheet_layer.add_child(modal)
	if player != null:
		player.freeze_movement()

func _on_debug_dimension_shift() -> void:
	if player != null and world_router != null and world_router.active_region != null:
		var space: PhysicsDirectSpaceState2D = player.get_world_2d().direct_space_state if player.get_world_2d() != null else null
		var err: Error = dimension_manager.request_shift(player, space)
		if err == OK:
			dimension_manager.apply_dimension_to_region(world_router.active_region)
			_sync_debug_bar()

func _on_debug_grant_items() -> void:
	if inventory_manager != null:
		inventory_manager.add_banked_item("spirit_salve", 5)
		inventory_manager.add_banked_item("health_elixir", 5)
		inventory_manager.add_banked_item("iron_sword", 1)
		inventory_manager.add_banked_item("iron_armor", 1)
		inventory_manager.add_banked_item("flame_relic", 1)
		inventory_manager.add_banked_item("void_key", 1)
		if profile_store != null:
			inventory_manager.save_to_store(profile_store, _profile_slot)
	if status_label != null:
		status_label.text = "[Evaluator] Granted full equipment set & consumables."

func _on_debug_complete_activities() -> void:
	for ch in [1, 2, 3]:
		var q_id := QuestionBank.get_required_question_id_for_chapter(ch)
		var q: Dictionary = QuestionBank.get_question(q_id)
		if not q.is_empty():
			assessment_controller.submit_answer(q_id, int(q["correct_index"]))
	if profile_store != null:
		assessment_controller.save_to_store(profile_store, _profile_slot)
	chapter_manager.current_chapter = ChapterManager.CHAPTER_3
	chapter_manager.set_chapter_flag(SHRINE_FEEDBACK, true)
	if not chapter_manager.unlocked_chapters.has(ChapterManager.CHAPTER_2):
		chapter_manager.unlocked_chapters.append(ChapterManager.CHAPTER_2)
	if not chapter_manager.unlocked_chapters.has(ChapterManager.CHAPTER_3):
		chapter_manager.unlocked_chapters.append(ChapterManager.CHAPTER_3)
	if profile_store != null:
		chapter_manager.save_to_store(profile_store, _profile_slot)
	_sync_chapter_gates()
	_update_objective()
	_sync_debug_bar()
	if status_label != null:
		status_label.text = "[Evaluator] Completed Chapters 1-3 activities. Sanctum portal active!"

func _on_debug_max_stats() -> void:
	if character_stats != null:
		character_stats.level = 10
		character_stats.vitality = 25
		character_stats.resonance = 25
		character_stats.agility = 25
		character_stats.focus = 25
		if profile_store != null:
			character_stats.save_to_store(profile_store, _profile_slot)
		_sync_debug_bar()
	if status_label != null:
		status_label.text = "[Evaluator] Maximized Ren stats (Lvl 10, HP %d, Attributes 25)." % character_stats.get_max_hp()

# ==============================================================================
# Title Screen Management
# ==============================================================================

func open_title_screen() -> void:
	if _title_screen != null and is_instance_valid(_title_screen):
		return
	if _title_layer == null:
		return
	var title_inst: TitleScreen = TITLE_SCREEN_SCENE.instantiate() as TitleScreen
	if title_inst == null:
		return
	_title_screen = title_inst
	_title_layer.add_child(_title_screen)
	_title_screen.setup_profiles(profile_store, _profile_slot)
	_title_screen.game_started.connect(_on_title_game_started)
	_title_screen.settings_requested.connect(_toggle_settings_sheet)
	_title_screen.backup_requested.connect(_on_title_backup_requested)
	_title_screen.defense_demo_requested.connect(_on_title_defense_demo)
	if player != null:
		player.freeze_movement()

func _close_title_screen() -> void:
	if _title_screen != null and is_instance_valid(_title_screen):
		_title_screen.queue_free()
		_title_screen = null
	if not has_blocking_modal():
		_restore_combat_movement()

func _on_title_game_started(slot_id: String) -> void:
	_init_slice_progress(profile_store, slot_id)
	_close_title_screen()
	if audio_manager != null:
		audio_manager.play_cue("portal")

func _on_title_backup_requested() -> void:
	_toggle_settings_sheet()

func _on_title_defense_demo() -> void:
	_on_debug_complete_activities()
	_on_debug_grant_items()
	_on_debug_max_stats()
	_close_title_screen()
	if audio_manager != null:
		audio_manager.play_cue("correct")
