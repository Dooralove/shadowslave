extends Node3D
## Игровая демо-сцена засады: Санни, локация с Горным Королём и отладочный HUD.
## HUD показывает цель эпизода, состояние AI, здоровье игрока, укрытие и
## доступность эвакуации. R — перезапуск.
##
## Сам сценарий живёт в AmbushController и AmbushSiteUI. Этот скрипт только
## отображает его состояние и не дублирует правила засады.

@onready var _ambush: AmbushController = $AmbushSite
@onready var _king: MountainKing = $AmbushSite/MountainKing
@onready var _sunny: SunnyController = $Sunny
@onready var _health_label: Label = $HUD/Root/PlayerHealth
@onready var _objective_label: Label = $HUD/Root/Objective
@onready var _state_label: Label = $HUD/Root/AIState
@onready var _cover_label: Label = $HUD/Root/CoverState
@onready var _message: Label = $HUD/Root/Message
@onready var _hint: Label = $HUD/Root/Hint

var _message_serial := 0


func _ready() -> void:
	_king.debug_log_state_changes = true
	_king.state_changed.connect(_on_king_state_changed)
	_king.health.died.connect(_on_king_died)
	_sunny.health.health_changed.connect(_on_player_health_changed)
	_sunny.health.died.connect(_on_player_died)
	_ambush.ambush_cutscene_started.connect(_on_ambush_started)
	_ambush.state_changed.connect(_on_episode_state_changed)
	_ambush.player_cover_changed.connect(_on_cover_changed)
	_ambush.cover_hold_completed.connect(_on_cover_hold_completed)
	_ambush.escape_denied.connect(_on_escape_denied)
	_ambush.episode_completed.connect(_on_episode_completed)

	_on_king_state_changed(_king.state)
	_on_player_health_changed(_sunny.health.current_health, _sunny.health.max_health)
	_on_cover_changed(_ambush.is_player_hidden())
	_refresh_scenario_hud()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		get_tree().reload_current_scene()


func _refresh_scenario_hud() -> void:
	if _state_label:
		_state_label.text = "Горный Король: %s · Эпизод: %s" % [
			_king.state_name(),
			_ambush.state_name(),
		]

	if _cover_label:
		var escape_text := "закрыта"
		if _ambush.is_escaped():
			escape_text = "завершена"
		elif _ambush.is_escape_available():
			escape_text = "открыта"
		_cover_label.text = "Укрытие: %s · Эвакуация: %s" % [
			"да" if _ambush.is_player_hidden() else "нет",
			escape_text,
		]

	if _objective_label:
		_objective_label.text = _objective_text()

	if _hint:
		if _ambush.is_escaped():
			_hint.text = "R — начать заново"
		else:
			_hint.text = "WASD — движение · Shift — бег · ЛКМ — удар · R — заново"


func _objective_text() -> String:
	match _ambush.get_state():
		AmbushController.State.WAITING:
			return "Цель: доберитесь до места засады."
		AmbushController.State.AMBUSH_STARTED, AmbushController.State.THREAT_ACTIVE:
			if _ambush.is_player_hidden():
				if _ambush.is_cover_ready():
					return "Цель: покиньте укрытие и уходите к каньону."
				return "Цель: переждите погоню в укрытии."
			return "Цель: укройтесь за опрокинутой повозкой."
		AmbushController.State.ESCAPE_AVAILABLE:
			return "Цель: бегите к точке эвакуации в каньоне на западе."
		AmbushController.State.ESCAPED:
			return "Эпизод завершён. R — начать заново."
	return ""


func _on_king_state_changed(_new_state: MountainKing.State) -> void:
	_refresh_scenario_hud()


func _on_episode_state_changed(_new_state: AmbushController.State) -> void:
	_refresh_scenario_hud()


func _on_player_health_changed(current: float, maximum: float) -> void:
	_health_label.text = "Санни: %d / %d" % [roundi(current), roundi(maximum)]


func _on_cover_changed(_hidden: bool) -> void:
	_refresh_scenario_hud()


func _on_cover_hold_completed() -> void:
	_refresh_scenario_hud()
	_show_message("Монстр потерял вас. Покиньте укрытие и уходите к каньону.", 3.5)


func _on_ambush_started() -> void:
	_refresh_scenario_hud()
	_show_message("Засада! Горный Король пробудился.", 3.0)


func _on_escape_denied(_reason: StringName) -> void:
	_show_message("Точка эвакуации закрыта. Сначала переждите погоню в укрытии.", 3.5)


func _on_episode_completed() -> void:
	_refresh_scenario_hud()


func _on_player_died() -> void:
	_show_message("Санни погиб. R — начать заново", 0.0)


func _on_king_died() -> void:
	_show_message("Горный Король повержен. Доберитесь до каньона.", 0.0)


func _show_message(text: String, seconds: float) -> void:
	_message_serial += 1
	var serial := _message_serial
	_message.text = text
	_message.visible = true
	if seconds <= 0.0:
		return
	await get_tree().create_timer(seconds).timeout
	if serial == _message_serial:
		_message.visible = false
