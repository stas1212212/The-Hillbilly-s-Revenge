extends CharacterBody2D
@export var move_speed: float = 235.0
@export var jump_velocity: float = -420.0
@export var gravity: float = 1100.0
@onready var art: Sprite2D = $Sprite2D
var elapsed: float = 0.0
var base_art_y: float = 0.0
func _ready() -> void:
    base_art_y = art.position.y
func _physics_process(delta: float) -> void:
    elapsed += delta
    if not is_on_floor():
        velocity.y += gravity * delta
    if (Input.is_action_just_pressed("ui_accept") or Input.is_key_pressed(KEY_SPACE)) and is_on_floor():
        velocity.y = jump_velocity
    var axis: float = Input.get_axis("ui_left", "ui_right")
    if Input.is_key_pressed(KEY_A):
        axis -= 1.0
    if Input.is_key_pressed(KEY_D):
        axis += 1.0
    axis = clampf(axis,-1.0,1.0)
    velocity.x = axis * move_speed
    if absf(axis) > 0.01:
        art.flip_h = axis < 0.0
    art.position.y = base_art_y + (sin(elapsed * 2.5) * 1.5 if is_on_floor() and absf(axis) < 0.01 else 0.0)
    move_and_slide()
func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("ui_cancel"):
        get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
