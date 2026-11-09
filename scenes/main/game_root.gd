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

const EXPECTED_ENCOUNTER_ID: StringName = &"combat_alpha_fixture"
const EXPECTED_NPC_ID: StringName = &"quest_guide_alpha"
const EXPECTED_GATEWAY_ID: StringName = &"expedition_shrine_alpha"
const EXPECTED_ACADEMIC_PORTAL_ID: StringName = &"academic_mvp_sanctum"

var _battle: Control = null
var _battle_pending: bool = false
var _dialog: Control = null
var _dialog_pending: bool = false
var _expedition: DungeonExpedition = null
var _expedition_pending: bool = false
var _character_sheet: CharacterSheet = null
var _inventory_sheet: InventorySheet = null
var _academic_modal: AcademicCompletionModal = null
var _settings_sheet: SettingsSheet = null
var _previous_input_frozen: bool = false

var profile_store: ProfileStore = null
var _profile_slot: String = "profile_01"
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

func _ready() -> void:
	if status_label != null:
		status_label.text = ""

	if settings_manager != null:
		settings_manager.load_settings()

	_init_slice_progress()

	if world_router != null and world_container != null and player != null:
		world_router.setup(world_container, player)
		world_router.region_transition_completed.connect(_on_region_transition_completed)
		world_router.region_transition_failed.connect(_on_region_transition_failed)

		# Boot into starting test region
		var booted: bool = world_router.initialize_starting_region(DEFAULT_START_REGION, DEFAULT_START_SPAWN)
		if booted:
			_bind_region_fixtures()
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
	var err: Error = slice_progress.configure(profile_store, slot)
	if err != OK:
		push_warning("Failed to configure SliceProgress: %s" % error_string(err))

	character_stats = CharacterStats.new()
	inventory_manager = InventoryManager.new()
	chapter_manager = ChapterManager.new()
	assessment_controller = AssessmentController.new()
	character_stats.load_from_store(profile_store, slot)
	inventory_manager.load_from_store(profile_store, slot)
	chapter_manager.load_from_store(profile_store, slot)
	assessment_controller.load_from_store(profile_store, slot)

	_update_objective()

func _on_region_transition_completed(region_id: String, spawn_id: String) -> void:
	_bind_region_fixtures()
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

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("shift_dimension"):
		if player != null and not player.input_frozen and world_router != null and world_router.active_region != null:
			var space: PhysicsDirectSpaceState2D = player.get_world_2d().direct_space_state if player.get_world_2d() != null else null
			var err: Error = dimension_manager.request_shift(player, space)
			if err == OK:
				dimension_manager.apply_dimension_to_region(world_router.active_region)
				if status_label != null:
					var dim_name: String = "Spirit Dimension" if dimension_manager.current_dimension == DimensionManager.Dimension.SPIRIT else "Physical Dimension"
					status_label.text = "Shifted to %s" % dim_name
	elif event.is_action_pressed("toggle_character"):
		_toggle_character_sheet()
	elif event.is_action_pressed("toggle_inventory"):
		_toggle_inventory_sheet()
	elif event.is_action_pressed("toggle_settings"):
		_toggle_settings_sheet()

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

	var instance: Control = BATTLE_FIXTURE_SCENE.instantiate() as Control
	if instance == null:
		return false
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
	instance.expedition_completed.connect(_on_expedition_completed)
	instance.expedition_failed.connect(_on_expedition_failed)
	instance.expedition_cancelled.connect(_on_expedition_cancelled)
	instance.commit_extraction = _commit_extraction
	target_layer.add_child(_expedition)
	instance.setup(1337, 6)
	if status_label != null:
		status_label.text = "Expedition active: Reach Extraction Portal"
	return true

func _commit_extraction(candidate: InventoryManager) -> Error:
	if profile_store == null:
		return ERR_UNCONFIGURED
	return candidate.save_to_store(profile_store, _profile_slot)

func _on_expedition_completed(extracted_items: Dictionary) -> void:
	if status_label != null:
		status_label.text = "Expedition Cleared! Extracted %d item types to Bank." % extracted_items.size()
	_close_expedition()

