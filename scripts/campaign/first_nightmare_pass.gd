extends Node3D
## S01: марш рабов от пролога до стоянки каравана.
##
## Сцена переиспользует caravan_road.tscn и добавляет поверх него то, чего
## не было в коротком проходе: обязательные знакомства каравана, продольный
## поводок цепи и прибытие в лагерь. Камера, ввод и дорога остаются прежними.
## После прибытия загружается отдельная сцена стоянки (S02–S03).

signal transition_started

const NEXT_SCENE := "res://scenes/campaign/caravan_site_arrival.tscn"
const DEFAULT_EXIT_LOCAL_Z := -36.0
## Колонна должна остановиться чуть дальше CampArrival: иначе игрок внутри
## corridor (lead 1.2 м) не сможет дойти до порога z <= -36 и S01 зависнет.
const CONVOY_STOP_Z := -37.4
const FLAG_MARCH_INTRO := &"march_intro_seen"
const FLAG_CAMP_REACHED := &"camp_reached"
const MARCH_THREAT := preload("res://resources/dialogue/caravan/march_threat.tres")
const MARCH_SCHOLAR := preload("res://resources/dialogue/caravan/march_scholar.tres")
const MARCH_WATER := preload("res://resources/dialogue/caravan/march_water.tres")
const MARCH_CAMP := preload("res://resources/dialogue/caravan/march_camp.tres")

@export var autostart := true
@export var transition_enabled := true
@export var debug_direct_scene := true
@export var fast_mode := false
@export var exit_local_z := DEFAULT_EXIT_LOCAL_Z
## Насколько Санни может уйти вперёд/назад относительно темпа цепи, м.
@export var march_lead_limit := 1.2
@export var march_trail_limit := 1.2
## Обязательные реплики S01. Порядок задаётся trigger_local_z.
@export var march_beats: Array[CaravanMarchBeat] = []

@onready var _caravan: SliceLocation = $CaravanRoad
@onready var _player: SunnyController = $Sunny
@onready var _ui: PrologueUI = $UI
@onready var _dialogue: DialogueRunner = $DialogueRunner
@onready var _exit_trigger: Area3D = $CaravanRoad/Road/Triggers/CampArrival
@onready var _note: Label = $PrototypeNote/Root/Note
@onready var _whip_flash: ColorRect = $WhipFlashLayer/WhipFlash

var _started := false
var _leaving := false
var _convoy_local_z := 0.0
var _convoy_speed := 0.0
var _dialogue_queue: Array[DialogueSequence] = []
var _dialogue_busy := false
var _triggered_beats: Dictionary = {}


func _ready() -> void:
	_place_player()
	_convoy_local_z = _player_local_z()
	_convoy_speed = _caravan.march_speed
	_caravan.auto_barks = false
	if march_beats.is_empty():
		march_beats = _default_march_beats()
	_dialogue.fast_mode = fast_mode
	_dialogue.subtitles = _ui.subtitles
	_exit_trigger.body_entered.connect(_on_exit_body_entered)
	_whip_flash.visible = false
	if autostart:
		start()


func start() -> void:
	if _started:
		return
	_started = true
	if not NightmareRunState.has_flag(&"prologue_completed"):
		if debug_direct_scene:
			NightmareRunState.set_flag(&"prologue_completed")
			_note.text = "ОТЛАДОЧНЫЙ ЗАПУСК · пролог не пройден. S01 можно проверить отдельно; в кампании сюда ведёт только финал пролога."
		else:
			push_warning("FirstNightmarePass: нет prologue_completed; сцена запущена напрямую")
	_caravan.set_march_follower(_player)
	_player.allow_sprint = false
	_player.allow_jump = false
	_player.combat_enabled = false
	_player.enable_chain_restraint(_caravan.march_velocity())
	_caravan.start_march()
	_ui.show_hint("Цель: идти вверх по дороге к стоянке каравана. WASD — движение, мышь — обзор.")
	await _ui.fade.fade_to(0.0, 1.0)


func has_started_transition() -> bool:
	return _leaving


func is_march_intro_seen() -> bool:
	return NightmareRunState.has_flag(FLAG_MARCH_INTRO)


func get_convoy_local_z() -> float:
	return _convoy_local_z


func _place_player() -> void:
	var spawn: Node3D = _caravan.get_spawn(&"Chain")
	if spawn == null:
		push_error("FirstNightmarePass: у дороги нет точки Spawns/Chain")
		return
	_player.global_position = spawn.global_position + Vector3(0.0, 0.05, 0.0)
	_player.velocity = Vector3.ZERO
	_player.visual.rotation.y = 0.0
	_player.camera_rig.yaw = 0.0
	_player.camera_rig.set_pitch(_player.camera_rig.pitch)


