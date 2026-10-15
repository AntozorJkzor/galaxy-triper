extends Node3D

@onready var ship_preview: Node3D = $ShipPreview
@onready var menu_column: VBoxContainer = $MenuUI/Root/Margin/Layout/MenuColumn
@onready var play_button: Button = $MenuUI/Root/Margin/Layout/MenuColumn/PlayButton
@onready var settings_button: Button = $MenuUI/Root/Margin/Layout/MenuColumn/SettingsButton
@onready var quit_button: Button = $MenuUI/Root/Margin/Layout/MenuColumn/QuitButton

var settings_overlay: Control
var touch_toggle: CheckButton
var continue_button: Button
var continue_hint: Label


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_use_starter_preview()
	_build_continue_button()
	play_button.pressed.connect(_on_play_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	_build_settings_overlay()


func _use_starter_preview() -> void:
	if ship_preview == null:
		return
	var Ships := preload("res://scripts/ship_catalog.gd")
	var packed := load(String(Ships.spec(Ships.DEFAULT_ID)["model"])) as PackedScene
	if packed == null:
		return
	var xf := ship_preview.transform
	var parent := ship_preview.get_parent()
	var idx := ship_preview.get_index()
	parent.remove_child(ship_preview)
	ship_preview.free()
	ship_preview = packed.instantiate() as Node3D
	if ship_preview == null:
		return
	ship_preview.name = "ShipPreview"
	ship_preview.transform = xf
	Ships.apply_packed_albedo(ship_preview, Ships.albedo_for(Ships.spec(Ships.DEFAULT_ID)))
	parent.add_child(ship_preview)
	parent.move_child(ship_preview, idx)


func _process(delta: float) -> void:
	if ship_preview != null:
		ship_preview.rotate_y(0.32 * delta)


func _on_play_pressed() -> void:
	var settings := get_node_or_null("/root/GameSettings")
	if settings != null and settings.has_method("start_new_game"):
		settings.call("start_new_game")
	get_tree().change_scene_to_file(preload("res://scripts/planet_catalog.gd").scene_path(0, 0))


func _on_continue_pressed() -> void:
	var settings := get_node_or_null("/root/GameSettings")
	if settings == null or not bool(settings.call("has_save")):
		return
	if not bool(settings.call("load_latest_save")):
		return
	get_tree().change_scene_to_file(String(settings.call("continue_scene_path")))


func _on_quit_pressed() -> void:
	get_tree().quit()


func _on_settings_pressed() -> void:
	_show_settings(true)


func _build_continue_button() -> void:
	play_button.text = "NEW GAME"
	continue_button = play_button.duplicate() as Button
	continue_button.name = "ContinueButton"
	continue_button.unique_name_in_owner = false
	continue_button.text = "CONTINUE"
	var column := play_button.get_parent()
	column.add_child(continue_button)
	column.move_child(continue_button, play_button.get_index())
	for conn: Dictionary in continue_button.pressed.get_connections():
		continue_button.pressed.disconnect(conn["callable"])
	continue_button.pressed.connect(_on_continue_pressed)
	continue_hint = Label.new()
	continue_hint.name = "ContinueHint"
	continue_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	continue_hint.custom_minimum_size = Vector2(340, 0)
	continue_hint.add_theme_font_size_override("font_size", 14)
	continue_hint.add_theme_color_override("font_color", Color(0.49, 0.576, 0.659, 1.0))
	column.add_child(continue_hint)
	column.move_child(continue_hint, continue_button.get_index() + 1)
	_refresh_continue()


func _refresh_continue() -> void:
	var settings := get_node_or_null("/root/GameSettings")
	var has_save := settings != null and bool(settings.call("has_save"))
	if continue_button != null:
		continue_button.visible = has_save
	if continue_hint != null:
		continue_hint.visible = has_save
		if has_save:
			continue_hint.text = String(settings.call("save_summary"))


func _on_settings_back_pressed() -> void:
	_show_settings(false)


func _on_touch_toggled(pressed: bool) -> void:
	var settings := get_node_or_null("/root/GameSettings")
	if settings != null:
		settings.call("set_touch_controls_enabled", pressed)


func _show_settings(open: bool) -> void:
	settings_overlay.visible = open
	menu_column.visible = not open
	if open and touch_toggle != null:
		touch_toggle.set_pressed_no_signal(_touch_setting_on())


func _build_settings_overlay() -> void:
	settings_overlay = Control.new()
	settings_overlay.name = "SettingsOverlay"
	settings_overlay.visible = false
	settings_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	settings_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	$MenuUI/Root.add_child(settings_overlay)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 72)
	margin.add_theme_constant_override("margin_top", 64)
	margin.add_theme_constant_override("margin_right", 72)
	margin.add_theme_constant_override("margin_bottom", 56)
	settings_overlay.add_child(margin)

	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(420, 0)
	column.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 16)
	margin.add_child(column)

	var title := Label.new()
	title.text = "SETTINGS"
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color(0.952941, 0.835294, 0.541176, 1.0))
	column.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Controls"
	subtitle.add_theme_font_size_override("font_size", 20)
	subtitle.add_theme_color_override("font_color", Color(0.556863, 0.784314, 0.909804, 1.0))
	column.add_child(subtitle)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 12)
	column.add_child(spacer)

	touch_toggle = CheckButton.new()
	touch_toggle.text = "Touch gamepad"
	touch_toggle.focus_mode = Control.FOCUS_NONE
	touch_toggle.custom_minimum_size = Vector2(340, 56)
	touch_toggle.add_theme_font_size_override("font_size", 20)
	touch_toggle.add_theme_color_override("font_color", Color(0.956863, 0.901961, 0.752941, 1.0))
	touch_toggle.button_pressed = _touch_setting_on()
	touch_toggle.toggled.connect(_on_touch_toggled)
	column.add_child(touch_toggle)

	var hint := Label.new()
	hint.text = "On-screen sticks and a fire button.\nOff by default — mouse and keyboard controls."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(360, 0)
	hint.add_theme_font_size_override("font_size", 16)
	hint.add_theme_color_override("font_color", Color(0.49, 0.576, 0.659, 1.0))
	column.add_child(hint)

	var stretch := Control.new()
	stretch.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(stretch)

	var back_button := Button.new()
	back_button.text = "BACK"
	back_button.custom_minimum_size = Vector2(340, 56)
	back_button.focus_mode = Control.FOCUS_NONE
	back_button.add_theme_font_size_override("font_size", 22)
	back_button.add_theme_color_override("font_color", Color(0.772549, 0.815686, 0.862745, 1.0))
	var quit_btn := quit_button
	if quit_btn != null:
		var normal: StyleBox = quit_btn.get_theme_stylebox("normal")
		var hover: StyleBox = quit_btn.get_theme_stylebox("hover")
		if normal != null:
			back_button.add_theme_stylebox_override("normal", normal)
		if hover != null:
			back_button.add_theme_stylebox_override("hover", hover)
			back_button.add_theme_stylebox_override("pressed", hover)
	back_button.pressed.connect(_on_settings_back_pressed)
	column.add_child(back_button)


func _touch_setting_on() -> bool:
	var settings := get_node_or_null("/root/GameSettings")
	return settings != null and bool(settings.get("touch_controls_enabled"))
