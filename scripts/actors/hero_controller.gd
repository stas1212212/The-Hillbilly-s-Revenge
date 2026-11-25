extends CharacterBody2D
## Элиан: движение, прыжок, комбо из трёх ударов, урон и отбрасывание.
##
## Анимация: «idle» (и «walk», если установлен walk-атлас) берутся из чистых
## атласов 256x384. Остальные состояния (бег, прыжок, удар, урон, смерть)
## собираются из того же чистого кадра и оживляются кодом: наклон, сжатие,
## выпад и дуга удара. Старые полосы assets/characters/hero/sprites/*.png
## были битой нарезкой (обрезанные кадры, мусор из соседних кадров) и больше
## не используются. Когда появятся настоящие кадры, их можно добавить в
## _build_sprite_frames() вместо процедурной позы.

signal health_changed(current: int, maximum: int)
signal died

const FRAME_W: int = 256
const FRAME_H: int = 384
## Нижний непрозрачный ряд пикселей в кадрах idle: ноги героя.
const FEET_ROW: float = 364.0
const ART_SCALE: float = 0.8
const ATTACK_REACH: float = 80.0
const HERO_LAYER: int = 8
const COYOTE_TIME: float = 0.10
const JUMP_BUFFER: float = 0.12

## Источники idle по приоритету: самый новый атлас, который установлен.
const IDLE_SOURCES: Array = [
	{"path": "res://assets/characters/hero/idle/elian_idle_25.png", "cols": 5, "rows": 5, "count": 25, "fps": 12.5},
	{"path": "res://assets/characters/hero/idle/elian_idle_60.png", "cols": 10, "rows": 6, "count": 60, "fps": 30.0},
	{"path": "res://assets/characters/hero/idle/elian_idle_12.png", "cols": 12, "rows": 1, "count": 12, "fps": 8.0},
]
const WALK_SOURCE: Dictionary = {"path": "res://assets/characters/hero/walk/elian_walk_16.png", "cols": 4, "rows": 4, "count": 16, "fps": 20.0}

@export var move_speed: float = 235.0
@export var run_speed: float = 340.0
@export var jump_velocity: float = -620.0
@export var gravity: float = 1500.0
@export var max_health: int = 100
@export var attack_damage: int = 20

@onready var art: AnimatedSprite2D = $AnimatedSprite2D
@onready var attack_box: Area2D = $AttackBox
@onready var attack_shape: CollisionShape2D = $AttackBox/CollisionShape2D
@onready var hurt_box: Area2D = $Hurtbox
@onready var body_shape: CollisionShape2D = $CollisionShape2D

var health: int = 100
var combo: int = 0
var attack_remaining: float = 0.0
var attack_total: float = 0.3
var combo_window: float = 0.0
var queued_attack: bool = false
var invulnerable_remaining: float = 0.0
var hurt_remaining: float = 0.0
var coyote_remaining: float = 0.0
var jump_buffer_remaining: float = 0.0
var facing: int = 1
var dead: bool = false
var animation_clock: float = 0.0
var foot_y: float = 47.0
var has_real_walk: bool = false
var w_was_down: bool = false
var pose_state: String = "idle"
var pose_scale: Vector2 = Vector2.ONE
var pose_rot: float = 0.0
var pose_off: Vector2 = Vector2.ZERO
var demon_form_visual: DemonFormVisual
var already_hit: Array[Node] = []


func _ready() -> void:
	add_to_group("hero")
	# Герой на своём слое, сталкивается только с миром (слой 1): враги его не толкают.
	collision_layer = HERO_LAYER
	collision_mask = 1
	health = max_health
	var capsule := body_shape.shape as CapsuleShape2D
	if capsule != null:
		foot_y = capsule.height * 0.5 + body_shape.position.y
	_build_sprite_frames()
	_setup_demon_form_visual()
	attack_box.monitoring = false
	attack_shape.disabled = true
	attack_box.position = Vector2(ATTACK_REACH, -10.0)
	hurt_box.add_to_group("hero_hurtbox")
	_update_pose(0.0)
	health_changed.emit(health, max_health)


func is_dead() -> bool:
	return dead


