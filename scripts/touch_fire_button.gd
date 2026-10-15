extends Control

var theme_id: String = "fire"
var pressed: bool = false

var _ignore_mouse_until_ms: int = 0
var _busy_until_ms: int = 0

const TOGGLE_LOCK_MS := 280
const MOUSE_GUARD_MS := 500


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	if custom_minimum_size.x < 8.0:
		custom_minimum_size = Vector2(118, 118)
	size = custom_minimum_size


func stop_firing() -> void:
	pressed = false
	_busy_until_ms = 0
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		_ignore_mouse_until_ms = Time.get_ticks_msec() + MOUSE_GUARD_MS
		if touch.pressed:
			_toggle()
		accept_event()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if Time.get_ticks_msec() < _ignore_mouse_until_ms:
			accept_event()
			return
		if event.pressed:
			_toggle()
		accept_event()


func _toggle() -> void:
	var now := Time.get_ticks_msec()
	if now < _busy_until_ms:
		return
	_busy_until_ms = now + TOGGLE_LOCK_MS
	pressed = not pressed
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.46
	var fill := Color(0.92, 0.22, 0.16, 0.96) if pressed else Color(0.62, 0.12, 0.12, 0.72)
	var ring := Color(1.0, 0.78, 0.42, 1.0) if pressed else Color(1.0, 0.42, 0.35, 0.8)
	var glow := Color(1.0, 0.35, 0.18, 0.28)
	var inner := Color(1.0, 0.92, 0.55, 0.95)
	if theme_id == "missile":
		fill = Color(0.95, 0.52, 0.12, 0.96) if pressed else Color(0.55, 0.28, 0.08, 0.74)
		ring = Color(1.0, 0.86, 0.42, 1.0) if pressed else Color(1.0, 0.62, 0.28, 0.82)
		glow = Color(1.0, 0.55, 0.12, 0.3)
		inner = Color(1.0, 0.94, 0.62, 0.95)
	draw_circle(center, radius + 5.0, Color(0.08, 0.04, 0.04, 0.45))
	if pressed:
		draw_circle(center, radius + 9.0, glow)
	draw_circle(center, radius, fill)
	draw_arc(center, radius, 0.0, TAU, 48, ring, 3.5, true)
	draw_arc(center, radius * 0.42, 0.0, TAU, 28, Color(1.0, 0.85, 0.8, 0.9), 2.4, true)
	draw_circle(center, 5.0, Color(1.0, 0.9, 0.85, 1.0))
	if pressed:
		draw_arc(center, radius * 0.68, 0.0, TAU, 36, inner, 2.2, true)
	if theme_id == "missile":
		draw_line(center + Vector2(0.0, -radius * 0.28), center + Vector2(0.0, radius * 0.22), Color(1.0, 0.92, 0.7, 0.9), 3.0, true)
