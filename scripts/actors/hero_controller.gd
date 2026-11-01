extends CharacterBody2D
## Functional character prototype: movement, jump, three-hit combo, damage and knockback.
## Replace placeholder single-image frames with hand-drawn sprite sheets later.
signal health_changed(current: int, maximum: int)
signal died

@export var move_speed: float = 235.0
@export var run_speed: float = 340.0
@export var jump_velocity: float = -420.0
@export var gravity: float = 1100.0
@export var max_health: int = 100
@export var attack_damage: int = 20

@onready var art: AnimatedSprite2D = $AnimatedSprite2D
@onready var attack_box: Area2D = $AttackBox
@onready var attack_shape: CollisionShape2D = $AttackBox/CollisionShape2D
@onready var hurt_box: Area2D = $Hurtbox
var health: int = 100
var combo: int = 0
var attack_remaining: float = 0.0
var combo_window: float = 0.0
var queued_attack: bool = false
var invulnerable_remaining: float = 0.0
var facing: int = 1
var dead: bool = false
var animation_clock: float = 0.0
var visual_origin: Vector2
var already_hit: Array[Node] = []

func _ready() -> void:
    health = max_health
    visual_origin = art.position
    attack_box.monitoring = false
    attack_shape.disabled = true
    hurt_box.add_to_group("hero_hurtbox")
    health_changed.emit(health, max_health)

func _physics_process(delta: float) -> void:
    animation_clock += delta
    invulnerable_remaining = maxf(0.0, invulnerable_remaining - delta)
    if not is_on_floor():
        velocity.y += gravity * delta

    if dead:
        velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
        move_and_slide()
        return

    if Input.is_action_just_pressed("ui_accept") and is_on_floor():
        velocity.y = jump_velocity

    var axis: float = Input.get_axis("ui_left", "ui_right")
    if Input.is_key_pressed(KEY_A):
        axis -= 1.0
    if Input.is_key_pressed(KEY_D):
        axis += 1.0
    axis = clampf(axis, -1.0, 1.0)
    var sprinting: bool = Input.is_key_pressed(KEY_SHIFT)
    var speed: float = run_speed if sprinting else move_speed
    if absf(axis) > 0.01:
        facing = -1 if axis < 0.0 else 1
        art.flip_h = facing < 0
        attack_box.position.x = 45.0 * facing

    if Input.is_key_pressed(KEY_J) and attack_remaining <= 0.0 and combo_window <= 0.0:
        _start_attack(1)

    if attack_remaining > 0.0:
        attack_remaining -= delta
        velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
        if Input.is_action_just_pressed("ui_accept"):
            pass
        if Input.is_key_pressed(KEY_J):
            queued_attack = true
        if attack_remaining <= 0.0:
            _finish_attack()
    else:
        velocity.x = axis * speed
        if combo_window > 0.0:
            combo_window -= delta
            if queued_attack and combo < 3:
                _start_attack(combo + 1)
            elif combo_window <= 0.0:
                combo = 0
                queued_attack = false

    move_and_slide()
    _update_animation(axis, sprinting)
    if attack_box.monitoring:
        for area in attack_box.get_overlapping_areas():
            _try_hit(area)

func _update_animation(axis: float, sprinting: bool) -> void:
    if attack_remaining > 0.0:
        _play_if_available("attack_" + str(combo))
        art.rotation = sin(animation_clock * 20.0) * 0.07 * facing
    elif not is_on_floor():
        _play_if_available("jump" if velocity.y < 0.0 else "fall")
        art.rotation = 0.0
    elif absf(axis) > 0.01:
        _play_if_available("run" if sprinting else "walk")
        art.rotation = 0.0
    else:
        _play_if_available("idle")
        art.rotation = 0.0
    # Small placeholder motion; real frame-by-frame art will replace this.
    art.position.y = visual_origin.y + (sin(animation_clock * 12.0) * 2.0 if absf(axis) > 0.01 and is_on_floor() else 0.0)

func _play_if_available(name: String) -> void:
    if art.sprite_frames != null and art.sprite_frames.has_animation(name) and art.animation != name:
        art.play(name)

func _start_attack(index: int) -> void:
    combo = index
    queued_attack = false
    already_hit.clear()
    attack_remaining = 0.23 + float(index) * 0.035
    combo_window = 0.0
    attack_shape.set_deferred("disabled", false)
    attack_box.set_deferred("monitoring", true)

func _finish_attack() -> void:
    attack_box.set_deferred("monitoring", false)
    attack_shape.set_deferred("disabled", true)
    combo_window = 0.24

func _try_hit(area: Area2D) -> void:
    if area == hurt_box or area in already_hit:
        return
    if area.has_method("receive_hit"):
        already_hit.append(area)
        area.receive_hit(attack_damage + combo * 5, Vector2(float(facing) * 220.0, -120.0))

func receive_hit(damage: int, impulse: Vector2) -> void:
    if dead or invulnerable_remaining > 0.0:
        return
    health = maxi(0, health - damage)
    invulnerable_remaining = 0.65
    velocity = impulse
    health_changed.emit(health, max_health)
    if health == 0:
        dead = true
        _play_if_available("death")
        died.emit()
    else:
        _play_if_available("hurt")

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("ui_cancel"):
        get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
