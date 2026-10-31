class_name SpellOverlay
extends CanvasLayer
## Сообщения Кошмарного Заклятия.
##
## Один компонент обслуживает два режима: короткую панель справа сверху и
## полноэкранное появление в темноте. Сообщения показываются по одному в
## порядке очереди; показом управляет один таймер, поэтому запоздавший показ
## не может погасить более новое сообщение.
##
## Слой не перехватывает мышь и не участвует в игровом вводе.

## Началось отображение конкретного сообщения. Удобно для звука и тестов.
signal message_started(message: SpellMessage)
## Сообщение полностью показано и растворено; визуальные узлы уже очищены.
signal message_finished
## Очередь опустела (или была очищена вызовом clear_messages).
signal queue_finished

const SHOW_ANIMATION := &"show_runes"
const HIDE_ANIMATION := &"hide_runes"
const PANEL_FADE_IN := 0.25
const PANEL_FADE_OUT := 0.3
const DIM_COLOR := Color(0.02, 0.03, 0.06)
const DIM_ALPHA := 0.28

enum Phase { IDLE, SHOW, HOLD, HIDE }

@onready var dim: ColorRect = get_node_or_null("%Dim") as ColorRect
@onready var rune_text: RichTextLabel = get_node_or_null("%RuneText") as RichTextLabel
@onready var animation_player: AnimationPlayer = get_node_or_null("%AnimationPlayer") as AnimationPlayer
@onready var message_panel: PanelContainer = get_node_or_null("%MessagePanel") as PanelContainer
@onready var header_label: Label = get_node_or_null("%HeaderLabel") as Label
@onready var body_label: RichTextLabel = get_node_or_null("%BodyLabel") as RichTextLabel

var _queue: Array[SpellMessage] = []
var _active: SpellMessage
var _phase := Phase.IDLE
var _phase_time := 0.0
var _phase_duration := 0.0
var _show_duration := 0.0
var _hold_duration := 0.0
var _hide_duration := 0.0


func _ready() -> void:
	visible = false
	set_process(false)
	_reset_visuals()


func _exit_tree() -> void:
	# Никаких корутин и отложенных таймеров: при уходе со сцены состояние
	# просто сбрасывается, и старый показ не может ничего изменить позже.
	_queue.clear()
	_active = null
	_phase = Phase.IDLE
	set_process(false)
	if is_instance_valid(animation_player):
		animation_player.stop()


## Основной способ показа. Сообщение встаёт в очередь и показывается после
## предыдущего. presentation переопределяет режим из ресурса (-1 — не менять).
func show_message(message: SpellMessage, presentation: int = -1) -> void:
	if message == null:
		push_warning("SpellOverlay: show_message() получил null")
		return

	var item := message
	if presentation != -1:
		if not _is_valid_presentation(presentation):
			push_warning("SpellOverlay: неизвестный режим показа %s" % presentation)
			return
		item = message.duplicate() as SpellMessage
		item.presentation = presentation as SpellMessage.Presentation

	if not item.is_valid():
		push_warning("SpellOverlay: сообщение '%s' пустое или имеет неверную длительность" % item.id)
		return

	_queue.append(item)
	if _active == null and _phase == Phase.IDLE:
		_start_next()


## Удобный показ текста без ресурса — для внешних сигналов вроде
## SanctuaryController.spell_message.
func show_text(
	text: String,
	duration := 4.0,
	presentation: int = SpellMessage.Presentation.PANEL,
	header := SpellMessage.DEFAULT_HEADER
) -> void:
	var message := SpellMessage.new()
	message.header = header
	message.text = text
	message.duration = duration
	message.presentation = presentation as SpellMessage.Presentation
	show_message(message)


## Совместимость с прежним API: полноэкранный BBCode-текст.
## Возвращается после растворения очереди; вызывать можно и без await.
func display_spell_message(bbcode_text: String, duration: float) -> void:
	if bbcode_text.strip_edges().is_empty():
		push_warning("SpellOverlay: пустой текст сообщения")
		return
	var message := SpellMessage.new()
	message.text = bbcode_text
	message.duration = duration
	message.presentation = SpellMessage.Presentation.CINEMATIC
	show_message(message)
	await queue_finished


## Немедленно убирает текущее сообщение и всю очередь.
func clear_messages() -> void:
	var had_work := _active != null or not _queue.is_empty()
	_queue.clear()
	_active = null
	_phase = Phase.IDLE
	_phase_time = 0.0
	set_process(false)
	if is_instance_valid(animation_player):
		animation_player.stop()
	_reset_visuals()
	visible = false
	if had_work:
		queue_finished.emit()


func is_showing() -> bool:
	return _active != null


func queued_count() -> int:
	return _queue.size()


func _process(delta: float) -> void:
	if _active == null:
		set_process(false)
		return

	_phase_time += delta

	match _phase:
		Phase.SHOW:
			_update_phase_visual()
			if _phase_time >= _phase_duration:
				_finish_show_phase()
		Phase.HOLD:
			if _phase_time >= _phase_duration:
				_begin_hide_phase()
		Phase.HIDE:
			_update_phase_visual()
			if _phase_time >= _phase_duration:
				_complete_active()


func _start_next() -> void:
	while _active == null and not _queue.is_empty():
		var candidate: SpellMessage = _queue.pop_front()
		if candidate == null or not candidate.is_valid():
			continue

		_active = candidate
		if not _begin_presentation(candidate):
			# Нет нужных узлов: сообщение пропускается, очередь не зависает.
			_active = null
			continue
		set_process(true)
		return

	set_process(false)
	queue_finished.emit()


