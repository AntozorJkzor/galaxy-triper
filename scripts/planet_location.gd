extends Node3D

const Catalog := preload("res://scripts/planet_catalog.gd")
const Anchor := preload("res://scripts/spawn_anchor.gd")
const SPHERE_SHADER := preload("res://shaders/planet_sphere.gdshader")
const STATION_SCENE := preload("res://assets/models/station.glb")
const STATION_ALBEDO := preload("res://assets/models/station_tripo_image_a0bbe845-d25b-430d-a84d-e7363ae63fbb_0_0.jpg")
const WARP_SCENE := preload("res://assets/models/warp.glb")
const WARP_ALBEDO := preload("res://assets/models/warp_tripo_image_70936edc-1eb2-4a89-95b9-cf8ed6a7a5e7_0_0.jpg")
const METEOR_SCRIPT := preload("res://scripts/meteorite.gd")
const HyperspaceFx := preload("res://scripts/hyperspace_fx.gd")
const StationMenuFx := preload("res://scripts/station_menu.gd")
const GalaxyMapFx := preload("res://scripts/galaxy_map.gd")

@export_range(0, 3) var planet_id: int = 0
@export_range(0, 2) var system_id: int = 0

const LOOK_DOT := 0.96
const STATION_LOOK_DOT := 0.86
const LOCAL_RADIUS := 390.0
const LOCAL_POSITION := Vector3(0.0, -360.0, -2100.0)
const DISTANT_SLOTS := [
	Vector3(-390.0, 70.0, -240.0),
	Vector3(370.0, 55.0, -200.0),
	Vector3(30.0, 130.0, -430.0),
]
const DISTANT_PIXEL_SIZE := 0.227
const SUN_OFFSET := Vector3(250.0, 115.0, -380.0)
const STATION_SCALE := 280.0
const WARP_SCALE := 240.0
const WARP_GOLD := Color(0.98, 0.82, 0.32, 1.0)

static var _sun_core_tex: Texture2D
static var _sun_halo_tex: Texture2D

var distant_root: Node3D
var local_planet: Node3D
var local_mesh: MeshInstance3D
var travel_button: Button
var location_label: Label
var look_target_id: int = -1
var looking_at_station: bool = false
var looking_at_warp: bool = false
var _globe_spin: float = 0.0
var _traveling: bool = false
var _docking: bool = false
var _dock_kind: String = ""
var _station_open: bool = false
var _map_open: bool = false
var orbit_station: Node3D
var warp_gate: Node3D
var warp_mark: Label3D
var station_menu: CanvasLayer
var galaxy_map: CanvasLayer
var rng := RandomNumberGenerator.new()
var _planet_position: Vector3 = LOCAL_POSITION
var _planet_radius: float = LOCAL_RADIUS


func _ready() -> void:
	planet_id = Catalog.clamp_planet(planet_id)
	system_id = Catalog.clamp_system(system_id)
	var settings := get_node_or_null("/root/GameSettings")
	if settings != null:
		if settings.has_method("set_current_planet"):
			settings.call("set_current_planet", planet_id)
		if settings.has_method("set_current_system"):
			settings.call("set_current_system", system_id)
	rng.randomize()
	_reset_space_environment()
	_remove_old_world_planets()
	_hide_old_sun()
	_spawn_local_planet()
	_spawn_distant_planets()
	_spawn_sun_backdrop()
	_spawn_station()
	_spawn_warp_gate()
	_spawn_meteor_fields()
	_spawn_pirates()
	_build_travel_ui()


func _unhandled_input(event: InputEvent) -> void:
	if _traveling or _station_open or _map_open or get_tree().paused:
		return
	if not event.is_action_pressed("travel"):
		return
	var viewport := get_viewport()
	if viewport != null:
		viewport.set_input_as_handled()
	if _docking:
		_cancel_autopilot()
	elif looking_at_warp:
		_start_warp_autopilot()
	elif looking_at_station:
		_start_station_autopilot()
	elif look_target_id >= 0:
		_travel_to(look_target_id)


func _process(delta: float) -> void:
	if not is_inside_tree():
		return
	if _traveling:
		return
	var camera := get_viewport().get_camera_3d()
	if distant_root != null and camera != null:
		distant_root.global_position = camera.global_position
	_orient_local_planet(camera, delta)
	_update_local_warp_mark(camera)
	if orbit_station != null and not _station_open and not _docking:
		orbit_station.rotate_y(0.07 * delta)
	if warp_gate != null and not _map_open and not _docking:
		warp_gate.rotate_y(0.045 * delta)
	if _docking:
		_tick_docking()
		return
	if _station_open or _map_open:
		return
	_update_look_target(camera)


func _reset_space_environment() -> void:
	var env_node := get_node_or_null("WorldEnvironment") as WorldEnvironment
	if env_node == null or env_node.environment == null:
		return
	var env := env_node.environment.duplicate() as Environment
	if env == null:
		return
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_strength = 0.9
	env.glow_bloom = 0.12
	env_node.environment = env


