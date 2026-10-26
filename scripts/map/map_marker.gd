class_name MapMarker
extends Resource
## Условный маркер на карте локации.
##
## Маркер хранит только данные: где он стоит, как называется и к какому типу
## относится. Внешний вид (цвет, значок, рамка) задаёт MapCanvas, поэтому
## добавление новой карты не требует новой копии UI.

enum Kind {
	LANDMARK,
	CAMP,
	DANGER,
	QUEST,
	PLAYER,
}

@export var id: StringName
@export var label := ""
@export_multiline var description := ""
## Позиция в нормализованных координатах карты: (0, 0) — левый верхний угол,
## (1, 1) — правый нижний. UI сам переводит её в пиксели.
@export var position := Vector2(0.5, 0.5)
@export var kind: Kind = Kind.LANDMARK


func kind_title() -> String:
	match kind:
		Kind.CAMP:
			return "Стоянка"
		Kind.DANGER:
			return "Опасность"
		Kind.QUEST:
			return "Задача"
		Kind.PLAYER:
			return "Вы здесь"
		_:
			return "Ориентир"
