extends StaticBody3D

var max_health: float = 36.0
var health: float = 36.0
var tumble: Vector3 = Vector3.ZERO
var visual: Node3D


func _ready() -> void:
	add_to_group("meteorites")
	collision_layer = 1
	collision_mask = 0


func setup(p_health: float, p_tumble: Vector3, p_visual: Node3D) -> void:
	max_health = p_health
	health = p_health
	tumble = p_tumble
	visual = p_visual


func _process(delta: float) -> void:
	if visual == null:
		return
	visual.rotate_x(tumble.x * delta)
	visual.rotate_y(tumble.y * delta)
	visual.rotate_z(tumble.z * delta)


func apply_damage(amount: float) -> void:
	if health <= 0.0:
		return
	health -= amount
	if health <= 0.0:
		var progress := get_node_or_null("/root/GameSettings")
		if progress != null and progress.has_method("notify_meteor_kill"):
			progress.call("notify_meteor_kill")
		queue_free()


func apply_missile_damage(_shield_damage: float, hull_damage: float) -> void:
	apply_damage(hull_damage)
