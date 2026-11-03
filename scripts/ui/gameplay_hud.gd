class_name GameplayHud
extends CanvasLayer
## Игровой HUD демонстрационного фрагмента: подсказка E, строка цели,
## субтитры, боевые полосы, квестовый тост и индикатор прилива. Собирает
## существующие компоненты, а не создаёт второй интерфейс.

@onready var prompt: InteractionPromptUI = %Prompt
@onready var objective_line: ObjectiveLine = %ObjectiveLine
@onready var dialogue_runner: DialogueRunner = %DialogueRunner
@onready var quest_toast: QuestToast = %QuestToast
@onready var hint: Label = %Hint
@onready var tide: TideIndicator = get_node_or_null(^"TideIndicator") as TideIndicator
@onready var minimap: HudMinimap = get_node_or_null(^"HUDMinimap") as HudMinimap
@onready var quick_items: HudQuickItems = get_node_or_null(^"QuickItems") as HudQuickItems
@onready var control_hints: HudControlHints = get_node_or_null(^"ControlHints") as HudControlHints

@export var hint_auto_hide_seconds := 9.0
@export var tutorial_enabled := true

static var _tutorial_claimed := false

var _hint_timer: Timer
var _tutorial_timer: Timer
var _tutorial_started := false
var _tutorial_step := 0


func _ready() -> void:
	if hint != null:
		hint.theme = RpgMenuTheme.build()
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_apply_hud_layout()
	_hint_timer = Timer.new()
	_hint_timer.one_shot = true
	_hint_timer.timeout.connect(_hide_hint)
	add_child(_hint_timer)
	_tutorial_timer = Timer.new()
	_tutorial_timer.one_shot = true
	_tutorial_timer.timeout.connect(_on_tutorial_timeout)
	add_child(_tutorial_timer)
	var run_state := get_node_or_null(^"/root/NightmareRunState")
	if run_state != null and run_state.has_signal(&"state_reset"):
		run_state.state_reset.connect(_on_run_state_reset)
	call_deferred(&"_bind_player")
	if tutorial_enabled and not _tutorial_claimed:
		_tutorial_claimed = true
		call_deferred(&"_start_tutorial")


func _on_run_state_reset() -> void:
	_tutorial_claimed = false


## Разводит верхнюю подсказку с целью/приливом, а тост — с субтитрами и
## подсказкой взаимодействия. Позиции задаются здесь, потому что HUD-сцена
## принадлежит A04 и A08 не перезаписывает её композицию.
func _apply_hud_layout() -> void:
	if hint != null:
		hint.offset_left = -300.0
		hint.offset_right = 300.0
		hint.offset_top = 92.0
		hint.offset_bottom = 140.0

	# Reference layout: vitals top-left (CombatHud), minimap top-right,
	# quest tracker below it, quick items bottom-left, control hints bottom-right.
	if objective_line != null:
		objective_line.anchor_left = 1.0
		objective_line.anchor_right = 1.0
		objective_line.anchor_top = 0.0
		objective_line.anchor_bottom = 0.0
		objective_line.offset_left = -360.0
		objective_line.offset_top = 242.0
		objective_line.offset_right = -24.0
		objective_line.offset_bottom = 342.0
		objective_line.grow_horizontal = 0
		objective_line.grow_vertical = 1
		objective_line.set_right_aligned(true)
		objective_line.refresh_from_sources(true)

	if tide != null:
		tide.offset_left = -360.0
		tide.offset_top = 352.0
		tide.offset_right = -24.0
		tide.offset_bottom = 430.0

	if minimap != null:
		minimap.anchor_left = 1.0
		minimap.anchor_right = 1.0
		minimap.anchor_top = 0.0
		minimap.anchor_bottom = 0.0
		minimap.offset_left = -214.0
		minimap.offset_top = 24.0
		minimap.offset_right = -24.0
		minimap.offset_bottom = 236.0

	if quick_items != null:
		quick_items.anchor_left = 0.0
		quick_items.anchor_right = 0.0
		quick_items.anchor_top = 1.0
		quick_items.anchor_bottom = 1.0
		quick_items.offset_left = 24.0
		quick_items.offset_top = -154.0
		quick_items.offset_right = 274.0
		quick_items.offset_bottom = -24.0
		quick_items.grow_horizontal = 1
		quick_items.grow_vertical = 0

	if control_hints != null:
		control_hints.anchor_left = 1.0
		control_hints.anchor_right = 1.0
		control_hints.anchor_top = 1.0
		control_hints.anchor_bottom = 1.0
		control_hints.offset_left = -360.0
		control_hints.offset_top = -154.0
		control_hints.offset_right = -24.0
		control_hints.offset_bottom = -24.0
		control_hints.grow_horizontal = 0
		control_hints.grow_vertical = 0

	if prompt != null:
		prompt.anchor_left = 0.0
		prompt.anchor_right = 0.0
		prompt.anchor_top = 0.0
		prompt.anchor_bottom = 0.0
		prompt.offset_left = 24.0
		prompt.offset_top = 158.0
		prompt.offset_right = 380.0
		prompt.offset_bottom = 186.0
		prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		prompt.add_theme_font_size_override("font_size", 14)

	var toast := get_node_or_null(^"QuestToast") as Control
	if toast != null:
		toast.anchor_left = 1.0
		toast.anchor_right = 1.0
		toast.anchor_top = 1.0
		toast.anchor_bottom = 1.0
		toast.offset_left = -360.0
		toast.offset_top = -230.0
		toast.offset_right = -24.0
		toast.offset_bottom = -170.0
		toast.grow_horizontal = 0
		toast.grow_vertical = 0


