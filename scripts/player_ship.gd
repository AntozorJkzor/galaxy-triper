extends CharacterBody3D

const LASER_SCENE := preload("res://scenes/laser.tscn")
const MISSILE_SCENE := preload("res://scenes/missile.tscn")
const HitFlashScene := preload("res://scripts/hit_flash.gd")
const Ships := preload("res://scripts/ship_catalog.gd")
const ENGINE_PATH := "res://assets/sounds/engine.wav"
const BLASTER_PATH := "res://assets/sounds/blaster.wav"
const DAMAGE_PATH := "res://assets/sounds/damage.wav"

@export var max_speed: float = 85.0
@export var boost_speed: float = 150.0
@export var acceleration: float = 48.0
@export var brake_deceleration: float = 80.0
@export var mouse_sensitivity: float = 0.0024
@export var roll_speed: float = 2.4
@export var lift_speed: float = 28.0
@export var normal_fov: float = 75.0
@export var boost_fov: float = 88.0
@export var max_health: float = 100.0
@export var max_shields: float = 100.0
@export var shield_regen_delay: float = 5.0
@export var shield_regen_rate: float = 5.0
@export var fire_interval: float = 0.14
@export var missile_interval: float = 1.35
@export var crash_damage: float = 18.0
@export var touch_look_speed: float = 2.6
@export var touch_pitch_speed: float = 2.2

@onready var camera: Camera3D = $Camera3D

var equipped_hull: String = ""
var engine_trails: Array[GPUParticles3D] = []
var muzzle_offsets: Array[Vector3] = [
	Vector3(-0.92, -0.18, -4.85),
	Vector3(0.92, -0.18, -4.85),
]
var missile_offsets: Array[Vector3] = [
	Vector3(0.0, -0.42, -4.4),
]
var missile_offset: Vector3 = Vector3(0.0, -0.42, -4.4)
var throttle: float = 0.0
var current_speed: float = 0.0
var boosting: bool = false
var combat := CombatStats.new()
var fire_cooldown: float = 0.0
var missile_cooldown: float = 0.0
var crash_cooldown: float = 0.0
var engine_player: AudioStreamPlayer
var blaster_player: AudioStreamPlayer
var missile_player: AudioStreamPlayer
var damage_player: AudioStreamPlayer
var damage_cooldown: float = 0.0
var hyperspace_active: bool = false
var hyperspace_drive: float = 0.0
var docking_active: bool = false
var dock_complete: bool = false
var dock_target: Vector3 = Vector3.ZERO
var dock_look: Vector3 = Vector3.ZERO
var hit_flash: MeshInstance3D

func _ready() -> void:
	add_to_group("player")
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	if _using_touch_controls():
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_apply_profile_ship()
	_collect_engine_trails()
	_setup_engine_fx()
	_setup_ship_audio()
	_setup_hit_flash()


func _apply_profile_ship() -> void:
	var settings := get_node_or_null("/root/GameSettings")
	var ship_id := Ships.DEFAULT_ID
	if settings != null:
		ship_id = String(settings.get("current_ship"))
	apply_ship(ship_id)


func apply_ship(ship_id: String) -> void:
	var spec: Dictionary = Ships.spec(ship_id)
	max_speed = float(spec["max_speed"])
	boost_speed = float(spec["boost_speed"])
	acceleration = float(spec["acceleration"])
	brake_deceleration = float(spec["brake_deceleration"])
	roll_speed = float(spec["roll_speed"])
	lift_speed = float(spec["lift_speed"])
	max_health = float(spec["max_health"])
	max_shields = float(spec["max_shields"])
	shield_regen_delay = float(spec["shield_regen_delay"])
	shield_regen_rate = float(spec["shield_regen_rate"])
	fire_interval = float(spec["fire_interval"])
	missile_interval = float(spec["missile_interval"])
	crash_damage = float(spec["crash_damage"])
	combat.configure(max_health, max_shields, shield_regen_delay, shield_regen_rate)
	var hull_id := String(spec["id"])
	if equipped_hull != hull_id:
		equipped_hull = hull_id
		_apply_hull_scene(spec)
	_collect_hardpoints()
	_collect_engine_trails()
	_setup_engine_fx()
	var model := get_node_or_null("Model")
	if model != null:
		Ships.apply_packed_albedo(model, Ships.albedo_for(spec))


