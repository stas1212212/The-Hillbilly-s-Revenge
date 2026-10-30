class_name PlayerController
extends CharacterBody2D

signal attacked
signal parried
signal dodged

@export var stats: ActorStats
@export var stamina: StaminaComponent
@export var move_speed := 210.0
@export var acceleration := 1300.0
@export var ground_friction := 1600.0
@export var jump_velocity := -310.0
@export var gravity := 950.0
@export var dodge_speed := 410.0
@export var dodge_duration := 0.18
@export var attack_cost := 14.0
@export var dodge_cost := 20.0
@export var parry_cost := 8.0
@export var parry_window := 0.16
@export var attack_cooldown := 0.35

var facing := 1
var dodge_left := 0.0
var parry_left := 0.0
var attack_left := 0.0
var recoil_velocity := Vector2.ZERO

func _physics_process(delta: float) -> void:
    var direction := Input.get_axis("ui_left", "ui_right")
    if Input.is_key_pressed(KEY_A): direction -= 1.0
    if Input.is_key_pressed(KEY_D): direction += 1.0
    direction = clampf(direction, -1.0, 1.0)
    if direction != 0.0: facing = 1 if direction > 0.0 else -1
    dodge_left = maxf(0.0, dodge_left - delta)
    parry_left = maxf(0.0, parry_left - delta)
    attack_left = maxf(0.0, attack_left - delta)

    if not is_on_floor():
        velocity.y += gravity * delta
    elif Input.is_action_just_pressed("ui_accept"):
        velocity.y = jump_velocity

    if Input.is_key_pressed(KEY_SHIFT) and dodge_left <= 0.0 and stamina != null and stamina.spend(dodge_cost):
        dodge_left = dodge_duration
        dodged.emit()
    if Input.is_key_pressed(KEY_E) and parry_left <= 0.0 and stamina != null and stamina.spend(parry_cost):
        parry_left = parry_window
        parried.emit()
    if Input.is_key_pressed(KEY_J) and attack_left <= 0.0 and stamina != null and stamina.spend(attack_cost):
        attack_left = attack_cooldown
        attacked.emit()

    var target_speed := direction * move_speed
    if dodge_left > 0.0:
        target_speed = facing * dodge_speed
    var rate := acceleration if direction != 0.0 else ground_friction
    velocity.x = move_toward(velocity.x, target_speed, rate * delta)
    velocity += recoil_velocity
    recoil_velocity = recoil_velocity.move_toward(Vector2.ZERO, 1100.0 * delta)
    move_and_slide()

func apply_hit_recoil(horizontal_impulse: float, source_x: float) -> void:
    var direction := signf(global_position.x - source_x)
    if direction == 0.0: direction = 1.0
    recoil_velocity.x = direction * clampf(horizontal_impulse, 0.0, 900.0)
