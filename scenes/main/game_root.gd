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
const ENDING_MODAL_SCENE: PackedScene = preload("res://scenes/ui/ending_modal.tscn")
const BOSS_ENCOUNTER_SCENE: PackedScene = preload("res://scenes/combat/boss_encounter.tscn")

const EXPECTED_ENCOUNTER_ID: StringName = &"combat_alpha_fixture"
const EXPECTED_NPC_ID: StringName = &"quest_guide_alpha"
const EXPECTED_GATEWAY_ID: StringName = &"expedition_shrine_alpha"
const EXPECTED_ACADEMIC_PORTAL_ID: StringName = &"academic_mvp_sanctum"
const ACTIVE_EXPEDITION_KEY: String = "active_expedition"

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
var _ending_modal: EndingModal = null
var _boss_encounter: BossEncounter = null
var _settings_sheet: SettingsSheet = null
var _title_settings_sheet: SettingsSheet = null
var _debug_bar: EvaluatorDebugBar = null
var _title_screen: TitleScreen = null
var audio_manager: AudioManager = null
var _previous_input_frozen: bool = false
var _pending_return_to_alpha: bool = false
var _chapter_baseline: String = "{}"
var _profile_slot: String = "profile_01"
var _session_generation: int = 0

var profile_store: ProfileStore = null
var slice_progress: SliceProgress = null
var dimension_manager: DimensionManager = DimensionManager.new()
var inventory_manager: InventoryManager = InventoryManager.new()
var character_stats: CharacterStats = CharacterStats.new()
var chapter_manager: ChapterManager = ChapterManager.new()
var assessment_controller: AssessmentController = AssessmentController.new()
var settings_manager: SettingsManager = SettingsManager.new()
var ending_manager: EndingManager = EndingManager.new()
var kurei_tree: KureiTree = KureiTree.new()

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
@onready var _title_overlay_layer: CanvasLayer = $TitleOverlayLayer
@onready var _debug_layer: CanvasLayer = $DebugLayer

func _ready() -> void:
	if status_label != null:
		status_label.text = ""

	AudioManager.ensure_audio_buses()

	audio_manager = AudioManager.new()
	audio_manager.name = "AudioManager"
	add_child(audio_manager)

	if settings_manager != null:
		settings_manager.load_settings()
		settings_manager.settings_changed.connect(_apply_runtime_settings)
		get_tree().node_added.connect(_on_ui_node_added)
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
	if _expedition != null and is_instance_valid(_expedition) and _expedition.is_active:
		if slot != _profile_slot:
			push_error("Cannot switch profile while an expedition is active. Suspend or retreat first.")
			return
	_session_generation += 1
	_suspended_expedition.clear()
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

	kurei_tree = KureiTree.new()
	kurei_tree.load_from_store(profile_store, _profile_slot)
	kurei_tree.sync_with_level(character_stats.level)

	var loaded := profile_store.load_profile(_profile_slot)
	var prof_dict: Dictionary = loaded.get("profile", {})
	if prof_dict.has("world") and prof_dict["world"] is Dictionary and prof_dict["world"].has("ending"):
		ending_manager.deserialize(prof_dict["world"]["ending"])
	else:
		ending_manager = EndingManager.new()

	_validate_and_clamp_progress()
	_sync_chapter_gates()
	_update_objective()

	_chapter_baseline = JSON.stringify(prof_dict.get("world", {}).get("chapter_progress", {}))
	_load_active_expedition()

func activate_profile(slot_id: String, is_new: bool = false) -> Error:
	# 1. Reject activation during active expedition, unresolved encounter, or in-flight transition
	if _expedition != null and is_instance_valid(_expedition) and _expedition.is_active:
		push_error("Cannot switch profile while an expedition is active. Suspend or retreat first.")
		return ERR_BUSY
	if (_battle != null and is_instance_valid(_battle)) or (_boss_encounter != null and is_instance_valid(_boss_encounter)):
		push_error("Cannot switch profile while combat is active.")
		return ERR_BUSY
	if world_router != null and world_router.is_transition_in_flight:
		push_error("Cannot switch profile during region transition.")
		return ERR_BUSY

	if profile_store == null:
		profile_store = ProfileStore.new()

	# 2. Preflight profile validation
	var loaded := profile_store.load_profile(slot_id)
	if loaded.get("error") == ERR_FILE_NOT_FOUND:
		if is_new:
			var new_prof := profile_store.new_profile(slot_id)
			var save_err: Error = profile_store.save_profile(slot_id, new_prof)
			if save_err != OK:
				push_error("Cannot activate new profile '%s': save error %s" % [slot_id, error_string(save_err)])
				return save_err
			loaded = profile_store.load_profile(slot_id)
		else:
			push_error("Cannot activate profile '%s': file not found" % slot_id)
			return ERR_FILE_NOT_FOUND
	elif loaded.get("error") != OK:
		push_error("Cannot activate profile '%s': load error %s" % [slot_id, error_string(loaded.get("error"))])
		return loaded.get("error")

	var prof_dict: Dictionary = loaded.get("profile", {})
	var val_res: Variant = GameplayProfileValidator.validate(prof_dict)
	if val_res is int and (val_res as int) != OK:
		push_error("Cannot activate profile '%s': validation failed with error %s" % [slot_id, error_string(val_res as int)])
		return val_res as Error
	elif val_res is bool and not (val_res as bool):
		push_error("Cannot activate profile '%s': validation failed" % slot_id)
		return ERR_INVALID_DATA

	# 3. Preflight & reset world to DEFAULT_START_REGION and DEFAULT_START_SPAWN
	if world_router != null and world_container != null and player != null:
		var reset_ok: bool = world_router.reset_to_starting_region(DEFAULT_START_REGION, DEFAULT_START_SPAWN)
		if not reset_ok:
			push_error("Cannot activate profile '%s': world router failed to reset to starting region %s" % [slot_id, DEFAULT_START_REGION])
			return ERR_CANT_CREATE
		_current_region_id = DEFAULT_START_REGION

	# 4. Set physical dimension and synchronize collision masks and region visibility
	if dimension_manager != null:
		dimension_manager.current_dimension = DimensionManager.Dimension.PHYSICAL
		_sync_dimension_state()

	# 5. Invalidate previous session callbacks, reset transient state & player velocity
	_battle_pending = false
	_dialog_pending = false
	_chapter_dialog_pending = false
	_expedition_pending = false
	_pending_return_to_alpha = false

	if player != null and is_instance_valid(player):
		player.velocity = Vector2.ZERO
		if _title_screen != null and is_instance_valid(_title_screen):
			player.freeze_movement()

	# 6. Load selected profile's consumers
	_init_slice_progress(profile_store, slot_id)
	_bind_region_fixtures()
	_sync_chapter_gates()
	_update_objective()
	_sync_debug_bar()

	return OK

