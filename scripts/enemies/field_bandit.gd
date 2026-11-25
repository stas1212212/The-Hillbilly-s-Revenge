extends CharacterBody2D
## Бандит с дороги у деревни: патрулирует, замечает героя, замахивается и бьёт.
## Графики пока нет, поэтому силуэт рисуется кодом (_draw). Когда появятся
## спрайты, достаточно заменить _draw на AnimatedSprite2D.

signal defeated(enemy: Node)

const HurtboxScript := preload("res://scripts/enemies/enemy_hurtbox.gd")
const GRAVITY: float = 1500.0
const BODY_RADIUS: float = 24.0
const BODY_HEIGHT: float = 170.0
const WINDUP_TIME: float = 0.5
const RECOVER_TIME: float = 0.65

@export var max_health: int = 60
@export var attack_damage: int = 14
@export var patrol_range: float = 140.0
@export var walk_speed: float = 70.0
@export var chase_speed: float = 150.0
@export var sight_range: float = 460.0
@export var attack_range: float = 100.0

var health: int = 60
var facing: int = -1
var state: String = "patrol"
var state_time: float = 0.0
var clock: float = 0.0
var flash: float = 0.0
var home_x: float = 0.0
var patrol_dir: int = 1
var hero = null
var hurtbox: Area2D


func _ready() -> void:
	health = max_health
	home_x = global_position.x
	add_to_group("enemy")
	# Слой 4, сталкивается только с миром (слой 1), поэтому героя не толкает.
	collision_layer = 4
	collision_mask = 1

	var body_shape := CollisionShape2D.new()
	var capsule := CapsuleShape2D.new()
	capsule.radius = BODY_RADIUS
	capsule.height = BODY_HEIGHT
	body_shape.shape = capsule
	add_child(body_shape)

	hurtbox = Area2D.new()
	hurtbox.set_script(HurtboxScript)
	hurtbox.collision_layer = 2
	hurtbox.collision_mask = 0
	var hurt_shape := CollisionShape2D.new()
	var hurt_capsule := CapsuleShape2D.new()
	hurt_capsule.radius = BODY_RADIUS + 4.0
	hurt_capsule.height = BODY_HEIGHT
	hurt_shape.shape = hurt_capsule
	hurtbox.add_child(hurt_shape)
	hurtbox.connect("hit", Callable(self, "_on_hit"))
	add_child(hurtbox)

	hero = get_tree().get_first_node_in_group("hero")


func _physics_process(delta: float) -> void:
	clock += delta
	state_time += delta
	flash = maxf(0.0, flash - delta)
	if not is_on_floor():
		velocity.y += GRAVITY * delta

	if state == "dead":
		velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
		move_and_slide()
		queue_redraw()
		return

	var dx: float = 0.0
	var dy: float = 0.0
	var hero_alive: bool = false
	if hero != null and is_instance_valid(hero) and not hero.is_dead():
		hero_alive = true
		dx = hero.global_position.x - global_position.x
		dy = hero.global_position.y - global_position.y
	var dist: float = absf(dx)

	match state:
		"patrol":
			var target_x: float = home_x + float(patrol_dir) * patrol_range
			if (patrol_dir > 0 and global_position.x >= target_x) or (patrol_dir < 0 and global_position.x <= target_x):
				patrol_dir = -patrol_dir
			facing = patrol_dir
			velocity.x = float(patrol_dir) * walk_speed
			if hero_alive and dist < sight_range and absf(dy) < 160.0:
				_set_state("chase")
		"chase":
			if not hero_alive or dist > sight_range * 1.6:
				_set_state("patrol")
			else:
				facing = 1 if dx > 0.0 else -1
				if dist <= attack_range:
					velocity.x = 0.0
					_set_state("windup")
				else:
					velocity.x = float(facing) * chase_speed
		"windup":
			velocity.x = 0.0
			if state_time >= WINDUP_TIME:
				_strike(hero_alive, dist, dy)
				_set_state("recover")
		"recover":
			velocity.x = move_toward(velocity.x, 0.0, 800.0 * delta)
			if state_time >= RECOVER_TIME:
				_set_state("chase")
		"hurt":
			velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
			if state_time >= 0.3:
				_set_state("chase")

	move_and_slide()
	queue_redraw()


func _set_state(new_state: String) -> void:
	state = new_state
	state_time = 0.0


