extends Node

const Catalog := preload("res://scripts/planet_catalog.gd")
const Ships := preload("res://scripts/ship_catalog.gd")

const SETTINGS_PATH := "user://settings.cfg"
const SAVE_DIR := "user://saves"
const AUTOSAVE_PATH := "user://saves/autosave.cfg"
const MANUAL_PATH := "user://saves/manual.cfg"
const STARTING_CREDITS := 1_000_000
const STARTER_SHIP := "capsule"

const MISSIONS := [
	{
		"id": "pirates_10",
		"title": "Orbit sweep",
		"desc": "Pirates are raiding convoys near the station. Destroy 10 of their ships.",
		"kind": "pirates",
		"target": 10,
		"reward": 450,
	},
	{
		"id": "pirates_25",
		"title": "Raider hunt",
		"desc": "The bar captain wants the sector quiet. Shoot down 25 pirates.",
		"kind": "pirates",
		"target": 25,
		"reward": 1100,
	},
	{
		"id": "meteors_12",
		"title": "Clear the field",
		"desc": "A meteor stream is blocking docking. Destroy 12 rocks.",
		"kind": "meteors",
		"target": 12,
		"reward": 280,
	},
]

var touch_controls_enabled: bool = false
var credits: int = STARTING_CREDITS
var pirate_kills: int = 0
var meteor_kills: int = 0
var current_system: int = 0
var current_planet: int = 0
var mission_states: Dictionary = {}
var current_ship: String = STARTER_SHIP
var owned_ships: PackedStringArray = PackedStringArray([STARTER_SHIP])
var at_station: bool = false
var last_save_unix: int = 0
var last_save_kind: String = ""


func _ready() -> void:
	_load_settings()
	_ensure_mission_states()
	_migrate_legacy_progress()


func set_touch_controls_enabled(enabled: bool) -> void:
	touch_controls_enabled = enabled
	_save_settings()


func set_current_system(system_id: int) -> void:
	current_system = Catalog.clamp_system(system_id)


func set_current_planet(planet_id: int) -> void:
	current_planet = Catalog.clamp_planet(planet_id)


func begin_station_visit(planet_id: int, system_id: int) -> bool:
	at_station = true
	current_planet = Catalog.clamp_planet(planet_id)
	current_system = Catalog.clamp_system(system_id)
	return autosave()


func end_station_visit() -> void:
	if at_station:
		autosave()
	at_station = false


func can_save() -> bool:
	return at_station


func has_save() -> bool:
	return FileAccess.file_exists(AUTOSAVE_PATH) or FileAccess.file_exists(MANUAL_PATH)


func autosave() -> bool:
	if not at_station:
		return false
	return _write_save(AUTOSAVE_PATH, "autosave")


func manual_save() -> bool:
	if not at_station:
		return false
	return _write_save(MANUAL_PATH, "manual")


func load_latest_save() -> bool:
	var path := _latest_save_path()
	if path == "":
		return false
	return _read_save(path)


func start_new_game() -> void:
	at_station = false
	credits = STARTING_CREDITS
	pirate_kills = 0
	meteor_kills = 0
	current_system = 0
	current_planet = 0
	current_ship = STARTER_SHIP
	owned_ships = PackedStringArray([STARTER_SHIP])
	mission_states = {}
	last_save_unix = 0
	last_save_kind = ""
	_ensure_mission_states()


func continue_scene_path() -> String:
	return Catalog.scene_path(current_planet, current_system)


func save_summary() -> String:
	if not has_save():
		return ""
	var path := _latest_save_path()
	if path == "":
		return ""
	var config := ConfigFile.new()
	if config.load(path) != OK:
		return ""
	var cr := int(config.get_value("progress", "credits", STARTING_CREDITS))
	var sys := Catalog.clamp_system(int(config.get_value("meta", "system", 0)))
	var planet := Catalog.clamp_planet(int(config.get_value("meta", "planet", 0)))
	var kind := String(config.get_value("meta", "kind", "save"))
	var stamp := _format_time(int(config.get_value("meta", "time", 0)))
	var kind_label := "autosave" if kind == "autosave" else "save"
	return "%s  ·  %s  ·  %d cr.  ·  %s" % [Catalog.planet_name(planet, sys), Catalog.system_name(sys), cr, kind_label if stamp == "" else stamp]