func _on_region_transition_completed(region_id: String, spawn_id: String) -> void:
	_current_region_id = region_id
	_bind_region_fixtures()
	_sync_chapter_gates()
	_sync_dimension_state()
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
	_bind_ending_altars()
	_bind_boss_encounter()

func _unhandled_input(event: InputEvent) -> void:
	if InputBindings.is_capture_active():
		return
	if event.is_action_pressed("shift_dimension"):
		if player != null and not player.input_frozen and not has_blocking_modal() \
				and world_router != null and world_router.active_region != null \
				and not world_router.is_transition_in_flight:
			var space: PhysicsDirectSpaceState2D = player.get_world_2d().direct_space_state if player.get_world_2d() != null else null
			var err: Error = dimension_manager.request_shift(player, space)
			if err == OK:
				_sync_dimension_state()
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

## Re-applies the active dimension to the live region and player after a shift or travel.
func _sync_dimension_state() -> void:
	if dimension_manager == null:
		return
	if player != null and is_instance_valid(player):
		dimension_manager.apply_player_collision(player)
	if world_router != null and world_router.active_region != null and is_instance_valid(world_router.active_region):
		dimension_manager.apply_dimension_to_region(world_router.active_region)

func has_blocking_modal() -> bool:
	return (_battle != null and is_instance_valid(_battle)) \
		or (_boss_encounter != null and is_instance_valid(_boss_encounter)) \
		or (_dialog != null and is_instance_valid(_dialog)) \
		or (_expedition != null and is_instance_valid(_expedition)) \
		or (_academic_modal != null and is_instance_valid(_academic_modal)) \
		or (_ending_modal != null and is_instance_valid(_ending_modal)) \
		or (_chapter_dialog != null and is_instance_valid(_chapter_dialog)) \
		or (_title_screen != null and is_instance_valid(_title_screen)) \
		or (_title_settings_sheet != null and is_instance_valid(_title_settings_sheet)) \
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
	instance.kurei_tree = kurei_tree
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
# Boss Encounter Binding & Handling (Void Sovereign Apex Climax)
# ==============================================================================

func _bind_boss_encounter() -> void:
	if not ReleaseTier.is_full_release():
		return
	if world_router == null or world_router.active_region == null or not is_instance_valid(world_router.active_region):
		return
	var trigger: Area2D = world_router.active_region.get_node_or_null("CitadelBossTrigger") as Area2D
	if trigger == null:
		return
	var callback: Callable = _on_boss_trigger_entered.bind(trigger.get_instance_id())
	if not trigger.body_entered.is_connected(callback):
		trigger.body_entered.connect(callback)

func _on_boss_trigger_entered(body: Node2D, _trigger_id: int) -> void:
	if body != player or player == null or player.input_frozen:
		return
	if has_blocking_modal():
		return
	open_boss_encounter()

func open_boss_encounter() -> void:
	if not ReleaseTier.is_full_release():
		return
	if _boss_encounter != null and is_instance_valid(_boss_encounter):
		return
	if has_blocking_modal():
		return
	if _battle_layer == null:
		return
	if player != null:
		player.freeze_movement()

	var inst: BossEncounter = BOSS_ENCOUNTER_SCENE.instantiate() as BossEncounter
	if inst == null:
		_restore_combat_movement()
		return

	_boss_encounter = inst
	inst.inventory = inventory_manager
	inst.kurei_tree = kurei_tree
	inst.action_performed.connect(_on_combat_action_performed)
	inst.boss_defeated.connect(_on_boss_defeated)
	inst.continued.connect(_close_boss_encounter)
	_battle_layer.add_child(inst)

	if status_label != null:
		status_label.text = "Apex Encounter: Void Sovereign engaged!"