func _strike(hero_alive: bool, dist: float, dy: float) -> void:
	if not hero_alive:
		return
	if dist <= attack_range + 25.0 and absf(dy) < 150.0:
		hero.receive_hit(attack_damage, Vector2(float(facing) * 280.0, -220.0))


func _on_hit(damage: int, impulse: Vector2) -> void:
	if state == "dead":
		return
	health -= damage
	flash = 0.12
	velocity = Vector2(impulse.x * 0.9, -60.0)
	if health <= 0:
		_die()
	else:
		_set_state("hurt")


func _die() -> void:
	state = "dead"
	hurtbox.set_deferred("monitorable", false)
	hurtbox.set_deferred("collision_layer", 0)
	defeated.emit(self)
	var tween := create_tween()
	tween.tween_interval(0.6)
	tween.tween_property(self, "modulate:a", 0.0, 0.6)
	tween.tween_callback(queue_free)


# ---------------------------------------------------------------- силуэт

func _draw() -> void:
	var f: float = float(facing)
	var foot: float = BODY_HEIGHT * 0.5
	var moving: bool = (state == "patrol" or state == "chase") and absf(velocity.x) > 5.0
	var bob: float = absf(sin(clock * 9.0)) * 4.0 if moving else 0.0
	var dark: Color = Color("#2b2126")
	var cloth: Color = Color("#4d2f2b")
	var skin: Color = Color("#b98b6a")
	if flash > 0.0:
		dark = Color.WHITE
		cloth = Color.WHITE
		skin = Color.WHITE
	if state == "dead":
		dark = dark.darkened(0.3)

	# тень
	var shadow: PackedVector2Array = PackedVector2Array()
	for i in range(16):
		var a: float = float(i) / 16.0 * TAU
		shadow.append(Vector2(cos(a) * 40.0, foot + sin(a) * 8.0))
	draw_colored_polygon(shadow, Color(0.0, 0.0, 0.0, 0.3))

	# ноги
	draw_rect(Rect2(-17.0, foot - 62.0 - bob, 13.0, 62.0 + bob), dark)
	draw_rect(Rect2(4.0, foot - 62.0 + bob, 13.0, 62.0 - bob), dark)
	# плащ-торс
	draw_colored_polygon(PackedVector2Array([
		Vector2(-24.0, foot - 128.0 - bob), Vector2(24.0, foot - 128.0 - bob),
		Vector2(34.0, foot - 48.0), Vector2(-34.0, foot - 48.0)]), cloth)
	draw_line(Vector2(-24.0, foot - 100.0 - bob), Vector2(24.0, foot - 100.0 - bob), dark, 5.0)
	# голова и капюшон
	var head: Vector2 = Vector2(5.0 * f, foot - 150.0 - bob)
	draw_circle(head, 17.0, skin)
	draw_colored_polygon(PackedVector2Array([
		head + Vector2(-19.0, 4.0), head + Vector2(-12.0, -20.0),
		head + Vector2(12.0, -20.0), head + Vector2(19.0, 4.0),
		head + Vector2(10.0 * f, -4.0)]), dark)
	draw_circle(head + Vector2(8.0 * f, 0.0), 2.5, Color("#e04a3a"))

	# дубина: опущена, поднята при замахе, вперёд при ударе
	var hand: Vector2 = Vector2(18.0 * f, foot - 100.0 - bob)
	var club: Vector2 = Vector2(12.0 * f, 44.0)
	if state == "windup":
		var w: float = clampf(state_time / WINDUP_TIME, 0.0, 1.0)
		club = Vector2(12.0 * f, lerpf(44.0, -78.0, w))
		draw_circle(head + Vector2(0.0, -34.0), 5.0 + 3.0 * w, Color(0.95, 0.3, 0.25, 0.35 + 0.5 * w))
	elif state == "recover" and state_time < 0.2:
		club = Vector2(78.0 * f, 28.0)
	draw_line(hand, hand + club, Color("#6b4a2e"), 9.0)
	draw_circle(hand + club, 10.0, Color("#5b3f28"))

	# полоска здоровья
	if health < max_health and state != "dead":
		var bar_w: float = 60.0
		var top: float = foot - 188.0
		draw_rect(Rect2(-bar_w * 0.5, top, bar_w, 6.0), Color(0.0, 0.0, 0.0, 0.6))
		draw_rect(Rect2(-bar_w * 0.5, top, bar_w * float(health) / float(max_health), 6.0), Color("#c0392b"))
