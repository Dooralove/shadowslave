class_name PrologueUI
extends CanvasLayer
## Слои интерфейса среза. Режиссёр обращается к ним через этот узел.
## Строка цели — общий слой кампании: она читает CampaignGuide, а не сцену.

@onready var drowsiness: DrowsinessOverlay = %Drowsiness
@onready var fade: FadeLayer = %Fade
@onready var subtitles: SubtitleUI = %Subtitles
@onready var prompt: InteractionPromptUI = %Prompt
@onready var hint: Label = %Hint
@onready var spell_message: SpellMessageUI = %SpellMessage
@onready var rune_status: RuneStatusUI = %RuneStatus
@onready var end_card: Label = %EndCard
@onready var objective_line: ObjectiveLine = %ObjectiveLine
@onready var combat_hud: CombatHud = $CombatHud

@export var hint_auto_hide_seconds := 10.0
var _hint_timer: Timer


func _ready() -> void:
	var ui_theme := RpgMenuTheme.build()
	for control in [hint, prompt, spell_message, end_card]:
		if control != null:
			control.theme = ui_theme
	hint.visible = false
	end_card.visible = false
	_hint_timer = Timer.new()
	_hint_timer.one_shot = true
	_hint_timer.timeout.connect(_hide_hint)
	add_child(_hint_timer)


## Подсказка не остаётся на экране бесконечно: пустая строка скрывает сразу,
## непустая — сама гаснет через hint_auto_hide_seconds.
func show_hint(text: String) -> void:
	var value := text.strip_edges()
	if value.is_empty():
		_hint_timer.stop()
		hint.text = ""
		hint.visible = false
		return
	hint.text = text
	hint.visible = true
	if hint_auto_hide_seconds > 0.0:
		_hint_timer.start(hint_auto_hide_seconds)


func _hide_hint() -> void:
	hint.text = ""
	hint.visible = false


func show_end_card() -> void:
	end_card.visible = true