func _on_boss_defeated(rewards: Dictionary) -> void:
	if audio_manager != null:
		audio_manager.play_cue("correct")
	if profile_store != null:
		inventory_manager.save_to_store(profile_store, _profile_slot)
	if status_label != null:
		status_label.text = "Void Sovereign defeated! Sovereign Core and Void Crown acquired."

func _close_boss_encounter() -> void:
	if _boss_encounter != null and is_instance_valid(_boss_encounter):
		_boss_encounter.hide()
		_boss_encounter.queue_free()
		_boss_encounter = null
	if not has_blocking_modal():
		_restore_combat_movement()

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
	var bound_slot: String = _profile_slot
	var bound_gen: int = _session_generation
	var instance_id: int = instance.get_instance_id()
	instance.inventory = inventory_manager
	instance.commit_extraction = func(candidate: InventoryManager) -> Error:
		return _commit_extraction_guarded(candidate, instance_id, bound_slot, bound_gen)
	instance.commit_defeat = func(candidate: InventoryManager, lost: Dictionary) -> Error:
		return _commit_defeat_guarded(candidate, lost, instance_id, bound_slot, bound_gen)
	instance.commit_suspend = func(snapshot: Dictionary) -> Error:
		return _commit_suspend_guarded(snapshot, instance_id, bound_slot, bound_gen)
	instance.extraction_save_failed.connect(_on_extraction_save_failed)
	instance.defeat_save_failed.connect(_on_defeat_save_failed)
	instance.suspend_save_failed.connect(_on_suspend_save_failed)
	instance.expedition_completed.connect(_on_expedition_completed)
	instance.expedition_failed.connect(_on_expedition_failed)
	instance.expedition_cancelled.connect(_on_expedition_cancelled)
	instance.expedition_suspended.connect(_on_expedition_suspended)
	target_layer.add_child(_expedition)
	if not _suspended_expedition.is_empty() and _suspended_expedition.get("is_active", false):
		var restored: bool = instance.restore_expedition(_suspended_expedition)
		if restored:
			if status_label != null:
				status_label.text = "Expedition resumed at chamber %d: Reach Extraction Portal" % (instance.current_step + 1)
		else:
			push_error("Failed to restore suspended expedition snapshot.")
			if status_label != null:
				status_label.text = "Expedition resume failed: invalid snapshot. Stored run preserved."
			_expedition = null
			instance.queue_free()
			_restore_combat_movement()
			return false
	else:
		instance.setup(1337, 6)
		if status_label != null:
			status_label.text = "Expedition active: Reach Extraction Portal"
	return true

func _is_expedition_callback_valid(origin_id: int, bound_slot: String, bound_gen: int) -> bool:
	if bound_slot.is_empty() or bound_slot != _profile_slot:
		return false
	if bound_gen != _session_generation:
		return false
	var origin: DungeonExpedition = instance_from_id(origin_id) as DungeonExpedition
	if origin == null or not is_instance_valid(origin) or origin.is_queued_for_deletion():
		return false
	if _expedition != origin:
		return false
	return true

func _commit_extraction_guarded(candidate: InventoryManager, origin_id: int, bound_slot: String, bound_gen: int) -> Error:
	if not _is_expedition_callback_valid(origin_id, bound_slot, bound_gen):
		return ERR_UNAUTHORIZED
	return _commit_extraction(candidate)

func _commit_defeat_guarded(candidate: InventoryManager, lost: Dictionary, origin_id: int, bound_slot: String, bound_gen: int) -> Error:
	if not _is_expedition_callback_valid(origin_id, bound_slot, bound_gen):
		return ERR_UNAUTHORIZED
	return _commit_defeat(candidate, lost)

func _commit_suspend_guarded(snapshot: Dictionary, origin_id: int, bound_slot: String, bound_gen: int) -> Error:
	if not _is_expedition_callback_valid(origin_id, bound_slot, bound_gen):
		return ERR_UNAUTHORIZED
	return _commit_suspend(snapshot)

## Extraction and the clearing of the active-expedition record are committed in a single
## profile write, so a resumed save can never bank the same satchel twice.
func _commit_extraction(candidate: InventoryManager) -> Error:
	if profile_store == null or candidate == null:
		return ERR_UNCONFIGURED
	var err: Error = _mutate_profile(func(profile: Dictionary) -> Error:
		profile["inventory"] = candidate.serialize()
		_clear_active_expedition_record(profile)
		return OK)
	if err == OK:
		inventory_manager.load_from_store(profile_store, _profile_slot)
		_suspended_expedition.clear()
	return err

func _commit_defeat(candidate: InventoryManager, _lost: Dictionary) -> Error:
	if profile_store == null or candidate == null:
		return ERR_UNCONFIGURED
	var err: Error = _mutate_profile(func(profile: Dictionary) -> Error:
		profile["inventory"] = candidate.serialize()
		_clear_active_expedition_record(profile)
		return OK)
	if err == OK:
		inventory_manager.load_from_store(profile_store, _profile_slot)
		_suspended_expedition.clear()
	return err

func _commit_suspend(snapshot: Dictionary) -> Error:
	if profile_store == null:
		return ERR_UNCONFIGURED
	var err: Error = _persist_active_expedition(snapshot)
	if err == OK:
		_suspended_expedition = snapshot.duplicate(true)
	return err

func _on_extraction_save_failed(err: Error) -> void:
	if status_label != null:
		status_label.text = "Extraction save failed (error %d). Expedition remains open for retry." % err

