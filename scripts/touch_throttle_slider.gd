extends Control

@export var track_width: float = 16.0
@export var knob_radius: float = 22.0
@export var snap_to_zero: float = 0.07

var value: float = 0.0

var _pointer_id: int = -999

const POINTER_NONE := -999
const POINTER_MOUSE := -2


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(64, 252)
	size = custom_minimum_size


func reset() -> void:
	value = 0.0
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_press(touch.index, touch.position)
		else:
			_release(touch.index)
		accept_event()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		_move(drag.index, drag.position)
		accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if _pointer_id >= 0:
			accept_event()
			return
		if event.pressed:
			_press(POINTER_MOUSE, event.position)
		else:
			_release(POINTER_MOUSE)
		accept_event()
	elif event is InputEventMouseMotion and _pointer_id == POINTER_MOUSE:
		if event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			_move(POINTER_MOUSE, event.position)
		accept_event()


func _press(pointer_id: int, local_pos: Vector2) -> void:
	if _pointer_id != POINTER_NONE:
		return
	_pointer_id = pointer_id
	_update_from_pos(local_pos)


func _move(pointer_id: int, local_pos: Vector2) -> void:
	if _pointer_id != pointer_id:
		return
	_update_from_pos(local_pos)


func _release(pointer_id: int) -> void:
	if _pointer_id != pointer_id:
		return
	_pointer_id = POINTER_NONE
	if absf(value) < snap_to_zero:
		value = 0.0
	queue_redraw()


func _update_from_pos(local_pos: Vector2) -> void:
	var pad := knob_radius + 6.0
	var y := clampf(local_pos.y, pad, size.y - pad)
	var t := inverse_lerp(size.y - pad, pad, y)
	value = clampf(t * 2.0 - 1.0, -1.0, 1.0)
	queue_redraw()


func _knob_y() -> float:
	var pad := knob_radius + 6.0
	var t := (value + 1.0) * 0.5
	return lerpf(size.y - pad, pad, t)


func _draw() -> void:
	var center_x := size.x * 0.5
	var pad := knob_radius + 6.0
	var top := Vector2(center_x, pad)
	var bottom := Vector2(center_x, size.y - pad)
	var mid := Vector2(center_x, lerpf(bottom.y, top.y, 0.5))
	var knob := Vector2(center_x, _knob_y())
	draw_line(top, bottom, Color(0.06, 0.1, 0.16, 0.85), track_width + 10.0, true)
	draw_line(top, bottom, Color(0.22, 0.32, 0.44, 0.95), track_width, true)
	draw_line(top, bottom, Color(0.7, 0.86, 1.0, 0.35), 2.0, true)
	if value > 0.01:
		draw_line(mid, knob, Color(0.45, 0.82, 1.0, 0.85), track_width - 4.0, true)
	elif value < -0.01:
		draw_line(mid, knob, Color(1.0, 0.62, 0.32, 0.85), track_width - 4.0, true)
	draw_line(Vector2(center_x - 16.0, mid.y), Vector2(center_x + 16.0, mid.y), Color(0.92, 0.84, 0.55, 0.8), 2.0, true)
	draw_circle(knob, knob_radius + 3.0, Color(0.08, 0.12, 0.2, 0.9))
	var knob_fill := Color(0.78, 0.9, 1.0, 0.95)
	if value > 0.04:
		knob_fill = Color(0.55, 0.86, 1.0, 0.96)
	elif value < -0.04:
		knob_fill = Color(1.0, 0.7, 0.42, 0.96)
	draw_circle(knob, knob_radius, knob_fill)
	draw_circle(knob, 6.0, Color(1.0, 1.0, 1.0, 0.9))
	draw_arc(knob, knob_radius, 0.0, TAU, 40, Color(0.85, 0.94, 1.0, 0.7), 2.0, true)