func all_missions() -> Array:
	return MISSIONS


func mission_spec(id: String) -> Dictionary:
	for spec: Dictionary in MISSIONS:
		if String(spec["id"]) == id:
			return spec
	return {}


func mission_state(id: String) -> Dictionary:
	if not mission_states.has(id):
		mission_states[id] = {
			"accepted": false,
			"progress": 0,
			"completed": false,
			"claimed": false,
		}
	return mission_states[id] as Dictionary


func accept_mission(id: String) -> bool:
	var spec := mission_spec(id)
	var state := mission_state(id)
	if spec.is_empty() or bool(state["accepted"]) or bool(state["claimed"]):
		return false
	state["accepted"] = true
	_save_if_station()
	return true


func claim_mission(id: String) -> bool:
	var spec := mission_spec(id)
	var state := mission_state(id)
	if spec.is_empty() or not bool(state["completed"]) or bool(state["claimed"]):
		return false
	state["claimed"] = true
	credits += int(spec["reward"])
	_save_if_station()
	return true


func notify_pirate_kill() -> void:
	pirate_kills += 1
	_advance_missions("pirates")


func notify_meteor_kill() -> void:
	meteor_kills += 1
	_advance_missions("meteors")


func spend_credits(amount: int) -> bool:
	if amount <= 0 or credits < amount:
		return false
	credits -= amount
	_save_if_station()
	return true


func owns_ship(id: String) -> bool:
	return owned_ships.has(id)


func buy_ship(id: String) -> bool:
	if not Ships.exists(id) or owns_ship(id):
		return false
	var price := int(Ships.spec(id)["price"])
	if price > 0 and not spend_credits(price):
		return false
	owned_ships.append(id)
	_save_if_station()
	return true


func equip_ship(id: String) -> bool:
	if not Ships.exists(id) or not owns_ship(id):
		return false
	current_ship = id
	_save_if_station()
	return true


func _advance_missions(kind: String) -> void:
	for spec: Dictionary in MISSIONS:
		if String(spec["kind"]) != kind:
			continue
		var state := mission_state(String(spec["id"]))
		if not bool(state["accepted"]) or bool(state["completed"]):
			continue
		state["progress"] = mini(int(state["progress"]) + 1, int(spec["target"]))
		if int(state["progress"]) >= int(spec["target"]):
			state["completed"] = true


func _ensure_mission_states() -> void:
	for spec: Dictionary in MISSIONS:
		mission_state(String(spec["id"]))


func _save_if_station() -> void:
	if at_station:
		autosave()


func _latest_save_path() -> String:
	var auto_time := _save_time(AUTOSAVE_PATH)
	var manual_time := _save_time(MANUAL_PATH)
	if auto_time <= 0 and manual_time <= 0:
		return ""
	if manual_time >= auto_time:
		return MANUAL_PATH
	return AUTOSAVE_PATH


func _save_time(path: String) -> int:
	if not FileAccess.file_exists(path):
		return 0
	var config := ConfigFile.new()
	if config.load(path) != OK:
		return 0
	return int(config.get_value("meta", "time", 0))


func _write_save(path: String, kind: String) -> bool:
	_ensure_save_dir()
	var config := ConfigFile.new()
	var now := int(Time.get_unix_time_from_system())
	config.set_value("meta", "kind", kind)
	config.set_value("meta", "time", now)
	config.set_value("meta", "system", current_system)
	config.set_value("meta", "planet", current_planet)
	config.set_value("progress", "credits", credits)
	config.set_value("progress", "pirate_kills", pirate_kills)
	config.set_value("progress", "meteor_kills", meteor_kills)
	config.set_value("progress", "missions", JSON.stringify(mission_states))
	config.set_value("ship", "current", current_ship)
	config.set_value("ship", "owned", JSON.stringify(Array(owned_ships)))
	var err := config.save(path)
	if err != OK:
		return false
	last_save_unix = now
	last_save_kind = kind
	return true