func _apply_hull_scene(spec: Dictionary) -> void:
	var path := String(spec.get("scene", ""))
	if path == "":
		return
	var packed := load(path) as PackedScene
	if packed == null:
		push_error("Ship scene missing: %s" % path)
		return
	var hull := packed.instantiate() as Node
	if hull == null:
		return
	_replace_child_from(hull, "Model")
	_copy_node3d_pose(hull, "Camera3D")
	_copy_collision(hull)
	var keep: Dictionary = {}
	for child: Node in hull.get_children():
		var n := String(child.name)
		if child is GPUParticles3D and n.begins_with("EngineTrail"):
			_sync_child(hull, n)
			keep[n] = true
		elif child is Marker3D and (n.begins_with("Laser") or n.begins_with("Missile")):
			_sync_child(hull, n)
			keep[n] = true
	var extras: Array[Node] = []
	for child: Node in get_children():
		var n := String(child.name)
		if child is GPUParticles3D and n.begins_with("EngineTrail") and not keep.has(n):
			extras.append(child)
		elif child is Marker3D and (n.begins_with("Laser") or n.begins_with("Missile")) and not keep.has(n):
			extras.append(child)
	for extra: Node in extras:
		extra.free()
	hull.free()


func _replace_child_from(hull: Node, child_name: String) -> void:
	var incoming := hull.get_node_or_null(child_name)
	if incoming == null:
		return
	var old := get_node_or_null(child_name)
	if old != null:
		remove_child(old)
		old.free()
	hull.remove_child(incoming)
	incoming.name = child_name
	add_child(incoming)
	move_child(incoming, 0)


func _copy_node3d_pose(hull: Node, child_name: String) -> void:
	var src := hull.get_node_or_null(child_name) as Node3D
	var dst := get_node_or_null(child_name) as Node3D
	if src == null or dst == null:
		return
	dst.transform = src.transform


func _copy_collision(hull: Node) -> void:
	var src := hull.get_node_or_null("CollisionShape") as CollisionShape3D
	var dst := get_node_or_null("CollisionShape") as CollisionShape3D
	if src == null or dst == null:
		return
	if src.shape != null:
		dst.shape = src.shape.duplicate()
	dst.transform = src.transform


func _sync_child(hull: Node, child_name: String) -> void:
	var src := hull.get_node_or_null(child_name) as Node3D
	if src == null:
		return
	var dst := get_node_or_null(child_name) as Node3D
	if dst == null:
		hull.remove_child(src)
		add_child(src)
		return
	dst.transform = src.transform


func _collect_hardpoints() -> void:
	muzzle_offsets.clear()
	missile_offsets.clear()
	var laser_names: PackedStringArray = PackedStringArray()
	var missile_names: PackedStringArray = PackedStringArray()
	for child: Node in get_children():
		if not (child is Marker3D):
			continue
		var n := String(child.name)
		if n.begins_with("Laser"):
			laser_names.append(n)
		elif n.begins_with("Missile"):
			missile_names.append(n)
	laser_names.sort()
	missile_names.sort()
	for n: String in laser_names:
		var marker := get_node(n) as Node3D
		muzzle_offsets.append(marker.position)
	if muzzle_offsets.is_empty():
		muzzle_offsets.append(Vector3(-0.7, -0.12, -3.9))
		muzzle_offsets.append(Vector3(0.7, -0.12, -3.9))
	for n: String in missile_names:
		var marker := get_node(n) as Node3D
		missile_offsets.append(marker.position)
	if missile_offsets.is_empty():
		missile_offsets.append(Vector3(0.0, -0.32, -3.6))
	missile_offset = missile_offsets[0]


