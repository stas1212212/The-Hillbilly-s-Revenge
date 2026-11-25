extends Area2D
## Яблоко: восстанавливает здоровье героя. Подбирается при касании.

@export var heal_amount: int = 25

var clock: float = 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 8 # слой героя
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 34.0
	shape.shape = circle
	add_child(shape)
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	clock += delta
	queue_redraw()


func _draw() -> void:
	var y: float = sin(clock * 3.0) * 4.0
	draw_circle(Vector2(0.0, y), 26.0, Color(1.0, 0.85, 0.5, 0.18 + 0.06 * sin(clock * 4.0)))
	draw_circle(Vector2(0.0, y), 13.0, Color("#c0392b"))
	draw_circle(Vector2(-4.0, y - 4.0), 4.0, Color(1.0, 0.7, 0.65, 0.8))
	draw_line(Vector2(0.0, y - 12.0), Vector2(3.0, y - 20.0), Color("#5b4426"), 2.5)
	draw_colored_polygon(PackedVector2Array([
		Vector2(3.0, y - 18.0), Vector2(14.0, y - 22.0), Vector2(9.0, y - 13.0)]), Color("#6f8f3a"))


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("hero") and body.has_method("heal"):
		var healed: bool = body.heal(heal_amount)
		if healed:
			queue_free()
