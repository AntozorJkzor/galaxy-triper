extends Control

@export var ring_color := Color(0.82, 0.94, 1.0, 0.95)
@export var ring_radius := 11.0
@export var ring_width := 1.7
@export var dot_radius := 1.6
@export var hit_color := Color(0.92, 0.97, 1.0, 0.98)
@export var kill_color := Color(0.96, 0.16, 0.16, 1.0)

const HIT_TIME := 0.5

var _hit_left: float = 0.0
var _hit_kill: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(36, 36)
	size = Vector2(36, 36)
	z_index = 20
	set_process(false)


func show_hit(killed: bool) -> void:
	_hit_kill = killed
	_hit_left = HIT_TIME
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	_hit_left -= delta
	if _hit_left <= 0.0:
		_hit_left = 0.0
		set_process(false)
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	draw_arc(center, ring_radius, 0.0, TAU, 48, ring_color, ring_width, true)
	draw_circle(center, dot_radius, ring_color)
	if _hit_left <= 0.0:
		return
	var mark := kill_color if _hit_kill else hit_color
	var arm := ring_radius * 0.78
	var width := 2.15 if _hit_kill else 1.85
	draw_line(center + Vector2(-arm, -arm), center + Vector2(arm, arm), mark, width, true)
	draw_line(center + Vector2(-arm, arm), center + Vector2(arm, -arm), mark, width, true)