func _remove_old_world_planets() -> void:
	var world := get_node_or_null("World")
	if world == null:
		return
	for child in world.get_children():
		var n := String(child.name)
		if n.begins_with("Planet") or n == "Moon" or n == "Asteroids":
			child.queue_free()


func _spawn_local_planet() -> void:
	_read_planet_anchor()
	var body := StaticBody3D.new()
	body.name = "LocalPlanet"
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = _planet_position
	add_child(body)
	local_planet = body

	var mesh := SphereMesh.new()
	mesh.radius = _planet_radius
	mesh.height = _planet_radius * 2.0
	mesh.radial_segments = 64
	mesh.rings = 32
	var instance := MeshInstance3D.new()
	instance.name = "Mesh"
	instance.mesh = mesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := ShaderMaterial.new()
	mat.shader = SPHERE_SHADER
	mat.set_shader_parameter("planet_tex", Catalog.texture_for(planet_id, system_id))
	instance.material_override = mat
	body.add_child(instance)
	local_mesh = instance

	var shape := SphereShape3D.new()
	shape.radius = _planet_radius
	var col := CollisionShape3D.new()
	col.shape = shape
	body.add_child(col)


func _orient_local_planet(camera: Camera3D, delta: float) -> void:
	if local_mesh == null or camera == null:
		return
	var to_camera := camera.global_position - local_mesh.global_position
	if to_camera.length_squared() < 0.001:
		return
	var z_axis := to_camera.normalized()
	var x_axis := Vector3.UP.cross(z_axis)
	if x_axis.length_squared() < 0.001:
		x_axis = Vector3.RIGHT.cross(z_axis)
	x_axis = x_axis.normalized()
	var y_axis := z_axis.cross(x_axis).normalized()
	_globe_spin += 0.045 * delta
	local_mesh.global_basis = Basis(x_axis, y_axis, z_axis).rotated(z_axis, _globe_spin)


func _spawn_distant_planets() -> void:
	distant_root = Node3D.new()
	distant_root.name = "DistantPlanets"
	add_child(distant_root)
	var slot := 0
	for id: int in Catalog.COUNT:
		if id == planet_id:
			continue
		var sprite := Sprite3D.new()
		sprite.name = "Distant_%d" % id
		sprite.texture = Catalog.texture_for(id, system_id)
		sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sprite.shaded = false
		sprite.double_sided = true
		sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		sprite.alpha_scissor_threshold = 0.4
		sprite.pixel_size = DISTANT_PIXEL_SIZE
		sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
		sprite.position = DISTANT_SLOTS[slot]
		sprite.set_meta("planet_id", id)
		sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		distant_root.add_child(sprite)
		if Catalog.has_warp_gate(id, system_id):
			sprite.add_child(_make_warp_letter(Vector3(22.0, 12.0, 2.0), 0.11, 88))
		slot += 1


func _hide_old_sun() -> void:
	var old := get_node_or_null("SunCore")
	if old != null:
		old.queue_free()
	var light := get_node_or_null("Sun") as DirectionalLight3D
	if light != null:
		light.light_color = Color(1.0, 0.78, 0.28, 1.0)
		light.light_energy = 1.75


func _spawn_sun_backdrop() -> void:
	if distant_root == null:
		return
	_ensure_sun_textures()
	distant_root.add_child(_make_sun_sprite("SunHalo", _sun_halo_tex, Vector2(128.0, 128.0), Color(1.0, 0.62, 0.12, 0.7)))
	distant_root.add_child(_make_sun_sprite("SunCore", _sun_core_tex, Vector2(78.0, 78.0), Color(1.0, 0.88, 0.28, 1.0)))


func _spawn_station() -> void:
	var pos := _default_station_position()
	var anchor := _first_anchor(Anchor.Kind.STATION)
	if anchor != null:
		pos = anchor.global_position
	var body := StaticBody3D.new()
	body.name = "OrbitStation"
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = pos
	var model := STATION_SCENE.instantiate() as Node3D
	model.name = "Model"
	model.scale = Vector3.ONE * STATION_SCALE
	model.rotation_degrees = Vector3(8.0, 90.0, 14.0)
	_apply_packed_albedo(model, STATION_ALBEDO)
	body.add_child(model)
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.28, 0.34, 1.02) * STATION_SCALE
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position = Vector3(0.0, 0.16, 0.0) * STATION_SCALE
	body.add_child(col)
	var lamp := OmniLight3D.new()
	lamp.name = "Beacon"
	lamp.light_color = Color(0.55, 0.82, 1.0, 1.0)
	lamp.light_energy = 10.0
	lamp.omni_range = 280.0
	lamp.position = Vector3(0.0, 28.0, 0.0)
	body.add_child(lamp)
	add_child(body)
	orbit_station = body
	_face_station_to_open_space()


