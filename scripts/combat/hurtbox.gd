class_name Hurtbox
extends Area2D

@export var health: HealthComponent

func receive_hit(damage: int) -> void:
    if health != null:
        health.take_damage(damage)
