class_name PrologueUI
extends CanvasLayer
## Слои интерфейса среза. Режиссёр обращается к ним через этот узел.

@onready var drowsiness: DrowsinessOverlay = %Drowsiness
@onready var fade: FadeLayer = %Fade
@onready var subtitles: SubtitleUI = %Subtitles
@onready var prompt: InteractionPromptUI = %Prompt
@onready var hint: Label = %Hint
@onready var spell_message: SpellMessageUI = %SpellMessage
@onready var rune_status: RuneStatusUI = %RuneStatus
@onready var end_card: Label = %EndCard


func _ready() -> void:
	hint.visible = false
	end_card.visible = false


func show_hint(text: String) -> void:
	hint.text = text
	hint.visible = not text.is_empty()


func show_end_card() -> void:
	end_card.visible = true