func _spawn_warp_gate() -> void:
	var anchor := _first_anchor(Anchor.Kind.WARP)
	if anchor == null and not Catalog.has_warp_gate(planet_id, system_id):
		return
	var pos := _default_warp_position()
	if anchor != null:
		pos = anchor.global_position
	var body := StaticBody3D.new()
	body.name = "WarpGate"
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = pos
	var model := WARP_SCENE.instantiate() as Node3D
	model.name = "Model"
	model.scale = Vector3.ONE * WARP_SCALE
	_apply_packed_albedo(model, WARP_ALBEDO)
	body.add_child(model)
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.99, 1.0, 0.42) * WARP_SCALE
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position = Vector3(0.0, 0.5, 0.0) * WARP_SCALE
	body.add_child(col)
	var lamp := OmniLight3D.new()
	lamp.name = "Beacon"
	lamp.light_color = WARP_GOLD
	lamp.light_energy = 12.0
	lamp.omni_range = 300.0
	lamp.position = Vector3(0.0, WARP_SCALE * 0.5, 0.0)
	body.add_child(lamp)
	add_child(body)
	warp_gate = body
	_face_warp_to_open_space()
	warp_mark = _make_warp_letter(Vector3.ZERO, 0.42, 160)
	warp_mark.name = "LocalWarpMark"
	add_child(warp_mark)


func _spawn_meteor_fields() -> void:
	var fields := _anchors_of(Anchor.Kind.METEOR_FIELD)
	if fields.is_empty():
		var field_count := rng.randi_range(2, 3)
		for field_i: int in field_count:
			var center := _random_orbit_point(150.0, 420.0, 90.0, false)
			_fill_meteor_field(center, rng.randi_range(10, 16), 48.0, field_i)
		return
	var field_i := 0
	for anchor: Node in fields:
		var count := 12
		var radius := 48.0
		if anchor.get("meteor_count") != null:
			count = int(anchor.get("meteor_count"))
		if anchor.get("field_radius") != null:
			radius = float(anchor.get("field_radius"))
		_fill_meteor_field((anchor as Node3D).global_position, count, radius, field_i)
		field_i += 1


func _fill_meteor_field(center: Vector3, rock_count: int, radius: float, field_i: int) -> void:
	for rock_i: int in rock_count:
		var offset := Vector3(
			rng.randf_range(-radius, radius),
			rng.randf_range(-radius * 0.58, radius * 0.58),
			rng.randf_range(-radius, radius),
		)
		var pos := center + offset
		if not _is_spawn_clear(pos, 55.0):
			continue
		_spawn_meteorite(pos, field_i, rock_i)