func _on_defeat_save_failed(err: Error) -> void:
	if status_label != null:
		status_label.text = "Expedition defeat save failed (error %d). Expedition remains open for retry." % err

func _on_suspend_save_failed(err: Error) -> void:
	if status_label != null:
		status_label.text = "Expedition suspend save failed (error %d). Expedition remains open for retry." % err

func _on_expedition_completed(extracted_items: Dictionary) -> void:
	_suspended_expedition.clear()
	if status_label != null:
		status_label.text = "Expedition Cleared! Extracted %d item types to Bank." % extracted_items.size()
	_close_expedition()

func _on_expedition_failed(lost_items: Dictionary) -> void:
	_suspended_expedition.clear()
	if status_label != null:
		status_label.text = "Expedition Defeat! Satchel lost (%d items); bank secured." % lost_items.size()
	_close_expedition()

func _on_expedition_cancelled() -> void:
	var had_saved_state: bool = not _suspended_expedition.is_empty()
	_suspended_expedition.clear()
	if had_saved_state:
		_persist_active_expedition({})
	if status_label != null:
		status_label.text = "Expedition cancelled. Returned to overworld."
	_close_expedition()

func _on_expedition_suspended(state: Dictionary) -> void:
	if _suspended_expedition.is_empty():
		var err: Error = _persist_active_expedition(state)
		if err != OK:
			if status_label != null:
				status_label.text = "Expedition suspend save failed (error %d). Expedition remains open." % err
			return
		_suspended_expedition = state.duplicate(true)
	if status_label != null:
		status_label.text = "Expedition suspended. Satchel preserved for resume."
	_close_expedition()

## Loads the persisted suspend snapshot so a resumed session can continue the same run.
func _load_active_expedition() -> void:
	_suspended_expedition = {}
	if profile_store == null:
		return
	var loaded: Dictionary = profile_store.load_profile(_profile_slot)
	if loaded["error"] != OK:
		return
	var profile: Dictionary = loaded["profile"] as Dictionary
	var world: Dictionary = profile["world"] if profile.get("world") is Dictionary else {}
	var state: Variant = world.get(ACTIVE_EXPEDITION_KEY, {})
	if state is Dictionary and bool((state as Dictionary).get("is_active", false)):
		var val_err: Error = GameplayProfileValidator._validate_active_expedition(state)
		if val_err == OK:
			_suspended_expedition = (state as Dictionary).duplicate(true)
		else:
			push_error("Stored active_expedition in slot %s failed validation (error %d). Snapshot preserved but not activated." % [_profile_slot, val_err])

func _persist_active_expedition(state: Dictionary) -> Error:
	return _mutate_profile(func(profile: Dictionary) -> Error:
		var world: Dictionary = profile["world"] if profile.get("world") is Dictionary else {}
		if state.is_empty():
			world.erase(ACTIVE_EXPEDITION_KEY)
		else:
			world[ACTIVE_EXPEDITION_KEY] = state.duplicate(true)
		profile["world"] = world
		return OK)

func _clear_active_expedition_record(profile: Dictionary) -> void:
	var world: Dictionary = profile["world"] if profile.get("world") is Dictionary else {}
	world.erase(ACTIVE_EXPEDITION_KEY)
	profile["world"] = world

## Load-modify-save against the newest revision so unrelated sections are never clobbered.
func _mutate_profile(mutator: Callable) -> Error:
	if profile_store == null:
		return ERR_UNCONFIGURED
	var loaded: Dictionary = profile_store.load_profile(_profile_slot)
	var profile: Dictionary = {}
	if loaded["error"] == ERR_FILE_NOT_FOUND:
		profile = profile_store.new_profile(_profile_slot)
	elif loaded["error"] == OK:
		profile = (loaded["profile"] as Dictionary).duplicate(true)
	else:
		return loaded["error"]
	var result: Variant = mutator.call(profile)
	if result is int and int(result) != OK:
		return int(result) as Error
	return profile_store.save_profile(_profile_slot, profile)

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
	sheet.set_kurei_tree(kurei_tree)
	sheet.closed.connect(_close_character_sheet)
	target_layer.add_child(sheet)

func _close_character_sheet() -> void:
	if _character_sheet != null and is_instance_valid(_character_sheet):
		_character_sheet.closed.disconnect(_close_character_sheet)
		_character_sheet.queue_free()
		_character_sheet = null

	if profile_store != null:
		character_stats.save_to_store(profile_store, _profile_slot)
		kurei_tree.save_to_store(profile_store, _profile_slot)

	if _inventory_sheet == null and _settings_sheet == null and _battle == null and _boss_encounter == null and _dialog == null and _expedition == null and _academic_modal == null and _ending_modal == null and _chapter_dialog == null:
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

	if _character_sheet == null and _settings_sheet == null and _battle == null and _boss_encounter == null and _dialog == null and _expedition == null and _academic_modal == null and _ending_modal == null and _chapter_dialog == null:
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

	if _character_sheet == null and _inventory_sheet == null and _battle == null and _boss_encounter == null and _dialog == null and _expedition == null and _academic_modal == null and _ending_modal == null and _chapter_dialog == null:
		_restore_combat_movement()

