extends Node2D
## Поле у деревни: дорога с бандитами, лечилками и выходом в конце.
## Цель: победить всех бандитов и дойти до правого края дороги.

const BanditScript := preload("res://scripts/enemies/field_bandit.gd")
const PickupScript := preload("res://scripts/items/health_pickup.gd")

const GROUND_TOP: float = 650.0
const BANDIT_HALF_HEIGHT: float = 85.0
const GATE_X: float = 1880.0
const EXIT_X: float = 1925.0
const BANDIT_SPAWNS: Array = [820.0, 1130.0, 1420.0, 1700.0]
const PICKUP_SPAWNS: Array = [640.0, 1280.0, 1560.0]

@onready var hero = $Hero
@onready var hud: CanvasLayer = $CanvasLayer

var remaining: int = 0
var finished: bool = false
var game_over: bool = false
var gate_shape: CollisionShape2D
var exit_label: Label
var hp_fill: ColorRect
var hp_text: Label
var enemy_label: Label
var message_label: Label
var message_time: float = 0.0
var gate_message_cooldown: float = 0.0
var dim: ColorRect
var end_title: Label
var end_hint: Label
const HP_BAR_WIDTH: float = 298.0


func _ready() -> void:
	hero.z_index = 2
	_build_gate()
	_build_hud()
	_spawn_bandits()
	_spawn_pickups()
	hero.health_changed.connect(_on_hero_health_changed)
	hero.died.connect(_on_hero_died)
	_on_hero_health_changed(hero.health, hero.max_health)
	_update_enemy_label()
	_show_message("Дойди до конца дороги. Бандиты просто так не пропустят.", 5.0)


func _process(delta: float) -> void:
	message_time = maxf(0.0, message_time - delta)
	gate_message_cooldown = maxf(0.0, gate_message_cooldown - delta)
	if message_label != null:
		message_label.modulate.a = clampf(message_time, 0.0, 1.0)
	if finished or game_over:
		return
	if remaining > 0 and hero.global_position.x > GATE_X - 90.0 and gate_message_cooldown <= 0.0:
		gate_message_cooldown = 3.0
		_show_message("Путь закрыт. Победи оставшихся бандитов: %d" % remaining, 2.5)
	if remaining <= 0 and hero.global_position.x > EXIT_X:
		_finish()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		get_tree().reload_current_scene()


# ---------------------------------------------------------------- построение

func _build_gate() -> void:
	var gate := StaticBody2D.new()
	gate.position = Vector2(GATE_X, 360.0)
	gate_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(24.0, 820.0)
	gate_shape.shape = rect
	gate.add_child(gate_shape)
	add_child(gate)

	exit_label = Label.new()
	exit_label.text = "ВЫХОД В ДЕРЕВНЮ  →"
	exit_label.position = Vector2(1640.0, 430.0)
	exit_label.add_theme_font_size_override("font_size", 26)
	exit_label.add_theme_color_override("font_color", Color("#ffe7b0"))
	exit_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.8))
	exit_label.visible = false
	add_child(exit_label)


func _build_hud() -> void:
	var back := ColorRect.new()
	back.color = Color(0.0, 0.0, 0.0, 0.55)
	back.position = Vector2(26.0, 96.0)
	back.size = Vector2(304.0, 22.0)
	hud.add_child(back)

	hp_fill = ColorRect.new()
	hp_fill.color = Color("#c0392b")
	hp_fill.position = Vector2(29.0, 99.0)
	hp_fill.size = Vector2(HP_BAR_WIDTH, 16.0)
	hud.add_child(hp_fill)

	hp_text = _make_label(Vector2(34.0, 96.0), 16)
	hud.add_child(hp_text)

	enemy_label = _make_label(Vector2(1010.0, 22.0), 20)
	enemy_label.size = Vector2(240.0, 30.0)
	enemy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hud.add_child(enemy_label)

	message_label = _make_label(Vector2(190.0, 640.0), 22)
	message_label.size = Vector2(900.0, 40.0)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.modulate.a = 0.0
	hud.add_child(message_label)

	dim = ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.6)
	dim.position = Vector2.ZERO
	dim.size = Vector2(1280.0, 720.0)
	dim.visible = false
	hud.add_child(dim)

	end_title = _make_label(Vector2(0.0, 250.0), 54)
	end_title.size = Vector2(1280.0, 80.0)
	end_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_title.visible = false
	hud.add_child(end_title)

	end_hint = _make_label(Vector2(0.0, 345.0), 24)
	end_hint.size = Vector2(1280.0, 40.0)
	end_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_hint.text = "R — заново   •   Esc — меню"
	end_hint.visible = false
	hud.add_child(end_hint)


func _make_label(pos: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.position = pos
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("#f4ead8"))
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.85))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	return label


func _spawn_bandits() -> void:
	var holder := Node2D.new()
	holder.name = "Enemies"
	add_child(holder)
	for x in BANDIT_SPAWNS:
		var bandit := CharacterBody2D.new()
		bandit.set_script(BanditScript)
		bandit.position = Vector2(float(x), GROUND_TOP - BANDIT_HALF_HEIGHT)
		holder.add_child(bandit)
		bandit.connect("defeated", Callable(self, "_on_bandit_defeated"))
		remaining += 1


func _spawn_pickups() -> void:
	for x in PICKUP_SPAWNS:
		var apple := Area2D.new()
		apple.set_script(PickupScript)
		apple.position = Vector2(float(x), GROUND_TOP - 40.0)
		add_child(apple)


# ---------------------------------------------------------------- события

func _on_hero_health_changed(current: int, maximum: int) -> void:
	hp_fill.size.x = HP_BAR_WIDTH * float(current) / float(maxi(maximum, 1))
	hp_text.text = "%d / %d" % [current, maximum]


func _on_hero_died() -> void:
	game_over = true
	get_tree().create_timer(1.2).timeout.connect(_show_game_over)


func _on_bandit_defeated(_enemy: Node) -> void:
	remaining = maxi(0, remaining - 1)
	_update_enemy_label()
	if remaining == 0:
		gate_shape.set_deferred("disabled", true)
		exit_label.visible = true
		var tween := create_tween().set_loops()
		tween.tween_property(exit_label, "modulate:a", 0.45, 0.7)
		tween.tween_property(exit_label, "modulate:a", 1.0, 0.7)
		_show_message("Дорога свободна. Иди вправо!", 4.0)


func _update_enemy_label() -> void:
	enemy_label.text = "Бандитов осталось: %d" % remaining


func _show_message(text: String, seconds: float) -> void:
	message_label.text = text
	message_time = seconds + 1.0


func _show_game_over() -> void:
	dim.visible = true
	end_title.text = "ЭЛИАН ПАЛ"
	end_title.visible = true
	end_hint.visible = true


func _finish() -> void:
	finished = true
	dim.visible = true
	end_title.text = "ПРОЛОГ ПРОЙДЕН"
	end_title.visible = true
	end_hint.visible = true
