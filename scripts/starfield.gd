extends MultiMeshInstance3D

@export var star_count: int = 2800
@export var radius: float = 650.0

func _ready() -> void:
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var mesh := SphereMesh.new()
	mesh.radius = 0.35
	mesh.height = 0.7
	mesh.radial_segments = 4
	mesh.rings = 2

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.albedo_color = Color.WHITE
	material.disable_receive_shadows = true
	mesh.material = material

	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.mesh = mesh
	multi.instance_count = star_count

	var rng := RandomNumberGenerator.new()
	rng.randomize()

	for i: int in star_count:
		var direction := Vector3(
			rng.randf_range(-1.0, 1.0),
			rng.randf_range(-1.0, 1.0),
			rng.randf_range(-1.0, 1.0)
		).normalized()
		var distance := rng.randf_range(radius * 0.5, radius)
		var star_scale := rng.randf_range(0.25, 2.2)
		var transform_3d := Transform3D.IDENTITY.scaled(Vector3.ONE * star_scale)
		transform_3d.origin = direction * distance
		multi.set_instance_transform(i, transform_3d)

		var color := Color(0.85, 0.9, 1.0)
		var roll := rng.randf()
		if roll < 0.12:
			color = Color(0.55, 0.75, 1.0)
		elif roll < 0.22:
			color = Color(1.0, 0.82, 0.55)
		elif roll < 0.3:
			color = Color(0.7, 0.85, 1.0)
		color *= rng.randf_range(0.45, 1.0)
		multi.set_instance_color(i, color)

	multimesh = multi


func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera != null:
		global_position = camera.global_position
