extends Area3D

@export var start_speed: float = 72.0
@export var max_speed: float = 168.0
@export var acceleration: float = 96.0
@export var turn_rate: float = 5.4
@export var lifetime: float = 7.0
@export var explode_radius: float = 3.4
@export var seek_range: float = 520.0
@export var shield_damage: float = 50.0
@export var hull_damage: float = 80.0

var direction: Vector3 = Vector3(0.0, 0.0, -1.0)
var extra_velocity: Vector3 = Vector3.ZERO
var shooter: Node = null
var target: Node3D = null
var speed: float = 72.0
var _exploded: bool = false


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1 | 2
	monitorable = false
	monitoring = true
	body_entered.connect(_on_body_entered)
	speed = start_speed
	_build_visual()
	var timer := get_tree().create_timer(lifetime)
	timer.timeout.connect(_on_timeout)


func setup(spawn_transform: Transform3D, inherit_velocity: Vector3, p_shooter: Node = null, p_target: Node3D = null) -> void:
	global_transform = spawn_transform
	var forward := -spawn_transform.basis.z
	if forward.length_squared() < 0.0001:
		forward = Vector3(0.0, 0.0, -1.0)
	direction = forward.normalized()
	extra_velocity = inherit_velocity * 0.28
	shooter = p_shooter
	target = p_target
	_face_flight()


func _physics_process(delta: float) -> void:
	if _exploded:
		return
	_refresh_target()
	if is_instance_valid(target):
		var to_target := target.global_position - global_position
		var dist := to_target.length()
		if dist <= explode_radius:
			_explode(target)
			return
		if dist > 0.001:
			_steer_toward(to_target / dist, delta)
	speed = move_toward(speed, max_speed, acceleration * delta)
	global_position += direction * speed * delta + extra_velocity * delta
	extra_velocity = extra_velocity.move_toward(Vector3.ZERO, 28.0 * delta)
	_face_flight()


func _steer_toward(desired: Vector3, delta: float) -> void:
	if desired.length_squared() < 0.0001:
		return
	desired = desired.normalized()
	var angle := direction.angle_to(desired)
	if angle < 0.001:
		direction = desired
		return
	var t := clampf((turn_rate * delta) / angle, 0.0, 1.0)
	direction = direction.slerp(desired, t).normalized()


func _refresh_target() -> void:
	if is_instance_valid(target) and _is_valid_enemy(target):
		return
	target = _find_nearest_enemy()


func _find_nearest_enemy() -> Node3D:
	var tree := get_tree()
	if tree == null:
		return null
	var best: Node3D = null
	var best_d := seek_range * seek_range
	for node: Node in tree.get_nodes_in_group("enemies"):
		if not _is_valid_enemy(node):
			continue
		var enemy := node as Node3D
		var d := global_position.distance_squared_to(enemy.global_position)
		if d < best_d:
			best_d = d
			best = enemy
	return best


func _is_valid_enemy(node: Node) -> bool:
	if node == null or not is_instance_valid(node):
		return false
	if not node.is_in_group("enemies") or not (node is Node3D):
		return false
	if node.has_method("get_health") and float(node.call("get_health")) <= 0.0:
		return false
	return true


func _face_flight() -> void:
	if direction.length_squared() < 0.0001:
		return
	var ahead := global_position + direction
	var up := Vector3.UP
	if absf(direction.dot(up)) > 0.96:
		up = Vector3.RIGHT
	look_at(ahead, up)


func _on_body_entered(body: Node) -> void:
	if _exploded:
		return
	if shooter != null and body == shooter:
		return
	if shooter != null and shooter.is_in_group("player") and body.is_in_group("player"):
		return
	if shooter != null and shooter.is_in_group("enemies") and body.is_in_group("enemies"):
		return
	_explode(body)


func _on_timeout() -> void:
	if _exploded:
		return
	_explode(null)


func _explode(hit: Node) -> void:
	if _exploded:
		return
	_exploded = true
	monitoring = false
	if is_instance_valid(hit):
		var is_enemy := hit.is_in_group("enemies")
		if hit.has_method("apply_missile_damage"):
			hit.call("apply_missile_damage", shield_damage, hull_damage)
		elif hit.has_method("apply_damage"):
			hit.call("apply_damage", hull_damage)
		if is_enemy:
			_report_player_hit(hit)
	_spawn_burst()
	queue_free()


