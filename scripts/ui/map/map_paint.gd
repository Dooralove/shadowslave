class_name MapPaint
extends RefCounted
## Рисованный стиль карты поверх растровой подложки: текстуры геометрии
## локаций, подписи, дорога, роза ветров и рамка.
##
## Подложки карт мира и регионов рисует tools/map/build_maps.py. Здесь —
## только то, что строится из данных в рантайме: площадки и скалы локаций
## (шумовые текстуры Godot, сгенерированные один раз), подписи и украшения.

const TEXTURE_SIZE := 512

## Палитры рельефа: тёмный → светлый. Ключ — MapDefinition.terrain_style.
const LAND_PALETTES := {
	&"kingdom": [Color(0.17, 0.18, 0.13), Color(0.28, 0.28, 0.19), Color(0.39, 0.36, 0.25), Color(0.50, 0.46, 0.35)],
	&"snow": [Color(0.22, 0.24, 0.26), Color(0.36, 0.38, 0.40), Color(0.52, 0.54, 0.55), Color(0.66, 0.67, 0.67)],
	&"pass": [Color(0.20, 0.21, 0.21), Color(0.32, 0.33, 0.32), Color(0.47, 0.48, 0.47), Color(0.62, 0.62, 0.60)],
	&"temple": [Color(0.12, 0.11, 0.13), Color(0.20, 0.19, 0.21), Color(0.28, 0.26, 0.27), Color(0.36, 0.33, 0.32)],
	&"city": [Color(0.15, 0.16, 0.17), Color(0.22, 0.23, 0.24), Color(0.29, 0.30, 0.31), Color(0.35, 0.36, 0.37)],
	&"stone": [Color(0.17, 0.16, 0.14), Color(0.27, 0.25, 0.21), Color(0.36, 0.33, 0.27), Color(0.44, 0.41, 0.34)],
}

const INK := Color(0.93, 0.89, 0.78)
const INK_DIM := Color(0.66, 0.64, 0.58)
const OUTLINE := Color(0.02, 0.02, 0.025, 0.92)
const GOLD := Color(0.78, 0.63, 0.38)

static var _textures: Dictionary = {}
static var _fonts: Dictionary = {}


## Текстура рельефа суши для стиля. Неизвестный стиль — «камень».
static func land_texture(style: StringName) -> Texture2D:
	var key := StringName("land_%s" % style)
	if not _textures.has(key):
		var palette: Array = LAND_PALETTES.get(style, LAND_PALETTES[&"stone"])
		_textures[key] = _noise_texture(
			hash(style) & 0xffff, 0.006, 6, FastNoiseLite.FRACTAL_FBM,
			[0.0, 0.35, 0.65, 1.0], palette
		)
	return _textures[key]


## Тени хребтов поверх рельефа: прозрачная текстура с тёмными гребнями.
static func relief_texture() -> Texture2D:
	return _cached(&"relief", func() -> Texture2D:
		return _noise_texture(
			7, 0.011, 5, FastNoiseLite.FRACTAL_RIDGED,
			[0.0, 0.55, 0.8, 1.0],
			[Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.22), Color(1, 1, 0.95, 0.10)]
		)
	)


static func sea_texture() -> Texture2D:
	return _cached(&"sea", func() -> Texture2D:
		return _noise_texture(
			3, 0.004, 4, FastNoiseLite.FRACTAL_FBM,
			[0.0, 0.5, 1.0],
			[Color(0.04, 0.07, 0.085), Color(0.065, 0.105, 0.12), Color(0.10, 0.15, 0.165)]
		)
	)


## Пустота за краем локальной карты: почти чёрная бездна с лёгкой фактурой.
static func void_texture() -> Texture2D:
	return _cached(&"void", func() -> Texture2D:
		return _noise_texture(
			11, 0.005, 4, FastNoiseLite.FRACTAL_FBM,
			[0.0, 1.0],
			[Color(0.025, 0.028, 0.032), Color(0.06, 0.065, 0.07)]
		)
	)


## Туман неизведанных земель: клубы с просветами.
static func fog_texture() -> Texture2D:
	return _cached(&"fog", func() -> Texture2D:
		return _noise_texture(
			19, 0.007, 5, FastNoiseLite.FRACTAL_FBM,
			[0.0, 0.45, 1.0],
			[Color(0.03, 0.035, 0.04, 0.62), Color(0.08, 0.085, 0.09, 0.46), Color(0.20, 0.21, 0.21, 0.30)]
		)
	)


static func rock_texture() -> Texture2D:
	return _cached(&"rock", func() -> Texture2D:
		return _noise_texture(
			23, 0.02, 5, FastNoiseLite.FRACTAL_RIDGED,
			[0.0, 0.6, 1.0],
			[Color(0.05, 0.05, 0.05), Color(0.12, 0.115, 0.105), Color(0.22, 0.21, 0.19)]
		)
	)


## Зерно бумаги поверх всей карты.
static func grain_texture() -> Texture2D:
	return _cached(&"grain", func() -> Texture2D:
		return _noise_texture(
			31, 0.08, 2, FastNoiseLite.FRACTAL_FBM,
			[0.0, 0.5, 1.0],
			[Color(0, 0, 0, 0.10), Color(0, 0, 0, 0.0), Color(1, 0.95, 0.85, 0.05)]
		)
	)


## Виньетка: прозрачный центр, тёмные края.
static func vignette_texture() -> Texture2D:
	return _cached(&"vignette", func() -> Texture2D:
		var gradient := Gradient.new()
		gradient.offsets = PackedFloat32Array([0.0, 0.62, 1.0])
		gradient.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0.18), Color(0, 0, 0, 0.72)])
		var texture := GradientTexture2D.new()
		texture.gradient = gradient
		texture.fill = GradientTexture2D.FILL_RADIAL
		texture.fill_from = Vector2(0.5, 0.5)
		texture.fill_to = Vector2(1.0, 1.0)
		texture.width = 256
		texture.height = 256
		return texture
	)


