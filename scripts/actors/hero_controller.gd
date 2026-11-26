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
## Раскладка «марионетки» для ходьбы/бега/прыжка: верх тела и две ноги ниже подола плаща.
const HIP_Y: float = 318.0
const LEG_X0: float = 85.0
const LEG_SPLIT: float = 125.0
const LEG_X1: float = 180.0
const PIVOT_BACK_X: float = 105.0
const PIVOT_FRONT_X: float = 150.0
## Длина шага: сколько пикселей проходит герой за полный цикл (левый + правый шаг).
## Шаг привязан к скорости, поэтому ноги не скользят по земле.
const STRIDE_LEN: float = 135.0
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
var rig: Node2D
var rig_top: Sprite2D
var rig_cape: Sprite2D
var rig_leg_back: Sprite2D
var rig_leg_front: Sprite2D
var rig_tiles: Array[Texture2D] = []
var rig_fps: float = 12.0
var rig_torso: Node2D
var step_phase: float = 0.0
var step_angle: float = 0.0
var squash: float = 0.0
var squash_vel: float = 0.0
var torso_rot: float = 0.0
var torso_vel: float = 0.0
var floor_prev: bool = true
var leg_back_rot: float = 0.0
var leg_front_rot: float = 0.0
var leg_back_lift: float = 0.0
var leg_front_lift: float = 0.0
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
	_build_rig()
	attack_box.monitoring = false
	attack_shape.disabled = true
	attack_box.position = Vector2(ATTACK_REACH, -10.0)
	hurt_box.add_to_group("hero_hurtbox")
	_update_pose(0.0)
	health_changed.emit(health, max_health)


func is_dead() -> bool:
	return dead


func _physics_process(delta: float) -> void:
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
		return

	if _jump_just_pressed():
		jump_buffer_remaining = JUMP_BUFFER
	if jump_buffer_remaining > 0.0 and coyote_remaining > 0.0 and attack_remaining <= 0.0 and hurt_remaining <= 0.0:
		velocity.y = jump_velocity
		jump_buffer_remaining = 0.0
		coyote_remaining = 0.0
		squash = -0.16
		squash_vel = 0.0
		_spawn_dust(3, 14.0)

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
		var accel: float = 4200.0 if absf(axis) < 0.01 else 3400.0
		if not is_on_floor():
			accel = 2000.0
		velocity.x = move_toward(velocity.x, axis * speed, accel * delta)
		if combo_window > 0.0:
			combo_window -= delta
			if queued_attack and combo < 3:
				_start_attack(combo + 1)
			elif combo_window <= 0.0:
				combo = 0
				queued_attack = false

	var pre_vy: float = velocity.y
	move_and_slide()
	var landed: bool = is_on_floor() and not floor_prev
	floor_prev = is_on_floor()
	if landed and pre_vy > 160.0:
		var impact: float = clampf(pre_vy / 1000.0, 0.0, 1.0)
		squash = 0.08 + 0.20 * impact
		squash_vel = 0.0
		_spawn_dust(2 + int(impact * 4.0), 18.0)
	_update_animation(axis, sprinting)
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

## Вся визуальная часть считается здесь, каждый кадр экрана (60 FPS и выше),
## а не в физическом тике, поэтому движение плавное на любой частоте монитора.
func _process(delta: float) -> void:
	var dt: float = minf(delta, 1.0 / 30.0)
	animation_clock += delta
	# Пружина сжатия/растяжения: приземление, отрыв от земли.
	squash_vel += (-320.0 * squash - 20.0 * squash_vel) * dt
	squash += squash_vel * dt
	# Фаза шага растёт со скоростью: 0..1 — полный цикл (два шага).
	if is_on_floor() and not dead:
		var before: int = floori(step_phase * 2.0)
		step_phase += absf(velocity.x) * dt / STRIDE_LEN
		if step_phase >= 1.0:
			step_phase -= 1.0
		var after: int = floori(step_phase * 2.0)
		if after != before and absf(velocity.x) > 260.0:
			_spawn_dust(2, 10.0)
	step_angle = step_phase * TAU
	_update_pose(delta)


func _speed_ratio() -> float:
	return clampf((absf(velocity.x) - 100.0) / 240.0, 0.0, 1.0)