func _report_player_hit(body: Node) -> void:
	if shooter == null or not shooter.is_in_group("player"):
		return
	var killed := false
	if is_instance_valid(body) and body.has_method("get_health"):
		killed = float(body.call("get_health")) <= 0.0
	elif not is_instance_valid(body):
		killed = true
	var hud := get_tree().get_first_node_in_group("space_hud")
	if hud != null and hud.has_method("show_weapon_hit"):
		hud.call("show_weapon_hit", killed)


func _spawn_burst() -> void:
	var host := get_parent()
	if host == null:
		return
	var burst := Node3D.new()
	burst.name = "MissileBurst"
	host.add_child(burst)
	burst.global_position = global_position
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.52, 0.18, 1.0)
	light.light_energy = 12.0
	light.omni_range = 22.0
	burst.add_child(light)
	var sparks := GPUParticles3D.new()
	sparks.amount = 36
	sparks.lifetime = 0.42
	sparks.one_shot = true
	sparks.explosiveness = 1.0
	sparks.emitting = true
	sparks.process_material = _burst_process_material()
	sparks.draw_pass_1 = _burst_draw_mesh()
	burst.add_child(sparks)
	var tween := burst.create_tween()
	tween.tween_property(light, "light_energy", 0.0, 0.38)
	tween.tween_callback(burst.queue_free)


func _build_visual() -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.62, 0.18, 1.0)
	mat.disable_receive_shadows = true
	var body_mesh := CylinderMesh.new()
	body_mesh.top_radius = 0.11
	body_mesh.bottom_radius = 0.16
	body_mesh.height = 1.28
	var body := MeshInstance3D.new()
	body.mesh = body_mesh
	body.material_override = mat
	body.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	add_child(body)
	var nose_mesh := CylinderMesh.new()
	nose_mesh.top_radius = 0.0
	nose_mesh.bottom_radius = 0.16
	nose_mesh.height = 0.38
	var nose := MeshInstance3D.new()
	nose.mesh = nose_mesh
	nose.material_override = mat
	nose.position = Vector3(0.0, 0.0, -0.82)
	nose.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	add_child(nose)
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.48, 0.16, 1.0)
	glow.light_energy = 3.4
	glow.omni_range = 7.0
	add_child(glow)
	var trail := GPUParticles3D.new()
	trail.amount = 40
	trail.lifetime = 0.22
	trail.local_coords = true
	trail.position = Vector3(0.0, 0.0, 0.72)
	trail.process_material = _trail_process_material()
	trail.draw_pass_1 = _burst_draw_mesh()
	trail.emitting = true
	add_child(trail)


func _trail_process_material() -> ParticleProcessMaterial:
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0.0, 0.0, 1.0)
	mat.spread = 6.0
	mat.initial_velocity_min = 8.0
	mat.initial_velocity_max = 14.0
	mat.gravity = Vector3.ZERO
	mat.scale_min = 0.22
	mat.scale_max = 0.4
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	gradient.colors = PackedColorArray([
		Color(1.0, 0.9, 0.45, 1.0),
		Color(1.0, 0.38, 0.08, 0.7),
		Color(0.2, 0.04, 0.02, 0.0),
	])
	var ramp := GradientTexture1D.new()
	ramp.gradient = gradient
	mat.color_ramp = ramp
	return mat


func _burst_process_material() -> ParticleProcessMaterial:
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0.0, 1.0, 0.0)
	mat.spread = 180.0
	mat.initial_velocity_min = 10.0
	mat.initial_velocity_max = 28.0
	mat.gravity = Vector3.ZERO
	mat.damping_min = 8.0
	mat.damping_max = 14.0
	mat.scale_min = 0.35
	mat.scale_max = 0.7
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.2, 1.0])
	gradient.colors = PackedColorArray([
		Color(1.0, 0.95, 0.7, 1.0),
		Color(1.0, 0.4, 0.12, 0.85),
		Color(0.15, 0.04, 0.02, 0.0),
	])
	var ramp := GradientTexture1D.new()
	ramp.gradient = gradient
	mat.color_ramp = ramp
	return mat


func _burst_draw_mesh() -> QuadMesh:
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.22, 0.22)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.vertex_color_use_as_albedo = true
	material.disable_receive_shadows = true
	mesh.material = material
	return mesh
