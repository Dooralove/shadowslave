class_name ActionClipMap
extends Resource
## Соответствие логических действий сценария клипам конкретной модели.
## При замене модели меняется только этот ресурс, а не сценарий.

## Ключ — действие (StringName, например &"sit_idle"), значение — имя клипа в AnimationPlayer модели.
@export var clips := {}


func clip_for(action: StringName) -> StringName:
	return clips.get(action, &"")
