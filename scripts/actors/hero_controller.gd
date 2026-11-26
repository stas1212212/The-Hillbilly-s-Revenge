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
var refined_idle_loaded: bool = false
var refined_walk_loaded: bool = false
var w_was_down: bool = false
var demon_form_visual: DemonFormVisual
var already_hit: Array[Node] = []


func _ready() -> void:
	add_to_group("hero")
	# Герой сталкивается с миром, но не отталкивается противниками.
	collision_layer = HERO_LAYER
	collision_mask = 1
	health = max_health

	var capsule := body_shape.shape as CapsuleShape2D
	if capsule != null:
		foot_y = capsule.height * 0.5 + body_shape.position.y

	# Возвращаем покадровые анимации, которые использовались до процедурного рига.
	_load_optional_sprite_strips()
	_load_refined_idle_frames()
	_load_idle_60_frames()
	_load_idle_25_frames()
	_load_walk_16_frames()

	art.centered = true
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	art.scale = Vector2(ART_SCALE, ART_SCALE)
	art.position = Vector2(0.0, foot_y)
	_apply_art_anchor()

	_setup_demon_form_visual()
	attack_box.monitoring = false
	attack_shape.disabled = true
	attack_box.position = Vector2(ATTACK_REACH, -10.0)
	hurt_box.add_to_group("hero_hurtbox")
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
		# Возвращено прежнее прямое управление скоростью без искусственного разгона.
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
		_play_if_available("death")
		died.emit()
	else:
		hurt_remaining = 0.28
		_play_if_available("hurt")


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

## Состояние выбирает полноценный кадр из SpriteFrames; сам рисунок не разрезается
## и не деформируется по частям.
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

	_play_if_available(state)
	if state.begins_with("attack_"):
		art.rotation = sin(animation_clock * 20.0) * 0.07 * float(facing)
	else:
		art.rotation = 0.0
	_apply_art_anchor()


func _play_if_available(anim_name: String) -> void:
	if art.sprite_frames != null and art.sprite_frames.has_animation(anim_name) and art.animation != anim_name:
		art.play(anim_name)


## Атласы idle имеют высоту 384, старые циклы ходьбы/бега — 256.
## Смещение рассчитывается по высоте кадра, чтобы ноги оставались на земле.
func _apply_art_anchor() -> void:
	if art.sprite_frames == null:
		return
	if not art.sprite_frames.has_animation(art.animation):
		return
	if art.sprite_frames.get_frame_count(art.animation) <= 0:
		return
	var frame_texture: Texture2D = art.sprite_frames.get_frame_texture(art.animation, art.frame)
	if frame_texture == null:
		return
	art.centered = true
	art.offset = Vector2(0.0, -float(frame_texture.get_height()) * 0.45)
	art.scale = Vector2(ART_SCALE, ART_SCALE)
	art.position = Vector2(0.0, foot_y)


## Import the optional 256x256, five-column character strips supplied in the art patch.
## The original one-frame SpriteFrames remain usable if the art has not been installed.
func _load_optional_sprite_strips() -> void:
	var names: Array[String] = [
		"idle", "walk", "run", "jump", "fall",
		"attack_1", "attack_2", "attack_3", "hurt", "death"
	]
	var directory := "res://assets/characters/hero/sprites/"
	if not ResourceLoader.exists(directory + "idle.png"):
		return
	var frames := art.sprite_frames.duplicate(true) as SpriteFrames
	for name in names:
		var path := directory + name + ".png"
		if not ResourceLoader.exists(path):
			continue
		var texture := load(path) as Texture2D
		if texture == null:
			continue
		if not frames.has_animation(name):
			frames.add_animation(name)
		for i in range(frames.get_frame_count(name) - 1, -1, -1):
			frames.remove_frame(name, i)
		var count: int = int(texture.get_width() / 256)
		for i in range(count):
			var atlas := AtlasTexture.new()
			atlas.atlas = texture
			atlas.region = Rect2(i * 256, 0, 256, 256)
			frames.add_frame(name, atlas)
		frames.set_animation_speed(name, 16.0 if name == "run" else 12.0)
		frames.set_animation_loop(name, name in ["idle", "walk", "run"])
	art.sprite_frames = frames
	art.centered = true
	art.play("idle")

## The clean 12-frame idle atlas is optional. Until its PNG is installed,
## the existing project animations still work without missing-file errors.
func _load_refined_idle_frames() -> void:
	const IDLE_ATLAS_PATH: String = "res://assets/characters/hero/idle/elian_idle_12.png"
	if not ResourceLoader.exists(IDLE_ATLAS_PATH):
		return

	var texture: Texture2D = load(IDLE_ATLAS_PATH) as Texture2D
	if texture == null:
		return
	if texture.get_width() != 3072 or texture.get_height() != 384:
		push_warning("Elian idle atlas must be 3072x384 (12 frames of 256x384).")
		return

	var frames: SpriteFrames = art.sprite_frames.duplicate(true) as SpriteFrames
	if frames == null:
		return
	if not frames.has_animation("idle"):
		frames.add_animation("idle")
	for i in range(frames.get_frame_count("idle") - 1, -1, -1):
		frames.remove_frame("idle", i)
	for i in range(12):
		var tile := AtlasTexture.new()
		tile.atlas = texture
		tile.region = Rect2(i * 256, 0, 256, 384)
		frames.add_frame("idle", tile)

	frames.set_animation_speed("idle", 8.0)
	frames.set_animation_loop("idle", true)
	art.sprite_frames = frames
	refined_idle_loaded = true
	art.play("idle")


