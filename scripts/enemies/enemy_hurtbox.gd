extends Area2D
## Зона, по которой попадает удар героя. Герой ищет у Area2D метод receive_hit.

signal hit(damage: int, impulse: Vector2)


func receive_hit(damage: int, impulse: Vector2) -> void:
	hit.emit(damage, impulse)
