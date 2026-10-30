class_name HealthComponent
extends Node

signal health_changed(current: int, maximum: int)
signal died

@export_range(1, 10000) var max_health: int = 100
var current_health: int

func _ready() -> void:
    current_health = max_health
    health_changed.emit(current_health, max_health)

func take_damage(amount: int) -> void:
    if amount <= 0 or current_health <= 0:
        return
    current_health = maxi(0, current_health - amount)
    health_changed.emit(current_health, max_health)
    if current_health == 0:
        died.emit()

func heal(amount: int) -> void:
    if amount <= 0 or current_health <= 0:
        return
    current_health = mini(max_health, current_health + amount)
    health_changed.emit(current_health, max_health)
