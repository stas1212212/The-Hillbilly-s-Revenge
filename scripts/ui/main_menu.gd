extends Control

const GAME_SCENE := "res://scenes/field_prologue.tscn"
const ART_PATH := "res://assets/menu/menu_art.png"
const FALLBACK := preload("res://assets/menu/menu_background.svg")

var ui_layer: Control
var background: TextureRect
var atmosphere: Node2D
var menu_buttons: Array[Button] = []
var menu_time := 0.0
var hovered_index := -1
var hover_progress: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
var settings_panel: PanelContainer
var message_panel: PanelContainer

func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _build()
    resized.connect(_layout)
    _layout()
    set_process(true)

func _build() -> void:
    var bg := TextureRect.new()
    bg.name = "MenuArtwork"
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
    if ResourceLoader.exists(ART_PATH):
        bg.texture = load(ART_PATH)
    else:
        bg.texture = FALLBACK
    add_child(bg)
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    background = bg

    atmosphere = Node2D.new()
    atmosphere.name = "AnimatedAtmosphere"
    atmosphere.set_script(load("res://scripts/ui/menu_atmosphere.gd"))
    atmosphere.z_index = 1
    add_child(atmosphere)

    ui_layer = Control.new()
    ui_layer.name = "ClickableMenu"
    ui_layer.mouse_filter = Control.MOUSE_FILTER_PASS
    add_child(ui_layer)

    # The labels and ornaments are painted into the reference image.
    # Transparent buttons sit exactly over those labels; hover shows a subtle glow.
    var entries := [
        ["Продолжить", Rect2(77, 304, 334, 47), _not_ready],
        ["Новая игра", Rect2(78, 359, 302, 43), _start_game],
        ["Загрузить", Rect2(78, 412, 302, 43), _not_ready],
        ["Настройки", Rect2(78, 465, 302, 43), _show_settings],
        ["Дополнительно", Rect2(78, 519, 302, 43), _show_info],
        ["Выход", Rect2(78, 573, 302, 43), _quit],
    ]
    for entry in entries:
        var button := Button.new()
        button.name = str(entry[0]).replace(" ", "_")
        button.tooltip_text = str(entry[0])
        button.text = ""
        button.focus_mode = Control.FOCUS_NONE
        button.position = entry[1].position
        button.size = entry[1].size
        button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
        var transparent := StyleBoxEmpty.new()
        button.add_theme_stylebox_override("normal", transparent)
        var hover := StyleBoxFlat.new()
        hover.bg_color = Color(0.65, 0.11, 0.16, 0.17)
        hover.border_color = Color(1.0, 0.45, 0.37, 0.7)
        hover.set_border_width_all(1)
        button.add_theme_stylebox_override("hover", hover)
        button.add_theme_stylebox_override("pressed", hover)
        button.pressed.connect(entry[2])
        ui_layer.add_child(button)
        var index := menu_buttons.size()
        menu_buttons.append(button)
        button.mouse_entered.connect(_on_hover.bind(index))
        button.mouse_exited.connect(_on_unhover.bind(index))

    settings_panel = _panel("НАСТРОЙКИ")
    var fullscreen := CheckButton.new()
    fullscreen.text = "Полный экран"
    fullscreen.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
    fullscreen.toggled.connect(_toggle_fullscreen)
    settings_panel.get_node("Margin/VBox").add_child(fullscreen)
    _back_button(settings_panel)

    message_panel = _panel("ИНФОРМАЦИЯ")
    var description := Label.new()
    description.text = "Раздел находится в разработке."
    description.add_theme_font_size_override("font_size", 17)
    message_panel.get_node("Margin/VBox").add_child(description)
    _back_button(message_panel)