func _on_expedition_failed(lost_items: Dictionary) -> void:
	if profile_store != null:
		inventory_manager.save_to_store(profile_store, "profile_01")
	if status_label != null:
		status_label.text = "Expedition Defeat! Satchel lost (%d items); bank secured." % lost_items.size()
	_close_expedition()

func _on_expedition_cancelled() -> void:
	if status_label != null:
		status_label.text = "Expedition cancelled. Returned to overworld."
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
	if _character_sheet != null and is_instance_valid(_character_sheet):
		_close_character_sheet()
		return

	if _inventory_sheet != null and is_instance_valid(_inventory_sheet):
		_close_inventory_sheet()
	if _settings_sheet != null and is_instance_valid(_settings_sheet):
		_close_settings_sheet()

	if _battle != null or _dialog != null or _expedition != null:
		return

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
		character_stats.save_to_store(profile_store, "profile_01")

	if _inventory_sheet == null and _settings_sheet == null and _battle == null and _dialog == null and _expedition == null and _academic_modal == null:
		_restore_combat_movement()

func _toggle_inventory_sheet() -> void:
	if _inventory_sheet != null and is_instance_valid(_inventory_sheet):
		_close_inventory_sheet()
		return

	if _character_sheet != null and is_instance_valid(_character_sheet):
		_close_character_sheet()
	if _settings_sheet != null and is_instance_valid(_settings_sheet):
		_close_settings_sheet()

	if _battle != null or _dialog != null or _expedition != null:
		return

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
	sheet.closed.connect(_close_inventory_sheet)
	target_layer.add_child(sheet)

func _close_inventory_sheet() -> void:
	if _inventory_sheet != null and is_instance_valid(_inventory_sheet):
		_inventory_sheet.closed.disconnect(_close_inventory_sheet)
		_inventory_sheet.queue_free()
		_inventory_sheet = null

	if profile_store != null:
		inventory_manager.save_to_store(profile_store, "profile_01")

	if _character_sheet == null and _settings_sheet == null and _battle == null and _dialog == null and _expedition == null and _academic_modal == null:
		_restore_combat_movement()

func _toggle_settings_sheet() -> void:
	if _settings_sheet != null and is_instance_valid(_settings_sheet):
		_close_settings_sheet()
		return

	if _character_sheet != null and is_instance_valid(_character_sheet):
		_close_character_sheet()
	if _inventory_sheet != null and is_instance_valid(_inventory_sheet):
		_close_inventory_sheet()

	if _battle != null or _dialog != null or _expedition != null:
		return

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
		_settings_sheet.closed.disconnect(_close_settings_sheet)
		_settings_sheet.queue_free()
		_settings_sheet = null

	if settings_manager != null:
		settings_manager.save_settings()

	if _character_sheet == null and _inventory_sheet == null and _battle == null and _dialog == null and _expedition == null and _academic_modal == null:
		_restore_combat_movement()

func _reload_imported_profile() -> void:
	_init_slice_progress(profile_store, _profile_slot)

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

func _on_academic_portal_entered(body: Node2D, _portal_id: int) -> void:
	if body != player or player == null:
		return
	if _academic_modal != null and is_instance_valid(_academic_modal):
		return
	if _expedition != null or _dialog != null or _battle != null:
		return
	_open_academic_modal()

func _open_academic_modal() -> void:
	if player != null:
		player.freeze_movement()
	var target_layer: CanvasLayer = _sheet_layer if _sheet_layer != null else _dialog_layer
	if target_layer == null:
		return

	chapter_manager.current_chapter = ChapterManager.ACADEMIC_COMPLETE
	chapter_manager.is_academic_complete = true
	if profile_store != null:
		chapter_manager.save_to_store(profile_store, "profile_01")
		assessment_controller.save_to_store(profile_store, "profile_01")

	var modal: AcademicCompletionModal = ACADEMIC_COMPLETION_SCENE.instantiate() as AcademicCompletionModal
	if modal == null:
		return
	_academic_modal = modal
	modal.configure(chapter_manager, assessment_controller, character_stats, inventory_manager)
	modal.closed.connect(_close_academic_modal)
	target_layer.add_child(modal)

	if status_label != null:
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
