extends Control

const STICK_SCRIPT := preload("res://scripts/virtual_joystick.gd")
const FIRE_SCRIPT := preload("res://scripts/touch_fire_button.gd")
const SLIDER_SCRIPT := preload("res://scripts/touch_throttle_slider.gd")

const LOOK_DEADZONE := 0.2
const LOOK_SCALE := 0.42

signal pause_requested

var throttle_slider: Control
var look_stick: Control
var fire_button: Control
var missile_button: Control
var stop_button: Button
var pause_button: Button
var throttle_label: Label
var look_label: Label
var fire_label: Label
var missile_label: Label


func _ready() -> void:
	add_to_group("touch_controls")
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	_apply_enabled()


func get_move_vector() -> Vector2:
	return Vector2(0.0, get_throttle())


func get_throttle() -> float:
	if not _is_active() or throttle_slider == null:
		return 0.0
	return float(throttle_slider.get("value"))


func get_look_vector() -> Vector2:
	if not _is_active() or look_stick == null:
		return Vector2.ZERO
	return Vector2(look_stick.get("value"))


func is_firing() -> bool:
	if not _is_active() or fire_button == null or get_tree().paused:
		return false
	return bool(fire_button.get("pressed"))


func is_missile_firing() -> bool:
	if not _is_active() or missile_button == null or get_tree().paused:
		return false
	return bool(missile_button.get("pressed"))


func stop_firing() -> void:
	if fire_button != null and fire_button.has_method("stop_firing"):
		fire_button.call("stop_firing")
	if missile_button != null and missile_button.has_method("stop_firing"):
		missile_button.call("stop_firing")
	reset_throttle()
	if fire_label != null:
		fire_label.text = "FIRE"
	if missile_label != null:
		missile_label.text = "MISSILES"


func reset_throttle() -> void:
	if throttle_slider != null and throttle_slider.has_method("reset"):
		throttle_slider.call("reset")


func _process(_delta: float) -> void:
	_apply_enabled()
	var playing := not get_tree().paused and visible
	if throttle_slider != null:
		throttle_slider.visible = playing
	if look_stick != null:
		look_stick.visible = playing
	if fire_button != null:
		fire_button.visible = playing
	if missile_button != null:
		missile_button.visible = playing
	if stop_button != null:
		stop_button.visible = playing
	if throttle_label != null:
		throttle_label.visible = playing
	if look_label != null:
		look_label.visible = playing
	if fire_label != null:
		fire_label.visible = playing
		if fire_button != null:
			fire_label.text = "FIRE · ON" if bool(fire_button.get("pressed")) else "FIRE"
	if missile_label != null:
		missile_label.visible = playing
		if missile_button != null:
			missile_label.text = "MISSILES · ON" if bool(missile_button.get("pressed")) else "MISSILES"


func _build_ui() -> void:
	throttle_slider = SLIDER_SCRIPT.new()
	throttle_slider.name = "ThrottleSlider"
	add_child(throttle_slider)

	look_stick = STICK_SCRIPT.new()
	look_stick.name = "LookStick"
	look_stick.set("invert_y", true)
	look_stick.set("deadzone", LOOK_DEADZONE)
	look_stick.set("output_scale", LOOK_SCALE)
	add_child(look_stick)

	fire_button = FIRE_SCRIPT.new()
	fire_button.name = "FireButton"
	add_child(fire_button)

	missile_button = FIRE_SCRIPT.new()
	missile_button.name = "MissileButton"
	missile_button.set("theme_id", "missile")
	missile_button.custom_minimum_size = Vector2(96, 96)
	add_child(missile_button)

	stop_button = Button.new()
	stop_button.name = "StopButton"
	stop_button.text = "STOP"
	stop_button.focus_mode = Control.FOCUS_NONE
	stop_button.custom_minimum_size = Vector2(64, 48)
	stop_button.add_theme_font_size_override("font_size", 16)
	stop_button.add_theme_color_override("font_color", Color(0.96, 0.9, 0.75, 1.0))
	var stop_style := StyleBoxFlat.new()
	stop_style.bg_color = Color(0.16, 0.08, 0.08, 0.82)
	stop_style.set_border_width_all(2)
	stop_style.border_color = Color(0.95, 0.55, 0.35, 0.9)
	stop_style.set_corner_radius_all(10)
	stop_button.add_theme_stylebox_override("normal", stop_style)
	var stop_hover := stop_style.duplicate() as StyleBoxFlat
	stop_hover.bg_color = Color(0.28, 0.12, 0.1, 0.92)
	stop_button.add_theme_stylebox_override("hover", stop_hover)
	stop_button.add_theme_stylebox_override("pressed", stop_hover)
	stop_button.pressed.connect(reset_throttle)
	add_child(stop_button)

	pause_button = Button.new()
	pause_button.name = "TouchPause"
	pause_button.text = "II"
	pause_button.focus_mode = Control.FOCUS_NONE
	pause_button.custom_minimum_size = Vector2(56, 56)
	pause_button.add_theme_font_size_override("font_size", 22)
	pause_button.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0, 1.0))
	var pause_style := StyleBoxFlat.new()
	pause_style.bg_color = Color(0.08, 0.12, 0.2, 0.72)
	pause_style.set_border_width_all(1)
	pause_style.border_color = Color(0.7, 0.82, 1.0, 0.55)
	pause_style.set_corner_radius_all(10)
	pause_button.add_theme_stylebox_override("normal", pause_style)
	var pause_hover := pause_style.duplicate() as StyleBoxFlat
	pause_hover.bg_color = Color(0.14, 0.2, 0.32, 0.88)
	pause_button.add_theme_stylebox_override("hover", pause_hover)
	pause_button.add_theme_stylebox_override("pressed", pause_hover)
	pause_button.pressed.connect(func() -> void: pause_requested.emit())
	add_child(pause_button)
	pause_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	pause_button.offset_left = -80.0
	pause_button.offset_top = 18.0
	pause_button.offset_right = -24.0
	pause_button.offset_bottom = 74.0

	throttle_label = _make_caption("THROTTLE")
	look_label = _make_caption("LOOK")
	fire_label = _make_caption("FIRE")
	missile_label = _make_caption("MISSILES")
	add_child(throttle_label)
	add_child(look_label)
	add_child(fire_label)
	add_child(missile_label)

	resized.connect(_layout_controls)
	call_deferred("_layout_controls")