func _spawn_meteorite(pos: Vector3, field_i: int, rock_i: int) -> void:
	var body := StaticBody3D.new()
	body.name = "Meteorite_%d_%d" % [field_i, rock_i]
	body.position = pos
	body.set_script(METEOR_SCRIPT)
	var radius := rng.randf_range(1.7, 4.4)
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * rng.randf_range(1.4, 2.1)
	mesh.radial_segments = 10
	mesh.rings = 6
	var visual := MeshInstance3D.new()
	visual.name = "Mesh"
	visual.mesh = mesh
	visual.scale = Vector3(rng.randf_range(0.75, 1.2), rng.randf_range(0.65, 1.15), rng.randf_range(0.75, 1.25))
	visual.rotation = Vector3(rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(
		rng.randf_range(0.28, 0.52),
		rng.randf_range(0.24, 0.44),
		rng.randf_range(0.2, 0.36),
		1.0
	)
	mat.roughness = rng.randf_range(0.78, 0.96)
	mat.metallic = rng.randf_range(0.05, 0.22)
	visual.material_override = mat
	body.add_child(visual)
	var shape := SphereShape3D.new()
	shape.radius = radius * 0.92
	var col := CollisionShape3D.new()
	col.shape = shape
	body.add_child(col)
	add_child(body)
	var tumble := Vector3(
		rng.randf_range(-0.55, 0.55),
		rng.randf_range(-0.8, 0.8),
		rng.randf_range(-0.55, 0.55),
	)
	body.call("setup", rng.randf_range(24.0, 48.0), tumble, visual)


func _spawn_pirates() -> void:
	var packed: PackedScene = load("res://scenes/pirate_ship.tscn") as PackedScene
	if packed == null:
		push_error("Pirate ship scene failed to load")
		return
	var points: Array[Vector3] = []
	for anchor: Node in _anchors_of(Anchor.Kind.PIRATE):
		points.append((anchor as Node3D).global_position)
	if points.is_empty():
		var count := rng.randi_range(2, 3)
		for i: int in range(count):
			points.append(_random_orbit_point(180.0, 280.0, 110.0, true))
	var i := 0
	for pos: Vector3 in points:
		var pirate := packed.instantiate() as Node3D
		if pirate == null:
			push_error("Pirate ship failed to instantiate")
			continue
		pirate.name = "Pirate_%d" % i
		pirate.position = pos
		add_child(pirate)
		pirate.add_to_group("enemies")
		i += 1


func _orbit_frame() -> Array[Vector3]:
	var toward := -_planet_position.normalized()
	if toward.length_squared() < 0.001:
		toward = Vector3(0.0, 0.0, 1.0)
	var right := toward.cross(Vector3.UP)
	if right.length_squared() < 0.001:
		right = toward.cross(Vector3.RIGHT)
	right = right.normalized()
	var up := right.cross(toward).normalized()
	return [toward, right, up]


func _default_station_position() -> Vector3:
	var frame := _orbit_frame()
	return _planet_position + frame[0] * (_planet_radius + 95.0) + frame[1] * 430.0 + frame[2] * 55.0


func _default_warp_position() -> Vector3:
	var frame := _orbit_frame()
	return _planet_position + frame[0] * (_planet_radius + 110.0) - frame[1] * 430.0 + frame[2] * 70.0


func _read_planet_anchor() -> void:
	_planet_position = LOCAL_POSITION
	_planet_radius = LOCAL_RADIUS
	var anchor := _first_anchor(Anchor.Kind.PLANET)
	if anchor == null:
		return
	_planet_position = (anchor as Node3D).global_position
	var radius_value: Variant = anchor.get("planet_radius")
	if radius_value != null:
		_planet_radius = maxf(40.0, float(radius_value))


func _first_anchor(kind: Anchor.Kind) -> Node3D:
	var list := _anchors_of(kind)
	if list.is_empty():
		return null
	return list[0] as Node3D


func _anchors_of(kind: Anchor.Kind) -> Array[Node]:
	var found: Array[Node] = []
	_collect_anchors(self, kind, found)
	return found


func _collect_anchors(n: Node, kind: Anchor.Kind, found: Array[Node]) -> void:
	if n.is_in_group("spawn_anchor") and int(n.get("kind")) == int(kind):
		found.append(n)
	for child: Node in n.get_children():
		_collect_anchors(child, kind, found)


func _random_orbit_point(min_range: float, max_range: float, planet_pad: float, avoid_forward: bool) -> Vector3:
	for _try: int in 36:
		var dir := Vector3.ZERO
		if avoid_forward:
			var yaw := rng.randf_range(1.15, TAU - 1.15)
			var elev := rng.randf_range(-0.36, 0.36)
			dir = Vector3(sin(yaw), elev, -cos(yaw))
		else:
			dir = Vector3(
				rng.randf_range(-1.0, 1.0),
				rng.randf_range(-0.48, 0.48),
				rng.randf_range(-1.0, 1.0),
			)
		if dir.length_squared() < 0.08:
			continue
		dir = dir.normalized()
		var pos := dir * rng.randf_range(min_range, max_range)
		if _is_spawn_clear(pos, planet_pad):
			return pos
	return Vector3(220.0, 36.0, 160.0)


func _is_spawn_clear(pos: Vector3, planet_pad: float) -> bool:
	if pos.length() < 70.0:
		return false
	if pos.distance_to(_planet_position) < _planet_radius + planet_pad:
		return false
	if orbit_station != null and pos.distance_to(orbit_station.position) < 70.0:
		return false
	if warp_gate != null and pos.distance_to(warp_gate.position) < 80.0:
		return false
	return true


func _make_sun_sprite(node_name: String, texture: Texture2D, quad_size: Vector2, modulate: Color) -> MeshInstance3D:
	var mesh := QuadMesh.new()
	mesh.size = quad_size
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position = SUN_OFFSET
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = modulate
	mat.albedo_texture = texture
	mat.disable_receive_shadows = true
	instance.material_override = mat
	return instance


func _ensure_sun_textures() -> void:
	if _sun_core_tex != null and _sun_halo_tex != null:
		return
	_sun_core_tex = _make_glow_disc(256, Color(1.0, 0.95, 0.45, 1.0), Color(1.0, 0.62, 0.08, 0.0), 0.42)
	_sun_halo_tex = _make_glow_disc(256, Color(1.0, 0.7, 0.12, 0.55), Color(1.0, 0.35, 0.0, 0.0), 0.12)


func _make_glow_disc(size: int, inner: Color, outer: Color, core_start: float) -> ImageTexture:
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := (size - 1) * 0.5
	var radius := center - 1.0
	for y: int in size:
		for x: int in size:
			var dist := Vector2(float(x) - center, float(y) - center).length() / radius
			if dist >= 1.0:
				image.set_pixel(x, y, Color(0.0, 0.0, 0.0, 0.0))
				continue
			var t := smoothstep(core_start, 1.0, dist)
			image.set_pixel(x, y, inner.lerp(outer, t))
	return ImageTexture.create_from_image(image)


func _build_travel_ui() -> void:
	var hud_root := get_node_or_null("HUD/Root") as Control
	if hud_root == null:
		return

	location_label = Label.new()
	location_label.name = "LocationLabel"
	location_label.text = "ORBIT  %s  ·  %s" % [Catalog.planet_name(planet_id, system_id), Catalog.system_name(system_id)]
	location_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	location_label.add_theme_font_size_override("font_size", 18)
	location_label.add_theme_color_override("font_color", Color(0.95, 0.84, 0.54, 1.0))
	location_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	location_label.offset_left = -180.0
	location_label.offset_top = 52.0
	location_label.offset_right = 180.0
	location_label.offset_bottom = 80.0
	location_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(location_label)

	travel_button = Button.new()
	travel_button.name = "TravelButton"
	travel_button.visible = false
	travel_button.focus_mode = Control.FOCUS_NONE
	travel_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	travel_button.custom_minimum_size = Vector2(360, 58)
	travel_button.add_theme_font_size_override("font_size", 20)
	travel_button.add_theme_color_override("font_color", Color(0.98, 0.93, 0.78, 1.0))
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.1, 0.16, 0.27, 0.92)
	normal.set_border_width_all(2)
	normal.border_color = Color(0.88, 0.75, 0.44, 1.0)
	normal.set_corner_radius_all(10)
	normal.content_margin_left = 18.0
	normal.content_margin_right = 18.0
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.16, 0.25, 0.38, 0.96)
	travel_button.add_theme_stylebox_override("normal", normal)
	travel_button.add_theme_stylebox_override("hover", hover)
	travel_button.add_theme_stylebox_override("pressed", hover)
	travel_button.pressed.connect(_on_prompt_pressed)
	hud_root.add_child(travel_button)