func _physics_process(delta: float) -> void:
	if _leaving:
		return
	var road: Node3D = _caravan.road
	if not is_instance_valid(road):
		return

	# Цепь задаёт темп, но не отбирает управление полностью: внутри коридора
	# Санни может ускориться или отстать, а за его границами его тянет обратно.
	_convoy_local_z = maxf(_convoy_local_z - _convoy_speed * delta, CONVOY_STOP_Z)
	var local: Vector3 = road.to_local(_player.global_position)
	_trigger_beats(local.z)
	local.z = clampf(
		local.z,
		_convoy_local_z - march_lead_limit,
		_convoy_local_z + march_trail_limit
	)
	_player.global_position = road.to_global(local)
	if local.z <= exit_local_z:
		_begin_transition()


func _player_local_z() -> float:
	var road: Node3D = _caravan.road
	if road == null:
		return 0.0
	return road.to_local(_player.global_position).z


func _default_march_beats() -> Array[CaravanMarchBeat]:
	var result: Array[CaravanMarchBeat] = []
	result.append(_make_beat(-2.5, &"march_threat_seen", MARCH_THREAT))
	result.append(_make_beat(-11.0, &"march_scholar_seen", MARCH_SCHOLAR))
	result.append(_make_beat(-21.0, &"march_water_seen", MARCH_WATER, false, true))
	result.append(_make_beat(-30.0, &"march_camp_seen", MARCH_CAMP, true))
	return result


func _make_beat(
	trigger: float,
	flag: StringName,
	sequence: DialogueSequence,
	completes_intro := false,
	whip := false
) -> CaravanMarchBeat:
	var beat := CaravanMarchBeat.new()
	beat.trigger_local_z = trigger
	beat.flag = flag
	beat.sequence = sequence
	beat.completes_intro = completes_intro
	beat.whip = whip
	return beat


func _trigger_beats(local_z: float) -> void:
	for beat in march_beats:
		if beat == null or beat.sequence == null:
			continue
		var key := _beat_key(beat)
		if _triggered_beats.has(key):
			continue
		if beat.flag != &"" and NightmareRunState.has_flag(beat.flag):
			_triggered_beats[key] = true
			if beat.completes_intro:
				NightmareRunState.set_flag(FLAG_MARCH_INTRO)
			continue
		if local_z > beat.trigger_local_z:
			continue
		_triggered_beats[key] = true
		if beat.flag != &"":
			NightmareRunState.set_flag(beat.flag)
		if beat.completes_intro:
			NightmareRunState.set_flag(FLAG_MARCH_INTRO)
		if beat.whip:
			_flash_whip()
		_queue_sequence(beat.sequence)


func _beat_key(beat: CaravanMarchBeat) -> String:
	if beat.flag != &"":
		return String(beat.flag)
	return "%s:%s" % [beat.trigger_local_z, beat.sequence.resource_path]


func _queue_sequence(sequence: DialogueSequence) -> void:
	if sequence == null:
		return
	_dialogue_queue.append(sequence)
	if not _dialogue_busy:
		_play_next_sequence()


func _play_next_sequence() -> void:
	if _dialogue_busy or _dialogue_queue.is_empty():
		return
	_dialogue_busy = true
	var sequence: DialogueSequence = _dialogue_queue.pop_front()
	await _dialogue.run(sequence)
	_dialogue_busy = false
	if not _dialogue_queue.is_empty():
		_play_next_sequence()


func _flash_whip() -> void:
	_whip_flash.visible = true
	_whip_flash.color.a = 0.62
	var tween := create_tween()
	tween.tween_property(_whip_flash, "color:a", 0.0, 0.35)
	tween.tween_callback(func() -> void: _whip_flash.visible = false)


func _on_exit_body_entered(body: Node3D) -> void:
	if body.is_in_group(&"player"):
		_begin_transition()


func _begin_transition() -> void:
	if _leaving:
		return
	_leaving = true
	transition_started.emit()
	_player.input_enabled = false
	_player.forced_velocity = Vector3.ZERO
	_player.clear_chain_restraint()
	_caravan.stop_march()
	_ui.show_hint("Привал. Цепь натянута, колонна останавливается.")
	_note.visible = false
	NightmareRunState.set_flag(FLAG_MARCH_INTRO)
	NightmareRunState.set_flag(FLAG_CAMP_REACHED)

	if not transition_enabled:
		return

	# Даже если игрок добежал до зоны раньше последней реплики, знакомство
	# заканчивается до смены сцены: лагерь доступен только после S01.
	while _dialogue_busy or not _dialogue_queue.is_empty():
		await get_tree().process_frame
	await _ui.fade.fade_to(1.0, 1.0)
	get_tree().change_scene_to_file(NEXT_SCENE)
