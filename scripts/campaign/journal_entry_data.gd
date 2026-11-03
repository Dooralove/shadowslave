class_name JournalEntryData
extends Resource
## Запись журнала кампании. Текст хранится в .tres, а не в режиссёре.

@export var id: StringName = &""
@export var title := ""
@export_multiline var text := ""


func is_valid() -> bool:
	return id != &"" and not title.strip_edges().is_empty() and not text.strip_edges().is_empty()
