extends CanvasLayer

const SHADER := preload("res://shaders/hyperspace.gdshader")

var _mat: ShaderMaterial
var _rect: ColorRect


func _ready() -> void:
	layer = 15
	process_mode = Node.PROCESS_MODE_ALWAYS
	var copy := BackBufferCopy.new()
	copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	add_child(copy)
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	var root := Control.new()
	root.name = "Root"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_rect = ColorRect.new()
	_rect.name = "Warp"
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.color = Color.WHITE
	_rect.material = _mat
	root.add_child(_rect)
	set_amount(0.0)


func set_amount(amount: float) -> void:
	if _mat == null:
		return
	var u := clampf(amount, 0.0, 1.0)
	_mat.set_shader_parameter("amount", u)
	var flash := 0.0
	if u > 0.72:
		flash = smoothstep(0.72, 1.0, u)
	_mat.set_shader_parameter("flash", flash)
