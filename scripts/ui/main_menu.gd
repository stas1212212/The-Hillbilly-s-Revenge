extends Control

const GAME_SCENE := "res://scenes/main.tscn"
const BG := preload("res://assets/menu/menu_background.svg")

var main_panel: VBoxContainer
var settings_panel: VBoxContainer
var info_panel: VBoxContainer
var background: TextureRect
var shade: ColorRect
var title_label: Label
var status_label: Label

func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _build_ui()
    _show_main()

func _build_ui() -> void:
    background = TextureRect.new()
    background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    background.texture = BG
    add_child(background)
    background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

    shade = ColorRect.new()
    shade.color = Color(0.035, 0.028, 0.044, 0.44)
    shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(shade)
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

    var left := VBoxContainer.new()
    left.position = Vector2(78, 80)
    left.custom_minimum_size = Vector2(490, 0)
    left.add_theme_constant_override("separation", 14)
    add_child(left)

    title_label = Label.new()
    title_label.text = "МЕСТЬ\nДЕРЕВЕНЩИНЫ"
    title_label.add_theme_font_size_override("font_size", 48)
    title_label.add_theme_color_override("font_color", Color("#e5d5c4"))
    title_label.add_theme_color_override("font_shadow_color", Color("#210e14"))
    title_label.add_theme_constant_override("shadow_offset_x", 3)
    title_label.add_theme_constant_override("shadow_offset_y", 4)
    left.add_child(title_label)

    var gap := Control.new()
    gap.custom_minimum_size.y = 36
    left.add_child(gap)

    main_panel = VBoxContainer.new()
    main_panel.add_theme_constant_override("separation", 11)
    left.add_child(main_panel)
    _add_button(main_panel, "Новая игра", _start_game)
    _add_button(main_panel, "Продолжить (скоро)", _unavailable, true)
    _add_button(main_panel, "Настройки", _show_settings)
    _add_button(main_panel, "Дополнительно", _show_info)
    _add_button(main_panel, "Выход", _quit)

    settings_panel = VBoxContainer.new()
    settings_panel.add_theme_constant_override("separation", 14)
    left.add_child(settings_panel)
    var settings_title := Label.new()
    settings_title.text = "НАСТРОЙКИ"
    settings_title.add_theme_font_size_override("font_size", 28)
    settings_panel.add_child(settings_title)
    var fullscreen := CheckButton.new()
    fullscreen.text = "Полный экран"
    fullscreen.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
    fullscreen.toggled.connect(_toggle_fullscreen)
    settings_panel.add_child(fullscreen)
    _add_button(settings_panel, "Назад", _show_main)

    info_panel = VBoxContainer.new()
    left.add_child(info_panel)
    var info := Label.new()
    info.text = "Ранняя версия. Сохранения и загрузка\nбудут добавлены позднее."
    info.add_theme_font_size_override("font_size", 19)
    info_panel.add_child(info)
    _add_button(info_panel, "Назад", _show_main)

    status_label = Label.new()
    status_label.text = "ПРОТОТИП • 0.1"
    status_label.add_theme_font_size_override("font_size", 16)
    status_label.add_theme_color_override("font_color", Color("#baa9a3"))
    status_label.position = Vector2(82, 650)
    add_child(status_label)

func _add_button(parent: VBoxContainer, caption: String, callback: Callable, disabled := false) -> void:
    var button := Button.new()
    button.text = caption
    button.custom_minimum_size = Vector2(370, 51)
    button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
    button.add_theme_font_size_override("font_size", 23)
    button.add_theme_color_override("font_color", Color("#e9dcd1"))
    button.add_theme_color_override("font_hover_color", Color("#f5c7b6"))
    button.disabled = disabled
    var normal := StyleBoxFlat.new()
    normal.bg_color = Color("#170e14cc")
    normal.border_color = Color("#8e6259")
    normal.set_border_width_all(1)
    normal.set_content_margin_all(8)
    button.add_theme_stylebox_override("normal", normal)
    var hover := normal.duplicate()
    hover.bg_color = Color("#49202bcc")
    hover.border_color = Color("#c69283")
    button.add_theme_stylebox_override("hover", hover)
    var pressed := hover.duplicate()
    pressed.bg_color = Color("#6c2933")
    button.add_theme_stylebox_override("pressed", pressed)
    button.pressed.connect(callback)
    parent.add_child(button)

func _show_main() -> void:
    main_panel.show()
    settings_panel.hide()
    info_panel.hide()

func _show_settings() -> void:
    main_panel.hide()
    settings_panel.show()
    info_panel.hide()

func _show_info() -> void:
    main_panel.hide()
    settings_panel.hide()
    info_panel.show()

func _start_game() -> void:
    get_tree().change_scene_to_file(GAME_SCENE)

func _unavailable() -> void:
    pass

func _toggle_fullscreen(enabled: bool) -> void:
    DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED)

func _quit() -> void:
    get_tree().quit()

func _unhandled_key_input(event: InputEvent) -> void:
    if event.is_action_pressed("ui_cancel"):
        _show_main()
