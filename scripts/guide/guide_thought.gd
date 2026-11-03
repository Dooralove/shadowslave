class_name GuideThought
extends Resource
## Короткая мысль Санни, которую вызывает мировая точка-триггер.
##
## Текст хранится здесь, а не в сцене или скрипте. `trigger_id` связывает
## ресурс с ThoughtTrigger в мире. Мысль не называет кнопку: она подсказывает
## действие словами Санни.

@export var id: StringName = &""
@export var trigger_id: StringName = &""
@export_multiline var text := ""
## Повторный вход в зону не повторяет мысль.
@export var once := true


func is_valid() -> bool:
	return id != &"" and trigger_id != &"" and not text.strip_edges().is_empty()
