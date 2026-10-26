class_name AmbushController
extends Node3D
## Контроллер локации «Место засады каравана».
##
## Эпизод: WAITING → AMBUSH_STARTED → THREAT_ACTIVE → ESCAPE_AVAILABLE → ESCAPED.
## Контроллер связывает входную зону, укрытие у повозки, каньон побега и AI
## Горного Короля. Сам AI не дублируется: активация идёт через публичный
## интерфейс MountainKing. Сценарий, камера и UI подключаются к сигналам.
##
## Точка эвакуации открывается не сразу: игрок должен переждать погоню в
## укрытии, выйти из него и только затем добраться до конца каньона. Так
## укрытие остаётся обязательным битом прототипа, а не декоративной зоной.

signal ambush_cutscene_started
signal player_hidden_in_cover
signal player_cover_changed(hidden: bool)
signal cover_hold_completed
signal escape_path_opened
signal escape_available
signal escape_denied(reason: StringName)
signal episode_completed
signal mountain_king_activated
signal mountain_king_retreated
signal state_changed(new_state: State)

enum State { WAITING, AMBUSH_STARTED, THREAT_ACTIVE, ESCAPE_AVAILABLE, ESCAPED }

## AI монстра. Если не задан, ищется дочерний узел MountainKing.
@export var mountain_king: MountainKing
## Если false, AI выключен до start_ambush() (обычный режим засады).
@export var monster_starts_active := false
## Короткая вступительная пауза между началом засады и разрешением маршрута.
@export_range(0.0, 10.0, 0.1, "suffix:s") var ambush_intro_time := 1.6
## Сколько секунд игрок должен провести в укрытии, чтобы оно считалось рабочим.
@export_range(0.0, 10.0, 0.1, "suffix:s") var cover_dwell_to_open_escape := 1.5
## Если false, эвакуация разрешается сразу после начала преследования.
@export var require_cover_for_escape := true

@onready var _ambush_start_trigger: Area3D = get_node_or_null("Triggers/Trigger_AmbushStart") as Area3D
@onready var _wagon_cover_trigger: Area3D = get_node_or_null("Triggers/Trigger_WagonCover") as Area3D
@onready var _escape_reach_trigger: Area3D = get_node_or_null("Triggers/Trigger_EscapeReach") as Area3D

var _state := State.WAITING
var _ambush_started := false
var _player_hidden := false
var _escape_path_open := false
var _escape_available := false
var _escaped := false
var _intro_left := 0.0
var _cover_dwell := 0.0
var _cover_ready := false
var _escape_denied_notified := false


func _ready() -> void:
	if mountain_king == null:
		mountain_king = get_node_or_null("MountainKing") as MountainKing

	if is_instance_valid(_ambush_start_trigger):
		_ambush_start_trigger.body_entered.connect(_on_ambush_start_body_entered)
	if is_instance_valid(_wagon_cover_trigger):
		_wagon_cover_trigger.body_entered.connect(_on_wagon_cover_body_entered)
		_wagon_cover_trigger.body_exited.connect(_on_wagon_cover_body_exited)
	if is_instance_valid(_escape_reach_trigger):
		_escape_reach_trigger.body_entered.connect(_on_escape_reach_body_entered)

	# Сцена засады не должна начинаться с автоматической погони.
	if mountain_king:
		mountain_king.set_player_hidden(_player_hidden)
		if monster_starts_active:
			_ambush_started = true
			_state = State.THREAT_ACTIVE
			activate_monster()
			open_escape_path()
			if not require_cover_for_escape:
				_arm_escape()
		else:
			mountain_king.deactivate()

	set_process(true)


func _process(delta: float) -> void:
	tick_scenario(delta)


## Продвигает таймеры сценария. Отдельный публичный шаг нужен тестам:
## они отключают _process и проверяют переходы без ожидания реального времени.
func tick_scenario(delta: float) -> void:
	if _state == State.ESCAPED:
		return

	if _state == State.AMBUSH_STARTED:
		_intro_left = maxf(_intro_left - maxf(delta, 0.0), 0.0)
		if _intro_left <= 0.0:
			_enter_state(State.THREAT_ACTIVE)

	if _state != State.THREAT_ACTIVE:
		return

	if _player_hidden:
		_cover_dwell = minf(
			_cover_dwell + maxf(delta, 0.0),
			cover_dwell_to_open_escape
		)
		if cover_dwell_to_open_escape <= 0.0 or _cover_dwell >= cover_dwell_to_open_escape:
			_mark_cover_ready()

	if not require_cover_for_escape:
		_arm_escape()


