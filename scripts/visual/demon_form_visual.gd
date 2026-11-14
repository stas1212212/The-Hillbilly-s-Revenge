class_name DemonFormVisual
extends Node2D
## Visual-only spectral transformation for AnimatedSprite2D.
## Does not modify physics, collisions, health or combat damage.

const FORM_SHADER: Shader = preload("res://assets/shaders/elian_demon_form.gdshader")
const TRANSITION_SECONDS: float = 0.65

var sprite: AnimatedSprite2D
var shader_material: ShaderMaterial
var aura: PointLight2D
var motes: CPUParticles2D
var transition: Tween
var active: bool = false
var strength: float = 0.0
var elapsed: float = 0.0


func setup(hero_sprite: AnimatedSprite2D) -> void:
    sprite = hero_sprite
    shader_material = ShaderMaterial.new()
    shader_material.shader = FORM_SHADER
    # Unique material: other heroes and previews do not share its uniforms.
    sprite.material = shader_material
    shader_material.set_shader_parameter("form_strength", 0.0)

    aura = PointLight2D.new()
    aura.name = "SpectralAura"
    aura.position = Vector2(0, -74)
    aura.color = Color(0.67, 0.83, 1.0)
    aura.energy = 0.0
    aura.texture_scale = 2.2

    var gradient := Gradient.new()
    gradient.set_color(0, Color(1, 1, 1, 1))
    gradient.set_color(1, Color(1, 1, 1, 0))
    var halo_texture := GradientTexture2D.new()
    halo_texture.width = 128
    halo_texture.height = 128
    halo_texture.gradient = gradient
    halo_texture.fill = GradientTexture2D.FILL_RADIAL
    halo_texture.fill_from = Vector2(0.5, 0.5)
    halo_texture.fill_to = Vector2(0.5, 0.0)
    aura.texture = halo_texture
    add_child(aura)

    motes = CPUParticles2D.new()
    motes.name = "SpectralMotes"
    motes.position = Vector2(0, -62)
    motes.amount = 23
    motes.lifetime = 0.95
    motes.explosiveness = 0.0
    motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
    motes.emission_rect_extents = Vector2(24, 39)
    motes.direction = Vector2(0, -1)
    motes.spread = 32.0
    motes.gravity = Vector2(0, -7)
    motes.initial_velocity_min = 9.0
    motes.initial_velocity_max = 27.0
    motes.scale_amount_min = 1.0
    motes.scale_amount_max = 2.5
    motes.color = Color(0.76, 0.88, 1.0, 0.55)
    motes.emitting = false
    motes.z_index = -1
    add_child(motes)


func _process(delta: float) -> void:
    elapsed += delta
    if aura != null:
        var pulse := 1.0 + 0.12 * sin(elapsed * 3.0)
        aura.energy = strength * 0.56 * pulse


func set_active(enabled: bool) -> void:
    if sprite == null or active == enabled:
        return
    active = enabled

    if transition != null and transition.is_running():
        transition.kill()
    if enabled:
        motes.emitting = true

    transition = create_tween()
    transition.set_trans(Tween.TRANS_SINE)
    transition.set_ease(Tween.EASE_IN_OUT)
    transition.tween_method(_set_strength, strength, 1.0 if enabled else 0.0, TRANSITION_SECONDS)
    if not enabled:
        transition.tween_callback(_stop_motes)


func _set_strength(value: float) -> void:
    strength = value
    shader_material.set_shader_parameter("form_strength", value)


func _stop_motes() -> void:
    if not active:
        motes.emitting = false
