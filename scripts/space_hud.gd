extends CanvasLayer

const CrosshairScene := preload("res://scripts/crosshair.gd")
const EnemyHudScene := preload("res://scripts/enemy_hud.gd")

@onready var speed_label: Label = %SpeedLabel
@onready var throttle_bar: ProgressBar = %ThrottleBar
@onready var boost_label: Label = %BoostLabel
@onready var health_label: Label = %HealthLabel
@onready var health_bar: ProgressBar = %HealthBar
@onready var shield_label: Label = %ShieldLabel
@onready var shield_bar: ProgressBar = %ShieldBar
@onready var pause_panel: Control = %PausePanel

var player: CharacterBody3D
var crosshair: Control
var enemy_hud: Control

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("space_hud")
	pause_panel.visible = false
	player = get_tree().get_first_node_in_group("player") as CharacterBody3D
	$Root/PausePanel/PauseBox/ResumeButton.pressed.connect(_on_resume_pressed)
	$Root/PausePanel/PauseBox/MenuButton.pressed.connect(_on_menu_pressed)
	var touch := $Root.get_node_or_null("TouchControls")
	if touch != null and touch.has_signal("pause_requested"):
		touch.connect("pause_requested", _on_touch_pause_pressed)
	var hint := $Root.get_node_or_null("HintLabel") as Label
	if hint != null:
		hint.visible = not _touch_setting_on()
	_setup_crosshair()
	_setup_enemy_hud()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		var ship := get_tree().get_first_node_in_group("player")
		if ship != null and bool(ship.get("hyperspace_active")):
			get_viewport().set_input_as_handled()
			return
		_set_paused(not get_tree().paused)
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if player == null:
		player = get_tree().get_first_node_in_group("player") as CharacterBody3D
		return
	if not player.has_method("get_display_speed"):
		return

	var speed: float = player.call("get_display_speed")
	var throttle: float = player.call("get_throttle")
	speed_label.text = "SPEED  %d u/s" % int(round(speed))
	throttle_bar.value = absf(throttle) * 100.0
	boost_label.visible = bool(player.call("is_boosting"))

	var health: float = player.call("get_health")
	var shields: float = player.call("get_shields")
	health_label.text = "HULL  %d" % int(round(health))
	health_bar.max_value = player.call("get_max_health")
	health_bar.value = health
	shield_label.text = "SHIELDS  %d" % int(round(shields))
	shield_bar.max_value = player.call("get_max_shields")
	shield_bar.value = shields
	_update_crosshair()


func _on_resume_pressed() -> void:
	_set_paused(false)


func _on_touch_pause_pressed() -> void:
	_set_paused(not get_tree().paused)


func _on_menu_pressed() -> void:
	_set_paused(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _set_paused(paused: bool) -> void:
	get_tree().paused = paused
	pause_panel.visible = paused
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if paused else _play_mouse_mode()


func _play_mouse_mode() -> Input.MouseMode:
	if _touch_setting_on():
		return Input.MOUSE_MODE_VISIBLE
	return Input.MOUSE_MODE_CAPTURED


func _setup_enemy_hud() -> void:
	var root := $Root as Control
	enemy_hud = EnemyHudScene.new()
	enemy_hud.name = "EnemyHud"
	root.add_child(enemy_hud)


func _setup_crosshair() -> void:
	var root := $Root as Control
	var old := root.get_node_or_null("Crosshair")
	crosshair = CrosshairScene.new()
	crosshair.name = "WeaponCrosshair"
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(crosshair)
	if old != null:
		old.visible = false


func _update_crosshair() -> void:
	if crosshair == null:
		return
	if get_tree().paused or player == null:
		crosshair.visible = false
		return
	crosshair.visible = true
	crosshair.size = Vector2(36, 36)
	var root := $Root as Control
	var center := root.size * 0.5 if root != null else get_viewport().get_visible_rect().size * 0.5
	crosshair.position = center - crosshair.size * 0.5


func show_weapon_hit(killed: bool) -> void:
	if crosshair != null and crosshair.has_method("show_hit"):
		crosshair.call("show_hit", killed)


func _touch_setting_on() -> bool:
	var settings := get_node_or_null("/root/GameSettings")
	return settings != null and bool(settings.get("touch_controls_enabled"))