func _is_active() -> bool:
	return _touch_setting_on() and visible and is_visible_in_tree()


func _apply_enabled() -> void:
	visible = _touch_setting_on()


func _touch_setting_on() -> bool:
	var settings := get_node_or_null("/root/GameSettings")
	return settings != null and bool(settings.get("touch_controls_enabled"))


func _make_caption(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(0.75, 0.85, 0.95, 0.8))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _layout_controls() -> void:
	var slider_size := throttle_slider.custom_minimum_size if throttle_slider else Vector2(64, 252)
	var stick_size := look_stick.custom_minimum_size if look_stick else Vector2(172, 172)
	var fire_size := fire_button.custom_minimum_size if fire_button else Vector2(118, 118)
	var missile_size := missile_button.custom_minimum_size if missile_button else Vector2(96, 96)
	var stop_size := Vector2(maxi(int(slider_size.x), 72), 48)
	var bottom := 24.0
	var side := 18.0
	var gap := 14.0
	if stop_button != null:
		_place_free(stop_button, Vector2(side, size.y - stop_size.y - bottom), stop_size)
	if throttle_slider != null:
		_place_free(
			throttle_slider,
			Vector2(side + (stop_size.x - slider_size.x) * 0.5, size.y - stop_size.y - bottom - gap - slider_size.y),
			slider_size
		)
	var weapons_x := side + stop_size.x + 16.0
	if fire_button != null:
		_place_free(fire_button, Vector2(weapons_x, size.y - fire_size.y - bottom), fire_size)
	if missile_button != null:
		_place_free(
			missile_button,
			Vector2(weapons_x + (fire_size.x - missile_size.x) * 0.5, size.y - fire_size.y - bottom - missile_size.y - 40.0),
			missile_size
		)
	if look_stick != null:
		_place_free(look_stick, Vector2(size.x - stick_size.x - side, size.y - stick_size.y - bottom), stick_size)
	if throttle_label != null and throttle_slider != null:
		throttle_label.size = Vector2(slider_size.x, 20.0)
		throttle_label.position = Vector2(throttle_slider.position.x, throttle_slider.position.y - 22.0)
	if look_label != null and look_stick != null:
		look_label.size = Vector2(stick_size.x, 20.0)
		look_label.position = Vector2(look_stick.position.x, look_stick.position.y - 22.0)
	if fire_label != null and fire_button != null:
		fire_label.size = Vector2(fire_size.x, 20.0)
		fire_label.position = Vector2(fire_button.position.x, fire_button.position.y - 22.0)
	if missile_label != null and missile_button != null:
		missile_label.size = Vector2(missile_size.x, 20.0)
		missile_label.position = Vector2(missile_button.position.x, missile_button.position.y - 22.0)


func _place_free(control: Control, pos: Vector2, control_size: Vector2) -> void:
	control.set_anchors_preset(Control.PRESET_TOP_LEFT)
	control.position = pos
	control.size = control_size
