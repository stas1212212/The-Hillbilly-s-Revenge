class_name PerchPoint
extends Area2D

@export var perch_offset := Vector2(0, -12)
@export var concealment := 0.7

func can_perch(actor: Node2D) -> bool:
    return overlaps_body(actor)

func perch_position() -> Vector2:
    return global_position + perch_offset
