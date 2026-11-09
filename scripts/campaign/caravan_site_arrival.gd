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
const BLOODBANE_SEQUENCE := preload("res://resources/dialogue/caravan/camp_bloodbane.tres")
const SECOND_LARVA_SEQUENCE := preload("res://resources/dialogue/caravan/camp_second_larva.tres")
const VETERAN_APPROACH := preload("res://resources/dialogue/caravan/camp_veteran.tres")
const VETERAN_KILL := preload("res://resources/dialogue/caravan/camp_veteran_kill.tres")
const VETERAN_LOOT := preload("res://resources/dialogue/caravan/camp_veteran_loot.tres")
const NIGHT_MONTAGE := preload("res://resources/dialogue/caravan/camp_night_montage.tres")
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
@export var bloodbane_sequence: DialogueSequence
@export var second_larva_sequence: DialogueSequence
@export var veteran_approach_sequence: DialogueSequence
@export var veteran_kill_sequence: DialogueSequence
@export var veteran_loot_sequence: DialogueSequence
@export var night_montage_sequence: DialogueSequence
@export var dawn_sequence: DialogueSequence
@export var messages: SpellMessageCatalog

@onready var _site: CaravanSite = $CaravanSite
@onready var _player: SunnyController = $Sunny
@onready var _ui: PrologueUI = $UI
@onready var _dialogue: DialogueRunner = $DialogueRunner
@onready var _fade: FadeLayer = $Transition/Fade
@onready var _flash: ColorRect = $Transition/Flash
@onready var _wagon_camera: Camera3D = $WagonCamera
@onready var _night_camera: Camera3D = $NightMontageCamera
@onready var _timing: TimingChallenge = $TimingChallenge
@onready var _dusk: ColorRect = $NightTint/Tint

var _sequence_queue: Array[DialogueSequence] = []
var _sequence_busy := false
var _attack_running := false
var _larva_running := false
var _meal_running := false
var _second_larva_running := false
var _key_running := false
var _rockfall_retry := false
var _wagon_running := false
var _veteran_running := false
var _night_running := false
var _leaving := false
var _saved_camera_yaw := 0.0
var _saved_camera_pitch := 0.0
var _saved_camera_look := true
var beat_director: BeatDirector


func _ready() -> void:
	_ensure_beat_director()
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
	if bloodbane_sequence == null:
		bloodbane_sequence = BLOODBANE_SEQUENCE
	if second_larva_sequence == null:
		second_larva_sequence = SECOND_LARVA_SEQUENCE
	if veteran_approach_sequence == null:
		veteran_approach_sequence = VETERAN_APPROACH
	if veteran_kill_sequence == null:
		veteran_kill_sequence = VETERAN_KILL
	if veteran_loot_sequence == null:
		veteran_loot_sequence = VETERAN_LOOT
	if night_montage_sequence == null:
		night_montage_sequence = NIGHT_MONTAGE
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
	_site.meal_taken.connect(_handle_meal_taken)
	_site.second_larva_finished.connect(_handle_second_larva_finished)
	_site.tyrant_attention_caught.connect(_handle_tyrant_attention)
	_site.larva_grabbed.connect(_handle_larva_grabbed)
	_site.key_collected.connect(_handle_key_collected)
	_site.wagon_push_requested.connect(_handle_wagon_push)
	_timing.resolved.connect(_on_throw_resolved)
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


func _ensure_beat_director() -> void:
	if beat_director != null:
		return
	beat_director = get_node_or_null("BeatDirector") as BeatDirector
	if beat_director == null:
		beat_director = BeatDirector.new()
		beat_director.name = "BeatDirector"
		add_child(beat_director)
	beat_director.bind_player(_player)



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
	# Прыжок не зависит от боевого режима и остаётся доступен в лагере.
	_player.allow_jump = true
	_player.combat_enabled = false

	# Служебная подпись сегмента — только при отладочном запуске сцены; в кампании игрок её не видит.
	if not NightmareRunState.has_flag(FLAG_CAMP_REACHED):
		if debug_direct_scene:
			NightmareRunState.set_flag(&"march_intro_seen")
			NightmareRunState.set_flag(FLAG_CAMP_REACHED)
		else:
			push_warning("CaravanSiteArrival: нет camp_reached; сцена запущена напрямую")

	if anchor:
		_player.enable_camp_tether(anchor.global_position, camp_tether_radius)
		NightmareRunState.set_flag(&"chain_restrained")


