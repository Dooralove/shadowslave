class_name MapRegion
extends Resource
## Регион на общей карте: часть Царства снов или отдельный мир вне его.
##
## Общая карта показывает все регионы; доступный регион открывает свою карту
## (region_map) — рисованную подложку, на которой собраны локации региона.
## Регион со статусом IN_DEVELOPMENT виден, но не кликабелен и не имеет карты.

enum Status {
	ACTIVE,
	IN_DEVELOPMENT,
}

@export var id: StringName
@export var title := ""
@export var subtitle := ""
@export_multiline var description := ""
@export var status: Status = Status.IN_DEVELOPMENT
## Регион вне Царства снов (Кошмар, реальный мир): рисуется отдельной вставкой
## в колонке справа от карты мира, а не областью на ней.
@export var outside_realm := false
## Контур региона в нормализованных координатах области общей карты (0..1).
## У регионов вне Царства — прямоугольник вставки.
@export var outline := PackedVector2Array()
## Где подписать регион (нормализованные координаты области общей карты).
@export var label_position := Vector2(0.5, 0.5)
## Локации региона в порядке маршрута. Ссылки на MapAtlas.locations.
@export var location_ids: Array[StringName] = []
## Карта региона. Пусто, пока регион в разработке.
@export var region_map: MapDefinition


func is_playable() -> bool:
	return status == Status.ACTIVE and region_map != null


func contains_point(normalized: Vector2) -> bool:
	if outline.size() < 3:
		return false
	return Geometry2D.is_point_in_polygon(normalized, outline)


func status_title() -> String:
	if is_playable():
		return "ДОСТУПЕН"
	return "В РАЗРАБОТКЕ"


func has_location(location_id: StringName) -> bool:
	return location_ids.has(location_id)


## Прямоугольник вставки (для регионов вне Царства).
func outline_rect() -> Rect2:
	if outline.is_empty():
		return Rect2()
	var rect := Rect2(outline[0], Vector2.ZERO)
	for point in outline:
		rect = rect.expand(point)
	return rect
