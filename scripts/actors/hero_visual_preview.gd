extends Node2D

# Visual-only preview: demonstrates a provisional side-view hero sprite.
# This is NOT the integrated combat controller or finished animation.
var elapsed := 0.0

func _process(delta: float) -> void:
    elapsed += delta
    $Hero.position.y = 463.0 + sin(elapsed * 2.5) * 2.0

func _draw() -> void:
    draw_rect(Rect2(0, 0, 1280, 720), Color("#252832"))
    draw_rect(Rect2(0, 590, 1280, 130), Color("#393b36"))
    draw_line(Vector2(0, 590), Vector2(1280, 590), Color("#817e66"), 3.0)
