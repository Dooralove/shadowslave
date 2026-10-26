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
## Если use_world_position = true, маркер стоит в мировых XZ сцены, и
## MapDefinition переводит их в нормализованные координаты через world_bounds.
@export var use_world_position := false
@export var world_position := Vector2.ZERO
@export var kind: Kind = Kind.LANDMARK
## Локация, к которой относится маркер на общей карте региона (заполняет
## MapAtlas.compose_region_map). Пусто — маркер самой карты.
@export var location_id: StringName = &""
## Задание, к которому относится маркер. Заготовка под квестовую систему:
## пока ничего не выбирает, только помечает маркер кольцом.
@export var quest_id: StringName = &""
## Если задано, маркер виден только когда этот флаг выставлен в игре.
## Пустое значение — маркер виден всегда.
@export var show_when_flag: StringName = &""


func is_visible_with(flags: Dictionary) -> bool:
	if show_when_flag == &"":
		return true
	return bool(flags.get(show_when_flag, false))


func is_objective() -> bool:
	return quest_id != &""


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
