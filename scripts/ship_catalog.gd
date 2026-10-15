extends RefCounted

const DIR := "res://data/ships"
const DEFAULT_ID := "capsule"
const SHIP_IDS := ["capsule", "dantist", "gladis", "bigboy", "gladiator"]

const TEX_CAPSULE := preload("res://assets/models/starship/capsule_tripo_image_692cd0c7-c77f-4be8-a844-d04ddbf001a2_0_0.jpg")
const TEX_DANTIST := preload("res://assets/models/starship/dantist_tripo_image_68bee17a-550d-47e6-b77f-6b6ae2c9d409_0_0.jpg")
const TEX_GLADIS := preload("res://assets/models/starship/gladis_tripo_image_53f497ea-deef-4437-bb44-bdb2ed0ced9d_0_0.jpg")
const TEX_BIGBOY := preload("res://assets/models/starship/bigboy_tripo_image_9c4007b2-5ed5-4024-9133-33647159ba58_0_0.jpg")
const TEX_GLADIATOR := preload("res://assets/models/starship/gladiator_tripo_image_488ceb9b-e755-4722-ad96-8380350f2d5d_0_0.jpg")
const TEX_SHIP1 := preload("res://assets/models/starship/ship1_tripo_image_ac21b834-43e3-438f-8ce2-b96a70acb9db_0_0.jpg")

const SCENE_CAPSULE := "res://scenes/ships/capsule.tscn"
const SCENE_DANTIST := "res://scenes/ships/dantist.tscn"
const SCENE_GLADIS := "res://scenes/ships/gladis.tscn"
const SCENE_BIGBOY := "res://scenes/ships/bigboy.tscn"
const SCENE_GLADIATOR := "res://scenes/ships/gladiator.tscn"
const MODEL_CAPSULE := "res://assets/models/starship/capsule.glb"
const MODEL_DANTIST := "res://assets/models/starship/dantist.glb"
const MODEL_GLADIS := "res://assets/models/starship/gladis.glb"
const MODEL_BIGBOY := "res://assets/models/starship/bigboy.glb"
const MODEL_GLADIATOR := "res://assets/models/starship/gladiator.glb"
const MODEL_SHIP1 := "res://assets/models/starship/ship1.glb"


static func all_ids() -> PackedStringArray:
	return PackedStringArray(SHIP_IDS)


static func exists(id: String) -> bool:
	return SHIP_IDS.has(id)


static func spec(id: String) -> Dictionary:
	var key := id if exists(id) else DEFAULT_ID
	return _load_cfg(key)


static func all_specs() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for ship_id: String in SHIP_IDS:
		out.append(spec(ship_id))
	return out


static func instantiate_model(id: String, for_preview: bool = false) -> Node3D:
	var data := spec(id)
	var model := _model_from_scene(String(data.get("scene", "")))
	if model == null:
		var packed := load(String(data["model"])) as PackedScene
		if packed == null:
			return null
		model = packed.instantiate() as Node3D
		if model == null:
			return null
		var sc := float(data["preview_scale"] if for_preview else data["scale"])
		model.scale = Vector3.ONE * sc
		if for_preview:
			model.position = Vector3(0.0, -0.6, 0.0)
		else:
			model.position = data["model_offset"] as Vector3
	elif for_preview:
		var live := float(data["scale"])
		var preview := float(data["preview_scale"])
		if live > 0.001:
			model.scale *= preview / live
		model.position = Vector3(0.0, -0.6, 0.0)
	apply_packed_albedo(model, albedo_for(data))
	return model


static func _model_from_scene(scene_path: String) -> Node3D:
	if scene_path == "":
		return null
	var packed := load(scene_path) as PackedScene
	if packed == null:
		return null
	var hull := packed.instantiate() as Node
	if hull == null:
		return null
	var model := hull.get_node_or_null("Model") as Node3D
	if model != null:
		hull.remove_child(model)
	hull.free()
	return model


static func albedo_for(data: Dictionary) -> Texture2D:
	var explicit := String(data.get("albedo", ""))
	if explicit != "":
		var loaded := load(explicit) as Texture2D
		if loaded != null:
			return loaded
	return albedo_for_id(String(data.get("id", DEFAULT_ID)))