func _physics_process(delta: float) -> void:
	animation_clock += delta
	invulnerable_remaining = maxf(0.0, invulnerable_remaining - delta)
	hurt_remaining = maxf(0.0, hurt_remaining - delta)
	coyote_remaining = maxf(0.0, coyote_remaining - delta)
	jump_buffer_remaining = maxf(0.0, jump_buffer_remaining - delta)

	if is_on_floor():
		coyote_remaining = COYOTE_TIME
	else:
		velocity.y += gravity * delta

	if dead:
		velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
		move_and_slide()
		_update_pose(delta)
		return

	if _jump_just_pressed():
		jump_buffer_remaining = JUMP_BUFFER
	if jump_buffer_remaining > 0.0 and coyote_remaining > 0.0 and attack_remaining <= 0.0 and hurt_remaining <= 0.0:
		velocity.y = jump_velocity
		jump_buffer_remaining = 0.0
		coyote_remaining = 0.0

	var axis: float = Input.get_axis("ui_left", "ui_right")
	if Input.is_key_pressed(KEY_A):
		axis -= 1.0
	if Input.is_key_pressed(KEY_D):
		axis += 1.0
	axis = clampf(axis, -1.0, 1.0)
	var sprinting: bool = Input.is_key_pressed(KEY_SHIFT)
	var speed: float = run_speed if sprinting else move_speed
	if hurt_remaining > 0.0:
		axis = 0.0
	elif absf(axis) > 0.01 and attack_remaining <= 0.0:
		facing = -1 if axis < 0.0 else 1
		art.flip_h = facing < 0
		attack_box.position.x = ATTACK_REACH * float(facing)

	if _attack_held() and attack_remaining <= 0.0 and combo_window <= 0.0 and hurt_remaining <= 0.0:
		_start_attack(1)

	if hurt_remaining > 0.0:
		velocity.x = move_toward(velocity.x, 0.0, 500.0 * delta)
	elif attack_remaining > 0.0:
		attack_remaining -= delta
		velocity.x = move_toward(velocity.x, 0.0, 700.0 * delta)
		if _attack_held():
			queued_attack = true
		if attack_remaining <= 0.0:
			_finish_attack()
	else:
		velocity.x = axis * speed
		if combo_window > 0.0:
			combo_window -= delta
			if queued_attack and combo < 3:
				_start_attack(combo + 1)
			elif combo_window <= 0.0:
				combo = 0
				queued_attack = false

	move_and_slide()
	_update_animation(axis, sprinting)
	_update_pose(delta)
	if attack_box.monitoring:
		for area in attack_box.get_overlapping_areas():
			_try_hit(area)


func _jump_just_pressed() -> bool:
	var w_down: bool = Input.is_key_pressed(KEY_W)
	var w_edge: bool = w_down and not w_was_down
	w_was_down = w_down
	return Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("ui_up") or w_edge


func _attack_held() -> bool:
	return Input.is_key_pressed(KEY_J) or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)


# ---------------------------------------------------------------- бой

func _start_attack(index: int) -> void:
	combo = index
	queued_attack = false
	already_hit.clear()
	attack_total = 0.23 + float(index) * 0.035
	attack_remaining = attack_total
	combo_window = 0.0
	velocity.x = float(facing) * (150.0 + 40.0 * float(index))
	attack_shape.set_deferred("disabled", false)
	attack_box.set_deferred("monitoring", true)
	_spawn_slash(index)


func _finish_attack() -> void:
	attack_box.set_deferred("monitoring", false)
	attack_shape.set_deferred("disabled", true)
	combo_window = 0.24


func _try_hit(area: Area2D) -> void:
	if area == hurt_box or area in already_hit:
		return
	if area.has_method("receive_hit"):
		already_hit.append(area)
		area.receive_hit(attack_damage + combo * 5, Vector2(float(facing) * 240.0, -140.0))


func receive_hit(damage: int, impulse: Vector2) -> void:
	if dead or invulnerable_remaining > 0.0:
		return
	health = maxi(0, health - damage)
	invulnerable_remaining = 0.65
	velocity = impulse
	attack_remaining = 0.0
	combo_window = 0.0
	combo = 0
	queued_attack = false
	_finish_attack()
	combo_window = 0.0
	health_changed.emit(health, max_health)
	if health == 0:
		dead = true
		pose_state = "death"
		_play_if_available("death")
		died.emit()
	else:
		hurt_remaining = 0.28