func _read_save(path: String) -> bool:
	var config := ConfigFile.new()
	if config.load(path) != OK:
		return false
	credits = int(config.get_value("progress", "credits", STARTING_CREDITS))
	pirate_kills = int(config.get_value("progress", "pirate_kills", 0))
	meteor_kills = int(config.get_value("progress", "meteor_kills", 0))
	current_system = Catalog.clamp_system(int(config.get_value("meta", "system", 0)))
	current_planet = Catalog.clamp_planet(int(config.get_value("meta", "planet", 0)))
	last_save_unix = int(config.get_value("meta", "time", 0))
	last_save_kind = String(config.get_value("meta", "kind", ""))
	mission_states = {}
	var raw := String(config.get_value("progress", "missions", ""))
	if raw != "":
		var parsed: Variant = JSON.parse_string(raw)
		if parsed is Dictionary:
			mission_states = parsed
	_ensure_mission_states()
	_read_ship_profile(config)
	at_station = false
	return true


func _read_ship_profile(config: ConfigFile) -> void:
	current_ship = String(config.get_value("ship", "current", STARTER_SHIP))
	owned_ships = PackedStringArray()
	var raw: Variant = config.get_value("ship", "owned", "")
	if raw is PackedStringArray:
		owned_ships = raw
	elif raw is Array:
		for item: Variant in raw:
			owned_ships.append(String(item))
	else:
		var text := String(raw)
		if text != "":
			var parsed: Variant = JSON.parse_string(text)
			if parsed is Array:
				for item: Variant in parsed:
					owned_ships.append(String(item))
			else:
				for part: String in text.split(","):
					var id := part.strip_edges()
					if id != "":
						owned_ships.append(id)
	if not owned_ships.has(STARTER_SHIP):
		owned_ships.append(STARTER_SHIP)
	if not Ships.exists(current_ship) or not owns_ship(current_ship):
		current_ship = STARTER_SHIP


func _ensure_save_dir() -> void:
	var dir := DirAccess.open("user://")
	if dir == null:
		return
	if not dir.dir_exists("saves"):
		dir.make_dir("saves")


func _format_time(unix: int) -> String:
	if unix <= 0:
		return ""
	var t: Dictionary = Time.get_datetime_dict_from_unix_time(unix)
	return "%02d.%02d %02d:%02d" % [int(t["day"]), int(t["month"]), int(t["hour"]), int(t["minute"])]


func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		touch_controls_enabled = false
		return
	touch_controls_enabled = bool(config.get_value("controls", "touch", false))


func _save_settings() -> void:
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value("controls", "touch", touch_controls_enabled)
	config.save(SETTINGS_PATH)


func _migrate_legacy_progress() -> void:
	if has_save():
		return
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	if not config.has_section_key("progress", "credits") and not config.has_section_key("progress", "missions"):
		return
	credits = int(config.get_value("progress", "credits", STARTING_CREDITS))
	pirate_kills = int(config.get_value("progress", "pirate_kills", 0))
	meteor_kills = int(config.get_value("progress", "meteor_kills", 0))
	current_system = Catalog.clamp_system(int(config.get_value("galaxy", "system", 0)))
	var raw := String(config.get_value("progress", "missions", ""))
	if raw != "":
		var parsed: Variant = JSON.parse_string(raw)
		if parsed is Dictionary:
			mission_states = parsed
	_ensure_mission_states()
	at_station = true
	autosave()
	at_station = false
	config.load(SETTINGS_PATH)
	if config.has_section("progress"):
		config.erase_section("progress")
	if config.has_section("galaxy"):
		config.erase_section("galaxy")
	config.set_value("controls", "touch", touch_controls_enabled)
	config.save(SETTINGS_PATH)
