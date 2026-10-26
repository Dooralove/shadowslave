class_name RpgDemoSkill
extends Resource
## Временный узел DEMO-дерева навыков.
##
## Ресурс описывает только демонстрационную схему интерфейса: названия,
## зависимости, стоимость и эффекты не являются каноном и не подключены к игре.

@export var id: StringName
@export var code := "A0"
@export var branch := "A"
@export var branch_title := "DEMO · ВЕТВЬ A"
@export var display_name := "DEMO · УЗЕЛ"
@export var subtitle := "ВРЕМЕННЫЙ УЗЕЛ"
@export_multiline var description := ""
@export_multiline var effect_note := "Эффект не назначен. Содержание будет согласовано отдельно."
@export var cost := 1
@export var required_ids := PackedStringArray()
## Нормализованный центр карточки на поле графа: (0..1, 0..1).
@export var graph_position := Vector2(0.5, 0.5)
@export var initially_learned := false


func required_skill_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for required_id in required_ids:
		result.append(StringName(required_id))
	return result