## Все текстуры стиля — чтобы холст мог перерисоваться, когда шум догенерируется.
static func all_textures(styles: Array) -> Array[Texture2D]:
	var result: Array[Texture2D] = [
		relief_texture(), sea_texture(), void_texture(), fog_texture(),
		rock_texture(), grain_texture(), vignette_texture(),
	]
	for style in styles:
		result.append(land_texture(style))
	return result


## Засечный шрифт подписей. Системные шрифты Windows/Linux, без файлов в проекте.
static func serif_font(spacing := 0) -> Font:
	var key := StringName("serif_%d" % spacing)
	if not _fonts.has(key):
		var base := SystemFont.new()
		base.font_names = PackedStringArray(["Georgia", "Cambria", "Times New Roman", "DejaVu Serif", "serif"])
		var variation := FontVariation.new()
		variation.base_font = base
		variation.set_spacing(TextServer.SPACING_GLYPH, spacing)
		_fonts[key] = variation
	return _fonts[key]


## Полигон с текстурой, повторяющейся с шагом tile_px пикселей.
static func draw_textured_polygon(
	ci: CanvasItem, points: PackedVector2Array, texture: Texture2D,
	tile_px: float, tint := Color.WHITE
) -> void:
	if points.size() < 3:
		return
	var uvs := PackedVector2Array()
	for point in points:
		uvs.append(point / tile_px)
	ci.draw_colored_polygon(points, tint, uvs, texture)




## Подпись по центру точки с тёмной обводкой — читается на любом рельефе.
static func draw_label(
	ci: CanvasItem, font: Font, at: Vector2, text: String,
	font_size: int, fill := INK, outline_size := 4
) -> void:
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var origin := at + Vector2(-width * 0.5, 0.0)
	ci.draw_string_outline(font, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, outline_size, OUTLINE)
	ci.draw_string(font, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, fill)


















## Дорога по стилю старых карт: тёмная подложка и светлый пунктир.
static func draw_road(ci: CanvasItem, points: PackedVector2Array) -> void:
	if points.size() < 2:
		return
	ci.draw_polyline(points, Color(0.04, 0.035, 0.03, 0.75), 6.0, true)
	ci.draw_polyline(points, Color(0.42, 0.34, 0.22, 0.95), 3.2, true)
	for index in range(points.size() - 1):
		ci.draw_dashed_line(points[index], points[index + 1], Color(0.88, 0.78, 0.56, 0.95), 1.4, 7.0, true, true)


## Роза ветров: восемь лучей, засечная «С» на севере.
static func draw_compass_rose(ci: CanvasItem, center: Vector2, radius: float) -> void:
	ci.draw_circle(center, radius + 6.0, Color(0, 0, 0, 0.35))
	ci.draw_arc(center, radius + 4.0, 0.0, TAU, 48, Color(GOLD, 0.55), 1.0, true)
	ci.draw_arc(center, radius * 0.45, 0.0, TAU, 32, Color(GOLD, 0.45), 1.0, true)
	for index in 8:
		var angle := -PI * 0.5 + index * PI * 0.25
		var length := radius if index % 2 == 0 else radius * 0.55
		var tip := center + Vector2.from_angle(angle) * length
		var side := Vector2.from_angle(angle + PI * 0.5) * (radius * 0.14)
		var light := Color(0.90, 0.82, 0.62) if index % 2 == 0 else Color(0.62, 0.55, 0.40)
		ci.draw_colored_polygon(PackedVector2Array([center + side, tip, center]), light)
		ci.draw_colored_polygon(PackedVector2Array([center, tip, center - side]), light.darkened(0.45))
	var font := serif_font()
	draw_label(ci, font, center + Vector2(0, -radius - 10.0), "С", 13, INK, 3)


## Орнаментальная рамка: двойная линия и ромбы в углах.
static func draw_ornate_frame(ci: CanvasItem, rect: Rect2) -> void:
	var outer := rect.grow(-6.0)
	var inner := rect.grow(-11.0)
	ci.draw_rect(outer, Color(GOLD, 0.55), false, 1.5)
	ci.draw_rect(inner, Color(GOLD, 0.28), false, 1.0)
	for corner in [outer.position, Vector2(outer.end.x, outer.position.y), outer.end, Vector2(outer.position.x, outer.end.y)]:
		var c: Vector2 = corner
		ci.draw_colored_polygon(PackedVector2Array([
			c + Vector2(0, -7), c + Vector2(7, 0), c + Vector2(0, 7), c + Vector2(-7, 0),
		]), Color(GOLD, 0.85))
		ci.draw_colored_polygon(PackedVector2Array([
			c + Vector2(0, -3.5), c + Vector2(3.5, 0), c + Vector2(0, 3.5), c + Vector2(-3.5, 0),
		]), Color(0.06, 0.05, 0.04))




static func _cached(key: StringName, build: Callable) -> Texture2D:
	if not _textures.has(key):
		_textures[key] = build.call()
	return _textures[key]


static func _noise_texture(
	seed_value: int, frequency: float, octaves: int, fractal: int,
	offsets: Array, colors: Array
) -> NoiseTexture2D:
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = frequency
	noise.fractal_type = fractal
	noise.fractal_octaves = octaves
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array(offsets)
	gradient.colors = PackedColorArray(colors)
	var texture := NoiseTexture2D.new()
	texture.width = TEXTURE_SIZE
	texture.height = TEXTURE_SIZE
	texture.seamless = true
	texture.noise = noise
	texture.color_ramp = gradient
	return texture