func _bind_player() -> void:
	var player := get_tree().get_first_node_in_group(&"player") as SunnyController
	if player == null:
		return
	var interactor := player.get_node_or_null(^"Interactor") as Interactor
	if interactor != null and not interactor.focus_changed.is_connected(prompt.show_for):
		interactor.focus_changed.connect(prompt.show_for)
	if dialogue_runner != null:
		dialogue_runner.add_to_group(&"dialogue_runner")
		dialogue_runner.subtitles = get_node_or_null(^"Subtitles") as SubtitleUI
		dialogue_runner.bind_subtitles()


## Показывает подсказку и гарантированно убирает её через hint_auto_hide_seconds.
## Пустая строка скрывает подсказку сразу. duration переопределяет таймер.
func show_hint(text: String, duration := -1.0) -> void:
	if hint == null:
		return
	var value := text.strip_edges()
	if value.is_empty():
		_hint_timer.stop()
		hint.text = ""
		hint.visible = false
		return
	hint.text = text
	hint.visible = true
	var hold := duration if duration > 0.0 else hint_auto_hide_seconds
	if hold <= 0.0:
		return
	_hint_timer.start(hold)


func _hide_hint() -> void:
	if hint == null:
		return
	hint.text = ""
	hint.visible = false


func _start_tutorial() -> void:
	if _tutorial_started:
		return
	_tutorial_started = true
	_tutorial_step = 0
	_tutorial_timer.start(1.4)


func _on_tutorial_timeout() -> void:
	# Не перекрываем сюжетный диалог обучающей карточкой.
	if _dialogue_running():
		_tutorial_timer.start(1.0)
		return
	match _tutorial_step:
		0:
			if _hint_is_free():
				show_hint("WASD — движение · мышь — обзор · Shift — бег", 8.0)
			_tutorial_step = 1
			_tutorial_timer.start(9.5)
		1:
			if _hint_is_free():
				show_hint("E — взаимодействие · C — меню · M — карта · Esc — пауза", 8.0)
			_tutorial_step = 2
			_tutorial_timer.start(9.5)
		2:
			if tide != null and tide.visible and _hint_is_free():
				show_hint("Прилив закрывает нижние проходы. Следите за индикатором справа.", 8.0)
			_tutorial_step = 3


func _dialogue_running() -> bool:
	for node in get_tree().get_nodes_in_group(&"dialogue_runner"):
		if node is DialogueRunner and bool(node.get(&"running")):
			return true
	return false


func _hint_is_free() -> bool:
	if hint == null or not hint.visible:
		return true
	return hint.text.begins_with("WASD —") or hint.text.begins_with("E — взаимодействие") or hint.text.begins_with("Прилив закрывает")