func _input(event: InputEvent) -> void:
	if hyperspace_active or docking_active or _using_touch_controls() or get_tree().paused:
		return

	if event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_object_local(Vector3.UP, -event.relative.x * mouse_sensitivity)
		rotate_object_local(Vector3.RIGHT, -event.relative.y * mouse_sensitivity)
		get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	if hyperspace_active:
		_physics_hyperspace(delta)
		return
	if docking_active:
		_physics_docking(delta)
		return
	var touch := _get_touch_controls()
	var touch_throttle := 0.0
	var touch_look := Vector2.ZERO
	var touch_fire := false
	var touch_missiles := false
	var using_touch := _using_touch_controls() and touch != null
	if using_touch:
		if touch.has_method("get_throttle"):
			touch_throttle = float(touch.call("get_throttle"))
		else:
			touch_throttle = Vector2(touch.call("get_move_vector")).y
		touch_look = Vector2(touch.call("get_look_vector"))
		touch_fire = bool(touch.call("is_firing"))
		touch_missiles = bool(touch.call("is_missile_firing"))

	if touch_look.length() > 0.02:
		rotate_object_local(Vector3.UP, -touch_look.x * touch_look_speed * delta)
		rotate_object_local(Vector3.RIGHT, touch_look.y * touch_pitch_speed * delta)

	var roll := Input.get_axis("roll_left", "roll_right")
	if not is_zero_approx(roll):
		rotate_object_local(Vector3.FORWARD, roll * roll_speed * delta)

	boosting = Input.is_action_pressed("boost") and throttle > 0.05
	var max_now := boost_speed if boosting else max_speed

	if using_touch:
		throttle = clampf(touch_throttle, -1.0, 1.0)
		if absf(throttle) <= 0.04:
			throttle = 0.0
			current_speed = move_toward(current_speed, 0.0, brake_deceleration * delta)
		else:
			current_speed = move_toward(current_speed, throttle * max_now, acceleration * delta)
	elif Input.is_action_pressed("brake"):
		current_speed = move_toward(current_speed, 0.0, brake_deceleration * delta)
		throttle = move_toward(throttle, 0.0, 1.8 * delta)
	else:
		var throttle_axis := Input.get_axis("throttle_down", "throttle_up")
		if throttle_axis > 0.0:
			throttle = move_toward(throttle, 1.0, 0.85 * delta)
		elif throttle_axis < 0.0:
			throttle = move_toward(throttle, -0.4, 0.85 * delta)
		var target_speed := throttle * max_now
		current_speed = move_toward(current_speed, target_speed, acceleration * delta)

	var lift := Input.get_axis("strafe_down", "strafe_up")
	velocity = -transform.basis.z * current_speed + transform.basis.y * lift * lift_speed
	move_and_slide()

	combat.tick(delta)
	fire_cooldown = maxf(0.0, fire_cooldown - delta)
	missile_cooldown = maxf(0.0, missile_cooldown - delta)
	crash_cooldown = maxf(0.0, crash_cooldown - delta)
	damage_cooldown = maxf(0.0, damage_cooldown - delta)
	if get_slide_collision_count() > 0 and crash_cooldown <= 0.0:
		apply_damage(crash_damage)
		crash_cooldown = 0.45

	if (touch_fire or (not _using_touch_controls() and Input.is_action_pressed("fire") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED)) and not get_tree().paused:
		_try_fire()
	if (touch_missiles or (not _using_touch_controls() and Input.is_action_pressed("missile") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED)) and not get_tree().paused:
		_try_fire_missile()

	if camera != null:
		var target_fov := boost_fov if boosting else normal_fov
		camera.fov = lerpf(camera.fov, target_fov, 5.0 * delta)

	_update_engine_fx()
	_update_engine_audio()


func begin_hyperspace() -> void:
	hyperspace_active = true
	hyperspace_drive = 0.0
	throttle = 1.0
	boosting = true
	crash_cooldown = 999.0
	collision_layer = 0
	collision_mask = 0
	_stop_touch_fire()
	_spawn_warp_streaks()


func _physics_hyperspace(delta: float) -> void:
	boosting = true
	throttle = 1.0
	var target_speed := lerpf(boost_speed, 1650.0, clampf(hyperspace_drive, 0.0, 1.0))
	current_speed = move_toward(current_speed, target_speed, (180.0 + hyperspace_drive * 2200.0) * delta)
	velocity = -transform.basis.z * current_speed
	move_and_slide()
	if camera != null:
		camera.fov = lerpf(camera.fov, normal_fov + 18.0 + hyperspace_drive * 42.0, 8.0 * delta)
	_update_engine_fx()
	_update_engine_audio()


