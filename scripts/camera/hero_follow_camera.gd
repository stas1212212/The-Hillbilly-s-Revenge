extends Camera2D
## Side-scrolling camera: smoothly follows the hero, with directional look-ahead.
## Camera2D's level limits keep the view inside the painted background.

@export var look_ahead_distance: float = 130.0
@export var look_ahead_response: float = 4.0
@export var movement_deadzone: float = 12.0

@onready var hero: CharacterBody2D = get_parent() as CharacterBody2D

var target_look_ahead: float = 0.0

func _ready() -> void:
    position_smoothing_enabled = true
    position_smoothing_speed = 4.5
    limit_smoothed = true
    make_current()

func _physics_process(delta: float) -> void:
    if hero == null:
        return

    if hero.velocity.x > movement_deadzone:
        target_look_ahead = look_ahead_distance
    elif hero.velocity.x < -movement_deadzone:
        target_look_ahead = -look_ahead_distance

    # Exponential smoothing behaves consistently at different frame rates.
    var amount: float = 1.0 - exp(-look_ahead_response * delta)
    position.x = lerpf(position.x, target_look_ahead, amount)
