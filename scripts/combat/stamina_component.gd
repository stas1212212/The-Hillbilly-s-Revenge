class_name StaminaComponent
extends Node

signal stamina_changed(current: float, maximum: float)

@export var max_stamina := 100.0
@export var regen_per_second := 18.0
@export var regen_delay := 0.65
var current := 100.0
var delay_left := 0.0

func _ready() -> void:
    current = max_stamina

func _physics_process(delta: float) -> void:
    delay_left = maxf(0.0, delay_left - delta)
    if delay_left <= 0.0 and current < max_stamina:
        current = minf(max_stamina, current + regen_per_second * delta)
        stamina_changed.emit(current, max_stamina)

func spend(cost: float) -> bool:
    if cost < 0.0 or current < cost:
        return false
    current -= cost
    delay_left = regen_delay
    stamina_changed.emit(current, max_stamina)
    return true
