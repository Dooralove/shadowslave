class_name BestiaryEntry
extends JournalEntryData
## Запись бестиария Первого Кошмара. Сейчас используется как запись журнала;
## при появлении полного боевого бестиария те же .tres можно читать напрямую.

## Событие, которым запись открывается: seen / defeated / weakness_known.
@export var unlock_event: StringName = &"seen"
## Человекочитаемая подпись события для журнала.
@export var event_label := ""
@export var category := "Первый Кошмар"
## Краткая слабость/повадка; пока не дублирует текст, но готова для полного бестиария.
@export_multiline var weakness := ""


func journal_record(event_id: StringName = &"") -> Dictionary:
	var resolved_event := event_id
	if resolved_event == &"":
		resolved_event = unlock_event
	return {
		"id": id,
		"title": title,
		"text": text,
		"kind": "bestiary",
		"category": category,
		"event": resolved_event,
		"event_label": event_label,
	}
