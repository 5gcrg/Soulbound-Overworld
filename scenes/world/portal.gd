class_name RegionPortal
extends Area2D

signal transition_requested(portal: RegionPortal, target_region_id: String, target_spawn_id: String)

@export var target_region_id: String = ""
@export var target_spawn_id: String = ""
@export var portal_label: String = "Portal"

@onready var label_node: Label = $Label

func _ready() -> void:
	if label_node != null and portal_label != "":
		label_node.text = portal_label
	
	# Connect body_entered signal
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body is PlayerCharacter or body.name == "Player":
		# Emit request; GameRoot will process deferred outside physics flush
		transition_requested.emit(self, target_region_id, target_spawn_id)