func heal(amount: int) -> bool:
	if dead or health >= max_health:
		return false
	health = mini(max_health, health + amount)
	health_changed.emit(health, max_health)
	return true


## Дуга удара: белый полумесяц перед героем, быстро гаснет.
func _spawn_slash(index: int) -> void:
	var slash := Line2D.new()
	slash.z_index = 5
	slash.width = 8.0 + float(index) * 3.0
	slash.default_color = Color(1.0, 0.95, 0.85, 0.9)
	slash.begin_cap_mode = Line2D.LINE_CAP_ROUND
	slash.end_cap_mode = Line2D.LINE_CAP_ROUND
	var radius: float = 100.0 + 12.0 * float(index)
	var from_angle: float = deg_to_rad(-75.0)
	var to_angle: float = deg_to_rad(45.0)
	if index == 2:
		from_angle = deg_to_rad(50.0)
		to_angle = deg_to_rad(-60.0)
	var centre := Vector2(float(facing) * 10.0, -35.0)
	for i in range(13):
		var a: float = lerpf(from_angle, to_angle, float(i) / 12.0)
		slash.add_point(centre + Vector2(cos(a) * float(facing), sin(a)) * radius)
	add_child(slash)
	var tween := create_tween()
	tween.tween_property(slash, "modulate:a", 0.0, 0.2)
	tween.tween_callback(slash.queue_free)


# ---------------------------------------------------------------- анимация

func _update_animation(axis: float, sprinting: bool) -> void:
	var state: String = "idle"
	if dead:
		state = "death"
	elif hurt_remaining > 0.0:
		state = "hurt"
	elif attack_remaining > 0.0:
		state = "attack_" + str(combo)
	elif not is_on_floor():
		state = "jump" if velocity.y < 0.0 else "fall"
	elif absf(axis) > 0.01:
		state = "run" if sprinting else "walk"
	pose_state = state
	_play_if_available(state)


func _play_if_available(anim_name: String) -> void:
	if art.sprite_frames != null and art.sprite_frames.has_animation(anim_name) and art.animation != anim_name:
		art.play(anim_name)


## Поза поверх кадра. Точка вращения и масштаба — под ногами героя.
func _update_pose(delta: float) -> void:
	var f: float = float(facing)
	var target_scale: Vector2 = Vector2.ONE
	var target_rot: float = 0.0
	var target_off: Vector2 = Vector2.ZERO
	var tint: Color = Color.WHITE
	var speed: float = 16.0

	match pose_state:
		"walk":
			target_rot = 0.04 * f
			if not has_real_walk:
				target_off.y = -absf(sin(animation_clock * 9.0)) * 5.0
				target_rot = 0.06 * f + sin(animation_clock * 9.0) * 0.015
		"run":
			target_rot = 0.13 * f
			target_scale = Vector2(1.03, 0.97)
			target_off.y = -absf(sin(animation_clock * 13.0)) * 8.0
		"jump":
			target_scale = Vector2(0.93, 1.08)
			target_rot = 0.08 * f
		"fall":
			target_scale = Vector2(0.96, 1.05)
			target_rot = -0.05 * f
		"attack_1", "attack_2", "attack_3":
			speed = 28.0
			var big: float = 1.4 if pose_state == "attack_3" else 1.0
			var p: float = 1.0 - attack_remaining / maxf(attack_total, 0.001)
			var windup: float = 0.3
			if p < windup:
				var w: float = p / windup
				target_rot = -0.16 * f * w
				target_off.x = -6.0 * f * w
			else:
				var s: float = minf((p - windup) / (windup * 1.2), 1.0)
				target_rot = lerpf(-0.16, 0.22, s) * f * big
				target_off.x = (-6.0 + 34.0 * s) * f * big
				target_scale = Vector2(1.04, 0.97)
		"hurt":
			target_rot = -0.22 * f
			target_off.x = -10.0 * f
			tint = Color(1.0, 0.55, 0.55)
		"death":
			speed = 7.0
			target_rot = -1.5 * f
			target_off = Vector2(-26.0 * f, -30.0)

	var k: float = 1.0 if delta <= 0.0 else 1.0 - exp(-speed * delta)
	pose_scale = pose_scale.lerp(target_scale, k)
	pose_rot = lerpf(pose_rot, target_rot, k)
	pose_off = pose_off.lerp(target_off, k)

	art.scale = Vector2(ART_SCALE, ART_SCALE) * pose_scale
	art.rotation = pose_rot
	art.position = Vector2(0.0, foot_y) + pose_off

	var alpha: float = 1.0
	if invulnerable_remaining > 0.0 and not dead and pose_state != "hurt":
		alpha = 0.55 if int(animation_clock * 24.0) % 2 == 0 else 1.0
	art.modulate = Color(tint.r, tint.g, tint.b, alpha)


