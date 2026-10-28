class_name RpgDemoQuest
extends Resource
## Демонстрационная запись журнала заданий. Не связана с квестами игры,
## сохранениями, сюжетом или наградами. Все записи помечены как DEMO.

enum Status {
	ACTIVE,
	AVAILABLE,
	COMPLETED,
}

@export var id: StringName
@export var code := ""
@export var title := ""
@export var category := ""
@export var status: Status = Status.AVAILABLE
@export_multiline var summary := ""
@export_multiline var description := ""
@export var objectives: Array = []
@export_multiline var note := ""


func completed_objectives() -> int:
	var count := 0
	for objective in objectives:
		if objective != null and objective.completed:
			count += 1
	return count
