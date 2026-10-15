class_name SpawnAnchor
extends Marker3D

## Place this marker in a planet scene and pick a type.
## Planet / station / gate — one point. Pirate — one ship.
## Meteor field — a cluster of rocks within field_radius.

enum Kind { STATION, WARP, METEOR_FIELD, PIRATE, PLANET }

@export var kind: Kind = Kind.PIRATE
@export_range(1, 48) var meteor_count: int = 12
@export_range(10.0, 250.0) var field_radius: float = 48.0
@export_range(40.0, 800.0) var planet_radius: float = 390.0


func _enter_tree() -> void:
	add_to_group("spawn_anchor")
	if gizmo_extents < 16.0:
		gizmo_extents = 48.0
	if kind == Kind.METEOR_FIELD:
		gizmo_extents = maxf(gizmo_extents, field_radius)
	elif kind == Kind.STATION or kind == Kind.WARP:
		gizmo_extents = maxf(gizmo_extents, 80.0)
	elif kind == Kind.PLANET:
		gizmo_extents = maxf(gizmo_extents, planet_radius)
