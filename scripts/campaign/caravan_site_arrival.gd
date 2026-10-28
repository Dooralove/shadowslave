extends Node3D
## Оболочка S02–S06: стоянка, нападение, личинка, повозка, совет, ветеран,
## Silver Bell, ночь и рассвет.
##
## Локация caravan_site владеет геометрией и одноразовыми взаимодействиями.
## Эта сцена добавляет Санни, UI, диалоги, постановочные тайминги и переход.

signal transition_started

const SCENE_PATH := "res://scenes/campaign/caravan_site_arrival.tscn"
const NEXT_SCENE := "res://scenes/campaign/pilgrim_path_arrival.tscn"
const DEFAULT_SPAWN := &"Chain"
const NEXT_SPAWN := &"Start"
const CAMP_ARRIVAL := preload("res://resources/dialogue/caravan/camp_arrival.tres")
const HERO_GAZE := preload("res://resources/dialogue/caravan/camp_hero_gaze.tres")
const ATTACK_SEQUENCE := preload("res://resources/dialogue/caravan/camp_attack.tres")
const METAMORPHOSIS := preload("res://resources/dialogue/caravan/camp_metamorphosis.tres")
const LARVA_KILL := preload("res://resources/dialogue/caravan/camp_larva_kill.tres")
const KEY_THROW := preload("res://resources/dialogue/caravan/camp_key_throw.tres")
const UNLOCK_SEQUENCE := preload("res://resources/dialogue/caravan/camp_unlock.tres")
const COMPLETE_SEQUENCE := preload("res://resources/dialogue/caravan/camp_complete.tres")
const WAGON_PLAN := preload("res://resources/dialogue/caravan/camp_wagon_plan.tres")
const WAGON_FALL := preload("res://resources/dialogue/caravan/camp_wagon_fall.tres")
const AFTERMATH_SEQUENCE := preload("res://resources/dialogue/caravan/camp_aftermath.tres")
const VETERAN_APPROACH := preload("res://resources/dialogue/caravan/camp_veteran.tres")
const VETERAN_KILL := preload("res://resources/dialogue/caravan/camp_veteran_kill.tres")
const VETERAN_LOOT := preload("res://resources/dialogue/caravan/camp_veteran_loot.tres")
const NIGHT_SEQUENCE := preload("res://resources/dialogue/caravan/camp_night.tres")
const NIGHT_POISON_SEQUENCE := preload("res://resources/dialogue/caravan/camp_night_poison.tres")
const DAWN_SEQUENCE := preload("res://resources/dialogue/caravan/camp_dawn.tres")
const SITE_MESSAGES := preload("res://resources/spell/caravan_site_messages.tres")
const FALL_RESET_Y := -3.0

const FLAG_CAMP_REACHED := &"camp_reached"
const FLAG_CAMP_COMPLETED := &"camp_completed"
const FLAG_CHAINS_RELEASED := &"chains_released"

@export var transition_enabled := true
@export var fade_in := true
@export var fast_mode := false
@export var debug_direct_scene := true
@export var camp_tether_radius := 4.9
@export var arrival_sequence: DialogueSequence
@export var hero_gaze_sequence: DialogueSequence
@export var attack_sequence: DialogueSequence
@export var metamorphosis_sequence: DialogueSequence
@export var larva_sequence: DialogueSequence
@export var key_throw_sequence: DialogueSequence
@export var unlock_sequence: DialogueSequence
@export var complete_sequence: DialogueSequence
@export var wagon_plan_sequence: DialogueSequence
@export var wagon_fall_sequence: DialogueSequence
@export var aftermath_sequence: DialogueSequence
@export var veteran_approach_sequence: DialogueSequence
@export var veteran_kill_sequence: DialogueSequence
@export var veteran_loot_sequence: DialogueSequence
@export var night_sequence: DialogueSequence
@export var dawn_sequence: DialogueSequence
@export var messages: SpellMessageCatalog