func begin_docking(target: Vector3, look_at_pos: Vector3) -> void:
	docking_active = true
	dock_complete = false
	dock_target = target
	dock_look = look_at_pos
	throttle = 1.0
	boosting = false
	crash_cooldown = 999.0
	collision_layer = 0
	collision_mask = 0
	_stop_touch_fire()
	if global_position.distance_to(dock_target) <= 20.0:
		current_speed = minf(current_speed, 12.0)


func is_dock_complete() -> bool:
	return dock_complete


func hold_at_dock() -> void:
	current_speed = 0.0
	velocity = Vector3.ZERO
	throttle = 0.0


func undock() -> void:
	docking_active = false
	dock_complete = false
	crash_cooldown = 0.6
	collision_layer = 2
	collision_mask = 1
	current_speed = 0.0
	velocity = Vector3.ZERO
	throttle = 0.0


func repair_hull() -> void:
	combat.restore_hull()


func recharge_shields() -> void:
	combat.restore_shields()


func _physics_docking(delta: float) -> void:
	if dock_complete:
		current_speed = 0.0
		velocity = Vector3.ZERO
		move_and_slide()
		_update_engine_fx()
		_update_engine_audio()
		return

	var offset := dock_target - global_position
	var dist := offset.length()
	var arrive_radius := 20.0
	if dist <= arrive_radius:
		current_speed = move_toward(current_speed, 0.0, 120.0 * delta)
		var brake := -global_transform.basis.z * current_speed
		if dist > 0.4:
			brake += offset * 1.8
			if brake.length() > 18.0:
				brake = brake.normalized() * 18.0
		velocity = brake
		move_and_slide()
		_turn_towards(dock_look, delta * 1.4)
		var facing := 1.0
		var to_look := dock_look - global_position
		if to_look.length_squared() > 0.2:
			facing = (-global_transform.basis.z).normalized().dot(to_look.normalized())
		if current_speed <= 5.0 and dist <= arrive_radius and facing > 0.72:
			dock_complete = true
			current_speed = 0.0
			velocity = Vector3.ZERO
			if global_position.distance_to(dock_target) < 40.0:
				global_position = dock_target
			var face := dock_look - global_position
			if face.length_squared() > 1.0 and absf(face.normalized().dot(Vector3.UP)) < 0.96:
				look_at(dock_look, Vector3.UP)
		if camera != null:
			camera.fov = lerpf(camera.fov, normal_fov, 4.0 * delta)
		_update_engine_fx()
		_update_engine_audio()
		return

	_turn_towards(dock_target, delta)
	var forward := -global_transform.basis.z.normalized()
	var closing := 0.0
	if dist > 0.001:
		closing = forward.dot(offset / dist)
	var cruise := clampf(dist * 0.38, 6.0, 150.0)
	if dist < 160.0:
		cruise = clampf(dist * 0.28, 4.0, 36.0)
	if dist < 55.0:
		cruise = clampf(dist * 0.22, 2.5, 14.0)
	if closing < 0.72:
		cruise = minf(cruise, 18.0)
	if closing < 0.28:
		cruise = minf(cruise, 7.0)
	current_speed = move_toward(current_speed, cruise, 95.0 * delta)
	throttle = clampf(current_speed / max_speed, 0.0, 1.0)
	boosting = false
	velocity = forward * current_speed
	move_and_slide()
	if camera != null:
		camera.fov = lerpf(camera.fov, normal_fov, 4.0 * delta)
	_update_engine_fx()
	_update_engine_audio()


func _turn_towards(point: Vector3, delta: float) -> void:
	var to_point := point - global_position
	if to_point.length_squared() < 0.25:
		return
	if absf(to_point.normalized().dot(Vector3.UP)) > 0.96:
		return
	var desired := global_transform.looking_at(point, Vector3.UP)
	global_transform = global_transform.interpolate_with(desired, clampf(3.4 * delta, 0.0, 1.0))


