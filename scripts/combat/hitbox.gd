class_name Hitbox
extends Area2D

@export_range(1, 10000) var damage: int = 10
@export var owner_group: StringName = &"player"
var active := false
var already_hit: Array[Node] = []

func begin_attack() -> void:
    already_hit.clear()
    active = true
    monitoring = true

func end_attack() -> void:
    active = false
    monitoring = false

func _ready() -> void:
    monitoring = false
    area_entered.connect(_on_area_entered)

func _on_area_entered(area: Area2D) -> void:
    if not active or not area is Hurtbox:
        return
    if area.is_in_group(owner_group) or area in already_hit:
        return
    already_hit.append(area)
    area.receive_hit(damage)
