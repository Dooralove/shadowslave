extends Node3D
## Оболочка S13: святилище, подношение, приход Тирана и его смерть от теней.
##
## Ритуал завершает испытание, но не оценку. После подтверждения смерти
## Тирана оболочка переходит к звёздной оценке, а не показывает финальную
## карточку прототипа. R больше не перезапускает кампанию здесь: рестарт
## принадлежит финальной сцене.

signal transition_started

const SCENE_PATH := "res://scenes/campaign/sanctuary_arrival.tscn"
const NEXT_SCENE := "res://scenes/campaign/appraisal_arrival.tscn"
const DEFAULT_SPAWN := &"SanctuaryEntrance"

@export var fade_in := true
@export var transition_enabled := true
@export var completion_pause := 1.2

@onready var _sanctuary: SanctuaryController = $Sanctuary
@onready var _ritual: AltarRitual = $Sanctuary/AltarRitual
@onready var _player: SunnyController = $Sanctuary/Sunny
@onready var _fade: FadeLayer = $Transition/Fade
@onready var _card: Control = $Transition/Card

var _completed := false
var beat_director: BeatDirector


func _ready() -> void:
	_ensure_beat_director()
	_audio_scene(&"sanctuary", &"sanctuary")
	beat_director.transition_to_beat(&"N24")
	_ritual.finished.connect(_on_trial_finished)
	_place_player()
	_card.visible = false
	if fade_in:
		_fade.color.a = 1.0
		await _fade.fade_to(0.0, 1.2)
	else:
		_fade.color.a = 0.0


func _audio_scene(zone_id: StringName, music_id: StringName) -> void:
	var director := get_node_or_null(^"/root/AudioDirector")
	if director == null:
		return
	if director.has_method(&"play_music"):
		director.call(&"play_music", music_id, 3.0)
	if director.has_method(&"play_ambience"):
		director.call(&"play_ambience", zone_id, 3.0)
	if director.has_method(&"set_reverb_profile"):
		director.call(&"set_reverb_profile", &"sanctuary")


func _audio_stop(fade: float) -> void:
	var director := get_node_or_null(^"/root/AudioDirector")
	if director == null:
		return
	if director.has_method(&"stop_music"):
		director.call(&"stop_music", fade)
	if director.has_method(&"stop_ambience"):
		director.call(&"stop_ambience", fade)
	if director.has_method(&"set_reverb_profile"):
		director.call(&"set_reverb_profile", &"outdoor")


func _ensure_beat_director() -> void:
	if beat_director != null:
		return
	beat_director = get_node_or_null("BeatDirector") as BeatDirector
	if beat_director == null:
		beat_director = BeatDirector.new()
		beat_director.name = "BeatDirector"
		add_child(beat_director)
	beat_director.bind_player(_player)



func is_completed() -> bool:
	return _completed


func has_started_transition() -> bool:
	return _completed


func _place_player() -> void:
	var requested := LevelPortal.take_pending_spawn(SCENE_PATH)
	var spawn := LevelPortal.resolve_spawn(_sanctuary, requested, DEFAULT_SPAWN)
	if spawn == null:
		push_error("SanctuaryArrival: нет точки Spawns/%s" % requested)
		return
	# Сцена святилища содержит игрока внутри; оболочка только применяет
	# именованную точку входа, не создавая второго Санни.
	_player.global_position = spawn.global_position
	_player.velocity = Vector3.ZERO
	# Прыжок доступен в кампании; бой в святилище по-прежнему выключен.
	_player.allow_jump = true
	_player.combat_enabled = false
	var yaw := spawn.global_rotation.y
	_player.visual.rotation.y = yaw
	_player.camera_rig.yaw = yaw
	_player.camera_rig.set_pitch(_player.camera_rig.pitch)


func _on_trial_finished() -> void:
	if _completed:
		return
	_completed = true
	var guide := get_node_or_null("/root/CampaignGuide")
	if guide != null and guide.has_method(&"clear_current_objective"):
		guide.call(&"clear_current_objective")
	transition_started.emit()

	var player := _sanctuary.get_node_or_null("Sunny") as SunnyController
	if player != null:
		player.input_enabled = false
		player.forced_velocity = Vector3.ZERO
		player.camera_rig.look_enabled = false

	_sanctuary.complete_trial()
	_audio_stop(2.0)
	NightmareRunState.set_flag(&"trial_completed")
	NightmareRunState.set_flag(&"tyrant_death_confirmed")
	NightmareRunState.set_item(&"shadow_blessing")
	if beat_director != null and beat_director.current_beat != null:
		beat_director.beat_completed.emit(beat_director.current_beat)


	if not transition_enabled:
		return
	await get_tree().create_timer(completion_pause).timeout
	await _fade.fade_to(1.0, 1.2)
	get_tree().change_scene_to_file(NEXT_SCENE)


func _unhandled_input(event: InputEvent) -> void:
	if _completed and event.is_action_pressed("restart") and not transition_enabled:
		get_viewport().set_input_as_handled()

