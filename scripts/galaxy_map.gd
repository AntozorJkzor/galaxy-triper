extends CanvasLayer

const Catalog := preload("res://scripts/planet_catalog.gd")

const GOLD := Color(0.95, 0.84, 0.54, 1.0)
const CYAN := Color(0.55, 0.78, 0.91, 1.0)
const TEXT := Color(0.96, 0.90, 0.75, 1.0)
const MUTED := Color(0.49, 0.58, 0.66, 1.0)

signal closed
signal jump_requested(system_id: int)

var current_system: int = 0
var chart: Control
var status_label: Label
var _buttons: Array[Button] = []
var _hover: int = -1
var _stars: PackedVector2Array = PackedVector2Array()
var _star_sizes: PackedFloat32Array = PackedFloat32Array()


func _ready() -> void:
	layer = 23
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()


func setup(system_id: int) -> void:
	current_system = Catalog.clamp_system(system_id)
	_refresh_status()
	if chart != null:
		chart.queue_redraw()


func _build() -> void:
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.01, 0.02, 0.05, 0.92)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)

	chart = Control.new()
	chart.name = "Chart"
	chart.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	chart.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chart.draw.connect(_draw_chart)
	chart.resized.connect(_on_chart_resized)
	root.add_child(chart)

	var title := Label.new()
	title.text = "GALAXY MAP"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", GOLD)
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.offset_left = -280.0
	title.offset_top = 24.0
	title.offset_right = 280.0
	title.offset_bottom = 70.0
	root.add_child(title)

	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 16)
	status_label.add_theme_color_override("font_color", MUTED)
	status_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	status_label.offset_left = -420.0
	status_label.offset_top = -118.0
	status_label.offset_right = 420.0
	status_label.offset_bottom = -88.0
	root.add_child(status_label)

	for sys: int in Catalog.SYSTEMS:
		var btn := Button.new()
		btn.focus_mode = Control.FOCUS_NONE
		btn.flat = true
		btn.custom_minimum_size = Vector2(72, 72)
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var empty := StyleBoxEmpty.new()
		btn.add_theme_stylebox_override("normal", empty)
		btn.add_theme_stylebox_override("hover", empty)
		btn.add_theme_stylebox_override("pressed", empty)
		btn.add_theme_stylebox_override("focus", empty)
		btn.pressed.connect(_on_star_pressed.bind(sys))
		btn.mouse_entered.connect(_on_star_hover.bind(sys))
		btn.mouse_exited.connect(_on_star_unhover.bind(sys))
		root.add_child(btn)
		_buttons.append(btn)

	var close_btn := Button.new()
	close_btn.text = "CLOSE MAP"
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.custom_minimum_size = Vector2(240, 46)
	close_btn.add_theme_font_size_override("font_size", 17)
	close_btn.add_theme_color_override("font_color", TEXT)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.1, 0.16, 0.92)
	style.set_border_width_all(1)
	style.border_color = Color(0.5, 0.6, 0.72, 0.55)
	style.set_corner_radius_all(8)
	close_btn.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.12, 0.18, 0.26, 0.96)
	close_btn.add_theme_stylebox_override("hover", hover)
	close_btn.add_theme_stylebox_override("pressed", hover)
	close_btn.pressed.connect(func() -> void: closed.emit())
	close_btn.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	close_btn.offset_left = -120.0
	close_btn.offset_top = -72.0
	close_btn.offset_right = 120.0
	close_btn.offset_bottom = -24.0
	root.add_child(close_btn)

	_refresh_status()
	call_deferred("_on_chart_resized")


func _on_chart_resized() -> void:
	_make_stars()
	_layout_buttons()
	if chart != null:
		chart.queue_redraw()


func _star_anchor(sys: int) -> Vector2:
	match Catalog.clamp_system(sys):
		0:
			return Vector2(0.24, 0.58)
		1:
			return Vector2(0.50, 0.36)
		2:
			return Vector2(0.78, 0.54)
		_:
			return Vector2(0.5, 0.5)


func _star_pos(sys: int) -> Vector2:
	return _star_anchor(sys) * chart.size


func _layout_buttons() -> void:
	if chart == null:
		return
	for sys: int in _buttons.size():
		var btn := _buttons[sys]
		var pos := _star_pos(sys)
		var hit := 78.0 if sys == current_system else 68.0
		btn.size = Vector2(hit, hit)
		btn.position = chart.global_position - btn.get_parent().global_position + pos - btn.size * 0.5


func _make_stars() -> void:
	_stars.clear()
	_star_sizes.clear()
	if chart == null:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 7741
	var area := chart.size
	for i: int in 140:
		_stars.append(Vector2(rng.randf() * area.x, rng.randf() * area.y))
		_star_sizes.append(rng.randf_range(0.6, 2.1))


