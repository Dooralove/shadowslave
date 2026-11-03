class_name DialogueLine
extends Resource
## Одна реплика. Текст — пересказ, а не цитата романа.

## Кто говорит: ключ из DialogueRunner.speaker_names (sunny, desk_officer, policeman, narration …).
@export var speaker: StringName
@export_multiline var text := ""
## Больше нуля — реплика уходит сама через столько секунд; ноль — ждёт действия «далее».
@export var duration := 0.0
## Optional key in VoiceDirector. When empty, DialogueRunner derives one from
## the sequence resource path and line index. Missing voice files are silent.
@export var voice_id: StringName = &""