## Облачко пыли под ногами. Живёт в родителе героя, поэтому остаётся на месте.
func _spawn_dust(count: int, spread: float) -> void:
	var host: Node = get_parent()
	if host == null:
		return
	for i in range(count):
		var puff := Polygon2D.new()
		var points := PackedVector2Array()
		for j in range(10):
			var a: float = float(j) / 10.0 * TAU
			points.append(Vector2(cos(a), sin(a)) * randf_range(4.0, 8.0))
		puff.polygon = points
		puff.color = Color(0.80, 0.70, 0.54, 0.55)
		puff.z_index = 1
		host.add_child(puff)
		puff.global_position = global_position + Vector2(randf_range(-spread, spread), foot_y - 4.0)
		var drift := Vector2(randf_range(-26.0, 26.0) - velocity.x * 0.08, randf_range(-26.0, -8.0))
		var tween := puff.create_tween()
		tween.set_parallel(true)
		tween.tween_property(puff, "position", puff.position + drift, 0.45)
		tween.tween_property(puff, "scale", Vector2(2.2, 2.2), 0.45)
		tween.tween_property(puff, "modulate:a", 0.0, 0.45)
		tween.chain().tween_callback(puff.queue_free)


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
	elif absf(velocity.x) > 25.0:
		state = "run" if absf(velocity.x) > (move_speed + run_speed) * 0.5 else "walk"
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
		"walk", "run":
			speed = 40.0
			var sr: float = _speed_ratio()
			target_rot = lerpf(0.02, 0.07, sr) * f
			if not has_real_walk:
				# Тело выше всего, когда ноги под ним, и ниже в момент шага.
				target_off.y = -absf(cos(step_angle)) * lerpf(3.0, 8.0, sr)
				target_scale = Vector2(1.0 + 0.02 * sr, 1.0 - 0.02 * sr)
		"jump", "fall":
			var stretch: float = clampf(absf(velocity.y) / 900.0, 0.0, 1.0) * 0.10
			target_scale = Vector2(1.0 - stretch * 0.4, 1.0 + stretch)
			target_rot = (0.06 if pose_state == "jump" else -0.04) * f
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

	art.scale = Vector2(ART_SCALE, ART_SCALE) * pose_scale * Vector2(1.0 + squash * 0.6, 1.0 - squash)
	art.rotation = pose_rot
	art.position = Vector2(0.0, foot_y) + pose_off

	var alpha: float = 1.0
	if invulnerable_remaining > 0.0 and not dead and pose_state != "hurt":
		alpha = 0.55 if int(animation_clock * 24.0) % 2 == 0 else 1.0
	art.modulate = Color(tint.r, tint.g, tint.b, alpha)
	_update_rig(delta)


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

	rig_tiles = idle_tiles
	rig_fps = idle_fps
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


# ---------------------------------------------------------------- ноги (ходьба/бег/прыжок)

func _build_rig() -> void:
	if rig_tiles.is_empty():
		return
	var first := rig_tiles[0] as AtlasTexture
	if first == null or first.atlas == null:
		return
	var atlas: Texture2D = first.atlas
	rig = Node2D.new()
	rig.name = "LegRig"
	rig.visible = false
	add_child(rig)
	var half_w: float = float(FRAME_W) * 0.5
	# Порядок отрисовки: ноги сзади, потом плащ, потом верх тела на шарнире в бёдрах.
	rig_leg_back = _make_rig_sprite(atlas, rig)
	rig_leg_front = _make_rig_sprite(atlas, rig)
	rig_cape = _make_rig_sprite(atlas, rig)
	rig_torso = Node2D.new()
	rig_torso.position = Vector2(0.0, HIP_Y - FEET_ROW)
	rig.add_child(rig_torso)
	rig_top = _make_rig_sprite(atlas, rig_torso)
	# Начало координат узла rig — под ногами героя, единицы — пиксели кадра.
	rig_leg_back.position = Vector2(PIVOT_BACK_X - half_w, HIP_Y - FEET_ROW)
	rig_leg_back.offset = Vector2(LEG_X0 - PIVOT_BACK_X, 0.0)
	rig_leg_front.position = Vector2(PIVOT_FRONT_X - half_w, HIP_Y - FEET_ROW)
	rig_leg_front.offset = Vector2(LEG_SPLIT - PIVOT_FRONT_X, 0.0)
	rig_cape.position = Vector2(-half_w, HIP_Y - FEET_ROW)
	rig_top.position = Vector2(-half_w, -HIP_Y)
	# Тот же материал, что и у основного спрайта: белая форма работает и на ногах.
	if art.material != null:
		for part in [rig_leg_back, rig_leg_front, rig_cape, rig_top]:
			part.material = art.material


func _make_rig_sprite(atlas: Texture2D, parent: Node) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = atlas
	sprite.centered = false
	sprite.region_enabled = true
	sprite.region_filter_clip_enabled = true
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	parent.add_child(sprite)
	return sprite


