class_name MapFeature
extends Resource
## Геометрический слой карты в мировых координатах XZ.
##
## Точки задаются парами (x, z) из сцены. MapDefinition переводит их в
## нормализованные координаты с севером вверху (-Z), а MapCanvas рисует.
## Слои позволяют отделять проходимые площадки от скал, обрывов и служебных
## границ, не изобретая дорожную сеть.

enum Kind {
	WALKABLE,
	BLOCKED,
	HAZARD,
	ROUTE,
	EDGE,
	UNAVAILABLE,
}

## Тип слоя: заливка площадки, линия маршрута или край обрыва.
@export var kind: Kind = Kind.WALKABLE
## Мировые координаты XZ: x — восток, z — юг. Север находится в -Z.
@export var points := PackedVector2Array()
## Замкнутая площадка или открытая линия.
@export var closed := true


func is_line() -> bool:
	return kind == Kind.ROUTE or kind == Kind.EDGE


func is_area() -> bool:
	return not is_line() and points.size() >= 3
