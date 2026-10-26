class_name SpellMessage
extends Resource
## Одно сообщение Кошмарного Заклятия.
##
## Текст хранится в ресурсе, а не в UI-скрипте. Канонические формулировки
## берутся из docs/story/nightmare_spell_prompts.md; квадратные скобки в
## документе — постановочная разметка, в самом тексте сообщения их нет.

enum Presentation {
	PANEL,      ## Короткая панель уведомлений поверх игры.
	CINEMATIC,  ## Полноэкранное появление в темноте для постановочных сцен.
}

const DEFAULT_HEADER := "КОШМАРНОЕ ЗАКЛЯТИЕ"

## Стабильный идентификатор для поиска в SpellMessageCatalog.
@export var id: StringName
@export var header := DEFAULT_HEADER
@export_multiline var text := ""
## Полное время от начала появления до начала исчезновения, в секундах.
@export_range(0.0, 30.0, 0.1, "suffix:s") var duration := 4.0
@export var presentation: Presentation = Presentation.PANEL


func is_valid() -> bool:
	return not text.strip_edges().is_empty() and duration >= 0.0
