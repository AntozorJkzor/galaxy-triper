extends Control

const STRIP_SIZE := Vector2(440.0, 28.0)
const STRIP_TOP := 10.0
const FAR_MARK_DIST := 64.0
const MARK_COLOR := Color(1.0, 0.18, 0.18, 1.0)
const STRIP_BG := Color(0.04, 0.07, 0.12, 0.82)
const STRIP_LINE := Color(0.62, 0.82, 1.0, 0.55)

var _contacts: Array[Dictionary] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 18


func _process(_delta: float) -> void:
	_contacts.clear()
	if get_tree().paused:
		queue_redraw()
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		queue_redraw()
		return
	var view := get_viewport_rect().size
	var cam_inv := camera.global_transform.affine_inverse()

	for enemy: Node in get_tree().get_nodes_in_group("enemies"):
		if not (enemy is Node3D):
			continue
		var node := enemy as Node3D
		if not is_instance_valid(node) or not node.is_inside_tree():
			continue
		var local := cam_inv * node.global_position
		var dist := local.length()
		if dist < 0.4:
			continue
		var bearing := atan2(local.x, -local.z)
		var behind := local.z > 0.0
		var screen := Vector2.ZERO
		var on_screen := false
		if not behind:
			screen = camera.unproject_position(node.global_position)
			on_screen = Rect2(Vector2(12.0, 48.0), view - Vector2(24.0, 80.0)).has_point(screen)
		_contacts.append({
			"bearing": bearing,
			"dist": dist,
			"screen": screen,
			"on_screen": on_screen,
			"behind": behind,
		})
	queue_redraw()


func _draw() -> void:
	var view := size
	if view.x < 8.0:
		return
	var strip_pos := Vector2((view.x - STRIP_SIZE.x) * 0.5, STRIP_TOP)
	draw_rect(Rect2(strip_pos, STRIP_SIZE), STRIP_BG, true)
	draw_rect(Rect2(strip_pos, STRIP_SIZE), STRIP_LINE, false, 1.2)
	var mid_x := strip_pos.x + STRIP_SIZE.x * 0.5
	var mid_y := strip_pos.y + STRIP_SIZE.y * 0.5
	draw_line(
		Vector2(mid_x, strip_pos.y + 3.0),
		Vector2(mid_x, strip_pos.y + STRIP_SIZE.y - 3.0),
		Color(0.85, 0.93, 1.0, 0.8),
		1.6
	)
	var font := ThemeDB.fallback_font
	if font != null:
		draw_string(
			font,
			Vector2(strip_pos.x + 8.0, strip_pos.y + 19.0),
			"HOSTILES",
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			11,
			Color(0.78, 0.88, 1.0, 0.72)
		)

	for i: int in _contacts.size():
		var contact := _contacts[i]
		var bearing := float(contact["bearing"])
		var behind := bool(contact["behind"])
		var t := clampf(bearing / (PI * 0.5), -1.0, 1.0)
		var pip := Vector2(mid_x + t * (STRIP_SIZE.x * 0.5 - 16.0), mid_y)
		var pip_color := MARK_COLOR if not behind else Color(1.0, 0.48, 0.18, 0.95)
		_draw_diamond(pip, 6.5, pip_color)
		if behind or absf(bearing) > PI * 0.48:
			_draw_edge_caret(pip, signf(bearing), pip_color)
		if bool(contact["on_screen"]) and float(contact["dist"]) >= FAR_MARK_DIST:
			_draw_world_mark(contact["screen"] as Vector2, float(contact["dist"]), font)


func _draw_diamond(center: Vector2, radius: float, color: Color) -> void:
	var pts := PackedVector2Array([
		center + Vector2(0.0, -radius),
		center + Vector2(radius, 0.0),
		center + Vector2(0.0, radius),
		center + Vector2(-radius, 0.0),
	])
	draw_colored_polygon(pts, color)
	var outline := PackedVector2Array(pts)
	outline.append(pts[0])
	draw_polyline(outline, Color(1.0, 0.82, 0.82, 1.0), 1.2, true)


func _draw_edge_caret(center: Vector2, side: float, color: Color) -> void:
	if is_zero_approx(side):
		return
	var dir := signf(side)
	var tip := center + Vector2(dir * 10.0, 0.0)
	draw_colored_polygon(
		PackedVector2Array([
			tip,
			center + Vector2(dir * 3.0, -4.5),
			center + Vector2(dir * 3.0, 4.5),
		]),
		color
	)


func _draw_world_mark(screen: Vector2, dist: float, font: Font) -> void:
	var mark := screen + Vector2(24.0, -12.0)
	_draw_diamond(mark, 8.0, MARK_COLOR)
	var box := Rect2(screen + Vector2(-18.0, -18.0), Vector2(36.0, 36.0))
	draw_rect(box, Color(1.0, 0.18, 0.18, 0.95), false, 1.6)
	draw_line(screen + Vector2(18.0, -6.0), mark + Vector2(-8.0, 2.0), MARK_COLOR, 1.3)
	if font != null:
		draw_string(
			font,
			mark + Vector2(12.0, 6.0),
			"%d" % int(round(dist)),
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			14,
			Color(1.0, 0.55, 0.55, 1.0)
		)