func _draw_chart() -> void:
	if chart == null:
		return
	var size := chart.size
	chart.draw_rect(Rect2(Vector2.ZERO, size), Color(0.015, 0.03, 0.07, 1.0), true)
	chart.draw_circle(Vector2(size.x * 0.50, size.y * 0.46), size.x * 0.28, Color(0.16, 0.12, 0.32, 0.14))
	chart.draw_circle(Vector2(size.x * 0.38, size.y * 0.52), size.x * 0.16, Color(0.10, 0.18, 0.36, 0.10))
	chart.draw_circle(Vector2(size.x * 0.66, size.y * 0.50), size.x * 0.14, Color(0.22, 0.10, 0.28, 0.10))
	for i: int in _stars.size():
		var p: Vector2 = _stars[i]
		var s: float = _star_sizes[i]
		var a := 0.18 + s * 0.18
		chart.draw_circle(p, s, Color(0.78, 0.86, 1.0, a))

	var links := [
		Vector2i(0, 1),
		Vector2i(1, 2),
	]
	for pair: Vector2i in links:
		var a := _star_pos(pair.x)
		var b := _star_pos(pair.y)
		var usable := (
			Catalog.is_linked(current_system, pair.x)
			or Catalog.is_linked(current_system, pair.y)
			or pair.x == current_system
			or pair.y == current_system
		)
		_draw_route(a, b, usable)

	for sys: int in Catalog.SYSTEMS:
		_draw_system(sys)


func _draw_route(a: Vector2, b: Vector2, usable: bool) -> void:
	var col := Color(0.95, 0.82, 0.42, 0.95) if usable else Color(0.42, 0.52, 0.64, 0.35)
	var width := 3.4 if usable else 1.6
	chart.draw_line(a, b, col, width, true)
	if usable:
		chart.draw_line(a, b, Color(1.0, 0.92, 0.62, 0.22), width + 6.0, true)
		var mid := a.lerp(b, 0.5)
		var dir := (b - a).normalized()
		var side := Vector2(-dir.y, dir.x)
		chart.draw_circle(mid, 4.0, GOLD)
		chart.draw_colored_polygon(
			PackedVector2Array([
				mid + dir * 10.0,
				mid - dir * 6.0 + side * 5.0,
				mid - dir * 6.0 - side * 5.0,
			]),
			GOLD
		)


func _draw_system(sys: int) -> void:
	var pos := _star_pos(sys)
	var here := sys == current_system
	var linked := Catalog.is_linked(current_system, sys)
	var hovered := sys == _hover
	var core := GOLD if here or linked else Color(0.55, 0.64, 0.74, 0.7)
	if here:
		core = CYAN
	var radius := 11.0
	if here:
		radius = 14.0
	if hovered:
		radius += 3.0
	chart.draw_circle(pos, radius + 16.0, Color(core.r, core.g, core.b, 0.12))
	chart.draw_circle(pos, radius + 7.0, Color(core.r, core.g, core.b, 0.28))
	chart.draw_circle(pos, radius, core)
	chart.draw_circle(pos, radius * 0.42, Color(1.0, 0.98, 0.9, 0.95))
	if here:
		chart.draw_arc(pos, radius + 11.0, 0.0, TAU, 48, CYAN, 2.2, true)
	elif linked:
		chart.draw_arc(pos, radius + 8.0, 0.0, TAU, 40, GOLD, 1.6, true)

	var font := ThemeDB.fallback_font
	var name_size := 22 if here else 18
	var label := Catalog.system_name(sys)
	var label_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, name_size)
	var label_pos := pos + Vector2(-label_size.x * 0.5, radius + 28.0)
	chart.draw_string(font, label_pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, name_size, GOLD if here or linked else MUTED)
	var tag := ""
	if here:
		tag = "you are here"
	elif linked:
		tag = "available"
	if tag != "":
		var tag_size := font.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 13)
		chart.draw_string(
			font,
			pos + Vector2(-tag_size.x * 0.5, radius + 46.0),
			tag,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			13,
			CYAN if here else GOLD
		)


func _refresh_status() -> void:
	if status_label == null:
		return
	if _hover >= 0 and Catalog.is_linked(current_system, _hover):
		status_label.text = "Tap a point to jump to system  %s" % Catalog.system_name(_hover)
		status_label.add_theme_color_override("font_color", GOLD)
	elif _hover == current_system:
		status_label.text = "Current system  ·  %s" % Catalog.system_name(current_system)
		status_label.add_theme_color_override("font_color", CYAN)
	else:
		status_label.text = "Dots are systems. The glowing line is an open route."
		status_label.add_theme_color_override("font_color", MUTED)


func _on_star_hover(sys: int) -> void:
	_hover = sys
	_refresh_status()
	if chart != null:
		chart.queue_redraw()


func _on_star_unhover(sys: int) -> void:
	if _hover == sys:
		_hover = -1
	_refresh_status()
	if chart != null:
		chart.queue_redraw()


func _on_star_pressed(sys: int) -> void:
	if sys == current_system:
		return
	if not Catalog.is_linked(current_system, sys):
		return
	jump_requested.emit(sys)