## Запускает событие начала засады и будит AI. Повторные вызовы игнорируются.
func start_ambush() -> bool:
	if _ambush_started:
		return false
	_ambush_started = true
	DialogueManager.request_bark(DialogueManager.CONTEXT_AMBUSH)
	_enter_state(State.AMBUSH_STARTED)
	ambush_cutscene_started.emit()
	activate_monster()

	_intro_left = maxf(ambush_intro_time, 0.0)
	if _intro_left <= 0.0:
		_enter_state(State.THREAT_ACTIVE)
	return true


## Включает AI и заставляет монстра найти игрока.
func activate_monster() -> bool:
	if mountain_king == null:
		return false
	mountain_king.set_player_hidden(_player_hidden)
	var activated := mountain_king.activate()
	if activated:
		mountain_king_activated.emit()
	return activated


## Полностью выключает принятие решений монстром.
func disable_monster_ai() -> void:
	if mountain_king:
		mountain_king.deactivate()


## Единая точка для сценария: false — выключить, true — снова активировать.
func set_monster_ai_enabled(enabled: bool) -> void:
	if mountain_king == null:
		return
	if enabled:
		activate_monster()
	else:
		mountain_king.deactivate()


## Сценарное отступление. destination — мировая точка, куда уходит монстр.
func order_monster_retreat(destination: Vector3, duration := -1.0) -> bool:
	if mountain_king == null:
		return false
	var started := mountain_king.start_retreat(destination, duration)
	if started:
		mountain_king_retreated.emit()
	return started


## Открывает физический маршрут побега и сообщает об этом слушателям.
## Это ещё не разрешение на эвакуацию: Trigger_EscapeReach проверяет state.
func open_escape_path() -> void:
	if _escape_path_open:
		return
	_escape_path_open = true
	DialogueManager.request_bark(DialogueManager.CONTEXT_ESCAPE)
	escape_path_opened.emit()


func is_ambush_started() -> bool:
	return _ambush_started


func is_player_hidden() -> bool:
	return _player_hidden


func is_cover_ready() -> bool:
	return _cover_ready


func is_escape_path_open() -> bool:
	return _escape_path_open


func is_escape_available() -> bool:
	return _escape_available


func is_escaped() -> bool:
	return _escaped


func get_state() -> State:
	return _state


func state_name() -> String:
	return str(State.keys()[_state])


## Прогресс пребывания в укрытии от 0 до 1. Нужен HUD, не влияет на AI.
func get_cover_dwell_progress() -> float:
	if cover_dwell_to_open_escape <= 0.0:
		return 1.0
	return clampf(_cover_dwell / cover_dwell_to_open_escape, 0.0, 1.0)


func _enter_state(new_state: State) -> void:
	if _state == new_state:
		return
	_state = new_state

	match _state:
		State.THREAT_ACTIVE:
			open_escape_path()
		State.ESCAPE_AVAILABLE:
			_escape_available = true
			escape_available.emit()
		State.ESCAPED:
			_escaped = true
			disable_monster_ai()
			if is_instance_valid(_escape_reach_trigger):
				_escape_reach_trigger.set_deferred("monitoring", false)
			episode_completed.emit()

	state_changed.emit(_state)

	if _state == State.THREAT_ACTIVE and not require_cover_for_escape:
		_arm_escape()


func _arm_escape() -> void:
	if _escaped or _escape_available:
		return
	if _state != State.THREAT_ACTIVE:
		return
	_enter_state(State.ESCAPE_AVAILABLE)


func _mark_cover_ready() -> void:
	if _cover_ready:
		return
	_cover_ready = true
	cover_hold_completed.emit()


func _on_ambush_start_body_entered(body: Node3D) -> void:
	if body.is_in_group(&"player"):
		start_ambush()


func _on_wagon_cover_body_entered(body: Node3D) -> void:
	if not body.is_in_group(&"player") or _player_hidden:
		return
	if _state == State.WAITING or _state == State.ESCAPED:
		return
	_player_hidden = true
	_cover_dwell = 0.0
	_cover_ready = false
	if mountain_king:
		mountain_king.set_player_hidden(true)
	DialogueManager.request_bark(DialogueManager.CONTEXT_COVER)
	player_hidden_in_cover.emit()
	player_cover_changed.emit(true)


func _on_wagon_cover_body_exited(body: Node3D) -> void:
	if not body.is_in_group(&"player") or not _player_hidden:
		return
	_player_hidden = false
	if mountain_king:
		mountain_king.set_player_hidden(false)
	player_cover_changed.emit(false)

	if _state != State.THREAT_ACTIVE:
		return
	if not require_cover_for_escape:
		_arm_escape()
	elif _cover_ready:
		_arm_escape()


func _on_escape_reach_body_entered(body: Node3D) -> void:
	if not body.is_in_group(&"player") or _escaped:
		return
	if _state != State.ESCAPE_AVAILABLE or not _escape_available:
		if not _escape_denied_notified:
			_escape_denied_notified = true
			escape_denied.emit(&"escape_not_ready")
		return
	_enter_state(State.ESCAPED)