func _spawn_warp_streaks() -> void:
	if camera == null:
		return
	if camera.get_node_or_null("WarpStreaks") != null:
		return
	var particles := GPUParticles3D.new()
	particles.name = "WarpStreaks"
	particles.position = Vector3(0.0, 0.0, -18.0)
	particles.amount = 160
	particles.lifetime = 0.32
	particles.preprocess = 0.2
	particles.explosiveness = 0.05
	particles.local_coords = true
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	particles.visibility_aabb = AABB(Vector3(-40.0, -30.0, -20.0), Vector3(80.0, 60.0, 120.0))
	var process_mat := ParticleProcessMaterial.new()
	process_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process_mat.emission_box_extents = Vector3(22.0, 14.0, 6.0)
	process_mat.direction = Vector3(0.0, 0.0, 1.0)
	process_mat.spread = 7.0
	process_mat.initial_velocity_min = 90.0
	process_mat.initial_velocity_max = 260.0
	process_mat.gravity = Vector3.ZERO
	process_mat.scale_min = 0.15
	process_mat.scale_max = 0.45
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.2, 1.0])
	gradient.colors = PackedColorArray([
		Color(0.85, 0.95, 1.0, 1.0),
		Color(0.45, 0.75, 1.0, 0.75),
		Color(0.2, 0.4, 0.9, 0.0),
	])
	var ramp := GradientTexture1D.new()
	ramp.gradient = gradient
	process_mat.color_ramp = ramp
	particles.process_material = process_mat
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.08, 2.8)
	var draw_mat := StandardMaterial3D.new()
	draw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	draw_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	draw_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	draw_mat.vertex_color_use_as_albedo = true
	draw_mat.disable_receive_shadows = true
	mesh.material = draw_mat
	particles.draw_pass_1 = mesh
	particles.trail_enabled = true
	particles.trail_lifetime = 0.18
	particles.transform_align = GPUParticles3D.TRANSFORM_ALIGN_Y_TO_VELOCITY
	camera.add_child(particles)
	particles.emitting = true


func _get_touch_controls() -> Node:
	return get_tree().get_first_node_in_group("touch_controls")


func _stop_touch_fire() -> void:
	var touch := _get_touch_controls()
	if touch != null and touch.has_method("stop_firing"):
		touch.call("stop_firing")


func _using_touch_controls() -> bool:
	var settings := get_node_or_null("/root/GameSettings")
	return settings != null and bool(settings.get("touch_controls_enabled"))


func get_weapon_aim_point(distance: float = 420.0) -> Vector3:
	var origin := global_position
	var dir := -global_transform.basis.z.normalized()
	if camera != null:
		origin = camera.global_position
		dir = -camera.global_transform.basis.z.normalized()
	var space := get_world_3d().direct_space_state
	if space != null:
		var query := PhysicsRayQueryParameters3D.create(origin + dir * 4.0, origin + dir * distance)
		query.collision_mask = 1
		query.exclude = [get_rid()]
		var hit := space.intersect_ray(query)
		if not hit.is_empty():
			return hit["position"] as Vector3
	return origin + dir * distance


func _weapon_spawn_transform(local_offset: Vector3, aim: Vector3) -> Transform3D:
	var origin := global_transform * local_offset
	var to_aim := aim - origin
	if to_aim.length_squared() < 0.001:
		return Transform3D(global_transform.basis, origin)
	var up := global_transform.basis.y
	if absf(to_aim.normalized().dot(up)) > 0.96:
		up = global_transform.basis.x
	return Transform3D(Basis.looking_at(to_aim.normalized(), up), origin)


func get_display_speed() -> float:
	return absf(current_speed)

func get_throttle() -> float:
	return throttle


func is_boosting() -> bool:
	return boosting


func get_health() -> float:
	return combat.health


func get_shields() -> float:
	return combat.shields


func get_max_health() -> float:
	return combat.max_health


func get_max_shields() -> float:
	return combat.max_shields


