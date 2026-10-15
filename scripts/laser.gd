extends Area3D

@export var speed: float = 340.0
@export var lifetime: float = 2.0
@export var damage: float = 12.0

var direction: Vector3 = Vector3(0.0, 0.0, -1.0)
var extra_velocity: Vector3 = Vector3.ZERO
var shooter: Node = null

func _ready() -> void:
	collision_layer = 4
	collision_mask = 1 | 2
	monitorable = false
	monitoring = true
	body_entered.connect(_on_body_entered)
	var timer := get_tree().create_timer(lifetime)
	timer.timeout.connect(queue_free)


func setup(spawn_transform: Transform3D, inherit_velocity: Vector3, p_shooter: Node = null) -> void:
	global_transform = spawn_transform
	direction = -spawn_transform.basis.z.normalized()
	extra_velocity = inherit_velocity
	shooter = p_shooter


func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta + extra_velocity * delta


func _on_body_entered(body: Node) -> void:
	if shooter != null and body == shooter:
		return
	if shooter != null and shooter.is_in_group("player") and body.is_in_group("player"):
		return
	if shooter != null and shooter.is_in_group("enemies") and body.is_in_group("enemies"):
		return
	var is_enemy := body.is_in_group("enemies")
	if body.has_method("apply_damage"):
		body.call("apply_damage", damage)
	if is_enemy:
		_report_player_hit(body)
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
