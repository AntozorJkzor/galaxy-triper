extends Control

@export var stick_radius: float = 68.0
@export var knob_radius: float = 28.0
@export var deadzone: float = 0.12
@export var invert_y: bool = true
@export var output_scale: float = 1.0

var value: Vector2 = Vector2.ZERO

var _pointer_id: int = -999
var _knob_offset: Vector2 = Vector2.ZERO

const POINTER_NONE := -999
const POINTER_MOUSE := -2


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var side := (stick_radius + 18.0) * 2.0
	custom_minimum_size = Vector2(side, side)
	size = custom_minimum_size


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
	_knob_offset = Vector2.ZERO
	value = Vector2.ZERO
	queue_redraw()


func _update_from_pos(local_pos: Vector2) -> void:
	var center := size * 0.5
	var delta := local_pos - center
	if delta.length() > stick_radius:
		delta = delta.normalized() * stick_radius
	_knob_offset = delta
	var raw := delta / stick_radius
	var axis := Vector2(raw.x, -raw.y if invert_y else raw.y)
	if axis.length() < deadzone:
		value = Vector2.ZERO
	else:
		var analog := (axis.length() - deadzone) / (1.0 - deadzone)
		value = axis.normalized() * clampf(analog, 0.0, 1.0) * output_scale
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	draw_circle(center, stick_radius + 6.0, Color(0.05, 0.08, 0.14, 0.42))
	draw_arc(center, stick_radius, 0.0, TAU, 52, Color(0.72, 0.88, 1.0, 0.55), 3.0, true)
	var knob := center + _knob_offset
	draw_circle(knob, knob_radius + 2.0, Color(0.12, 0.2, 0.32, 0.9))
	draw_circle(knob, knob_radius, Color(0.78, 0.9, 1.0, 0.92))
	draw_circle(knob, 7.0, Color(1.0, 1.0, 1.0, 0.85))