const _BASE_FONT_META: StringName = &"_base_font_size"
const _BASE_FONT_OVERRIDE_META: StringName = &"_base_font_had_override"
const _BASE_FONT_COLOR_META: StringName = &"_base_font_color"
const _BASE_FONT_COLOR_OVERRIDE_META: StringName = &"_base_font_color_had_override"
const _BASE_SHADOW_COLOR_META: StringName = &"_base_shadow_color"
const _BASE_SHADOW_COLOR_OVERRIDE_META: StringName = &"_base_shadow_color_had_override"
const _BASE_SHADOW_OX_META: StringName = &"_base_shadow_ox"
const _BASE_SHADOW_OY_META: StringName = &"_base_shadow_oy"
const _BASE_SHADOW_OFFSET_OVERRIDE_META: StringName = &"_base_shadow_offset_had_override"

func _apply_runtime_settings() -> void:
	if settings_manager == null:
		return
	settings_manager.apply_all_settings()
	if world_container != null:
		world_container.modulate = Color(1.15, 1.15, 1.15, 1.0) if settings_manager.high_contrast else Color.WHITE
	_apply_accessibility_tree(self)

## Applies text scale and high-contrast presentation to the live UI (not just stored flags).
func _apply_accessibility_tree(node: Node) -> void:
	if node is Control:
		var ctrl: Control = node as Control
		_apply_text_scale(ctrl)
		_apply_high_contrast(ctrl)
		if ctrl.get_parent() is CanvasLayer or ctrl.get_parent() == self:
			ctrl.modulate = Color(1.2, 1.2, 1.2, 1.0) if settings_manager.high_contrast else Color.WHITE
	for child in node.get_children():
		_apply_accessibility_tree(child)

## Extends high contrast beyond modulate to font color and shadow overrides, preserving authored values for restore.
func _apply_high_contrast(control: Control) -> void:
	if control is Label:
		var label: Label = control as Label
		if not label.has_meta(_BASE_FONT_COLOR_META):
			label.set_meta(_BASE_FONT_COLOR_META, label.get_theme_color("font_color"))
			label.set_meta(_BASE_FONT_COLOR_OVERRIDE_META, label.has_theme_color_override("font_color"))
			label.set_meta(_BASE_SHADOW_COLOR_META, label.get_theme_color("font_shadow_color"))
			label.set_meta(_BASE_SHADOW_COLOR_OVERRIDE_META, label.has_theme_color_override("font_shadow_color"))
			label.set_meta(_BASE_SHADOW_OX_META, label.get_theme_constant("shadow_offset_x"))
			label.set_meta(_BASE_SHADOW_OY_META, label.get_theme_constant("shadow_offset_y"))
			label.set_meta(_BASE_SHADOW_OFFSET_OVERRIDE_META, label.has_theme_constant_override("shadow_offset_x"))

		if settings_manager.high_contrast:
			# High contrast: crisp pure white text with high-contrast black shadow outline
			label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
			label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 1.0))
			label.add_theme_constant_override("shadow_offset_x", 1)
			label.add_theme_constant_override("shadow_offset_y", 1)
		else:
			# Restore authored values
			if bool(label.get_meta(_BASE_FONT_COLOR_OVERRIDE_META)):
				label.add_theme_color_override("font_color", label.get_meta(_BASE_FONT_COLOR_META))
			else:
				label.remove_theme_color_override("font_color")

			if bool(label.get_meta(_BASE_SHADOW_COLOR_OVERRIDE_META)):
				label.add_theme_color_override("font_shadow_color", label.get_meta(_BASE_SHADOW_COLOR_META))
			else:
				label.remove_theme_color_override("font_shadow_color")

			if bool(label.get_meta(_BASE_SHADOW_OFFSET_OVERRIDE_META)):
				label.add_theme_constant_override("shadow_offset_x", int(label.get_meta(_BASE_SHADOW_OX_META)))
				label.add_theme_constant_override("shadow_offset_y", int(label.get_meta(_BASE_SHADOW_OY_META)))
			else:
				label.remove_theme_constant_override("shadow_offset_x")
				label.remove_theme_constant_override("shadow_offset_y")

## Scales each control from its authored font size. The authored size is captured once so
## repeated settings changes never compound (e.g. 1.5x applied twice stays 1.5x, not 2.25x),
## and returning to 1.0 restores the scene-authored size instead of forcing a theme default.
func _apply_text_scale(control: Control) -> void:
	if not control.has_meta(_BASE_FONT_META):
		control.set_meta(_BASE_FONT_META, control.get_theme_font_size("font_size"))
		control.set_meta(_BASE_FONT_OVERRIDE_META, control.has_theme_font_size_override("font_size"))
	var base: int = int(control.get_meta(_BASE_FONT_META))
	if is_equal_approx(settings_manager.text_scale, 1.0):
		if bool(control.get_meta(_BASE_FONT_OVERRIDE_META)):
			control.add_theme_font_size_override("font_size", base)
		else:
			control.remove_theme_font_size_override("font_size")
		return
	var scaled: int = maxi(8, int(round(float(base) * settings_manager.text_scale)))
	control.add_theme_font_size_override("font_size", scaled)

func _on_ui_node_added(node: Node) -> void:
	if settings_manager == null or not is_ancestor_of(node):
		return
	if node is Control:
		var control: Control = node as Control
		_apply_text_scale(control)
		_apply_high_contrast(control)
		if control.get_parent() is CanvasLayer or control.get_parent() == self:
			control.modulate = Color(1.2, 1.2, 1.2, 1.0) if settings_manager.high_contrast else Color.WHITE