func _update_look_target(camera: Camera3D) -> void:
	if travel_button == null:
		return
	travel_button.mouse_filter = (
		Control.MOUSE_FILTER_STOP if _touch_on() else Control.MOUSE_FILTER_IGNORE
	)
	looking_at_station = false
	looking_at_warp = false
	look_target_id = -1
	if camera == null or get_tree().paused:
		travel_button.visible = false
		return

	var view_size := get_viewport().get_visible_rect().size
	var look := -camera.global_transform.basis.z.normalized()
	var station_screen := Vector2.ZERO
	var station_facing := -1.0
	if orbit_station != null:
		var hit := _look_hit(camera, look, view_size, orbit_station.global_position, STATION_LOOK_DOT)
		if not hit.is_empty():
			station_facing = float(hit["facing"])
			station_screen = hit["screen"]
	var warp_screen := Vector2.ZERO
	var warp_facing := -1.0
	if warp_gate != null:
		var hit := _look_hit(camera, look, view_size, warp_gate.global_position, STATION_LOOK_DOT)
		if not hit.is_empty():
			warp_facing = float(hit["facing"])
			warp_screen = hit["screen"]

	if warp_facing >= station_facing and warp_facing >= STATION_LOOK_DOT:
		looking_at_warp = true
		var suffix := "" if _touch_on() else "   ·   F"
		travel_button.text = "AUTOPILOT · GATE%s" % suffix
		travel_button.visible = true
		_place_prompt(warp_screen, view_size)
		return
	if station_facing >= STATION_LOOK_DOT:
		looking_at_station = true
		var suffix := "" if _touch_on() else "   ·   F"
		travel_button.text = "AUTOPILOT · STATION%s" % suffix
		travel_button.visible = true
		_place_prompt(station_screen, view_size)
		return

	if distant_root == null:
		travel_button.visible = false
		return
	var best_id := -1
	var best_dot := LOOK_DOT
	var best_screen := Vector2.ZERO
	for child in distant_root.get_children():
		if not (child is Sprite3D):
			continue
		var sprite := child as Sprite3D
		var to_planet := sprite.global_position - camera.global_position
		if to_planet.length_squared() < 1.0:
			continue
		var dir := to_planet.normalized()
		var facing := look.dot(dir)
		if facing < best_dot:
			continue
		if camera.is_position_behind(sprite.global_position):
			continue
		var screen := camera.unproject_position(sprite.global_position)
		if not Rect2(Vector2(40, 40), view_size - Vector2(80, 80)).has_point(screen):
			continue
		best_dot = facing
		best_id = int(sprite.get_meta("planet_id"))
		best_screen = screen

	look_target_id = best_id
	if best_id < 0:
		travel_button.visible = false
		return

	var target_name := Catalog.planet_name(best_id, system_id)
	var planet_suffix := "" if _touch_on() else "   ·   F"
	if Catalog.has_warp_gate(best_id, system_id):
		travel_button.text = "TO %s  ·  W%s" % [target_name.to_upper(), planet_suffix]
	else:
		travel_button.text = "TO %s%s" % [target_name.to_upper(), planet_suffix]
	travel_button.visible = true
	_place_prompt(best_screen, view_size)


