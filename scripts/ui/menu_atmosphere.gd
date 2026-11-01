extends Node2D

# Animated overlay on top of the original illustration.
# Mist and falling crimson leaves are procedural and do not alter the image.
var elapsed := 0.0
const WIDTH := 1280.0
const HEIGHT := 720.0

func _draw() -> void:
    # Thin drifting fog across the distant ruined town, kept away from UI.
    for i in range(7):
        var phase := float(i) * 1.31
        var x := fposmod(410.0 + float(i) * 179.0 + elapsed * (7.0 + float(i % 3) * 3.0), 1660.0) - 160.0
        var y := 470.0 + sin(elapsed * 0.25 + phase) * 13.0 + float(i % 3) * 38.0
        var opacity := 0.025 + 0.013 * sin(elapsed * 0.3 + phase) ** 2
        draw_set_transform(Vector2(x, y), 0.0, Vector2(3.6, 0.35))
        draw_circle(Vector2.ZERO, 65.0, Color(0.76, 0.69, 0.75, opacity))
    draw_set_transform(Vector2.ZERO)

    # Slow windblown leaves, with reproducible positions.
    for i in range(22):
        var seed := float(i) * 2.399
        var speed := 17.0 + float(i % 5) * 8.0
        var x := fposmod(117.0 * float(i) + elapsed * speed, WIDTH + 180.0) - 90.0
        var y := fposmod(53.0 * float(i) + sin(elapsed * 0.7 + seed) * 24.0 + elapsed * (8.0 + float(i % 3) * 3.0), HEIGHT + 110.0) - 55.0
        var alpha := 0.26 + float(i % 4) * 0.11
        var p := Vector2(x, y)
        var angle := elapsed * 0.8 + seed
        var dir := Vector2(cos(angle), sin(angle))
        var side := Vector2(-dir.y, dir.x)
        var length := 3.0 + float(i % 4) * 1.3
        var points := PackedVector2Array([p + dir * length, p + side * (length * 0.5), p - dir * length, p - side * (length * 0.5)])
        draw_colored_polygon(points, Color(0.72, 0.11 + float(i % 3) * 0.035, 0.17, alpha))
