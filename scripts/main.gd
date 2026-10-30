extends Node2D

const PLAYER_SPEED := 280.0
const ATTACK_RANGE := 110.0
const ATTACK_COOLDOWN := 0.35
var player_pos := Vector2(320, 480)
var enemy_pos := Vector2(850, 480)
var enemy_health := 5
var player_facing := 1
var attack_timer := 0.0
var attack_flash := 0.0
var message := "WASD / arrows: move | Space / left click: attack"
var font: Font

func _ready() -> void:
    font = ThemeDB.fallback_font

func _process(delta: float) -> void:
    var direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
    if Input.is_key_pressed(KEY_A): direction.x -= 1.0
    if Input.is_key_pressed(KEY_D): direction.x += 1.0
    if Input.is_key_pressed(KEY_W): direction.y -= 1.0
    if Input.is_key_pressed(KEY_S): direction.y += 1.0
    player_pos += direction.limit_length() * PLAYER_SPEED * delta
    player_pos = player_pos.clamp(Vector2(40, 160), Vector2(1240, 645))
    if direction.x != 0: player_facing = 1 if direction.x > 0 else -1
    attack_timer = maxf(0.0, attack_timer - delta)
    attack_flash = maxf(0.0, attack_flash - delta)
    if (Input.is_key_pressed(KEY_SPACE) or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)) and attack_timer <= 0.0:
        attack()
    queue_redraw()

func attack() -> void:
    attack_timer = ATTACK_COOLDOWN
    attack_flash = 0.16
    if enemy_health > 0 and player_pos.distance_to(enemy_pos) < ATTACK_RANGE and (enemy_pos.x - player_pos.x) * player_facing >= -10:
        enemy_health -= 1
        if enemy_health == 0:
            message = "Training enemy defeated! Prototype complete."

func _draw() -> void:
    draw_rect(Rect2(0, 0, 1280, 720), Color("#161923"))
    draw_rect(Rect2(0, 555, 1280, 165), Color("#292c32"))
    for i in range(9):
        draw_line(Vector2(i * 180, 555), Vector2(i * 180 - 90, 720), Color("#38383c"), 2.0)
    draw_circle(player_pos, 30.0, Color("#d1b18a"))
    draw_rect(Rect2(player_pos + Vector2(-18, -54), Vector2(36, 35)), Color("#454d63"))
    draw_line(player_pos + Vector2(12 * player_facing, -4), player_pos + Vector2(58 * player_facing, -28), Color("#d2d2d5"), 7.0)
    if attack_flash > 0.0:
        draw_arc(player_pos, 82.0, -1.0 if player_facing > 0 else 2.1, 1.0 if player_facing > 0 else 4.2, 24, Color("#f3d7a1"), 9.0)
    if enemy_health > 0:
        draw_circle(enemy_pos, 31.0, Color("#8c404c"))
        draw_rect(Rect2(enemy_pos + Vector2(-35, -64), Vector2(70, 8)), Color("#321f27"))
        draw_rect(Rect2(enemy_pos + Vector2(-35, -64), Vector2(70.0 * enemy_health / 5.0, 8)), Color("#c94e58"))
    draw_string(font, Vector2(34, 46), "THE HILLBILLY'S REVENGE — combat sandbox", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("#eee3d5"))
    draw_string(font, Vector2(34, 85), message, HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color("#c4c5ca"))
    draw_string(font, Vector2(34, 118), "Temporary shapes only. Replace with hand-drawn sprites and AnimationPlayer.", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#969aa4"))