func apply_damage(amount: float) -> void:
	if docking_active or hyperspace_active:
		return
	if not combat.is_alive():
		return
	var layer: int = combat.apply_damage(amount)
	_play_hit_flash(layer)
	_play_damage()
	if not combat.is_alive():
		_on_destroyed()


func apply_missile_damage(shield_damage: float, hull_damage: float) -> void:
	if docking_active or hyperspace_active:
		return
	if not combat.is_alive():
		return
	var layer: int = combat.apply_missile_damage(shield_damage, hull_damage)
	_play_hit_flash(layer)
	_play_damage()
	if not combat.is_alive():
		_on_destroyed()


func _setup_hit_flash() -> void:
	if get_node_or_null("HitFlash") != null:
		hit_flash = get_node("HitFlash") as MeshInstance3D
		return
	hit_flash = HitFlashScene.new()
	hit_flash.name = "HitFlash"
	add_child(hit_flash)


func _play_hit_flash(layer: int) -> void:
	if layer == CombatStats.HitLayer.NONE or hit_flash == null:
		return
	if hit_flash.has_method("play_hit"):
		hit_flash.call("play_hit", layer == CombatStats.HitLayer.SHIELD, _hit_flash_radius())


func _hit_flash_radius() -> float:
	var cs := get_node_or_null("CollisionShape") as CollisionShape3D
	if cs != null and cs.shape is BoxShape3D:
		var size: Vector3 = (cs.shape as BoxShape3D).size
		return maxf(size.x, maxf(size.y, size.z)) * 0.5
	return 6.0


func _on_destroyed() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _try_fire() -> void:
	if fire_cooldown > 0.0:
		return
	fire_cooldown = fire_interval
	var host := get_tree().current_scene
	if host == null:
		return
	var aim := get_weapon_aim_point()
	for offset: Vector3 in muzzle_offsets:
		var laser: Area3D = LASER_SCENE.instantiate()
		host.add_child(laser)
		laser.call("setup", _weapon_spawn_transform(offset, aim), velocity, self)
	_play_blaster()


func _try_fire_missile() -> void:
	if missile_cooldown > 0.0:
		return
	missile_cooldown = missile_interval
	var host := get_tree().current_scene
	if host == null:
		return
	var aim := get_weapon_aim_point()
	var lock := _nearest_enemy()
	for offset: Vector3 in missile_offsets:
		var missile: Area3D = MISSILE_SCENE.instantiate()
		host.add_child(missile)
		missile.call("setup", _weapon_spawn_transform(offset, aim), velocity, self, lock)
	_play_missile()


func _nearest_enemy() -> Node3D:
	var tree := get_tree()
	if tree == null:
		return null
	var best: Node3D = null
	var best_d := 520.0 * 520.0
	for node: Node in tree.get_nodes_in_group("enemies"):
		if node == null or not is_instance_valid(node) or not (node is Node3D):
			continue
		if node.has_method("get_health") and float(node.call("get_health")) <= 0.0:
			continue
		var enemy := node as Node3D
		var d := global_position.distance_squared_to(enemy.global_position)
		if d < best_d:
			best_d = d
			best = enemy
	return best


func _setup_ship_audio() -> void:
	engine_player = AudioStreamPlayer.new()
	engine_player.name = "EngineAudio"
	var engine_stream: AudioStream = _load_audio(ENGINE_PATH, true)
	engine_player.stream = engine_stream
	engine_player.volume_db = -24.0
	engine_player.pitch_scale = 0.82
	add_child(engine_player)
	if engine_stream != null:
		engine_player.play()

	blaster_player = AudioStreamPlayer.new()
	blaster_player.name = "BlasterAudio"
	blaster_player.stream = _load_audio(BLASTER_PATH, false)
	blaster_player.volume_db = 6.0
	blaster_player.max_polyphony = 4
	add_child(blaster_player)

	missile_player = AudioStreamPlayer.new()
	missile_player.name = "MissileAudio"
	missile_player.stream = _load_audio(BLASTER_PATH, false)
	missile_player.volume_db = 8.0
	missile_player.max_polyphony = 2
	add_child(missile_player)

	damage_player = AudioStreamPlayer.new()
	damage_player.name = "DamageAudio"
	damage_player.stream = _load_audio(DAMAGE_PATH, false)
	damage_player.volume_db = 12.0
	damage_player.max_polyphony = 2
	add_child(damage_player)


