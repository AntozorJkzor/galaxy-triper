extends Node3D

const BAR_W := 3.4
const BAR_H := 0.38

@onready var name_label: Label3D = $NameLabel

var health_fill: MeshInstance3D
var shield_fill: MeshInstance3D
var ship: Node


func _ready() -> void:
	ship = get_parent()
	name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	name_label.fixed_size = false
	name_label.no_depth_test = true
	name_label.pixel_size = 0.018
	name_label.font_size = 64
	name_label.outline_size = 12
	_clear_old_bars()
	_make_bar(Color(0.08, 0.09, 0.12, 0.92), Vector3(0.0, 0.32, 0.0), false)
	health_fill = _make_bar(Color(0.9, 0.18, 0.18, 1.0), Vector3(0.0, 0.32, 0.02), true)
	_make_bar(Color(0.08, 0.09, 0.12, 0.92), Vector3(0.0, -0.12, 0.0), false)
	shield_fill = _make_bar(Color(0.25, 0.68, 1.0, 1.0), Vector3(0.0, -0.12, 0.02), true)


func _process(_delta: float) -> void:
	if ship == null or not is_instance_valid(ship):
		return
	if not ship.has_method("get_health") or health_fill == null or shield_fill == null:
		return
	var max_hp: float = maxf(float(ship.call("get_max_health")), 0.001)
	var max_sh: float = maxf(float(ship.call("get_max_shields")), 0.001)
	_set_fill(health_fill, float(ship.call("get_health")) / max_hp)
	_set_fill(shield_fill, float(ship.call("get_shields")) / max_sh)


func _clear_old_bars() -> void:
	for child_name: String in ["HealthBg", "HealthFill", "ShieldBg", "ShieldFill"]:
		var node := get_node_or_null(child_name)
		if node != null:
			node.queue_free()


func _make_bar(color: Color, local_pos: Vector3, is_fill: bool) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(BAR_W, BAR_H)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.no_depth_test = true
	material.disable_receive_shadows = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if color.a < 0.99 else BaseMaterial3D.TRANSPARENCY_DISABLED
	material.render_priority = 12 if is_fill else 11
	mesh_instance.mesh = quad
	mesh_instance.material_override = material
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh_instance.position = local_pos
	add_child(mesh_instance)
	return mesh_instance


func _set_fill(mesh: MeshInstance3D, ratio: float) -> void:
	ratio = clampf(ratio, 0.0, 1.0)
	mesh.scale.x = maxf(ratio, 0.001)
	mesh.position.x = -BAR_W * 0.5 * (1.0 - ratio)