func _update_rig(delta: float) -> void:
	if rig == null:
		return
	var use_rig: bool = pose_state == "jump" or pose_state == "fall" \
		or ((pose_state == "walk" or pose_state == "run") and not has_real_walk)
	rig.visible = use_rig
	art.visible = not use_rig
	if not use_rig:
		torso_rot = 0.0
		torso_vel = 0.0
		return
	var dt: float = minf(delta, 1.0 / 30.0)

	# Текущий кадр idle: плащ и волосы продолжают колыхаться.
	var tile := rig_tiles[int(animation_clock * rig_fps) % rig_tiles.size()] as AtlasTexture
	var o: Vector2 = tile.region.position
	var leg_h: float = float(FRAME_H) - HIP_Y
	rig_top.region_rect = Rect2(o.x, o.y, float(FRAME_W), HIP_Y)
	rig_cape.region_rect = Rect2(o.x, o.y + HIP_Y, LEG_X0, leg_h)
	rig_leg_back.region_rect = Rect2(o.x + LEG_X0, o.y + HIP_Y, LEG_SPLIT - LEG_X0, leg_h)
	rig_leg_front.region_rect = Rect2(o.x + LEG_SPLIT, o.y + HIP_Y, LEG_X1 - LEG_SPLIT, leg_h)

	# Углы и подъём ног. Назад — положительный угол, вперёд — отрицательный.
	var target_back: float = 0.0
	var target_front: float = 0.0
	var lift_back: float = 0.0
	var lift_front: float = 0.0
	var torso_target: float = 0.0
	match pose_state:
		"walk", "run":
			var sr: float = _speed_ratio()
			# При остановке шаг плавно сходит на нет, без рывка в стойку.
			var fade: float = clampf(absf(velocity.x) / 120.0, 0.0, 1.0)
			var amp: float = deg_to_rad(lerpf(12.0, 34.0, sr)) * fade
			var lift: float = lerpf(6.0, 13.0, sr) * fade
			target_back = amp * sin(step_angle)
			target_front = -target_back
			# Ступня поднимается в середине махового движения, когда нога идёт вперёд.
			lift_back = lift * maxf(0.0, -cos(step_angle))
			lift_front = lift * maxf(0.0, cos(step_angle))
			torso_target = lerpf(0.03, 0.11, sr) + sin(step_angle * 2.0) * 0.02 * fade
		"jump":
			var rise: float = clampf(-velocity.y / absf(jump_velocity), 0.0, 1.0)
			target_back = deg_to_rad(10.0 + 24.0 * rise)
			target_front = -deg_to_rad(14.0 + 26.0 * rise)
			lift_back = 4.0 + 6.0 * rise
			lift_front = 6.0 + 10.0 * rise
			torso_target = 0.05
		"fall":
			var drop: float = clampf(velocity.y / 700.0, 0.0, 1.0)
			target_back = deg_to_rad(10.0 - 6.0 * drop)
			target_front = -deg_to_rad(14.0 - 8.0 * drop)
			lift_back = 4.0 - 2.0 * drop
			lift_front = 6.0 - 4.0 * drop
			torso_target = -0.02

	var k: float = 1.0 if delta <= 0.0 else 1.0 - exp(-40.0 * delta)
	leg_back_rot = lerpf(leg_back_rot, target_back, k)
	leg_front_rot = lerpf(leg_front_rot, target_front, k)
	leg_back_lift = lerpf(leg_back_lift, lift_back, k)
	leg_front_lift = lerpf(leg_front_lift, lift_front, k)
	rig_leg_back.rotation = leg_back_rot
	rig_leg_front.rotation = leg_front_rot
	rig_leg_back.position.y = HIP_Y - FEET_ROW - leg_back_lift
	rig_leg_front.position.y = HIP_Y - FEET_ROW - leg_front_lift

	# Корпус наклоняется вокруг бёдер на пружине: при смене темпа он слегка запаздывает и покачивается.
	torso_vel += ((torso_target - torso_rot) * 260.0 - torso_vel * 17.0) * dt
	torso_rot += torso_vel * dt
	rig_torso.rotation = torso_rot

	# Тот же трансформ, что у основного спрайта; взгляд влево — зеркало по X.
	rig.position = art.position
	rig.rotation = art.rotation
	rig.scale = Vector2(art.scale.x * (1.0 if facing >= 0 else -1.0), art.scale.y)
	rig.modulate = art.modulate


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