func _place_prompt(screen: Vector2, view_size: Vector2) -> void:
	var btn_size := travel_button.size
	if btn_size.x < 8.0:
		btn_size = travel_button.custom_minimum_size
	var pos := screen + Vector2(-btn_size.x * 0.5, 28.0)
	pos.x = clampf(pos.x, 24.0, view_size.x - btn_size.x - 24.0)
	pos.y = clampf(pos.y, 80.0, view_size.y - btn_size.y - 140.0)
	travel_button.position = pos


func _on_prompt_pressed() -> void:
	if _docking:
		_cancel_autopilot()
	elif looking_at_warp:
		_start_warp_autopilot()
	elif looking_at_station:
		_start_station_autopilot()
	elif look_target_id >= 0:
		_travel_to(look_target_id)


func _travel_to(id: int) -> void:
	if _traveling or id == planet_id:
		return
	_traveling = true
	look_target_id = -1
	if travel_button != null:
		travel_button.visible = false
	_run_hyperspace(id, system_id)


func _planet_world_position(id: int) -> Vector3:
	if distant_root == null:
		return Vector3.ZERO
	for child in distant_root.get_children():
		if child is Sprite3D and int(child.get_meta("planet_id", -1)) == id:
			return (child as Node3D).global_position
	return Vector3.ZERO


func _run_hyperspace(id: int, dest_system: int = -1) -> void:
	var target_pos := _planet_world_position(id)
	if target_pos.length_squared() < 0.01 and warp_gate != null:
		target_pos = warp_gate.global_position
	var player := get_tree().get_first_node_in_group("player") as CharacterBody3D
	if player != null:
		if target_pos.length_squared() > 0.01:
			var to_planet := target_pos - player.global_position
			if to_planet.length_squared() > 0.04 and absf(to_planet.normalized().dot(Vector3.UP)) < 0.98:
				player.look_at(target_pos, Vector3.UP)
		player.call("begin_hyperspace")
	var fx := HyperspaceFx.new()
	fx.name = "HyperspaceFx"
	add_child(fx)
	var env_node := get_node_or_null("WorldEnvironment") as WorldEnvironment
	var env: Environment = env_node.environment if env_node != null else null
	if env != null:
		env = env.duplicate() as Environment
		env_node.environment = env
	var glow0 := env.glow_intensity if env != null else 0.7
	var bloom0 := env.glow_bloom if env != null else 0.12
	var t := 0.0
	var duration := 1.75
	while t < duration and is_inside_tree():
		var delta := get_process_delta_time()
		if delta <= 0.0:
			delta = 1.0 / 60.0
		t += delta
		var u := clampf(t / duration, 0.0, 1.0)
		var eased := u * u * (3.0 - 2.0 * u)
		eased = eased * eased
		if fx.has_method("set_amount"):
			fx.call("set_amount", eased)
		if player != null:
			player.set("hyperspace_drive", eased)
		if env != null:
			env.glow_intensity = lerpf(glow0, 2.4, eased)
			env.glow_bloom = lerpf(bloom0, 0.85, eased)
		await get_tree().process_frame
	if env != null:
		env.glow_intensity = glow0
		env.glow_bloom = bloom0
	var sys := system_id if dest_system < 0 else Catalog.clamp_system(dest_system)
	get_tree().change_scene_to_file(Catalog.scene_path(id, sys))


func _face_station_to_open_space() -> void:
	if orbit_station == null:
		return
	var model := orbit_station.get_node_or_null("Model") as Node3D
	if model == null:
		return
	var away := (orbit_station.global_position - _planet_position)
	if away.length_squared() < 0.01:
		away = Vector3(0.0, 0.0, 1.0)
	away = away.normalized()
	var look_point := orbit_station.global_position + away
	if absf(away.dot(Vector3.UP)) < 0.98:
		model.look_at(look_point, Vector3.UP)


func _station_front_dir() -> Vector3:
	if orbit_station == null:
		return Vector3(0.0, 0.0, 1.0)
	var model := orbit_station.get_node_or_null("Model") as Node3D
	var forward := -orbit_station.global_transform.basis.z
	if model != null:
		forward = -model.global_transform.basis.z
	var away := orbit_station.global_position - _planet_position
	if away.length_squared() > 0.01 and forward.dot(away.normalized()) < 0.0:
		forward = -forward
	if forward.length_squared() < 0.01:
		forward = Vector3(0.0, 0.0, 1.0)
	return forward.normalized()


func _station_dock_point() -> Vector3:
	return orbit_station.global_position + _station_front_dir() * 118.0 + Vector3.UP * 12.0


