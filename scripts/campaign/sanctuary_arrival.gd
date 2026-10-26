extends Node3D
## Оболочка S13: святилище, подношение, приход Тирана и его смерть от теней.
##
## Ритуал завершает испытание, но не оценку. После подтверждения смерти
## Тирана оболочка переходит к звёздной оценке, а не показывает финальную
## карточку прототипа. R больше не перезапускает кампанию здесь: рестарт
## принадлежит финальной сцене.

signal transition_started

const NEXT_SCENE := "res://scenes/campaign/appraisal_arrival.tscn"

@export var fade_in := true
@export var transition_enabled := true
@export var completion_pause := 1.2

@onready var _sanctuary: SanctuaryController = $Sanctuary
@onready var _ritual: AltarRitual = $Sanctuary/AltarRitual
@onready var _fade: FadeLayer = $Transition/Fade
@onready var _card: Control = $Transition/Card
@onready var _objective: Control = $Objective/Root

var _completed := false


func _ready() -> void:
	_ritual.finished.connect(_on_trial_finished)
	_card.visible = false
	if fade_in:
		_fade.color.a = 1.0
		await _fade.fade_to(0.0, 1.2)
	else:
		_fade.color.a = 0.0


func is_completed() -> bool:
	return _completed


func has_started_transition() -> bool:
	return _completed


func _on_trial_finished() -> void:
	if _completed:
		return
	_completed = true
	_objective.visible = false
	transition_started.emit()

	var player := _sanctuary.get_node_or_null("Sunny") as SunnyController
	if player != null:
		player.input_enabled = false
		player.forced_velocity = Vector3.ZERO
		player.camera_rig.look_enabled = false

	_sanctuary.complete_trial()
	NightmareRunState.set_flag(&"trial_completed")
	NightmareRunState.set_flag(&"tyrant_death_confirmed")
	NightmareRunState.set_item(&"shadow_blessing")

	if not transition_enabled:
		return
	await get_tree().create_timer(completion_pause).timeout
	await _fade.fade_to(1.0, 1.2)
	get_tree().change_scene_to_file(NEXT_SCENE)


func _unhandled_input(event: InputEvent) -> void:
	if _completed and event.is_action_pressed("restart") and not transition_enabled:
		get_viewport().set_input_as_handled()

