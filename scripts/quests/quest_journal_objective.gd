class_name QuestJournalObjective
extends RefCounted
## Снимок цели для существующего экрана журнала RpgQuestScreen. Экран
## работает через duck typing и не знает о ресурсах задания.

var id: StringName
var text := ""
var completed := false
var optional := false
var progress := 0
var required := 1


func progress_text() -> String:
	return "%d / %d" % [progress, required]
