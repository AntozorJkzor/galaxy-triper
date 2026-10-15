extends CharacterBody3D

const LASER_SCENE := preload("res://scenes/laser.tscn")
const Ships := preload("res://scripts/ship_catalog.gd")
const PIRATE_MODEL := "res://assets/models/starship/ship1.glb"

@export var max_health: float = 100.0
@export var max_shields: float = 100.0
@export var shield_regen_delay: float = 5.0
@export var shield_regen_rate: float = 5.0
@export var chase_speed: float = 42.0
@export var fire_interval: float = 0.78
@export var fire_range: float = 150.0
@export var preferred_distance: float = 78.0
@export var laser_damage: float = 2.67

var combat := CombatStats.new()
var engine_trails: Array[GPUParticles3D] = []
var hover_time: float = 0.0
var fire_cooldown: float = 1.1
var muzzle_offsets: Array[Vector3] = [
	Vector3(-0.82, -0.16, -4.7),
	Vector3(0.82, -0.16, -4.7),
]


func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 1
	collision_mask = 1
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	combat.configure(max_health, max_shields, shield_regen_delay, shield_regen_rate)
	hover_time = randf() * TAU
	fire_cooldown = randf_range(1.4, 2.4)
	Ships.apply_packed_albedo(get_node_or_null("Model"), Ships.albedo_for_model(PIRATE_MODEL))
	_collect_engine_trails()
	_setup_engine_fx()


func _physics_process(delta: float) -> void:
	combat.tick(delta)
	hover_time += delta
	fire_cooldown = maxf(0.0, fire_cooldown - delta)
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		velocity = Vector3.ZERO
		move_and_slide()
		_update_engine_fx()
		return

	var to_player := player.global_position - global_position
	var distance := to_player.length()
	if distance < 0.2:
		_update_engine_fx()
		return
	var dir := to_player / distance
	if absf(dir.dot(Vector3.UP)) < 0.98:
		look_at(player.global_position, Vector3.UP)

	var desired := Vector3.ZERO
	if distance > preferred_distance + 10.0:
		desired = dir * chase_speed
	elif distance < preferred_distance - 8.0:
		desired = -dir * chase_speed * 0.65
	else:
		var side := dir.cross(Vector3.UP)
		if side.length_squared() < 0.01:
			side = dir.cross(Vector3.RIGHT)
		desired = side.normalized() * chase_speed * 0.42
		desired += Vector3.UP * sin(hover_time * 1.4) * 4.0
	velocity = desired
	move_and_slide()

	var facing := -global_transform.basis.z.normalized().dot(dir)
	if distance <= fire_range and facing > 0.82 and fire_cooldown <= 0.0:
		_fire()

	_update_engine_fx()


func _fire() -> void:
	fire_cooldown = fire_interval
	var host := get_tree().current_scene
	if host == null:
		return
	for offset: Vector3 in muzzle_offsets:
		var laser: Area3D = LASER_SCENE.instantiate()
		host.add_child(laser)
		laser.set("damage", laser_damage)
		var spawn := global_transform
		spawn.origin = global_transform * offset
		laser.call("setup", spawn, velocity, self)


func get_health() -> float:
	return combat.health


func get_shields() -> float:
	return combat.shields


func get_max_health() -> float:
	return combat.max_health


func get_max_shields() -> float:
	return combat.max_shields


func apply_damage(amount: float) -> void:
	if not combat.is_alive():
		return
	combat.apply_damage(amount)
	if not combat.is_alive():
		_on_destroyed()


func apply_missile_damage(shield_damage: float, hull_damage: float) -> void:
	if not combat.is_alive():
		return
	combat.apply_missile_damage(shield_damage, hull_damage)
	if not combat.is_alive():
		_on_destroyed()


func _on_destroyed() -> void:
	var progress := get_node_or_null("/root/GameSettings")
	if progress != null and progress.has_method("notify_pirate_kill"):
		progress.call("notify_pirate_kill")
	queue_free()


func _collect_engine_trails() -> void:
	engine_trails.clear()
	for child in get_children():
		if child is GPUParticles3D and String(child.name).begins_with("EngineTrail"):
			engine_trails.append(child)


func _update_engine_fx() -> void:
	for trail: GPUParticles3D in engine_trails:
		trail.emitting = true
		trail.amount_ratio = 0.55
		trail.speed_scale = 0.9


func _setup_engine_fx() -> void:
	var process_mat := _make_jet_process_material()
	var draw_mesh := _make_jet_draw_mesh()
	for trail: GPUParticles3D in engine_trails:
		trail.process_material = process_mat
		trail.draw_pass_1 = draw_mesh
		trail.amount = 56
		trail.lifetime = 0.2
		trail.randomness = 0.08
		trail.explosiveness = 0.0
		trail.local_coords = true
		trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		trail.fixed_fps = 0
		trail.preprocess = 0.12
		trail.trail_enabled = true
		trail.trail_lifetime = 0.14
		trail.transform_align = GPUParticles3D.TRANSFORM_ALIGN_Y_TO_VELOCITY
		trail.visibility_aabb = AABB(Vector3(-2.0, -2.0, -1.0), Vector3(4.0, 4.0, 10.0))


func _make_jet_process_material() -> ParticleProcessMaterial:
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0.0, 0.0, 1.0)
	mat.spread = 2.0
	mat.initial_velocity_min = 22.0
	mat.initial_velocity_max = 34.0
	mat.gravity = Vector3.ZERO
	mat.damping_min = 10.0
	mat.damping_max = 16.0
	mat.scale_min = 0.4
	mat.scale_max = 0.65
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 0.07
	mat.particle_flag_align_y = true

	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.12, 0.45, 1.0])
	gradient.colors = PackedColorArray([
		Color(1.0, 0.92, 0.7, 1.0),
		Color(1.0, 0.42, 0.18, 0.95),
		Color(0.75, 0.08, 0.05, 0.35),
		Color(0.25, 0.02, 0.02, 0.0),
	])
	var ramp := GradientTexture1D.new()
	ramp.gradient = gradient
	mat.color_ramp = ramp

	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.55))
	curve.add_point(Vector2(0.18, 1.0))
	curve.add_point(Vector2(1.0, 0.05))
	var scale_tex := CurveTexture.new()
	scale_tex.curve = curve
	mat.scale_curve = scale_tex
	return mat


func _make_jet_draw_mesh() -> QuadMesh:
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.11, 1.15)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.vertex_color_use_as_albedo = true
	material.albedo_color = Color(1, 1, 1, 1)
	material.disable_receive_shadows = true
	mesh.material = material
	return mesh
