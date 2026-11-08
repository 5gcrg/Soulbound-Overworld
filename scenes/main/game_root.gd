extends Control

const EXPECTED_BOOTSTRAP_STAGE: String = "M1 Technical Foundation Bootstrap"

@onready var status_label: Label = $VBoxContainer/StatusLabel

func _ready() -> void:
	status_label.text = EXPECTED_BOOTSTRAP_STAGE
