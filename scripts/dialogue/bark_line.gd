class_name BarkLine
extends Resource
## Одна короткая внутренняя реплика (bark). Не произносится вслух и не блокирует игру.

## Стабильный идентификатор записи, например CARAVAN_THREAT_03.
@export var id: StringName
## Кто говорит: ключ, который UI переводит в отображаемое имя.
@export var speaker: StringName = &"sunny"
## Основной игровой контекст: march_start, danger, ambush, cover, escape, shrine_approach, altar…
@export var context: StringName
## Дополнительные контексты, в которых уместна та же реплика.
@export var aliases: Array[StringName] = []
@export_multiline var text := ""


func matches_context(context_id: StringName) -> bool:
	return context == context_id or aliases.has(context_id)


func to_dictionary() -> Dictionary:
	return {
		"id": String(id),
		"speaker": String(speaker),
		"context": String(context),
		"aliases": aliases.map(func(alias: StringName) -> String: return String(alias)),
		"text": text,
	}