func _panel(heading: String) -> PanelContainer:
    var panel := PanelContainer.new()
    panel.visible = false
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.045, 0.035, 0.055, 0.96)
    style.border_color = Color("#a65b58")
    style.set_border_width_all(2)
    panel.add_theme_stylebox_override("panel", style)
    add_child(panel)
    var margin := MarginContainer.new()
    margin.name = "Margin"
    margin.add_theme_constant_override("margin_left", 24)
    margin.add_theme_constant_override("margin_right", 24)
    margin.add_theme_constant_override("margin_top", 22)
    margin.add_theme_constant_override("margin_bottom", 22)
    panel.add_child(margin)
    var vbox := VBoxContainer.new()
    vbox.name = "VBox"
    vbox.add_theme_constant_override("separation", 16)
    margin.add_child(vbox)
    var label := Label.new()
    label.text = heading
    label.add_theme_font_size_override("font_size", 29)
    label.add_theme_color_override("font_color", Color("#f0d4c9"))
    vbox.add_child(label)
    return panel

func _back_button(panel: PanelContainer) -> void:
    var back := Button.new()
    back.text = "Назад"
    back.pressed.connect(_show_main)
    panel.get_node("Margin/VBox").add_child(back)

func _layout() -> void:
    if ui_layer == null:
        return
    var scale_factor := maxf(size.x / 1280.0, size.y / 720.0)
    ui_layer.scale = Vector2.ONE * scale_factor
    ui_layer.position = (size - Vector2(1280, 720) * scale_factor) / 2.0
    atmosphere.position = ui_layer.position
    atmosphere.scale = Vector2.ONE * scale_factor
    for panel in [settings_panel, message_panel]:
        panel.position = (size - Vector2(470, 230) * scale_factor) / 2.0
        panel.size = Vector2(470, 230) * scale_factor

func _show_main() -> void:
    settings_panel.hide()
    message_panel.hide()
    ui_layer.show()

func _show_settings() -> void:
    ui_layer.hide()
    message_panel.hide()
    settings_panel.show()

func _show_info() -> void:
    ui_layer.hide()
    settings_panel.hide()
    message_panel.show()

func _not_ready() -> void:
    _show_info()

func _start_game() -> void:
    get_tree().change_scene_to_file(GAME_SCENE)

func _toggle_fullscreen(enabled: bool) -> void:
    DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED)

func _quit() -> void:
    get_tree().quit()

func _unhandled_key_input(event: InputEvent) -> void:
    if event.is_action_pressed("ui_cancel"):
        _show_main()

func _process(delta: float) -> void:
    menu_time += delta
    # Gentle cinematic breathing: no hard movement or visible seams.
    if background != null:
        var zoom := 1.012 + sin(menu_time * 0.24) * 0.006
        background.pivot_offset = size * 0.5
        background.scale = Vector2.ONE * zoom
    if atmosphere != null:
        atmosphere.set("elapsed", menu_time)
        atmosphere.queue_redraw()
    for i in range(menu_buttons.size()):
        var target := 1.0 if i == hovered_index else 0.0
        hover_progress[i] = move_toward(hover_progress[i], target, delta * 5.0)
        var b := menu_buttons[i]
        # An animated crimson halo; labels remain part of the original art.
        b.modulate = Color(1.0, 0.91 + 0.09 * hover_progress[i], 0.91 + 0.09 * hover_progress[i])
        b.position.x = [77.0, 78.0, 78.0, 78.0, 78.0, 78.0][i] + hover_progress[i] * 4.0
        b.position.y = [304.0, 359.0, 412.0, 465.0, 519.0, 573.0][i]
        var box := b.get_theme_stylebox("hover")
        if box is StyleBoxFlat:
            box.bg_color = Color(0.73, 0.08, 0.12, 0.11 + 0.17 * hover_progress[i])
            box.border_color = Color(1.0, 0.43, 0.33, 0.45 + 0.45 * hover_progress[i])

func _on_hover(index: int) -> void:
    hovered_index = index

func _on_unhover(index: int) -> void:
    if hovered_index == index:
        hovered_index = -1