func _begin_presentation(message: SpellMessage) -> bool:
	var is_panel := message.presentation == SpellMessage.Presentation.PANEL
	var instant := message.duration <= 0.0

	if is_panel:
		if not _has_panel_nodes():
			push_warning("SpellOverlay: в сцене нет узлов панели сообщения")
			return false
		_prepare_panel(message)
		_show_duration = 0.0 if instant else PANEL_FADE_IN
		_hold_duration = maxf(message.duration - _show_duration, 0.0)
		_hide_duration = 0.0 if instant else PANEL_FADE_OUT
		_set_panel_alpha(1.0 if instant else 0.0)
	else:
		if not _has_cinematic_nodes():
			push_warning("SpellOverlay: в сцене нет узлов полноэкранного показа")
			return false
		_prepare_cinematic(message)
		if instant:
			_show_duration = 0.0
			_hold_duration = 0.0
			_hide_duration = 0.0
			rune_text.visible_ratio = 1.0
			_set_dim_alpha(DIM_ALPHA)
		else:
			_show_duration = _animation_length(SHOW_ANIMATION)
			_hold_duration = maxf(message.duration - _show_duration, 0.0)
			_hide_duration = _animation_length(HIDE_ANIMATION)
			animation_player.play(SHOW_ANIMATION)

	_phase = Phase.SHOW
	_phase_time = 0.0
	_phase_duration = _show_duration
	message_started.emit(message)
	return true


func _finish_show_phase() -> void:
	if _active == null:
		return
	if _active.presentation == SpellMessage.Presentation.PANEL:
		_set_panel_alpha(1.0)
	else:
		if is_instance_valid(rune_text):
			rune_text.visible_ratio = 1.0
		_set_dim_alpha(DIM_ALPHA)

	_phase = Phase.HOLD
	_phase_time = 0.0
	_phase_duration = _hold_duration
	if _hold_duration <= 0.0:
		_begin_hide_phase()


func _begin_hide_phase() -> void:
	if _active == null:
		return

	if _active.presentation == SpellMessage.Presentation.PANEL:
		if _hide_duration <= 0.0:
			_complete_active()
			return
		_set_panel_alpha(1.0)
	else:
		if _hide_duration <= 0.0:
			_complete_active()
			return
		if is_instance_valid(animation_player):
			animation_player.play(HIDE_ANIMATION)

	_phase = Phase.HIDE
	_phase_time = 0.0
	_phase_duration = _hide_duration


func _complete_active() -> void:
	_active = null
	_phase = Phase.IDLE
	_phase_time = 0.0
	_phase_duration = 0.0
	_reset_visuals()
	visible = false
	message_finished.emit()
	if _active == null:
		_start_next()


func _update_phase_visual() -> void:
	if _active == null or _active.presentation != SpellMessage.Presentation.PANEL:
		return
	if _phase_duration <= 0.0:
		return
	var t := clampf(_phase_time / _phase_duration, 0.0, 1.0)
	t = t * t * (3.0 - 2.0 * t)
	if _phase == Phase.HIDE:
		t = 1.0 - t
	_set_panel_alpha(t)


func _prepare_panel(message: SpellMessage) -> void:
	visible = true
	if is_instance_valid(animation_player):
		animation_player.stop()
	if is_instance_valid(rune_text):
		rune_text.visible = false
	_set_dim_alpha(0.0)

	var header := message.header
	if header.strip_edges().is_empty():
		header = SpellMessage.DEFAULT_HEADER
	header_label.text = header
	body_label.text = message.text
	message_panel.visible = true
	message_panel.modulate.a = 0.0


func _prepare_cinematic(message: SpellMessage) -> void:
	visible = true
	if is_instance_valid(message_panel):
		message_panel.visible = false
		message_panel.modulate.a = 0.0
	if is_instance_valid(animation_player):
		animation_player.stop()
	rune_text.visible = true
	rune_text.text = message.text
	rune_text.visible_ratio = 0.0
	rune_text.modulate = Color.WHITE
	_set_dim_alpha(0.0)


func _reset_visuals() -> void:
	if is_instance_valid(animation_player):
		animation_player.stop()
	if is_instance_valid(rune_text):
		rune_text.text = ""
		rune_text.visible = true
		rune_text.visible_ratio = 0.0
		rune_text.modulate = Color.WHITE
	if is_instance_valid(dim):
		dim.color = Color(DIM_COLOR.r, DIM_COLOR.g, DIM_COLOR.b, 0.0)
	if is_instance_valid(message_panel):
		message_panel.visible = false
		message_panel.modulate.a = 0.0
	if is_instance_valid(header_label):
		header_label.text = ""
	if is_instance_valid(body_label):
		body_label.text = ""


func _set_dim_alpha(alpha: float) -> void:
	if not is_instance_valid(dim):
		return
	var color := dim.color
	color.a = clampf(alpha, 0.0, 1.0)
	dim.color = color


func _set_panel_alpha(alpha: float) -> void:
	if not is_instance_valid(message_panel):
		return
	message_panel.modulate.a = clampf(alpha, 0.0, 1.0)


func _has_panel_nodes() -> bool:
	return (
		is_instance_valid(message_panel)
		and is_instance_valid(header_label)
		and is_instance_valid(body_label)
	)


func _has_cinematic_nodes() -> bool:
	return (
		is_instance_valid(dim)
		and is_instance_valid(rune_text)
		and is_instance_valid(animation_player)
	)


func _is_valid_presentation(presentation: int) -> bool:
	return SpellMessage.Presentation.values().has(presentation)


func _animation_length(animation_name: StringName) -> float:
	if not is_instance_valid(animation_player):
		return 0.0
	var animation := animation_player.get_animation(animation_name)
	if animation == null:
		push_warning("SpellOverlay: не найдена анимация %s" % animation_name)
		return 0.0
	return animation.length
