extends Control

const EXPECTED_BOOTSTRAP_STAGE: String = "Overworld Active"
const DEFAULT_START_REGION: String = "test_region_alpha"
const DEFAULT_START_SPAWN: String = "default"
const BATTLE_FIXTURE_SCENE: PackedScene = preload("res://scenes/combat/battle_fixture.tscn")
const EXPECTED_ENCOUNTER_ID: StringName = &"combat_alpha_fixture"

var _battle: Control = null
var _battle_pending: bool = false
var _previous_input_frozen: bool = false

@onready var world_container: Node2D = $WorldContainer
@onready var player: PlayerCharacter = $Player
@onready var world_router: WorldRouter = $WorldRouter
@onready var status_label: Label = $UIOverlay/VBoxContainer/StatusLabel
@onready var title_label: Label = $UIOverlay/VBoxContainer/TitleLabel
@onready var _battle_layer: CanvasLayer = $BattleLayer

func _ready() -> void:
	if status_label != null:
		status_label.text = ""

	if world_router != null and world_container != null and player != null:
		world_router.setup(world_container, player)
		world_router.region_transition_completed.connect(_on_region_transition_completed)
		world_router.region_transition_failed.connect(_on_region_transition_failed)

		# Boot into starting test region
		var booted: bool = world_router.initialize_starting_region(DEFAULT_START_REGION, DEFAULT_START_SPAWN)
		if booted:
			_bind_combat_encounter()
			if status_label != null:
				status_label.text = EXPECTED_BOOTSTRAP_STAGE
		else:
			push_error("Failed to initialize starting region: %s at spawn %s" % [DEFAULT_START_REGION, DEFAULT_START_SPAWN])

func _on_region_transition_completed(region_id: String, spawn_id: String) -> void:
	_bind_combat_encounter()
	if status_label != null:
		status_label.text = "Region: %s (Spawn: %s)" % [region_id, spawn_id]

func _on_region_transition_failed(reason: String, from_id: String, to_id: String) -> void:
	if status_label != null:
		status_label.text = "Transition failed (%s): %s -> %s" % [reason, from_id, to_id]

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
	if world_router == null or world_router.is_transition_in_flight:
		return
	_battle_pending = true
	_open_combat.call_deferred(encounter_id)

func _open_combat(encounter_id: int) -> void:
	_battle_pending = false
	var encounter: Area2D = instance_from_id(encounter_id) as Area2D
	if encounter == null or not is_instance_valid(encounter) or encounter.is_queued_for_deletion():
		return
	if world_router == null or world_router.active_region == null or not is_instance_valid(world_router.active_region) or world_router.active_region.is_queued_for_deletion():
		return
	if not world_router.active_region.is_ancestor_of(encounter):
		return
	if not encounter.has_meta("encounter_id") or StringName(encounter.get_meta("encounter_id")) != EXPECTED_ENCOUNTER_ID:
		return
	if world_router.is_transition_in_flight:
		return
	if _battle != null and is_instance_valid(_battle):
		return
	if player == null or _battle_layer == null:
		return

	var instance: Control = BATTLE_FIXTURE_SCENE.instantiate() as Control
	if instance == null:
		return
	_battle = instance
	_previous_input_frozen = player.input_frozen
	player.freeze_movement()
	if not _battle.is_connected("continued", _close_combat):
		_battle.connect("continued", _close_combat, CONNECT_ONE_SHOT)
	_battle_layer.add_child(_battle)

func _close_combat() -> void:
	if player != null and is_instance_valid(player):
		player.input_frozen = _previous_input_frozen
	if _battle != null and is_instance_valid(_battle):
		_battle.hide()
		_battle.queue_free()
	_battle = null
