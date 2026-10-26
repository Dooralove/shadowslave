class_name MapDefinition
extends Resource
## Данные одной карты: локальной локации или общей карты мира.
##
## Локальные карты не знают друг о друге. Атлас (MapAtlas) связывает их,
## а MapScreen показывает любую из них одним и тем же UI. Для карт локаций
## геометрия задаётся в мировых координатах сцены (XZ), а не в условных
## нормализованных долях: так маркеры и положение игрока остаются связаны
## с реальной сценой.

@export var id: StringName
@export var title := ""
@export var subtitle := ""
@export_multiline var description := ""

## Палитра карты-заглушки. Отдельная у каждой локации, чтобы карты
## различались без внешних иллюстраций.
@export var background_color := Color(0.055, 0.07, 0.082, 1.0)
@export var land_color := Color(0.23, 0.24, 0.205, 1.0)
@export var accent_color := Color(0.69, 0.55, 0.32, 1.0)
## Стиль поверхности для рисованной карты (см. MapPaint.LAND_PALETTES):
## snow, pass, temple, city, stone, kingdom.
@export var terrain_style: StringName = &"stone"

## Нормализованный контур суши (0..1). Для локальных карт вместо него
## используется world_contour, чтобы контур не отрывался от геометрии сцены.
@export var contour := PackedVector2Array()
@export var markers: Array[MapMarker] = []

## Границы игрового участка в мировых координатах XZ: position = (min X,
## min Z), size = (ширина по X, длина по Z). Север — это -Z, поэтому верх
## карты соответствует min Z. Пустой Rect2 включает старый режим (0..1).
@export var world_bounds := Rect2()
## Контур суши в мировых координатах XZ. Пустой — используется contour.
@export var world_contour := PackedVector2Array()
## Проходимые площадки, скалы, обрывы и линии маршрута в мировых XZ.
@export var features: Array[MapFeature] = []
## Если false, длинная линейная карта заполняет холст целиком. Пропорции
## при этом сжимаются только по продольной оси; на карте выводится пометка.
@export var preserve_aspect := true

## Рисованная подложка (растр из tools/map/build_maps.py). Рисуется в
## background_rect — доле области карты; координаты world_bounds совпадают
## с этой подложкой.
@export var background_texture: Texture2D
@export var background_rect := Rect2(0, 0, 1, 1)
## Локации на общей карте региона: геометрия собирается MapAtlas.compose_region_map.
@export var placements: Array[MapPlacement] = []

## Сцены, которым принадлежит эта карта. Сравнивается scene_file_path
## текущей сцены и её дочерних инстансов.
@export var scene_paths := PackedStringArray()

## Положение региона на общей карте мира (нормализованные координаты).
@export var world_rect := Rect2(0.1, 0.1, 0.2, 0.2)
## Закрытый регион виден на карте мира, но его нельзя открыть.
@export var available := true
## Порядок этапа в маршруте Первого Кошмара. -1 — вне эпизода.
@export var campaign_stage := -1

## Только для карты, собранной на лету, когда сцена не найдена в атласе.
var is_fallback := false


func matches_scene_path(scene_path: String) -> bool:
	if scene_path.is_empty():
		return false
	for path in scene_paths:
		if path == scene_path:
			return true
	return false


func has_world_bounds() -> bool:
	return world_bounds.size.x > 0.0 and world_bounds.size.y > 0.0


## Мировые XZ (x — восток, z — юг) в нормализованные координаты холста.
## Север (-Z) даёт y = 0, юг — y = 1.
func world_to_normalized(world_xz: Vector2) -> Vector2:
	if not has_world_bounds():
		return world_xz
	return Vector2(
		(world_xz.x - world_bounds.position.x) / world_bounds.size.x,
		(world_xz.y - world_bounds.position.y) / world_bounds.size.y
	)


func normalized_to_world(normalized: Vector2) -> Vector2:
	if not has_world_bounds():
		return normalized
	return world_bounds.position + normalized * world_bounds.size


## Точка маркера в нормализованных координатах карты. Маркеры с мировыми
## координатами пересчитываются через world_bounds, остальные — как есть.
func marker_point(marker: MapMarker) -> Vector2:
	if marker == null:
		return Vector2.ZERO
	if marker.use_world_position and has_world_bounds():
		return world_to_normalized(marker.world_position)
	return marker.position


func world_feature_points(feature: MapFeature) -> PackedVector2Array:
	if feature == null:
		return PackedVector2Array()
	var result := PackedVector2Array()
	for point in feature.points:
		result.append(world_to_normalized(point))
	return result


## Отсортированные карты маршрута эпизода (без песочниц и будущих глав).
static func campaign_route(locations: Array[MapDefinition]) -> Array[MapDefinition]:
	var staged: Array[MapDefinition] = []
	for location in locations:
		if location != null and location.campaign_stage >= 0 and location.available:
			staged.append(location)
	staged.sort_custom(func(a: MapDefinition, b: MapDefinition) -> bool:
		return a.campaign_stage < b.campaign_stage
	)
	return staged


func marker_by_id(marker_id: StringName) -> MapMarker:
	for marker in markers:
		if marker != null and marker.id == marker_id:
			return marker
	return null


## Маркеры, видимые при текущих флагах игры (см. MapMarker.show_when_flag).
func visible_markers(flags: Dictionary) -> Array[MapMarker]:
	var result: Array[MapMarker] = []
	for marker in markers:
		if marker != null and marker.is_visible_with(flags):
			result.append(marker)
	return result


func placement_for(location_id: StringName) -> MapPlacement:
	for placement in placements:
		if placement != null and placement.location_id == location_id:
			return placement
	return null


## Маркер региона, который ведёт в карту указанной локации.
func marker_for_location(location_id: StringName) -> MapMarker:
	for marker in markers:
		if marker != null and marker.location_id == location_id:
			return marker
	return null


## Универсальный контур помогает показать заглушку даже без данных.
func get_contour() -> PackedVector2Array:
	if contour.size() >= 3:
		return contour
	return PackedVector2Array([
		Vector2(0.12, 0.34), Vector2(0.20, 0.16), Vector2(0.42, 0.10),
		Vector2(0.66, 0.15), Vector2(0.86, 0.30), Vector2(0.90, 0.55),
		Vector2(0.78, 0.78), Vector2(0.55, 0.89), Vector2(0.30, 0.84),
		Vector2(0.14, 0.62),
	])


## Карта-заглушка для сцены, которой ещё нет в атласе. Возвращает обычный
## MapDefinition, поэтому экран карты не требует отдельной ветки логики.
static func create_fallback(location_title: String) -> MapDefinition:
	var map := MapDefinition.new()
	map.id = &"__fallback__"
	map.title = location_title.strip_edges()
	if map.title.is_empty():
		map.title = "Неизвестная локация"
	map.subtitle = "Универсальная карта · локальные данные ещё не заданы"
	map.description = (
		"Для этой локации пока нет отдельной карты в атласе. "
		+ "Показана универсальная схема с названием сцены; управление и переход "
		+ "к общей карте мира работают как обычно."
	)
	map.background_color = Color(0.065, 0.075, 0.085, 1.0)
	map.land_color = Color(0.19, 0.205, 0.19, 1.0)
	map.accent_color = Color(0.56, 0.48, 0.35, 1.0)
	map.is_fallback = true
	map.available = true
	var empty_markers: Array[MapMarker] = []
	map.markers = empty_markers
	return map