@onready var _site: CaravanSite = $CaravanSite
@onready var _player: SunnyController = $Sunny
@onready var _ui: PrologueUI = $UI
@onready var _dialogue: DialogueRunner = $DialogueRunner
@onready var _fade: FadeLayer = $Transition/Fade
@onready var _flash: ColorRect = $Transition/Flash
@onready var _note: Label = $PrototypeNote/Root/Note
@onready var _wagon_camera: Camera3D = $WagonCamera
@onready var _dusk: ColorRect = $NightTint/Tint

var _sequence_queue: Array[DialogueSequence] = []
var _sequence_busy := false
var _attack_running := false
var _larva_running := false
var _key_running := false
var _wagon_running := false
var _veteran_running := false
var _night_running := false
var _leaving := false
var _saved_camera_yaw := 0.0
var _saved_camera_pitch := 0.0
var _saved_camera_look := true


func _ready() -> void:
	if arrival_sequence == null:
		arrival_sequence = CAMP_ARRIVAL
	if hero_gaze_sequence == null:
		hero_gaze_sequence = HERO_GAZE
	if attack_sequence == null:
		attack_sequence = ATTACK_SEQUENCE
	if metamorphosis_sequence == null:
		metamorphosis_sequence = METAMORPHOSIS
	if larva_sequence == null:
		larva_sequence = LARVA_KILL
	if key_throw_sequence == null:
		key_throw_sequence = KEY_THROW
	if unlock_sequence == null:
		unlock_sequence = UNLOCK_SEQUENCE
	if complete_sequence == null:
		complete_sequence = COMPLETE_SEQUENCE
	if wagon_plan_sequence == null:
		wagon_plan_sequence = WAGON_PLAN
	if wagon_fall_sequence == null:
		wagon_fall_sequence = WAGON_FALL
	if aftermath_sequence == null:
		aftermath_sequence = AFTERMATH_SEQUENCE
	if veteran_approach_sequence == null:
		veteran_approach_sequence = VETERAN_APPROACH
	if veteran_kill_sequence == null:
		veteran_kill_sequence = VETERAN_KILL
	if veteran_loot_sequence == null:
		veteran_loot_sequence = VETERAN_LOOT
	if night_sequence == null:
		night_sequence = NIGHT_SEQUENCE
	if dawn_sequence == null:
		dawn_sequence = DAWN_SEQUENCE
	if messages == null:
		messages = SITE_MESSAGES

	_dialogue.subtitles = _ui.subtitles
	_dialogue.fast_mode = fast_mode
	_site.sequence_requested.connect(_queue_sequence)
	_site.hint_requested.connect(_ui.show_hint)
	# Контекстная подсказка «E — …» у ближайшей точки: тот же Interactor и тот же
	# InteractionPromptUI, что и в прологе. Без связи точки работают, а подсказки нет.
	var interactor := _player.get_node_or_null("Interactor") as Interactor
	if interactor:
		interactor.focus_changed.connect(_ui.prompt.show_for)
	_site.attack_requested.connect(_start_attack)
	_site.larva_grabbed.connect(_handle_larva_grabbed)
	_site.key_collected.connect(_handle_key_collected)
	_site.wagon_push_requested.connect(_handle_wagon_push)
	_site.veteran_found.connect(_handle_veteran_found)
	_site.veteran_execution_requested.connect(_handle_veteran_execution)
	_site.night_requested.connect(_handle_night)
	_site.dawn_requested.connect(_handle_dawn)
	_flash.color.a = 0.0
	# UI/Fade принадлежит PrologueUI и по умолчанию непрозрачен. В этой оболочке
	# затемнение ведёт Transition/Fade, поэтому старый слой нужно погасить.
	_ui.fade.color.a = 0.0
	_place_player()
	_begin_camp()
	if fade_in:
		_fade.color.a = 1.0
		await _fade.fade_to(0.0, 1.0)
	else:
		_fade.color.a = 0.0


func has_started_transition() -> bool:
	return _leaving


func get_phase() -> StringName:
	return _site.phase


