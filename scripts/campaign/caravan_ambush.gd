extends Node3D
## Оболочка игрового эпизода засады в кампании.
##
## Готовая сцена ambush_site_demo.tscn остаётся без изменений: контроллер,
## Горный Король, укрытие и эвакуация работают как раньше. Оболочка только
## слушает существующий сигнал episode_completed, даёт дочитать сообщение
## Заклятия и загружает святилище.

signal transition_started

const NEXT_SCENE := "res://scenes/campaign/sanctuary_arrival.tscn"

@export var transition_enabled := true
@export var fade_in := true
@export var post_escape_pause := 0.8

@onready var _ambush: AmbushController = $AmbushSiteDemo/AmbushSite
@onready var _overlay: SpellOverlay = $AmbushSiteDemo/AmbushSite/SpellOverlay
@onready var _fade: FadeLayer = $Transition/Fade

var _leaving := false


func _ready() -> void:
	_ambush.episode_completed.connect(_on_episode_completed)
	if fade_in:
		_fade.color.a = 1.0
		await _fade.fade_to(0.0, 1.0)
	else:
		_fade.color.a = 0.0


func has_started_transition() -> bool:
	return _leaving


func _on_episode_completed() -> void:
	if _leaving:
		return
	_leaving = true
	transition_started.emit()

	if not transition_enabled:
		return

	# episode_completed испускается до state_changed, поэтому сообщение об
	# эвакуации встаёт в очередь только следующим кадром.
	await get_tree().process_frame
	if _overlay.is_showing() or _overlay.queued_count() > 0:
		await _overlay.queue_finished
	else:
		await get_tree().create_timer(1.0).timeout

	await get_tree().create_timer(post_escape_pause).timeout
	await _fade.fade_to(1.0, 1.0)
	get_tree().change_scene_to_file(NEXT_SCENE)