## Собирает SpriteFrames из чистых атласов. Все кадры 256x384.
func _build_sprite_frames() -> void:
	var idle_tiles: Array[Texture2D] = []
	var idle_fps: float = 12.0
	for source in IDLE_SOURCES:
		idle_tiles = _slice_atlas(source)
		if not idle_tiles.is_empty():
			idle_fps = float(source["fps"])
			break
	if idle_tiles.is_empty():
		push_warning("Hero: не найден ни один чистый idle-атлас, оставляю кадры из сцены.")
		return

	var walk_tiles: Array[Texture2D] = _slice_atlas(WALK_SOURCE)
	has_real_walk = not walk_tiles.is_empty()

	var frames := SpriteFrames.new()
	if frames.has_animation("default"):
		frames.remove_animation("default")
	var still: Array[Texture2D] = [idle_tiles[0]]
	var setup: Dictionary = {
		"idle": [idle_tiles, idle_fps, true],
		"walk": [walk_tiles if has_real_walk else idle_tiles, float(WALK_SOURCE["fps"]) if has_real_walk else idle_fps, true],
		"run": [walk_tiles if has_real_walk else idle_tiles, float(WALK_SOURCE["fps"]) * 1.35 if has_real_walk else idle_fps, true],
		"jump": [still, 1.0, false],
		"fall": [still, 1.0, false],
		"attack_1": [still, 1.0, false],
		"attack_2": [still, 1.0, false],
		"attack_3": [still, 1.0, false],
		"hurt": [still, 1.0, false],
		"death": [still, 1.0, false],
	}
	for anim_name in setup:
		var entry: Array = setup[anim_name]
		frames.add_animation(anim_name)
		frames.set_animation_speed(anim_name, float(entry[1]))
		frames.set_animation_loop(anim_name, bool(entry[2]))
		for tile in entry[0]:
			frames.add_frame(anim_name, tile)

	art.sprite_frames = frames
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	art.centered = true
	# Ноги в нижней строке кадра: сдвигаем текстуру так, чтобы ноги были в начале координат узла.
	art.offset = Vector2(0.0, -(FEET_ROW - float(FRAME_H) * 0.5))
	art.play("idle")


func _slice_atlas(source: Dictionary) -> Array[Texture2D]:
	var tiles: Array[Texture2D] = []
	var path: String = source["path"]
	if not ResourceLoader.exists(path):
		return tiles
	var texture := load(path) as Texture2D
	if texture == null:
		return tiles
	var cols: int = source["cols"]
	var rows: int = source["rows"]
	var count: int = source["count"]
	if texture.get_width() != cols * FRAME_W or texture.get_height() != rows * FRAME_H:
		push_warning("%s: ожидался атлас %dx%d, а он %dx%d." % [path, cols * FRAME_W, rows * FRAME_H, texture.get_width(), texture.get_height()])
		return tiles
	for i in range(count):
		var tile := AtlasTexture.new()
		tile.atlas = texture
		tile.region = Rect2((i % cols) * FRAME_W, floori(float(i) / float(cols)) * FRAME_H, FRAME_W, FRAME_H)
		tiles.append(tile)
	return tiles


# ---------------------------------------------------------------- белая форма

## Visual-only prototype. Calling this from story/ability code is also supported.
func set_demon_form(enabled: bool) -> void:
	if dead or demon_form_visual == null:
		return
	demon_form_visual.set_active(enabled)


func _setup_demon_form_visual() -> void:
	demon_form_visual = DemonFormVisual.new()
	demon_form_visual.name = "DemonFormVisual"
	add_child(demon_form_visual)
	demon_form_visual.setup(art)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F:
		if not dead and demon_form_visual != null:
			set_demon_form(not demon_form_visual.active)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