func _place_player() -> void:
	var requested := LevelPortal.take_pending_spawn(SCENE_PATH)
	var spawn := LevelPortal.resolve_spawn(_site, requested, DEFAULT_SPAWN)
	var anchor: Node3D = _site.get_spawn(&"ChainAnchor")
	if spawn:
		_player.global_position = spawn.global_position + Vector3(0.0, 0.05, 0.0)
	_player.velocity = Vector3.ZERO
	_player.visual.rotation.y = 0.0
	_player.camera_rig.yaw = 0.0
	_player.camera_rig.set_pitch(_player.camera_rig.pitch)
	_player.allow_sprint = false
	_player.allow_jump = false
	_player.combat_enabled = false

	# Служебная подпись сегмента — только при отладочном запуске сцены; в кампании игрок её не видит.
	_note.visible = false
	if not NightmareRunState.has_flag(FLAG_CAMP_REACHED):
		if debug_direct_scene:
			NightmareRunState.set_flag(&"march_intro_seen")
			NightmareRunState.set_flag(FLAG_CAMP_REACHED)
			_note.text = "ОТЛАДОЧНЫЙ ЗАПУСК · S02–S06 можно проверить без перевала. В кампании сюда ведёт только CampArrival."
			_note.visible = true
		else:
			push_warning("CaravanSiteArrival: нет camp_reached; сцена запущена напрямую")

	if anchor:
		_player.enable_camp_tether(anchor.global_position, camp_tether_radius)
		NightmareRunState.set_flag(&"chain_restrained")


func _begin_camp() -> void:
	_site.begin_camp()
	_ui.show_hint("Стоянка каравана. Осмотрите костёр, ягоды и повозку; затем вернитесь к огню.")
	_queue_sequence(arrival_sequence)


func _queue_sequence(sequence: DialogueSequence) -> void:
	if sequence == null:
		return
	_sequence_queue.append(sequence)
	if not _sequence_busy:
		_play_next_sequence()


func _play_next_sequence() -> void:
	if _sequence_busy or _sequence_queue.is_empty():
		return
	_sequence_busy = true
	var sequence: DialogueSequence = _sequence_queue.pop_front()
	await _dialogue.run(sequence)
	_sequence_busy = false
	if not _sequence_queue.is_empty():
		_play_next_sequence()


## Ждёт не только свою реплику, но и всё, что уже стояло в очереди:
## постановка не начинается поверх обязательного осмотра лагеря.
func _await_sequence(sequence: DialogueSequence) -> void:
	_queue_sequence(sequence)
	while _sequence_busy or not _sequence_queue.is_empty():
		await get_tree().process_frame


func _start_attack() -> void:
	if _attack_running or _leaving:
		return
	_attack_running = true
	_player.input_enabled = false
	_player.forced_velocity = Vector3.ZERO
	_ui.show_hint("")
	_note.visible = false
	NightmareRunState.set_flag(&"hero_mountain_gaze")

	await _await_sequence(hero_gaze_sequence)
	_flash_screen(Color(0.62, 0.72, 1.0, 0.34), 0.5)
	await _pause(0.35)
	await _await_sequence(attack_sequence)
	await _site.drop_rocks(fast_mode)
	_stage_tyrant_camera()
	_site.show_tyrant()
	await _site.grow_tyrant(0.7, fast_mode)
	await _pause(0.2)
	await _tyrant_swipe()
	_site.show_broad_death()
	_flash_screen(Color(0.55, 0.05, 0.03, 0.58), 0.45)
	await _pause(0.5)
	await _await_sequence(metamorphosis_sequence)
	_site.show_larva()
	await _pause(0.6)
	_site.begin_larva_phase()
	_restore_player_camera()
	_player.input_enabled = true


