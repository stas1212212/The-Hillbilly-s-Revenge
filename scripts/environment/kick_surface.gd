class_name KickSurface
extends Area2D

@export var kick_horizontal := 300.0
@export var kick_vertical := -240.0
@export var min_strength := 1.0

func kick_velocity(facing_away: int, strength: float) -> Vector2:
    var scaling := clampf(strength / 10.0, 0.75, 2.5)
    return Vector2(kick_horizontal * facing_away * scaling, kick_vertical * scaling)