func _start_station_autopilot() -> void:
	if _traveling or _docking or _station_open or _map_open or orbit_station == null:
		return
	_docking = true
	_dock_kind = "station"
	looking_at_station = false
	looking_at_warp = false
	look_target_id = -1
	var player := get_tree().get_first_node_in_group("player") as CharacterBody3D
	if player != null:
		player.call("begin_docking", _station_dock_point(), orbit_station.global_position)
	_show_cancel_prompt()


func _start_warp_autopilot() -> void:
	if _traveling or _docking or _station_open or _map_open or warp_gate == null:
		return
	_docking = true
	_dock_kind = "warp"
	looking_at_station = false
	looking_at_warp = false
	look_target_id = -1
	var player := get_tree().get_first_node_in_group("player") as CharacterBody3D
	if player != null:
		player.call("begin_docking", _warp_dock_point(), warp_gate.global_position)
	_show_cancel_prompt()


func _cancel_autopilot() -> void:
	if not _docking or _station_open or _map_open:
		return
	_docking = false
	_dock_kind = ""
	var player := get_tree().get_first_node_in_group("player") as CharacterBody3D
	if player != null:
		player.call("undock")
	if travel_button != null:
		travel_button.visible = false


func _tick_docking() -> void:
	_show_cancel_prompt()
	var player := get_tree().get_first_node_in_group("player") as CharacterBody3D
	if player != null and bool(player.call("is_dock_complete")):
		if _dock_kind == "warp":
			_open_galaxy_map()
		else:
			_open_station_menu()


func _show_cancel_prompt() -> void:
	if travel_button == null:
		return
	var suffix := "" if _touch_on() else "   ·   F"
	travel_button.text = "CANCEL AUTOPILOT%s" % suffix
	travel_button.visible = true
	travel_button.mouse_filter = (
		Control.MOUSE_FILTER_STOP if _touch_on() else Control.MOUSE_FILTER_IGNORE
	)
	var view_size := get_viewport().get_visible_rect().size
	var btn_size := travel_button.size
	if btn_size.x < 8.0:
		btn_size = travel_button.custom_minimum_size
	travel_button.position = Vector2(
		(view_size.x - btn_size.x) * 0.5,
		view_size.y - btn_size.y - 96.0
	)


func _open_station_menu() -> void:
	if _station_open:
		return
	_station_open = true
	_docking = false
	var player := get_tree().get_first_node_in_group("player") as CharacterBody3D
	if player != null:
		player.call("hold_at_dock")
	var hud := get_node_or_null("HUD") as CanvasLayer
	if hud != null:
		hud.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	station_menu = StationMenuFx.new()
	station_menu.name = "StationMenu"
	var progress := get_node_or_null("/root/GameSettings")
	if progress != null and progress.has_method("begin_station_visit"):
		progress.call("begin_station_visit", planet_id, system_id)
	add_child(station_menu)
	station_menu.call("setup", player, Catalog.planet_name(planet_id, system_id))
	if station_menu.has_signal("departed"):
		station_menu.connect("departed", _on_station_departed)


func _on_station_departed() -> void:
	_station_open = false
	var progress := get_node_or_null("/root/GameSettings")
	if progress != null and progress.has_method("end_station_visit"):
		progress.call("end_station_visit")
	if station_menu != null:
		station_menu.queue_free()
		station_menu = null
	_leave_overlay(_station_dock_point(), _station_front_dir())


func _open_galaxy_map() -> void:
	if _map_open or warp_gate == null:
		return
	_map_open = true
	_docking = false
	var player := get_tree().get_first_node_in_group("player") as CharacterBody3D
	if player != null:
		player.call("hold_at_dock")
	var hud := get_node_or_null("HUD") as CanvasLayer
	if hud != null:
		hud.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	galaxy_map = GalaxyMapFx.new()
	galaxy_map.name = "GalaxyMap"
	galaxy_map.set("current_system", system_id)
	add_child(galaxy_map)
	galaxy_map.call("setup", system_id)
	if galaxy_map.has_signal("closed"):
		galaxy_map.connect("closed", _on_galaxy_closed)
	if galaxy_map.has_signal("jump_requested"):
		galaxy_map.connect("jump_requested", _on_galaxy_jump)


func _on_galaxy_closed() -> void:
	_map_open = false
	if galaxy_map != null:
		galaxy_map.queue_free()
		galaxy_map = null
	_leave_overlay(_warp_dock_point(), _warp_front_dir())


func _on_galaxy_jump(target_system: int) -> void:
	if _traveling or not Catalog.is_linked(system_id, target_system):
		return
	_map_open = false
	if galaxy_map != null:
		galaxy_map.queue_free()
		galaxy_map = null
	var settings := get_node_or_null("/root/GameSettings")
	if settings != null and settings.has_method("set_current_system"):
		settings.call("set_current_system", target_system)
	_traveling = true
	if travel_button != null:
		travel_button.visible = false
	_run_hyperspace(Catalog.WARP_SLOT, target_system)