func _begin_camp() -> void:
	_site.begin_camp()
	_ensure_beat_director()
	beat_director.transition_to_beat(&"N07")
	_ui.show_hint("")
	_queue_sequence(arrival_sequence)
	if NightmareRunState.has_flag(&"camp_rations_taken"):
		# Возврат после чекпоинта/перезагрузки: паёк уже взят, сразу к N08.
		_site.stage_camp_vision_recognition()
		call_deferred(&"_start_attack")


## N07: после пайка — короткая катсцена ягод, без объяснений и без чек-листа.
func _handle_meal_taken() -> void:
	if _meal_running or _leaving:
		return
	_meal_running = true
	await _await_sequence(bloodbane_sequence)
	_site.stage_camp_vision_recognition()
	await _pause(0.35)
	_meal_running = false
	_start_attack()



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
	_ensure_beat_director()
	# Раньше это делал E-интерактив camp_attack. Теперь N07 запускает нападение
	# постановкой, поэтому флаги и фаза ATTACK выставляются здесь же.
	_site.call(&"_begin_attack")
	beat_director.transition_to_beat(&"N08")
	_site.set_interactable_enabled(&"camp_attack", false)
	_player.input_enabled = false
	_player.forced_velocity = Vector3.ZERO
	_ui.show_hint("")
	NightmareRunState.set_flag(&"hero_mountain_gaze")

	if not _rockfall_retry:
		await _await_sequence(hero_gaze_sequence)
		_flash_screen(Color(0.62, 0.72, 1.0, 0.34), 0.5)
		await _pause(0.35)
		await _await_sequence(attack_sequence)
	# N08: три волны с пылью и звуком. Игрок успевает выйти из зоны.
	var rockfall_hit := false
	if fast_mode:
		await _site.drop_rocks(true)
	else:
		_player.input_enabled = true
		for wave in 3:
			_site.begin_rockfall_warning()
			await _pause(_site.get_rockfall_warning_time())
			await _site.drop_rocks(false)
			rockfall_hit = _site.resolve_rockfall()
			if rockfall_hit:
				break
			if wave < 2:
				_site.reset_rocks()
				await _pause(0.15)
		_player.input_enabled = false
	if rockfall_hit:
		# FallRecovery уже вернул Санни на CP-N08; повторяем только опасный
		# отрезок, без повторного брифинга и взгляда на гору.
		_rockfall_retry = true
		await _pause(0.45)
		_attack_running = false
		_player.input_enabled = true
		_start_attack()
		return
	_rockfall_retry = false
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
	_unlock_bestiary_event(&"seen")
	await _pause(0.6)
	_site.begin_larva_phase()
	beat_director.transition_to_beat(&"N09")
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
	_ui.show_hint("")
	NightmareRunState.set_flag(&"camp_episode_completed")
	# D04: вторая личинка — реальный бой после освобождения.
	_player.combat_enabled = true
	_player.input_enabled = true
	_site.spawn_second_larva(_player)


func _handle_second_larva_finished() -> void:
	if _second_larva_running or _leaving:
		return
	_second_larva_running = true
	_key_running = false
	_player.combat_enabled = false
	_player.input_enabled = false
	await _await_sequence(second_larva_sequence)
	_site.finish_episode()
	_second_larva_running = false
	_begin_wagon_plan()


func _begin_wagon_plan() -> void:
	if _leaving:
		return
	_ensure_beat_director()
	beat_director.transition_to_beat(&"N10")
	_site.begin_wagon_phase()
	_player.input_enabled = true
	await _await_sequence(wagon_plan_sequence)
	_site.begin_wagon_phase()
	_ui.show_hint("Повозка у обрыва. Выбейте клинья — E.")


func _handle_wagon_push() -> void:
	if _wagon_running or _leaving:
		return
	_wagon_running = true
	_ensure_beat_director()
	beat_director.activate_checkpoint(&"CP-N10b")
	_player.input_enabled = false
	_player.forced_velocity = Vector3.ZERO
	_site.set_tyrant_attention(false)
	_ui.show_hint("")
	NightmareRunState.set_flag(&"wagon_plan_started")
	_timing.start()


