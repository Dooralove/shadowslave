class_name QuestJournalEntry
extends RefCounted
## Снимок задания для RpgQuestScreen. Поля совпадают с RpgDemoQuest,
## поэтому существующий экран не требует второго набора виджетов.

var id: StringName
var code := ""
var title := ""
var category := ""
var status := 1
var summary := ""
var description := ""
var note := ""
var tracked := false
var objectives: Array = []


func completed_objectives() -> int:
	var count := 0
	for objective in objectives:
		var row := objective as QuestJournalObjective
		if row != null and row.completed:
			count += 1
	return count


func total_objectives() -> int:
	return objectives.size()
