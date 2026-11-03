class_name QuestDefinition
extends Resource
## Описание задания. Это данные, а не состояние: прогресс хранится в
## NightmareRunState, а QuestSystem только читает и меняет его.

enum Category {
	MAIN,
	SIDE,
}

@export var id: StringName
## Пространство имён: задания одного фрагмента не активируются в другом.
@export var scope: StringName = &"forgotten_shore"
@export var code := ""
@export var title := ""
@export var category: Category = Category.SIDE
@export_multiline var summary := ""
@export_multiline var description := ""
## Флаги, которые должны быть установлены, чтобы задание стало доступно.
@export var prerequisites: Array[StringName] = []
## Задания, которые должны быть завершены до этого задания.
@export var required_quests: Array[StringName] = []
## Если true, задание стартует автоматически, как только выполнены условия.
@export var auto_start := true
## Показывать задание в журнале до старта как «доступно».
@export var show_available := true
@export var objectives: Array = []
@export var rewards: Array = []
## Флаг, который ставится при завершении задания. Дублирует состояние для
## сцен, которые умеют читать только флаги.
@export var completion_flag: StringName


func is_valid() -> bool:
	if id == &"" or title.strip_edges().is_empty():
		return false
	for objective in objectives:
		if not (objective is QuestObjective) or not (objective as QuestObjective).is_valid():
			return false
	return not objectives.is_empty()


func required_objectives() -> Array[QuestObjective]:
	var result: Array[QuestObjective] = []
	for item in objectives:
		var objective := item as QuestObjective
		if objective != null and not objective.optional:
			result.append(objective)
	return result


func find_objective(objective_id: StringName) -> QuestObjective:
	for item in objectives:
		var objective := item as QuestObjective
		if objective != null and objective.id == objective_id:
			return objective
	return null


func get_category_title() -> String:
	return "ОСНОВНОЕ" if category == Category.MAIN else "ПОБОЧНОЕ"


func get_status_code() -> String:
	return code if not code.strip_edges().is_empty() else String(id)