## Prefer the refined 60-frame standing atlas when installed. The file is
## optional so existing projects still run if the PNG hasn't been copied yet.
## Layout: 10 columns, 6 rows; each frame is 256x384 pixels.
func _load_idle_60_frames() -> void:
	const IDLE_60_PATH: String = "res://assets/characters/hero/idle/elian_idle_60.png"
	if not ResourceLoader.exists(IDLE_60_PATH):
		return

	var texture: Texture2D = load(IDLE_60_PATH) as Texture2D
	if texture == null:
		return
	if texture.get_width() != 2560 or texture.get_height() != 2304:
		push_warning("Elian idle 60 atlas must be 2560x2304 (10x6 frames, 256x384 each).")
		return

	var frames: SpriteFrames = art.sprite_frames.duplicate(true) as SpriteFrames
	if frames == null:
		return
	if not frames.has_animation("idle"):
		frames.add_animation("idle")
	for frame_index in range(frames.get_frame_count("idle") - 1, -1, -1):
		frames.remove_frame("idle", frame_index)
	for frame_index in range(60):
		var atlas_frame := AtlasTexture.new()
		atlas_frame.atlas = texture
		atlas_frame.region = Rect2(
			(frame_index % 10) * 256,
			int(frame_index / 10) * 384,
			256, 384
		)
		frames.add_frame("idle", atlas_frame)

	frames.set_animation_speed("idle", 30.0)
	frames.set_animation_loop("idle", true)
	art.sprite_frames = frames
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	refined_idle_loaded = true
	art.play("idle")
	art.set_frame_and_progress(0, 0.0)


## Preferred latest idle: 25 cleaned, foot-aligned frames (5x5 x 256x384).
## This runs AFTER the old 60-frame loader, so users can keep that asset
## installed without accidentally playing it instead of the newer idle.
## No image -> graceful fallback to older idle assets.
func _load_idle_25_frames() -> void:
	const IDLE_25_PATH: String = "res://assets/characters/hero/idle/elian_idle_25.png"
	if not ResourceLoader.exists(IDLE_25_PATH):
		return

	var texture: Texture2D = load(IDLE_25_PATH) as Texture2D
	if texture == null:
		return
	if texture.get_width() != 1280 or texture.get_height() != 1920:
		push_warning("Elian idle 25 atlas must be 1280x1920 (5x5 frames of 256x384).")
		return

	var frames: SpriteFrames = art.sprite_frames.duplicate(true) as SpriteFrames
	if frames == null:
		return
	if not frames.has_animation("idle"):
		frames.add_animation("idle")
	for i in range(frames.get_frame_count("idle") - 1, -1, -1):
		frames.remove_frame("idle", i)
	for i in range(25):
		var tile := AtlasTexture.new()
		tile.atlas = texture
		tile.region = Rect2((i % 5) * 256, int(i / 5) * 384, 256, 384)
		frames.add_frame("idle", tile)

	frames.set_animation_speed("idle", 12.5)
	frames.set_animation_loop("idle", true)
	art.sprite_frames = frames
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	refined_idle_loaded = true
	art.play("idle")
	art.set_frame_and_progress(0, 0.0)


## Optional 16-frame side-view walking cycle, 4x4 cells at 256x384.
## No PNG installed -> keep existing five-frame walk animation.
func _load_walk_16_frames() -> void:
	const WALK_16_PATH: String = "res://assets/characters/hero/walk/elian_walk_16.png"
	if not ResourceLoader.exists(WALK_16_PATH):
		return

	var texture: Texture2D = load(WALK_16_PATH) as Texture2D
	if texture == null:
		return
	if texture.get_width() != 1024 or texture.get_height() != 1536:
		push_warning("Elian walk atlas must be 1024x1536 (4x4 frames of 256x384).")
		return

	var frames: SpriteFrames = art.sprite_frames.duplicate(true) as SpriteFrames
	if frames == null:
		return
	if not frames.has_animation("walk"):
		frames.add_animation("walk")
	for i in range(frames.get_frame_count("walk") - 1, -1, -1):
		frames.remove_frame("walk", i)
	for i in range(16):
		var tile := AtlasTexture.new()
		tile.atlas = texture
		tile.region = Rect2((i % 4) * 256, int(i / 4) * 384, 256, 384)
		frames.add_frame("walk", tile)

	frames.set_animation_speed("walk", 20.0)
	frames.set_animation_loop("walk", true)
	art.sprite_frames = frames
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	refined_walk_loaded = true


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
