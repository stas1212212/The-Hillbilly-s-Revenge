extends CharacterBody2D
## Functional character prototype: movement, jump, three-hit combo, damage and knockback.
## Replace placeholder single-image frames with hand-drawn sprite sheets later.
signal health_changed(current: int, maximum: int)
signal died

@export var move_speed: float = 235.0
@export var run_speed: float = 340.0
@export var jump_velocity: float = -420.0
@export var gravity: float = 1100.0
@export var max_health: int = 100
@export var attack_damage: int = 20

@onready var art: AnimatedSprite2D = $AnimatedSprite2D
@onready var attack_box: Area2D = $AttackBox
@onready var attack_shape: CollisionShape2D = $AttackBox/CollisionShape2D
@onready var hurt_box: Area2D = $Hurtbox
var health: int = 100
var combo: int = 0
var attack_remaining: float = 0.0
var combo_window: float = 0.0
var queued_attack: bool = false
var invulnerable_remaining: float = 0.0
var facing: int = 1
var dead: bool = false
var animation_clock: float = 0.0
var visual_origin: Vector2
var baseline_art_scale: Vector2 = Vector2.ONE
var refined_idle_loaded: bool = false
var already_hit: Array[Node] = []

func _ready() -> void:
	health = max_health
	_load_optional_sprite_strips()
	visual_origin = art.position
	baseline_art_scale = art.scale
	_load_refined_idle_frames()
	_load_idle_60_frames()
	_load_idle_25_frames()
	attack_box.monitoring = false
	attack_shape.disabled = true
	hurt_box.add_to_group("hero_hurtbox")
	health_changed.emit(health, max_health)

func _physics_process(delta: float) -> void:
	animation_clock += delta
	invulnerable_remaining = maxf(0.0, invulnerable_remaining - delta)
	if not is_on_floor():
		velocity.y += gravity * delta

	if dead:
		velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
		move_and_slide()
		return

	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = jump_velocity

	var axis: float = Input.get_axis("ui_left", "ui_right")
	if Input.is_key_pressed(KEY_A):
		axis -= 1.0
	if Input.is_key_pressed(KEY_D):
		axis += 1.0
	axis = clampf(axis, -1.0, 1.0)
	var sprinting: bool = Input.is_key_pressed(KEY_SHIFT)
	var speed: float = run_speed if sprinting else move_speed
	if absf(axis) > 0.01:
		facing = -1 if axis < 0.0 else 1
		art.flip_h = facing < 0
		attack_box.position.x = 45.0 * facing

	if Input.is_key_pressed(KEY_J) and attack_remaining <= 0.0 and combo_window <= 0.0:
		_start_attack(1)

	if attack_remaining > 0.0:
		attack_remaining -= delta
		velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
		if Input.is_action_just_pressed("ui_accept"):
			pass
		if Input.is_key_pressed(KEY_J):
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
	if attack_box.monitoring:
		for area in attack_box.get_overlapping_areas():
			_try_hit(area)

func _update_animation(axis: float, sprinting: bool) -> void:
	if attack_remaining > 0.0:
		_play_if_available("attack_" + str(combo))
		art.rotation = sin(animation_clock * 20.0) * 0.07 * facing
	elif not is_on_floor():
		_play_if_available("jump" if velocity.y < 0.0 else "fall")
		art.rotation = 0.0
	elif absf(axis) > 0.01:
		_play_if_available("run" if sprinting else "walk")
		art.rotation = 0.0
	else:
		_play_if_available("idle")
		art.rotation = 0.0

	if refined_idle_loaded and art.animation == "idle":
		# Новая стойка Еліана
		art.scale = Vector2(1.04, 1.04)
		art.position = Vector2(0.0, -130.0)
	else:
		# Остальные временные анимации
		art.scale = Vector2(1.45, 1.45)
		art.position = Vector2(0.0, -100.0)

		if absf(axis) > 0.01 and is_on_floor():
			art.position.y += sin(animation_clock * 12.0) * 2.0


func _play_if_available(name: String) -> void:
	if art.sprite_frames != null and art.sprite_frames.has_animation(name) and art.animation != name:
		art.play(name)

func _start_attack(index: int) -> void:
	combo = index
	queued_attack = false
	already_hit.clear()
	attack_remaining = 0.23 + float(index) * 0.035
	combo_window = 0.0
	attack_shape.set_deferred("disabled", false)
	attack_box.set_deferred("monitoring", true)

func _finish_attack() -> void:
	attack_box.set_deferred("monitoring", false)
	attack_shape.set_deferred("disabled", true)
	combo_window = 0.24

func _try_hit(area: Area2D) -> void:
	if area == hurt_box or area in already_hit:
		return
	if area.has_method("receive_hit"):
		already_hit.append(area)
		area.receive_hit(attack_damage + combo * 5, Vector2(float(facing) * 220.0, -120.0))

func receive_hit(damage: int, impulse: Vector2) -> void:
	if dead or invulnerable_remaining > 0.0:
		return
	health = maxi(0, health - damage)
	invulnerable_remaining = 0.65
	velocity = impulse
	health_changed.emit(health, max_health)
	if health == 0:
		dead = true
		_play_if_available("death")
		died.emit()
	else:
		_play_if_available("hurt")


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
	art.scale = Vector2(0.6, 0.6)
	art.position.y = -14.0
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


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
