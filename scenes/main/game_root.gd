extends Control

const EXPECTED_TITLE: String = "Soulbound"
const EXPECTED_BOOTSTRAP_STAGE: String = "M1 Technical Foundation Bootstrap"

@onready var title_label: Label = $VBoxContainer/TitleLabel
@onready var status_label: Label = $VBoxContainer/StatusLabel

func _ready() -> void:
	if title_label:
		title_label.text = EXPECTED_TITLE
	if status_label:
		status_label.text = EXPECTED_BOOTSTRAP_STAGE