static func albedo_for_id(id: String) -> Texture2D:
	match id:
		"dantist":
			return TEX_DANTIST
		"gladis":
			return TEX_GLADIS
		"bigboy":
			return TEX_BIGBOY
		"gladiator":
			return TEX_GLADIATOR
		"ship1":
			return TEX_SHIP1
		_:
			return TEX_CAPSULE


static func albedo_for_model(model_path: String) -> Texture2D:
	match model_path:
		MODEL_DANTIST:
			return TEX_DANTIST
		MODEL_GLADIS:
			return TEX_GLADIS
		MODEL_BIGBOY:
			return TEX_BIGBOY
		MODEL_GLADIATOR:
			return TEX_GLADIATOR
		MODEL_SHIP1:
			return TEX_SHIP1
		_:
			return TEX_CAPSULE


static func find_sibling_albedo(model_path: String) -> Texture2D:
	return albedo_for_model(model_path)


static func apply_packed_albedo(root: Node, albedo: Texture2D) -> void:
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
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = albedo
		mat.albedo_color = Color.WHITE
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.metallic = 0.0
		mat.metallic_specular = 0.2
		mat.roughness = 0.58
		mat.emission_enabled = true
		mat.emission = Color(0.06, 0.07, 0.09, 1.0)
		mat.emission_texture = albedo
		mat.emission_energy_multiplier = 0.85
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
		mesh.material_override = mat


static func stats_line(data: Dictionary) -> String:
	return "Speed %d  ·  Hull %d  ·  Shields %d" % [
		int(round(float(data["max_speed"]))),
		int(round(float(data["max_health"]))),
		int(round(float(data["max_shields"]))),
	]


