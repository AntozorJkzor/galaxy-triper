class_name CombatStats
extends RefCounted

enum HitLayer { NONE, SHIELD, HULL }

var max_health: float = 100.0
var max_shields: float = 100.0
var health: float = 100.0
var shields: float = 100.0
var shield_regen_delay: float = 5.0
var shield_regen_rate: float = 5.0
var time_since_damage: float = 9999.0


func configure(p_health: float, p_shields: float, p_delay: float, p_rate: float) -> void:
	max_health = p_health
	max_shields = p_shields
	health = p_health
	shields = p_shields
	shield_regen_delay = p_delay
	shield_regen_rate = p_rate
	time_since_damage = 9999.0


func is_alive() -> bool:
	return health > 0.0


func apply_damage(amount: float) -> int:
	if amount <= 0.0 or health <= 0.0:
		return HitLayer.NONE
	time_since_damage = 0.0
	var remaining := amount
	if shields > 0.0:
		var absorbed := minf(shields, remaining)
		shields -= absorbed
		remaining -= absorbed
	if remaining > 0.0:
		health = maxf(0.0, health - remaining)
		return HitLayer.HULL
	return HitLayer.SHIELD


func apply_missile_damage(shield_damage: float, hull_damage: float) -> int:
	if health <= 0.0:
		return HitLayer.NONE
	time_since_damage = 0.0
	if shields > 0.0:
		shields = maxf(0.0, shields - maxf(0.0, shield_damage))
		return HitLayer.SHIELD
	health = maxf(0.0, health - maxf(0.0, hull_damage))
	return HitLayer.HULL


func restore_hull() -> void:
	health = max_health


func restore_shields() -> void:
	shields = max_shields
	time_since_damage = shield_regen_delay


func tick(p_delta: float) -> void:
	if health <= 0.0:
		return
	time_since_damage += p_delta
	if time_since_damage >= shield_regen_delay and shields < max_shields:
		shields = minf(max_shields, shields + shield_regen_rate * p_delta)
