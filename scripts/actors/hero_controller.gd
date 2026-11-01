extends CharacterBody2D

# First controllable visual prototype using the reference design.
# One clean idle illustration; frame-by-frame combat animations come later.
@export var move_speed := 235.0
@export var jump_velocity := -420.0
@export var gravity := 1100.0
@onready var art: Sprite2D = $Sprite2D
var elapsed := 0.0

func _physics_process(delta: float) -> void:
    elapsed += delta
    if not is_on_floor():
        velocity.y += gravity * delta
    if Input.is_action_just_pressed("ui_accept") and is_on_floor():
        velocity.y = jump_velocity
    var axis := Input.get_axis("ui_left", "ui_right")
    if Input.is_key_pressed(KEY_A): axis -= 1.0
    if Input.is_key_pressed(KEY_D): axis += 1.0
    axis = clampf(axis, -1.0, 1.0)
    velocity.x = axis * move_speed
    if absf(axis) > 0.01:
        art.flip_h = axis < 0.0
    art.position.y = -33.0 + (sin(elapsed * 2.5) * 1.5 if is_on_floor() and absf(axis) < 0.01 else 0.0)
    move_and_slide()
