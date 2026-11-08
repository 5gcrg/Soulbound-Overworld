class_name PlayerCharacter
extends CharacterBody2D

## Technical fixture movement speed (named editor-tunable, not an approved player stat)
@export var fixture_move_speed: float = 160.0

@export var input_frozen: bool = false

var last_move_direction: Vector2 = Vector2.ZERO

@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _physics_process(_delta: float) -> void:
	if input_frozen:
		velocity = Vector2.ZERO
		return

	var input_vector: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input_vector != Vector2.ZERO:
		last_move_direction = input_vector
		velocity = input_vector.normalized() * fixture_move_speed
	else:
		velocity = Vector2.ZERO

	move_and_slide()

func freeze_movement() -> void:
	input_frozen = true
	velocity = Vector2.ZERO

func resume_movement() -> void:
	input_frozen = false