func _on_throw_resolved(success: bool) -> void:
	if not _wagon_running or _leaving:
		return
	if not success:
		_handle_throw_miss()
		return
	_commit_wagon_throw()


func _handle_throw_miss() -> void:
	_timing.reset()
	_wagon_running = false
	_site.reset_wagon_throw()
	_player.input_enabled = true
	var recovery := _player.get_node_or_null(^"FallRecovery") as FallRecovery
	if recovery != null:
		recovery.recover()
	_site.set_tyrant_attention(true)
	_ui.show_hint("Петля сорвалась. Вернитесь к повозке и попробуйте снова.")


func _handle_tyrant_attention() -> void:
	if _wagon_running or _leaving:
		return
	var recovery := _player.get_node_or_null(^"FallRecovery") as FallRecovery
	if recovery != null:
		recovery.recover()
	_ui.show_hint("Тиран заметил движение. Назад, к огню.")
	await _pause(0.6)
	_site.set_tyrant_attention(true)


func _commit_wagon_throw() -> void:
	_stage_wagon_camera()
	_site.stage_tyrant_for_wagon()
	await _await_sequence(wagon_fall_sequence)
	await _site.animate_wagon_fall(fast_mode)
	_flash_screen(Color(0.12, 0.12, 0.14, 0.7), 0.6)
	await _pause(1.0)
	_site.show_aftermath()
	beat_director.transition_to_beat(&"N11")
	_restore_player_camera()
	_player.input_enabled = true
	await _await_sequence(aftermath_sequence)
	_site.begin_aftermath_search()
	beat_director.transition_to_beat(&"N12")
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
	_ensure_beat_director()
	beat_director.transition_to_beat(&"N13")
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
	_stage_night_camera()
	# N13: монтаж Bloodbane за кадром. Флаги ставит постановка события.
	_site.stage_bloodbane_montage()
	await _await_sequence(night_montage_sequence)
	await _pause(0.6)
	_restore_player_camera()
	await _pause(0.4)
	_site.begin_dawn()
	_show_dawn_spots()
	await _tween_dusk(Color(0.95, 0.62, 0.42, 0.12), 1.4)
	await _await_sequence(dawn_sequence)
	_player.input_enabled = true
	_night_running = false
	_ui.show_hint("Рассвет. Пора уходить вверх по дороге.")


func _stage_night_camera() -> void:
	if not is_instance_valid(_night_camera):
		return
	_saved_camera_yaw = _player.camera_rig.yaw
	_saved_camera_pitch = _player.camera_rig.pitch
	_saved_camera_look = _player.camera_rig.look_enabled
	_player.camera_rig.look_enabled = false
	_night_camera.global_position = Vector3(4.6, 3.4, 4.6)
	var look_target := _site.get_fire_position() + Vector3(0.0, 0.9, 0.0)
	_night_camera.look_at(look_target, Vector3.UP)
	_night_camera.make_current()


func _show_dawn_spots() -> void:
	var spots := _player.get_node_or_null(^"BloodSpots")
	if spots != null and spots.has_method(&"set_spots_visible"):
		spots.call(&"set_spots_visible", NightmareRunState.has_flag(&"flasks_poisoned"))


func _handle_dawn() -> void:
	if _leaving:
		return
	_leaving = true
	if beat_director != null and beat_director.current_beat != null:
		beat_director.beat_completed.emit(beat_director.current_beat)
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
	# Держим камеру внутри площадки, выше костра и вне траектории падения.
	# Точка (9, 6, 9) была за скальным выступом: кадр заполняла стена, а не
	# повозка. Эта точка проверена лучом и кадром при падении повозки.
	_wagon_camera.global_position = Vector3(4.2, 4.2, 4.6)
	_wagon_camera.look_at(Vector3(-4.0, 1.4, -2.4), Vector3.UP)
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


func _unlock_bestiary_event(event_id: StringName) -> void:
	var guide := get_node_or_null("/root/CampaignGuide")
	if guide != null and guide.has_method(&"unlock_bestiary_by_event"):
		guide.call(&"unlock_bestiary_by_event", event_id)


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
