extends MeshInstance3D

const TEX_SHIELD := preload("res://assets/effects/shield.png")
const TEX_HULL := preload("res://assets/effects/health.png")
const DURATION := 0.42

var _mat: StandardMaterial3D
var _quad: QuadMesh
var _playing: bool = false
var _life: float = 0.0
var _diameter: float = 16.0


func _ready() -> void:
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	scale = Vector3.ONE
	_quad = QuadMesh.new()
	_quad.size = Vector2(_diameter, _diameter)
	mesh = _quad
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_mat.billboard_keep_scale = true
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat.disable_receive_shadows = true
	_mat.no_depth_test = true
	_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_mat.albedo_color = Color(1.2, 1.2, 1.2, 0.0)
	material_override = _mat
	visible = false
	set_process(false)


func play_hit(on_shield: bool, _radius: float = 0.0) -> void:
	if _mat == null or _quad == null:
		return
	_mat.albedo_texture = TEX_SHIELD if on_shield else TEX_HULL
	_diameter = _cover_diameter()
	_life = DURATION
	_playing = true
	visible = true
	scale = Vector3.ONE
	_set_quad_size(_diameter * 0.92)
	_mat.albedo_color = Color(1.2, 1.2, 1.2, 0.0)
	set_process(true)


func _process(delta: float) -> void:
	if not _playing:
		return
	_life -= delta
	var t := 1.0 - clampf(_life / DURATION, 0.0, 1.0)
	var alpha := t / 0.16 if t < 0.16 else 1.0 - (t - 0.16) / 0.84
	_mat.albedo_color = Color(1.2, 1.2, 1.2, clampf(alpha * 0.8, 0.0, 0.8))
	_set_quad_size(_diameter * lerpf(0.92, 1.18, t))
	if _life <= 0.0:
		_playing = false
		visible = false
		set_process(false)


func _set_quad_size(size: float) -> void:
	if _quad == null:
		return
	_quad.size = Vector2(size, size)


func _cover_diameter() -> float:
	var host := get_parent() as Node3D
	if host == null:
		return 16.0
	var aabb := AABB()
	var started := false
	var stack: Array[Node] = [host]
	while stack.size() > 0:
		var n: Node = stack.pop_back()
		if n == self:
			continue
		for child: Node in n.get_children():
			stack.append(child)
		if not (n is MeshInstance3D):
			continue
		var mesh_i := n as MeshInstance3D
		var local_aabb := mesh_i.get_aabb()
		var xf := host.global_transform.affine_inverse() * mesh_i.global_transform
		for i: int in 8:
			var p := xf * local_aabb.get_endpoint(i)
			if not started:
				aabb = AABB(p, Vector3.ZERO)
				started = true
			else:
				aabb = aabb.expand(p)
	if not started:
		return 16.0
	position = aabb.get_center()
	return maxf(aabb.size.length() * 1.2, 14.0)