func _reload_imported_profile() -> void:
	if profile_store == null:
		return
	# _init_slice_progress re-reads the imported profile into every live consumer
	# (character, inventory, chapters, assessment, Kurei tree, ending) and refreshes the
	# chapter baseline, so no pre-import state can be written back afterwards.
	_init_slice_progress(profile_store, _profile_slot)
	_pending_return_to_alpha = _is_current_location_locked()
	_sync_dimension_state()

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
	if _academic_modal != null or has_blocking_modal():
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
# Dual-Ending Altars & Modal Management (Chapter V Epilogue)
# ==============================================================================

func _bind_ending_altars() -> void:
	if not ReleaseTier.is_full_release():
		return
	if world_router == null or world_router.active_region == null or not is_instance_valid(world_router.active_region):
		return
	var altar_a := world_router.active_region.get_node_or_null("EndingAltarTranscendence") as Area2D
	if altar_a != null:
		var cb_a := _on_ending_altar_entered.bind(EndingManager.ENDING_A_TRANSCENDENCE)
		if not altar_a.body_entered.is_connected(cb_a):
			altar_a.body_entered.connect(cb_a)
	var altar_b := world_router.active_region.get_node_or_null("EndingAltarRestoration") as Area2D
	if altar_b != null:
		var cb_b := _on_ending_altar_entered.bind(EndingManager.ENDING_B_RESTORATION)
		if not altar_b.body_entered.is_connected(cb_b):
			altar_b.body_entered.connect(cb_b)

func _on_ending_altar_entered(body: Node2D, ending_type: String) -> void:
	if not ReleaseTier.is_full_release():
		return
	if body != player or player == null or player.input_frozen:
		return
	if has_blocking_modal():
		return
	open_ending_modal(ending_type)

func open_ending_modal(ending_type: String) -> void:
	if not ReleaseTier.is_full_release():
		return
	if _ending_modal != null and is_instance_valid(_ending_modal):
		return
	if has_blocking_modal():
		return
	var target_layer: CanvasLayer = _sheet_layer if _sheet_layer != null else _dialog_layer
	if target_layer == null:
		return

	if player != null:
		player.freeze_movement()

	ending_manager.choose_ending(ending_type)
	if profile_store != null:
		var loaded := profile_store.load_profile(_profile_slot)
		if loaded.get("error") == OK:
			var prof: Dictionary = loaded.get("profile", {})
			if not prof.has("world") or typeof(prof["world"]) != TYPE_DICTIONARY:
				prof["world"] = {}
			prof["world"]["ending"] = ending_manager.serialize()
			profile_store.save_profile(_profile_slot, prof)

	if audio_manager != null:
		audio_manager.play_cue("portal")

	var modal: EndingModal = ENDING_MODAL_SCENE.instantiate() as EndingModal
	if modal == null:
		_restore_combat_movement()
		return

	_ending_modal = modal
	modal.configure(ending_type, ending_manager, character_stats, assessment_controller)
	modal.closed.connect(_close_ending_modal)
	modal.title_menu_requested.connect(_on_ending_title_menu_requested)
	target_layer.add_child(modal)

	if status_label != null:
		status_label.text = "Reached Campaign Epilogue: %s" % ending_type.capitalize()
	_update_objective()

func _close_ending_modal() -> void:
	if _ending_modal != null and is_instance_valid(_ending_modal):
		_ending_modal.queue_free()
		_ending_modal = null
	if not has_blocking_modal():
		_restore_combat_movement()
	if status_label != null:
		status_label.text = "Campaign epilogue archived. Free exploration active across all realms."

func _on_ending_title_menu_requested() -> void:
	_close_ending_modal()
	open_title_screen()

# ==============================================================================
# Objective Tracking
# ==============================================================================

func _update_objective() -> void:
	if objective_label == null:
		return
	if ending_manager != null and ending_manager.is_ending_achieved:
		var ending_details: Dictionary = ending_manager.get_ending_details()
		objective_label.text = "Campaign Complete: %s! Free exploration active across all realms." % String(ending_details.get("title", "Epilogue Active"))
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
						var shift_hint: String = InputBindings.get_action_binding_text(&"shift_dimension", settings_manager.input_overrides if settings_manager != null else {})
						objective_label.text = "Chapter II: Use Dimension Shift [%s] to navigate Whispering Grove." % shift_hint
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
	world_router.set_region_available("void_citadel", ReleaseTier.is_full_release())
	_sync_release_tier_for_region(world_router.active_region_id)