func _load_audio(path: String, looping: bool) -> AudioStream:
	var stream := load(path) as AudioStream
	if stream == null:
		return null
	if stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		if looping:
			var bytes_per_frame := 2
			if wav.stereo:
				bytes_per_frame *= 2
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
			wav.loop_begin = 0
			wav.loop_end = int(wav.data.size() / bytes_per_frame)
		else:
			wav.loop_mode = AudioStreamWAV.LOOP_DISABLED
	else:
		stream.set("loop", looping)
	return stream


func _update_engine_audio() -> void:
	if engine_player == null or not engine_player.playing:
		if engine_player != null and engine_player.stream != null:
			engine_player.play()
	var power := clampf(absf(current_speed) / max_speed, 0.0, 1.2)
	if boosting or hyperspace_active:
		power = clampf(power + 0.2 + hyperspace_drive * 0.5, 0.0, 1.6)
	var target_db := lerpf(-22.0, 7.0, clampf(power, 0.0, 1.0))
	if hyperspace_active:
		target_db += hyperspace_drive * 4.0
	engine_player.volume_db = lerpf(engine_player.volume_db, target_db, 0.18)
	var target_pitch := lerpf(0.78, 1.16, clampf(power, 0.0, 1.0))
	if boosting:
		target_pitch += 0.1
	if hyperspace_active:
		target_pitch += 0.12 + hyperspace_drive * 0.55
	engine_player.pitch_scale = lerpf(engine_player.pitch_scale, target_pitch, 0.12)


func _play_blaster() -> void:
	if blaster_player == null or blaster_player.stream == null:
		return
	blaster_player.pitch_scale = randf_range(0.94, 1.08)
	blaster_player.play()


func _play_missile() -> void:
	if missile_player == null or missile_player.stream == null:
		return
	missile_player.pitch_scale = randf_range(0.42, 0.52)
	missile_player.play()


func _play_damage() -> void:
	if damage_player == null or damage_player.stream == null:
		return
	if damage_cooldown > 0.0:
		return
	damage_cooldown = 0.12
	damage_player.pitch_scale = randf_range(0.92, 1.08)
	damage_player.play()


func _collect_engine_trails() -> void:
	engine_trails.clear()
	for child in get_children():
		if child is GPUParticles3D and String(child.name).begins_with("EngineTrail"):
			engine_trails.append(child)


func _update_engine_fx() -> void:
	var power := clampf(absf(current_speed) / max_speed, 0.0, 1.0)
	if hyperspace_active:
		power = 1.0
	var thrusting := power > 0.04 or hyperspace_active
	for trail: GPUParticles3D in engine_trails:
		trail.emitting = thrusting
		trail.amount_ratio = clampf(power + hyperspace_drive, 0.25, 1.0)
		if boosting or hyperspace_active:
			trail.speed_scale = 1.15 + hyperspace_drive * 2.4
		else:
			trail.speed_scale = 1.0


func _setup_engine_fx() -> void:
	var process_mat := _make_jet_process_material()
	var draw_mesh := _make_jet_draw_mesh()
	for trail: GPUParticles3D in engine_trails:
		trail.process_material = process_mat
		trail.draw_pass_1 = draw_mesh
		trail.amount = 72
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
	mat.initial_velocity_min = 28.0
	mat.initial_velocity_max = 42.0
	mat.gravity = Vector3.ZERO
	mat.damping_min = 10.0
	mat.damping_max = 16.0
	mat.scale_min = 0.45
	mat.scale_max = 0.7
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 0.07
	mat.particle_flag_align_y = true

	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.12, 0.45, 1.0])
	gradient.colors = PackedColorArray([
		Color(1.0, 0.98, 0.85, 1.0),
		Color(0.55, 0.85, 1.0, 0.95),
		Color(0.15, 0.45, 1.0, 0.35),
		Color(0.05, 0.15, 0.6, 0.0),
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