func _tyrant_swipe() -> void:
	if not is_instance_valid(_site.tyrant):
		return
	var start := _site.tyrant.position
	var strike := start + Vector3(-2.6, 0.0, 0.8)
	if fast_mode:
		_site.tyrant.position = strike
		_site.tyrant.position = start
		return
	var tween := create_tween()
	tween.tween_property(_site.tyrant, "position", strike, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(_site.tyrant, "position", start, 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await tween.finished


## На время появления Горного Короля камера поднимается к стене, чтобы
## четырёхметровый силуэт не оставался за верхней кромкой кадра.
func _stage_tyrant_camera() -> void:
	_saved_camera_yaw = _player.camera_rig.yaw
	_saved_camera_pitch = _player.camera_rig.pitch
	_saved_camera_look = _player.camera_rig.look_enabled
	_player.camera_rig.look_enabled = false
	_player.camera_rig.yaw = 0.0
	_player.camera_rig.set_pitch(deg_to_rad(12.0))


func _restore_player_camera() -> void:
	_player.camera_rig.look_enabled = _saved_camera_look
	_player.camera_rig.yaw = _saved_camera_yaw
	_player.camera_rig.set_pitch(_saved_camera_pitch)
	if is_instance_valid(_player.camera_rig.camera):
		_player.camera_rig.camera.make_current()


func _handle_larva_grabbed() -> void:
	if _larva_running or _leaving:
		return
	_larva_running = true
	_player.input_enabled = false
	NightmareRunState.set_flag(&"larva_grabbed")
	await _await_sequence(larva_sequence)
	_site.kill_larva()
	var message := messages.get_message(&"larva_slain") if messages else null
	if message:
		_ui.spell_message.show_message(message)
	else:
		_ui.spell_message.show_text("Ты убил дремлющую тварь — личинку Горного Короля.", 3.4)
	await _pause(1.0)
	_site.show_four_larvae()
	await _pause(0.55)
	await _await_sequence(key_throw_sequence)
	_site.show_key()
	_player.input_enabled = true


func _handle_key_collected() -> void:
	if _key_running or _leaving:
		return
	_key_running = true
	_player.input_enabled = false
	_site.release_chains()
	_player.clear_chain_restraint()
	NightmareRunState.set_flag(&"chain_restrained", false)
	await _await_sequence(unlock_sequence)
	await _await_sequence(complete_sequence)
	_site.finish_episode()
	_ui.show_hint("")
	NightmareRunState.set_flag(&"camp_episode_completed")
	_begin_wagon_plan()


func _begin_wagon_plan() -> void:
	if _leaving:
		return
	_site.begin_wagon_phase()
	_player.input_enabled = true
	await _await_sequence(wagon_plan_sequence)
	_site.begin_wagon_phase()
	_ui.show_hint("Повозка у обрыва. Выбейте клинья — E.")


func _handle_wagon_push() -> void:
	if _wagon_running or _leaving:
		return
	_wagon_running = true
	_player.input_enabled = false
	_player.forced_velocity = Vector3.ZERO
	_ui.show_hint("")
	NightmareRunState.set_flag(&"wagon_plan_started")
	_stage_wagon_camera()
	_site.stage_tyrant_for_wagon()
	await _await_sequence(wagon_fall_sequence)
	await _site.animate_wagon_fall(fast_mode)
	_flash_screen(Color(0.12, 0.12, 0.14, 0.7), 0.6)
	await _pause(1.0)
	_site.show_aftermath()
	_restore_player_camera()
	_player.input_enabled = true
	await _await_sequence(aftermath_sequence)
	_site.begin_aftermath_search()
	_ui.show_hint("Соберите три фляги у мёртвых солдат. На тёмном краю кто-то стонет.")


func _handle_veteran_found() -> void:
	if _veteran_running or _leaving:
		return
	_veteran_running = true
	_player.input_enabled = false
	_player.forced_velocity = Vector3.ZERO
	await _await_sequence(veteran_approach_sequence)
	_player.input_enabled = true
	_veteran_running = false


func _handle_veteran_execution() -> void:
	if _veteran_running or _leaving:
		return
	_veteran_running = true
	_player.input_enabled = false
	_player.forced_velocity = Vector3.ZERO
	_ui.show_hint("")
	await _await_sequence(veteran_kill_sequence)
	_site.execute_veteran()
	await _show_site_messages([&"dormant_human_slain", &"memory_received", &"silver_bell_received"])
	await _await_sequence(veteran_loot_sequence)
	_player.input_enabled = true
	_veteran_running = false
	_ui.show_hint("Три фляги, колокольчик, накидка и сапоги. Пора к огню.")


func _handle_night() -> void:
	if _night_running or _leaving:
		return
	_night_running = true
	_player.input_enabled = false
	_player.forced_velocity = Vector3.ZERO
	_ui.show_hint("")
	var seat: Node3D = _site.get_spawn(&"FireSeat")
	if seat:
		_player.global_position = seat.global_position + Vector3(0.0, 0.05, 0.0)
		_player.velocity = Vector3.ZERO
	_player.camera_rig.yaw = 0.0
	_site.place_party_at_fire()
	await _tween_dusk(Color(0.015, 0.02, 0.05, 0.58), 1.2)
	# Симптомы появляются только после отравления общих фляг; ночь без него
	# не начинается (см. CaravanSite.night_block_reason).
	if NightmareRunState.has_flag(&"flasks_poisoned"):
		await _await_sequence(NIGHT_POISON_SEQUENCE)
	await _await_sequence(night_sequence)
	await _pause(1.0)
	_site.begin_dawn()
	await _tween_dusk(Color(0.95, 0.62, 0.42, 0.12), 1.4)
	await _await_sequence(dawn_sequence)
	_player.input_enabled = true
	_night_running = false
	_ui.show_hint("Рассвет. Пора уходить вверх по дороге.")


func _handle_dawn() -> void:
	if _leaving:
		return
	_leaving = true
	_player.input_enabled = false
	_player.forced_velocity = Vector3.ZERO
	_ui.show_hint("")
	transition_started.emit()
	if not transition_enabled:
		return
	await _fade.fade_to(1.0, 1.2)
	LevelPortal.set_pending_spawn(NEXT_SCENE, NEXT_SPAWN)
	get_tree().change_scene_to_file(NEXT_SCENE)


func _tween_dusk(color: Color, duration: float) -> void:
	if not is_instance_valid(_dusk):
		return
	if fast_mode or duration <= 0.0:
		_dusk.color = color
		return
	var tween := create_tween()
	tween.tween_property(_dusk, "color", color, duration)
	await tween.finished


## Показывает канонические сообщения по одному. В тестах длительность
## обнуляется, чтобы сюжетный шаг не ждал анимацию панели.
func _show_site_messages(ids: Array[StringName]) -> void:
	for id in ids:
		var message := messages.get_message(id) if messages else null
		if message == null:
			continue
		if fast_mode:
			var instant := message.duplicate() as SpellMessage
			instant.duration = 0.0
			_ui.spell_message.show_message(instant)
		else:
			_ui.spell_message.show_message(message)
			await _ui.spell_message.queue_finished


## Камера на время падения повозки смотрит на западный край площадки.
## Это отдельная кинематографическая камера: от третьего лица обрыв и
## четырёхметровый Тиран не помещаются в кадр одновременно.
func _stage_wagon_camera() -> void:
	_saved_camera_yaw = _player.camera_rig.yaw
	_saved_camera_pitch = _player.camera_rig.pitch
	_saved_camera_look = _player.camera_rig.look_enabled
	_player.camera_rig.look_enabled = false
	_wagon_camera.global_position = Vector3(2.8, 3.2, -0.4)
	_wagon_camera.look_at(Vector3(-6.0, 0.0, -2.6), Vector3.UP)
	_wagon_camera.make_current()


## Сорвавшийся с края площадки Санни возвращается к костру. Стены по краю нет,
## поэтому без этого падение без возврата блокирует кампанию.
func _physics_process(_delta: float) -> void:
	if _leaving or _player.global_position.y > FALL_RESET_Y:
		return
	var seat: Node3D = _site.get_spawn(&"FireSeat")
	if seat == null:
		return
	_player.global_position = seat.global_position + Vector3(0.0, 0.05, 0.0)
	_player.velocity = Vector3.ZERO


func _pause(seconds: float) -> void:
	if fast_mode or seconds <= 0.0:
		return
	await get_tree().create_timer(seconds).timeout


func _flash_screen(flash_color: Color, duration: float) -> void:
	_flash.color = flash_color
	if fast_mode or duration <= 0.0:
		_flash.color.a = 0.0
		return
	var tween := create_tween()
	tween.tween_property(_flash, "color:a", 0.0, duration)