func _sync_release_tier_for_region(region_id: String) -> void:
	if world_router == null or world_router.active_region == null or not is_instance_valid(world_router.active_region):
		return
	if ReleaseTier.is_academic_mvp():
		if region_id == "ashen_peaks":
			var citadel_portal: Node = world_router.active_region.get_node_or_null("Portals/PortalToCitadel")
			if citadel_portal != null:
				citadel_portal.visible = false
				if citadel_portal is Area2D:
					(citadel_portal as Area2D).monitoring = false
					(citadel_portal as Area2D).monitorable = false
				for child in citadel_portal.get_children():
					if child is CollisionShape2D:
						(child as CollisionShape2D).set_deferred("disabled", true)
		elif region_id == "void_citadel":
			var altar_a: Node = world_router.active_region.get_node_or_null("EndingAltarTranscendence")
			if altar_a != null:
				altar_a.visible = false
				if altar_a is Area2D:
					(altar_a as Area2D).monitoring = false
					(altar_a as Area2D).monitorable = false
			var altar_b: Node = world_router.active_region.get_node_or_null("EndingAltarRestoration")
			if altar_b != null:
				altar_b.visible = false
				if altar_b is Area2D:
					(altar_b as Area2D).monitoring = false
					(altar_b as Area2D).monitorable = false

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
	_debug_bar.boss_combat_requested.connect(open_boss_encounter)
	_debug_bar.dungeon_requested.connect(_on_debug_dungeon)
	_debug_bar.chapter_dialog_requested.connect(_on_debug_chapter_dialog)
	_debug_bar.academic_modal_requested.connect(_on_debug_academic_modal)
	_debug_bar.dimension_shift_requested.connect(_on_debug_dimension_shift)
	_debug_bar.grant_items_requested.connect(_on_debug_grant_items)
	_debug_bar.complete_activities_requested.connect(_on_debug_complete_activities)
	_debug_bar.max_stats_requested.connect(_on_debug_max_stats)
	_debug_bar.title_screen_requested.connect(open_title_screen)
	_debug_bar.ending_requested.connect(open_ending_modal)
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
	instance.kurei_tree = kurei_tree
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
	instance.commit_defeat = _commit_defeat
	instance.extraction_save_failed.connect(_on_extraction_save_failed)
	instance.defeat_save_failed.connect(_on_defeat_save_failed)
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
	if _academic_modal != null or has_blocking_modal():
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
			_sync_dimension_state()
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

func _get_title_overlay_layer() -> CanvasLayer:
	if _title_overlay_layer != null and is_instance_valid(_title_overlay_layer):
		return _title_overlay_layer
	if has_node("TitleOverlayLayer"):
		_title_overlay_layer = get_node("TitleOverlayLayer") as CanvasLayer
		return _title_overlay_layer
	var layer_num: int = (_title_layer.layer + 1) if (_title_layer != null and is_instance_valid(_title_layer)) else 9
	var overlay := CanvasLayer.new()
	overlay.name = "TitleOverlayLayer"
	overlay.layer = layer_num
	add_child(overlay)
	_title_overlay_layer = overlay
	return _title_overlay_layer

func open_title_settings(slot_id: String = "", origin_control: Control = null, initial_section: String = "general") -> void:
	if _title_screen == null or not is_instance_valid(_title_screen):
		return
	if _title_settings_sheet != null and is_instance_valid(_title_settings_sheet):
		return
	if _settings_sheet != null and is_instance_valid(_settings_sheet):
		return
	if (_battle != null and is_instance_valid(_battle)) \
			or (_boss_encounter != null and is_instance_valid(_boss_encounter)) \
			or (_dialog != null and is_instance_valid(_dialog)) \
			or (_expedition != null and is_instance_valid(_expedition)) \
			or (_academic_modal != null and is_instance_valid(_academic_modal)) \
			or (_ending_modal != null and is_instance_valid(_ending_modal)) \
			or (_chapter_dialog != null and is_instance_valid(_chapter_dialog)) \
			or (_character_sheet != null and is_instance_valid(_character_sheet)) \
			or (_inventory_sheet != null and is_instance_valid(_inventory_sheet)) \
			or _chapter_dialog_pending:
		return

	var target_layer: CanvasLayer = _get_title_overlay_layer()
	if target_layer == null:
		return

	var target_slot: String = slot_id if not slot_id.is_empty() else (_title_screen.current_slot if _title_screen != null else _profile_slot)

	_title_screen.set_modal_blocked(true)

	var sheet: SettingsSheet = SETTINGS_SHEET_SCENE.instantiate() as SettingsSheet
	if sheet == null:
		_title_screen.set_modal_blocked(false)
		return
	_title_settings_sheet = sheet

	sheet.set_settings(settings_manager)
	sheet.set_profile_context(profile_store, target_slot)
	sheet.set_initial_section(initial_section)

	var bound_target_slot := target_slot
	var origin_id: int = origin_control.get_instance_id() if origin_control != null and is_instance_valid(origin_control) else 0

	sheet.backup_imported.connect(func(): _on_title_backup_imported(bound_target_slot))
	sheet.closed.connect(func(): _close_title_settings(origin_id))

	target_layer.add_child(sheet)

func _close_title_settings(origin_id: int = 0) -> void:
	if _title_settings_sheet != null and is_instance_valid(_title_settings_sheet):
		_title_settings_sheet.queue_free()
		_title_settings_sheet = null

	if settings_manager != null:
		settings_manager.save_settings()

	if _title_screen != null and is_instance_valid(_title_screen):
		_title_screen.set_modal_blocked(false)

	if origin_id != 0:
		var origin: Object = instance_from_id(origin_id)
		if origin != null and origin is Control and is_instance_valid(origin):
			(origin as Control).grab_focus()

	if player != null and is_instance_valid(player) and _title_screen != null and is_instance_valid(_title_screen):
		player.freeze_movement()

func _on_title_backup_imported(slot_id: String) -> void:
	if _title_screen != null and is_instance_valid(_title_screen):
		_title_screen.refresh_slot_summary(slot_id)

