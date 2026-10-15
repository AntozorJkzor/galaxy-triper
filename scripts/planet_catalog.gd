extends RefCounted

const COUNT := 4
const SYSTEMS := 3
const WARP_SLOT := 3
const ATLAS_COLS := 4
const ATLAS_ROWS := 3
const ATLAS_PATH := "res://assets/planet/planets.jpg"

static var SYSTEM_NAMES: PackedStringArray = PackedStringArray(["Helios", "Lyra", "Altair"])
static var PLANET_NAMES: Array[PackedStringArray] = [
	PackedStringArray(["Earth", "Mars", "Iris", "Ice"]),
	PackedStringArray(["Amber", "Vox", "Nit", "Ash"]),
	PackedStringArray(["Storm", "Quartz", "Gloom", "Swell"]),
]
static var SCENES: Array[PackedStringArray] = [
	PackedStringArray([
		"res://scenes/systems/helios/earth.tscn",
		"res://scenes/systems/helios/mars.tscn",
		"res://scenes/systems/helios/iris.tscn",
		"res://scenes/systems/helios/ice.tscn",
	]),
	PackedStringArray([
		"res://scenes/systems/lyra/yantar.tscn",
		"res://scenes/systems/lyra/vox.tscn",
		"res://scenes/systems/lyra/nit.tscn",
		"res://scenes/systems/lyra/pepel.tscn",
	]),
	PackedStringArray([
		"res://scenes/systems/altair/burya.tscn",
		"res://scenes/systems/altair/kvarts.tscn",
		"res://scenes/systems/altair/morok.tscn",
		"res://scenes/systems/altair/zyb.tscn",
	]),
]

static var _textures: Array[Texture2D] = []


static func planet_count() -> int:
	return SYSTEMS * COUNT


static func clamp_system(system_id: int) -> int:
	return clampi(system_id, 0, SYSTEMS - 1)


static func clamp_planet(planet_id: int) -> int:
	return clampi(planet_id, 0, COUNT - 1)


static func global_index(system_id: int, planet_id: int) -> int:
	return clamp_system(system_id) * COUNT + clamp_planet(planet_id)


static func system_name(system_id: int) -> String:
	return SYSTEM_NAMES[clamp_system(system_id)]


static func planet_name(planet_id: int, system_id: int = 0) -> String:
	return PLANET_NAMES[clamp_system(system_id)][clamp_planet(planet_id)]


static func has_warp_gate(planet_id: int, _system_id: int = 0) -> bool:
	return clamp_planet(planet_id) == WARP_SLOT


static func linked_systems(system_id: int) -> PackedInt32Array:
	match clamp_system(system_id):
		0:
			return PackedInt32Array([1])
		1:
			return PackedInt32Array([0, 2])
		2:
			return PackedInt32Array([1])
		_:
			return PackedInt32Array()


static func is_linked(from_id: int, to_id: int) -> bool:
	var target := clamp_system(to_id)
	for sys: int in linked_systems(from_id):
		if sys == target:
			return true
	return false


static func scene_path(planet_id: int, system_id: int = 0) -> String:
	return SCENES[clamp_system(system_id)][clamp_planet(planet_id)]


static func texture_for(planet_id: int, system_id: int = 0) -> Texture2D:
	_ensure_textures()
	return _textures[global_index(system_id, planet_id)]


static func _ensure_textures() -> void:
	if _textures.size() == planet_count():
		return
	_textures.clear()
	var atlas := load(ATLAS_PATH) as Texture2D
	var src: Image = atlas.get_image() if atlas != null else null
	if src == null:
		for _i: int in planet_count():
			_textures.append(PlaceholderTexture2D.new())
		return
	if src.get_format() != Image.FORMAT_RGBA8:
		src.convert(Image.FORMAT_RGBA8)
	var cell_w := int(src.get_width() / ATLAS_COLS)
	var cell_h := int(src.get_height() / ATLAS_ROWS)
	for id: int in planet_count():
		var col := id % ATLAS_COLS
		var row := int(id / ATLAS_COLS)
		var cell := src.get_region(Rect2i(col * cell_w, row * cell_h, cell_w, cell_h))
		var globe := _extract_globe(cell)
		var tex := ImageTexture.create_from_image(globe)
		_textures.append(tex)


static func _extract_globe(cell: Image) -> Image:
	var w := cell.get_width()
	var h := cell.get_height()
	var cx := w * 0.5
	var cy := h * 0.5
	var rays := 48
	var radii: PackedFloat32Array = PackedFloat32Array()
	var max_scan := minf(cx, cy)
	for i: int in rays:
		var ang := TAU * float(i) / float(rays)
		var dir_x := cos(ang)
		var dir_y := sin(ang)
		var last := 0.0
		var t := 0.0
		while t < max_scan:
			var px := int(cx + dir_x * t)
			var py := int(cy + dir_y * t)
			if px < 0 or py < 0 or px >= w or py >= h:
				break
			var sample := cell.get_pixel(px, py)
			if maxf(sample.r, maxf(sample.g, sample.b)) > 0.16:
				last = t
			t += 1.0
		radii.append(last)
	radii.sort()
	var radius := radii[clampi(int(float(rays) * 0.55), 0, rays - 1)] * 0.94
	if radius < 8.0:
		radius = max_scan * 0.42
	var half := radius
	var x0 := clampi(int(floor(cx - half)), 0, w - 1)
	var y0 := clampi(int(floor(cy - half)), 0, h - 1)
	var side := clampi(int(ceil(half * 2.0)), 8, mini(w - x0, h - y0))
	var globe := cell.get_region(Rect2i(x0, y0, side, side))
	_apply_circle_mask(globe)
	return globe


static func _apply_circle_mask(image: Image) -> void:
	var w := image.get_width()
	var h := image.get_height()
	var cx := (w - 1) * 0.5
	var cy := (h - 1) * 0.5
	var r := minf(cx, cy) - 0.5
	var feather := maxf(2.5, r * 0.018)
	for y: int in h:
		for x: int in w:
			var color := image.get_pixel(x, y)
			var dist := Vector2(float(x) - cx, float(y) - cy).length()
			var disk := 1.0 - smoothstep(r - feather, r, dist)
			var brightness := maxf(color.r, maxf(color.g, color.b))
			if dist > r - feather * 2.4 and brightness < 0.2:
				disk = 0.0
			color.a = disk
			image.set_pixel(x, y, color)
