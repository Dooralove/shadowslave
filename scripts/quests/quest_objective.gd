class_name QuestObjective
extends Resource
## Одна цель задания. Данные цели не знают о сцене: тип и target_id
## сопоставляются с событиями, которые присылает QuestSystem.
##
## KILL       — event "killed",      target_id = тег противника
## COLLECT    — event "collected",   target_id = id предмета
## INTERACT   — event "interacted",  target_id = interaction_id
## REACH      — event "reached",     target_id = id триггера/зоны
## TALK       — event "talked",      target_id = id NPC
## FLAG       — event "flag",        target_id = имя флага
## CURRENCY   — event "currency",    target_id = id валюты

enum Kind {
	KILL,
	COLLECT,
	INTERACT,
	REACH,
	TALK,
	FLAG,
	CURRENCY,
}

@export var id: StringName
@export_multiline var text := ""
@export var kind: Kind = Kind.FLAG
@export var target_id: StringName
@export_range(1, 999, 1) var required_count := 1
## Необязательные цели не блокируют завершение задания.
@export var optional := false
## Скрывать текст цели, пока не выполнены предыдущие цели.
@export var hidden_until_previous := false


func is_valid() -> bool:
	return id != &"" and not text.strip_edges().is_empty() and target_id != &""


func event_id() -> StringName:
	match kind:
		Kind.KILL:
			return &"killed"
		Kind.COLLECT:
			return &"collected"
		Kind.INTERACT:
			return &"interacted"
		Kind.REACH:
			return &"reached"
		Kind.TALK:
			return &"talked"
		Kind.FLAG:
			return &"flag"
		Kind.CURRENCY:
			return &"currency"
	return &""


func matches(event_name: StringName, subject_id: StringName) -> bool:
	return event_name == event_id() and subject_id == target_id