static func _base_spec(id: String) -> Dictionary:
	match id:
		"dantist":
			return {
				"id": "dantist",
				"display_name": "Dantist",
				"blurb": "Strike interceptor. Mean guns and a tough frame — the workhorse of orbital patrol.",
				"price": 42000,
				"scene": SCENE_DANTIST,
				"model": MODEL_DANTIST,
				"albedo": TEX_DANTIST.resource_path,
				"scale": 10.0,
				"preview_scale": 5.2,
				"model_offset": Vector3(0.0, -2.22, 0.0),
				"max_speed": 98.0,
				"boost_speed": 168.0,
				"acceleration": 58.0,
				"brake_deceleration": 88.0,
				"roll_speed": 2.3,
				"lift_speed": 32.0,
				"max_health": 125.0,
				"max_shields": 115.0,
				"shield_regen_delay": 4.8,
				"shield_regen_rate": 6.0,
				"fire_interval": 0.12,
				"missile_interval": 1.15,
				"crash_damage": 20.0,
				"collision_size": Vector3(7.4, 3.4, 9.4),
				"camera_position": Vector3(0.0, 3.6, 13.2),
				"muzzle_left": Vector3(-0.92, -0.16, -4.85),
				"muzzle_right": Vector3(0.92, -0.16, -4.85),
				"missile_offset": Vector3(0.0, -0.4, -4.4),
				"trail_left": Vector3(-0.74, -0.36, 4.74),
				"trail_right": Vector3(0.96, -0.43, 4.75),
			}
		"gladis":
			return {
				"id": "gladis",
				"display_name": "Gladis",
				"blurb": "Flagship hunter. Best shields, speed, and missiles — top of the dock, if you can afford it.",
				"price": 98000,
				"scene": SCENE_GLADIS,
				"model": MODEL_GLADIS,
				"albedo": TEX_GLADIS.resource_path,
				"scale": 10.0,
				"preview_scale": 4.8,
				"model_offset": Vector3(0.0, -2.4, 0.0),
				"max_speed": 125.0,
				"boost_speed": 210.0,
				"acceleration": 72.0,
				"brake_deceleration": 96.0,
				"roll_speed": 2.1,
				"lift_speed": 36.0,
				"max_health": 170.0,
				"max_shields": 190.0,
				"shield_regen_delay": 3.8,
				"shield_regen_rate": 8.5,
				"fire_interval": 0.09,
				"missile_interval": 0.85,
				"crash_damage": 22.0,
				"collision_size": Vector3(8.6, 3.9, 11.2),
				"camera_position": Vector3(0.0, 4.1, 15.0),
				"muzzle_left": Vector3(-1.12, -0.18, -5.4),
				"muzzle_right": Vector3(1.12, -0.18, -5.4),
				"missile_offset": Vector3(0.0, -0.48, -5.0),
				"trail_left": Vector3(-0.9, -0.42, 5.4),
				"trail_right": Vector3(0.9, -0.42, 5.4),
			}
		"bigboy":
			return {
				"id": "bigboy",
				"display_name": "Bigboy",
				"blurb": "Heavy assault craft. Three lasers and a twin missile volley — slow as the Capsule, but it soaks hits.",
				"price": 186000,
				"scene": SCENE_BIGBOY,
				"model": MODEL_BIGBOY,
				"albedo": TEX_BIGBOY.resource_path,
				"scale": 10.0,
				"preview_scale": 4.0,
				"model_offset": Vector3(0.0, -2.8, 0.0),
				"max_speed": 72.0,
				"boost_speed": 128.0,
				"acceleration": 36.0,
				"brake_deceleration": 70.0,
				"roll_speed": 1.7,
				"lift_speed": 24.0,
				"max_health": 280.0,
				"max_shields": 260.0,
				"shield_regen_delay": 6.2,
				"shield_regen_rate": 7.2,
				"fire_interval": 0.16,
				"missile_interval": 1.45,
				"crash_damage": 28.0,
				"collision_size": Vector3(11.2, 5.2, 14.4),
				"camera_position": Vector3(0.0, 5.6, 18.0),
				"muzzle_left": Vector3(-1.4, -0.2, -6.2),
				"muzzle_right": Vector3(1.4, -0.2, -6.2),
				"missile_offset": Vector3(-0.55, -0.5, -5.6),
				"trail_left": Vector3(-1.2, -0.55, 6.4),
				"trail_right": Vector3(1.2, -0.55, 6.4),
			}
		"gladiator":
			return {
				"id": "gladiator",
				"display_name": "Gladiator",
				"blurb": "Orbital giant. Four lasers and four missiles per volley — crawls along, but its armor is station-grade.",
				"price": 340000,
				"scene": SCENE_GLADIATOR,
				"model": MODEL_GLADIATOR,
				"albedo": TEX_GLADIATOR.resource_path,
				"scale": 10.0,
				"preview_scale": 3.4,
				"model_offset": Vector3(0.0, -3.2, 0.0),
				"max_speed": 54.0,
				"boost_speed": 96.0,
				"acceleration": 26.0,
				"brake_deceleration": 62.0,
				"roll_speed": 1.35,
				"lift_speed": 18.0,
				"max_health": 420.0,
				"max_shields": 400.0,
				"shield_regen_delay": 7.0,
				"shield_regen_rate": 8.0,
				"fire_interval": 0.18,
				"missile_interval": 1.7,
				"crash_damage": 36.0,
				"collision_size": Vector3(14.0, 6.4, 18.2),
				"camera_position": Vector3(0.0, 7.2, 24.0),
				"muzzle_left": Vector3(-1.8, -0.25, -7.4),
				"muzzle_right": Vector3(1.8, -0.25, -7.4),
				"missile_offset": Vector3(-1.1, -0.55, -6.4),
				"trail_left": Vector3(-1.5, -0.7, 7.6),
				"trail_right": Vector3(1.5, -0.7, 7.6),
			}
		_:
			return {
				"id": "capsule",
				"display_name": "Capsule",
				"blurb": "Rescue shuttle. Starter ship — light, nimble, and cramped, but it will get you to a station.",
				"price": 0,
				"scene": SCENE_CAPSULE,
				"model": MODEL_CAPSULE,
				"albedo": TEX_CAPSULE.resource_path,
				"scale": 10.0,
				"preview_scale": 5.4,
				"model_offset": Vector3(0.0, -2.22, 0.0),
				"max_speed": 72.0,
				"boost_speed": 128.0,
				"acceleration": 44.0,
				"brake_deceleration": 78.0,
				"roll_speed": 2.6,
				"lift_speed": 30.0,
				"max_health": 80.0,
				"max_shields": 70.0,
				"shield_regen_delay": 5.5,
				"shield_regen_rate": 4.2,
				"fire_interval": 0.17,
				"missile_interval": 1.55,
				"crash_damage": 16.0,
				"collision_size": Vector3(5.8, 2.8, 7.6),
				"camera_position": Vector3(0.0, 3.2, 12.2),
				"muzzle_left": Vector3(-0.68, -0.12, -3.9),
				"muzzle_right": Vector3(0.68, -0.12, -3.9),
				"missile_offset": Vector3(0.0, -0.32, -3.6),
				"trail_left": Vector3(-0.48, -0.24, 3.7),
				"trail_right": Vector3(0.48, -0.24, 3.7),
			}