func _on_title_settings_requested() -> void:
	var slot: String = _title_screen.current_slot if _title_screen != null else _profile_slot
	var origin: Control = _title_screen.get_last_action_origin() if _title_screen != null else null
	if origin == null and _title_screen != null:
		origin = _title_screen.settings_btn
	open_title_settings(slot, origin, "general")

func _on_title_backup_requested() -> void:
	var slot: String = _title_screen.current_slot if _title_screen != null else _profile_slot
	var origin: Control = _title_screen.get_last_action_origin() if _title_screen != null else null
	if origin == null and _title_screen != null:
		if _title_screen.recovery_box != null and _title_screen.recovery_box.visible and _title_screen.recovery_export_btn != null and _title_screen.recovery_export_btn.has_focus():
			origin = _title_screen.recovery_export_btn
		else:
			origin = _title_screen.backup_btn
	open_title_settings(slot, origin, "backup")

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
	_title_screen.continue_requested.connect(_on_title_continue_requested)
	_title_screen.new_journey_requested.connect(_on_title_new_journey_requested)
	_title_screen.game_started.connect(_on_title_game_started)
	_title_screen.settings_requested.connect(_on_title_settings_requested)
	_title_screen.backup_requested.connect(_on_title_backup_requested)
	_title_screen.defense_demo_requested.connect(_on_title_defense_demo)
	if player != null:
		player.freeze_movement()

func _close_title_screen() -> void:
	if _title_settings_sheet != null and is_instance_valid(_title_settings_sheet):
		_close_title_settings()
	if _title_screen != null and is_instance_valid(_title_screen):
		_title_screen.queue_free()
		_title_screen = null
	if not has_blocking_modal():
		_restore_combat_movement()

func _on_title_continue_requested(slot_id: String) -> void:
	if profile_store == null:
		profile_store = ProfileStore.new()

	var check := profile_store.load_profile(slot_id)
	if check.get("error") != OK:
		push_error("Cannot continue journey: slot '%s' load error %s" % [slot_id, error_string(check.get("error"))])
		if _title_screen != null and is_instance_valid(_title_screen):
			_title_screen.show_error("Cannot load profile '%s'." % slot_id)
		return

	var act_err: Error = activate_profile(slot_id, false)
	if act_err == OK:
		_close_title_screen()
		if audio_manager != null:
			audio_manager.play_cue("portal")
	else:
		if _title_screen != null and is_instance_valid(_title_screen):
			_title_screen.show_error("Failed to activate profile: %s" % error_string(act_err))

func _on_title_new_journey_requested(slot_id: String) -> void:
	if profile_store == null:
		profile_store = ProfileStore.new()

	# Recheck slot emptiness immediately before creating
	var check := profile_store.load_profile(slot_id)
	if check.get("error") != ERR_FILE_NOT_FOUND:
		push_error("Cannot start new journey: slot '%s' is not empty." % slot_id)
		if _title_screen != null and is_instance_valid(_title_screen):
			_title_screen.show_error("Slot '%s' is not empty." % slot_id)
		return

	var new_prof := profile_store.new_profile(slot_id)
	var save_err: Error = profile_store.save_profile(slot_id, new_prof)
	if save_err != OK:
		push_error("Failed to write new profile for slot '%s': %s" % [slot_id, error_string(save_err)])
		if _title_screen != null and is_instance_valid(_title_screen):
			_title_screen.show_error("Failed to create profile: %s" % error_string(save_err))
		return

	var act_err: Error = activate_profile(slot_id, true)
	if act_err == OK:
		_close_title_screen()
		if audio_manager != null:
			audio_manager.play_cue("portal")
	else:
		if _title_screen != null and is_instance_valid(_title_screen):
			_title_screen.show_error("Failed to activate new profile: %s" % error_string(act_err))

func _on_title_game_started(_slot_id: String) -> void:
	pass

func _on_title_defense_demo(slot_id: String = "") -> void:
	if profile_store == null:
		profile_store = ProfileStore.new()

	var target_slot: String = slot_id if not slot_id.is_empty() else (_title_screen.current_slot if _title_screen != null else _profile_slot)
	if not (target_slot in ProfileStore.VALID_PROFILE_IDS):
		target_slot = _profile_slot

	var check := profile_store.load_profile(target_slot)
	var check_err: int = check.get("error", ERR_UNCONFIGURED)
	if check_err != OK and check_err != ERR_FILE_NOT_FOUND:
		push_error("Cannot start defense demo: slot '%s' load error %s" % [target_slot, error_string(check_err)])
		if _title_screen != null and is_instance_valid(_title_screen):
			_title_screen.show_error("Cannot load profile '%s'." % target_slot)
		return

	var is_empty: bool = (check_err == ERR_FILE_NOT_FOUND)
	var act_err: Error = activate_profile(target_slot, is_empty)
	if act_err != OK:
		push_error("Cannot start defense demo: failed to activate profile '%s': %s" % [target_slot, error_string(act_err)])
		if _title_screen != null and is_instance_valid(_title_screen):
			_title_screen.show_error("Failed to activate profile: %s" % error_string(act_err))
		return

	_on_debug_complete_activities()
	_on_debug_grant_items()
	_on_debug_max_stats()
	_close_title_screen()
	if audio_manager != null:
		audio_manager.play_cue("correct")
