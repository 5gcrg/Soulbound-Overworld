extends Control

const EXPECTED_BOOTSTRAP_STAGE: String = "Overworld Active"
const DEFAULT_START_REGION: String = "test_region_alpha"
const DEFAULT_START_SPAWN: String = "default"

@onready var world_container: Node2D = $WorldContainer
@onready var player: PlayerCharacter = $Player
@onready var world_router: WorldRouter = $WorldRouter
@onready var status_label: Label = $UIOverlay/VBoxContainer/StatusLabel
@onready var title_label: Label = $UIOverlay/VBoxContainer/TitleLabel

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
			if status_label != null:
				status_label.text = EXPECTED_BOOTSTRAP_STAGE
		else:
			push_error("Failed to initialize starting region: %s at spawn %s" % [DEFAULT_START_REGION, DEFAULT_START_SPAWN])

func _on_region_transition_completed(region_id: String, spawn_id: String) -> void:
	if status_label != null:
		status_label.text = "Region: %s (Spawn: %s)" % [region_id, spawn_id]

func _on_region_transition_failed(reason: String, from_id: String, to_id: String) -> void:
	if status_label != null:
		status_label.text = "Transition failed (%s): %s -> %s" % [reason, from_id, to_id]