static func _load_cfg(id: String) -> Dictionary:
	var data := _base_spec(id)
	var path := "%s/%s.cfg" % [DIR, id]
	var config := ConfigFile.new()
	if config.load(path) != OK:
		return data
	data["id"] = String(config.get_value("ship", "id", id))
	data["display_name"] = String(config.get_value("ship", "display_name", data["display_name"]))
	data["blurb"] = String(config.get_value("ship", "blurb", data["blurb"]))
	data["price"] = int(config.get_value("ship", "price", data["price"]))
	data["scene"] = String(config.get_value("ship", "scene", data.get("scene", "")))
	data["model"] = String(config.get_value("ship", "model", data["model"]))
	data["albedo"] = String(config.get_value("ship", "albedo", data.get("albedo", "")))
	data["scale"] = float(config.get_value("ship", "scale", data["scale"]))
	data["preview_scale"] = float(config.get_value("ship", "preview_scale", data["preview_scale"]))
	data["model_offset"] = _vec3(config.get_value("ship", "model_offset", ""), data["model_offset"] as Vector3)
	data["max_speed"] = float(config.get_value("stats", "max_speed", data["max_speed"]))
	data["boost_speed"] = float(config.get_value("stats", "boost_speed", data["boost_speed"]))
	data["acceleration"] = float(config.get_value("stats", "acceleration", data["acceleration"]))
	data["brake_deceleration"] = float(config.get_value("stats", "brake_deceleration", data["brake_deceleration"]))
	data["roll_speed"] = float(config.get_value("stats", "roll_speed", data["roll_speed"]))
	data["lift_speed"] = float(config.get_value("stats", "lift_speed", data["lift_speed"]))
	data["max_health"] = float(config.get_value("stats", "max_health", data["max_health"]))
	data["max_shields"] = float(config.get_value("stats", "max_shields", data["max_shields"]))
	data["shield_regen_delay"] = float(config.get_value("stats", "shield_regen_delay", data["shield_regen_delay"]))
	data["shield_regen_rate"] = float(config.get_value("stats", "shield_regen_rate", data["shield_regen_rate"]))
	data["fire_interval"] = float(config.get_value("stats", "fire_interval", data["fire_interval"]))
	data["missile_interval"] = float(config.get_value("stats", "missile_interval", data["missile_interval"]))
	data["crash_damage"] = float(config.get_value("stats", "crash_damage", data["crash_damage"]))
	data["collision_size"] = _vec3(config.get_value("layout", "collision_size", ""), data["collision_size"] as Vector3)
	data["camera_position"] = _vec3(config.get_value("layout", "camera_position", ""), data["camera_position"] as Vector3)
	data["muzzle_left"] = _vec3(config.get_value("layout", "muzzle_left", ""), data["muzzle_left"] as Vector3)
	data["muzzle_right"] = _vec3(config.get_value("layout", "muzzle_right", ""), data["muzzle_right"] as Vector3)
	data["missile_offset"] = _vec3(config.get_value("layout", "missile_offset", ""), data["missile_offset"] as Vector3)
	data["trail_left"] = _vec3(config.get_value("layout", "trail_left", ""), data["trail_left"] as Vector3)
	data["trail_right"] = _vec3(config.get_value("layout", "trail_right", ""), data["trail_right"] as Vector3)
	return data


static func _vec3(raw: Variant, fallback: Vector3) -> Vector3:
	if raw is Vector3:
		return raw
	var text := String(raw).strip_edges()
	if text == "":
		return fallback
	var parts := text.split(",")
	if parts.size() < 3:
		return fallback
	return Vector3(
		parts[0].strip_edges().to_float(),
		parts[1].strip_edges().to_float(),
		parts[2].strip_edges().to_float()
	)
