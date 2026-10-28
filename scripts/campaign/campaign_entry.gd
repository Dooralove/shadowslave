extends Node3D
## Точка входа кампании Первого Кошмара.
##
## Это не новый режиссёр и не менеджер уровней: оболочка показывает готовый
## пролог B01–B16, убирает его финальную карточку и переводит игрока на
## короткий перевал. Сценарий пролога не меняется.

signal campaign_started
signal transition_started

const NEXT_SCENE := "res://scenes/campaign/first_nightmare_pass.tscn"
const NEXT_SPAWN := &"Chain"
const CARD_HOLD := 3.0

@export var autostart := true
@export var transition_enabled := true
@export var card_hold := CARD_HOLD

@onready var _prologue: SliceDirector = $Prologue
@onready var _transition: CanvasLayer = $Transition

var _started := false
var _finished := false
var _leaving := false


func _ready() -> void:
	_transition.visible = false
	_prologue.slice_finished.connect(_on_slice_finished)
	if autostart:
		start()


func start() -> void:
	if _started:
		return
	_started = true
	# Новое прохождение начинается с чистого состояния, включая R-перезапуск.
	NightmareRunState.reset()
	LevelPortal.clear_pending_spawn()
	LevelPortal.clear_active_transition()
	campaign_started.emit()
	_prologue.start()


func is_finished() -> bool:
	return _finished


func is_transition_started() -> bool:
	return _leaving


func _on_slice_finished() -> void:
	if _finished:
		return
	_finished = true
	NightmareRunState.set_flag(&"prologue_completed")

	# Пролог сам показывает «Конец вертикального среза». В кампании вместо неё
	# появляется карточка перехода, поэтому готовый экран пролога только скрываем.
	_prologue.ui.end_card.visible = false
	_transition.visible = true

	if not transition_enabled:
		return

	_leaving = true
	transition_started.emit()
	await get_tree().create_timer(card_hold).timeout
	LevelPortal.set_pending_spawn(NEXT_SCENE, NEXT_SPAWN)
	get_tree().change_scene_to_file(NEXT_SCENE)