func _leave_overlay(dock_point: Vector3, front: Vector3) -> void:
	var hud := get_node_or_null("HUD") as CanvasLayer
	if hud != null:
		hud.visible = true
	var player := get_tree().get_first_node_in_group("player") as CharacterBody3D
	if player != null:
		var back := dock_point - front * 18.0
		player.global_position = back
		var away := player.global_position + front * 40.0
		if (away - player.global_position).length_squared() > 0.2:
			if absf((away - player.global_position).normalized().dot(Vector3.UP)) < 0.98:
				player.look_at(away, Vector3.UP)
		player.call("undock")
		if _touch_on():
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_dock_kind = ""


func _face_warp_to_open_space() -> void:
	if warp_gate == null:
		return
	var model := warp_gate.get_node_or_null("Model") as Node3D
	if model == null:
		return
	var away := (warp_gate.global_position - _planet_position)
	if away.length_squared() < 0.01:
		away = Vector3(0.0, 0.0, 1.0)
	away = away.normalized()
	var look_point := warp_gate.global_position + away
	if absf(away.dot(Vector3.UP)) < 0.98:
		model.look_at(look_point, Vector3.UP)


func _warp_front_dir() -> Vector3:
	if warp_gate == null:
		return Vector3(0.0, 0.0, 1.0)
	var model := warp_gate.get_node_or_null("Model") as Node3D
	var forward := -warp_gate.global_transform.basis.z
	if model != null:
		forward = -model.global_transform.basis.z
	var away := warp_gate.global_position - _planet_position
	if away.length_squared() > 0.01 and forward.dot(away.normalized()) < 0.0:
		forward = -forward
	if forward.length_squared() < 0.01:
		forward = Vector3(0.0, 0.0, 1.0)
	return forward.normalized()


func _warp_dock_point() -> Vector3:
	return warp_gate.global_position + _warp_front_dir() * 110.0 + Vector3.UP * (WARP_SCALE * 0.42)


func _look_hit(camera: Camera3D, look: Vector3, view_size: Vector2, world_pos: Vector3, min_dot: float) -> Dictionary:
	if camera.is_position_behind(world_pos):
		return {}
	var to_pos := world_pos - camera.global_position
	if to_pos.length_squared() < 1.0:
		return {}
	var facing := look.dot(to_pos.normalized())
	if facing < min_dot:
		return {}
	var screen := camera.unproject_position(world_pos)
	if not Rect2(Vector2(40, 40), view_size - Vector2(80, 80)).has_point(screen):
		return {}
	return {"facing": facing, "screen": screen}


func _make_warp_letter(offset: Vector3, pixel: float, font_px: int) -> Label3D:
	var mark := Label3D.new()
	mark.text = "W"
	mark.pixel_size = pixel
	mark.font_size = font_px
	mark.modulate = WARP_GOLD
	mark.outline_size = 14
	mark.outline_modulate = Color(0.22, 0.12, 0.02, 1.0)
	mark.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	mark.no_depth_test = true
	mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mark.position = offset
	return mark


func _update_local_warp_mark(camera: Camera3D) -> void:
	if warp_mark == null or local_planet == null or camera == null:
		return
	var to_cam := camera.global_position - local_planet.global_position
	if to_cam.length_squared() < 0.001:
		return
	var z_axis := to_cam.normalized()
	var right := z_axis.cross(Vector3.UP)
	if right.length_squared() < 0.001:
		right = z_axis.cross(Vector3.RIGHT)
	right = right.normalized()
	var up := right.cross(z_axis).normalized()
	warp_mark.global_position = local_planet.global_position + right * (_planet_radius + 95.0) + up * 80.0


func _apply_packed_albedo(root: Node, albedo: Texture2D) -> void:
	if root == null or albedo == null:
		return
	var stack: Array[Node] = [root]
	while stack.size() > 0:
		var n: Node = stack.pop_back()
		for child: Node in n.get_children():
			stack.append(child)
		if not (n is MeshInstance3D):
			continue
		var mesh := n as MeshInstance3D
		var src := mesh.get_active_material(0)
		var mat := StandardMaterial3D.new()
		if src is StandardMaterial3D:
			mat = (src as StandardMaterial3D).duplicate() as StandardMaterial3D
		mat.albedo_texture = albedo
		mat.albedo_color = Color.WHITE
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.metallic = 0.12
		mat.roughness = 0.52
		mat.emission_enabled = true
		mat.emission = Color(0.08, 0.1, 0.12, 1.0)
		mat.emission_texture = albedo
		mat.emission_energy_multiplier = 0.7
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		mesh.material_override = mat


func _settings_system() -> int:
	var settings := get_node_or_null("/root/GameSettings")
	if settings == null:
		return 0
	return Catalog.clamp_system(int(settings.get("current_system")))


func _touch_on() -> bool:
	var settings := get_node_or_null("/root/GameSettings")
	return settings != null and bool(settings.get("touch_controls_enabled"))
