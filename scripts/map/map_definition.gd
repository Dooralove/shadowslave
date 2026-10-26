class_name MapDefinition
extends Resource
## Данные одной карты: локальной локации или общей карты мира.
##
## Локальные карты не знают друг о друге. Атлас (MapAtlas) связывает их,
## а MapScreen показывает любую из них одним и тем же UI. Фон, контур и
## маркеры — заглушки из типизированных данных; позже их можно заменить
## текстурой, тайлами или настоящей топографией без переделки интерфейса.

@export var id: StringName
@export var title := ""
@export var subtitle := ""
@export_multiline var description := ""

## Палитра карты-заглушки. Отдельная у каждой локации, чтобы карты
## различались без внешних иллюстраций.
@export var background_color := Color(0.055, 0.07, 0.082, 1.0)
@export var land_color := Color(0.23, 0.24, 0.205, 1.0)
@export var accent_color := Color(0.69, 0.55, 0.32, 1.0)

## Нормализованный контур суши (0..1). Пустой массив — универсальная схема.
@export var contour := PackedVector2Array()
@export var markers: Array[MapMarker] = []

## Сцены, которым принадлежит эта карта. Сравнивается scene_file_path
## текущей сцены и её дочерних инстансов.
@export var scene_paths := PackedStringArray()

## Положение региона на общей карте мира (нормализованные координаты).
@export var world_rect := Rect2(0.1, 0.1, 0.2, 0.2)
## Закрытый регион виден на карте мира, но его нельзя открыть.
@export var available := true

## Только для карты, собранной на лету, когда сцена не найдена в атласе.
var is_fallback := false


func matches_scene_path(scene_path: String) -> bool:
	if scene_path.is_empty():
		return false
	for path in scene_paths:
		if path == scene_path:
			return true
	return false


func marker_by_id(marker_id: StringName) -> MapMarker:
	for marker in markers:
		if marker != null and marker.id == marker_id:
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
