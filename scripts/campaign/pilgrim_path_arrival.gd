extends Node3D
## Оболочка S07–S12: подъём, альков, смерть Шифти, Учёный, пещера,
## ранение и Silver Bell.
##
## Локация pilgrim_path хранит флаги и точки взаимодействия. Эта сцена
## ставит диалоги, затемнение, вспышки и переход к святилищу. Смерть
## Тирана здесь не подтверждается.

signal transition_started

const SCENE_PATH := "res://scenes/campaign/pilgrim_path_arrival.tscn"
const NEXT_SCENE := "res://scenes/campaign/sanctuary_arrival.tscn"
const DEFAULT_SPAWN := &"Start"
const NEXT_SPAWN := &"SanctuaryEntrance"
## Строка «Он падает назад...» в pilgrim_shifty.tres: с этого кадра
## живой Шифти скрывается, а на камне остаётся кровь.
const SHIFTY_FALL_LINE_INDEX := 4
## Индексы реплик pilgrim_bell.tres: 1 — «Герой оборачивается»,
## 3 — «Тиран уже рядом», 8 — рана и вид на храм после захвата.
const BELL_TURN_LINE_INDEX := 1
const BELL_CAPTURE_LINE_INDEX := 3
const BELL_CAPTURE_END_LINE_INDEX := 8
const ROAD_GAP_SEQUENCE := preload("res://resources/dialogue/pilgrim/pilgrim_road_gap.tres")
const SWORD_SEQUENCE := preload("res://resources/dialogue/pilgrim/pilgrim_sword.tres")
const ALCOVE_SEQUENCE := preload("res://resources/dialogue/pilgrim/pilgrim_alcove.tres")
const SHIFTY_SEQUENCE := preload("res://resources/dialogue/pilgrim/pilgrim_shifty.tres")
const SCHOLAR_SEQUENCE := preload("res://resources/dialogue/pilgrim/pilgrim_scholar.tres")
const CAVE_SEQUENCE := preload("res://resources/dialogue/pilgrim/pilgrim_cave.tres")
const CAVE_FLASHBACK_SEQUENCE := preload("res://resources/dialogue/pilgrim/pilgrim_cave_flashback.tres")
const HERO_SEQUENCE := preload("res://resources/dialogue/pilgrim/pilgrim_hero.tres")
const BELL_SEQUENCE := preload("res://resources/dialogue/pilgrim/pilgrim_bell.tres")
## E6.2 (03_ascent_and_climax_canon.md): «Found you» при виде храма, до подхода к нему.
const FOUND_YOU_SEQUENCE := preload("res://resources/dialogue/pilgrim/pilgrim_found_you.tres")
const TEMPLE_SEQUENCE := preload("res://resources/dialogue/pilgrim/pilgrim_temple.tres")

@export var fade_in := true
@export var transition_enabled := true
@export var fast_mode := false
@export var debug_direct_scene := false
@export var road_gap_sequence: DialogueSequence
@export var sword_sequence: DialogueSequence
@export var alcove_sequence: DialogueSequence
@export var shifty_sequence: DialogueSequence
@export var scholar_sequence: DialogueSequence
@export var cave_sequence: DialogueSequence
@export var hero_sequence: DialogueSequence
@export var bell_sequence: DialogueSequence
@export var found_you_sequence: DialogueSequence
@export var temple_sequence: DialogueSequence

@onready var _path: Node3D = $PilgrimPath
@onready var _player: SunnyController = $Sunny
@onready var _ui: PrologueUI = $UI
@onready var _dialogue: DialogueRunner = $DialogueRunner
@onready var _fade: FadeLayer = $Transition/Fade
@onready var _flash: ColorRect = $Transition/Flash
@onready var _dusk: ColorRect = $NightTint/Tint

var _sequence_queue: Array[DialogueSequence] = []
var _sequence_busy := false
var _cutscene_running := false
var _leaving := false
var beat_director: BeatDirector


func _ready() -> void:
	_ensure_beat_director()
	if road_gap_sequence == null:

		road_gap_sequence = ROAD_GAP_SEQUENCE
	if sword_sequence == null:
		sword_sequence = SWORD_SEQUENCE
	if alcove_sequence == null:
		alcove_sequence = ALCOVE_SEQUENCE
	if shifty_sequence == null:
		shifty_sequence = SHIFTY_SEQUENCE
	if scholar_sequence == null:
		scholar_sequence = SCHOLAR_SEQUENCE
	if cave_sequence == null:
		cave_sequence = CAVE_SEQUENCE
	if hero_sequence == null:
		hero_sequence = HERO_SEQUENCE
	if bell_sequence == null:
		bell_sequence = BELL_SEQUENCE
	if found_you_sequence == null:
		found_you_sequence = FOUND_YOU_SEQUENCE
	if temple_sequence == null:
		temple_sequence = TEMPLE_SEQUENCE

	_dialogue.subtitles = _ui.subtitles
	_dialogue.fast_mode = fast_mode
	_play_music(&"pilgrim", 3.0)
	_set_reverb_profile(&"outdoor")
	_path.hint_requested.connect(_ui.show_hint)
	_path.road_gap_seen.connect(_handle_road_gap)
	_path.sword_discarded.connect(_handle_sword_discarded)
	_path.rest_requested.connect(_handle_rest)
	_path.scholar_requested.connect(_handle_scholar)
	_path.cave_requested.connect(_handle_cave)
	_path.cave_escape_requested.connect(_handle_cave_escape)
	_path.stealth_completed.connect(_handle_stealth_completed)
	_path.stealth_caught.connect(_handle_stealth_caught)
	_path.hero_requested.connect(_handle_hero)
	_path.bell_rung.connect(_handle_bell)
	_path.temple_reached.connect(_handle_temple)

	var requested := LevelPortal.take_pending_spawn(SCENE_PATH)
	var spawn := LevelPortal.resolve_spawn(_path, requested, DEFAULT_SPAWN)
	if spawn:
		_player.global_position = spawn.global_position
		_player.velocity = Vector3.ZERO
		_player.camera_rig.yaw = spawn.global_rotation.y
	else:
		push_error("PilgrimPathArrival: нет стартовой точки Spawns/%s" % requested)
	_player.allow_sprint = false
	# Прыжок в Первом Кошмаре не нужен: с ним Санни выходит за границы тропы на скалы.
	_player.allow_jump = false
	_player.camera_rig.pitch = deg_to_rad(-18.0)
	_ui.show_hint("Дорога уходит вверх. Впереди — провал.")
	if NightmareRunState.has_flag(&"wound_taken") and _player.has_method(&"set_wounded"):
		_player.set_wounded(true)
	# Возврат на CP-N20: если Санни уже ранен в пещере, угроза должна
	# восстановиться вместе со сценой, иначе «выжить» исчезает после reload.
	if (NightmareRunState.has_flag(&"cave_entered")
			and NightmareRunState.has_flag(&"wound_taken")
			and not NightmareRunState.has_flag(&"cave_escaped")):
		_path.hero.visible = false
		_player.combat_enabled = true
		_player.allow_sprint = true
		_path.begin_cave_survival(_player)
	# Дочерняя локация эмитит стартовую подсказку до подключения сигналов,
	# поэтому оболочка задаёт её сама.
	beat_director.transition_to_beat(&"N14")
	_flash.color = Color(1, 1, 1, 0)
	# PrologueUI приносит собственный чёрный Fade; в этой оболочке затемнение
	# ведёт Transition/Fade, иначе экран остаётся чёрным.
	_ui.fade.color.a = 0.0
	_dusk.color = Color(0.015, 0.02, 0.05, 0.0)
	if fade_in:
		_fade.color.a = 1.0
		await _fade.fade_to(0.0, 1.2)
	else:
		_fade.color.a = 0.0
	# Возврат на CP-N21a после смерти Тирана: сцена могла быть перезагружена
	# уже после выхода из пещеры, поэтому стелс возобновляется здесь.
	if (NightmareRunState.has_flag(&"cave_escaped")
			and not NightmareRunState.has_flag(&"stealth_completed")
			and not NightmareRunState.has_flag(&"hero_confrontation_seen")):
		var stealth_start: Node3D = _path.get_spawn(&"StealthStart")
		if stealth_start != null:
			_player.global_position = stealth_start.global_position
			_player.velocity = Vector3.ZERO
		_player.allow_sprint = true
		beat_director.activate_checkpoint(&"CP-N21a")
		_path.begin_stealth(_player)
		beat_director.transition_to_beat(&"N21")


func has_started_transition() -> bool:
	return _leaving


func _play_music(cue_id: StringName, fade: float) -> void:
	var director := get_node_or_null(^"/root/AudioDirector")
	if director != null and director.has_method(&"play_music"):
		director.call(&"play_music", cue_id, fade)


func _set_music_intensity(value: float) -> void:
	var director := get_node_or_null(^"/root/AudioDirector")
	if director != null and director.has_method(&"set_music_intensity"):
		director.call(&"set_music_intensity", value)


func _set_reverb_profile(profile: StringName) -> void:
	var director := get_node_or_null(^"/root/AudioDirector")
	if director != null and director.has_method(&"set_reverb_profile"):
		director.call(&"set_reverb_profile", profile)


func _ensure_beat_director() -> void:
	if beat_director != null:
		return
	beat_director = get_node_or_null("BeatDirector") as BeatDirector
	if beat_director == null:
		beat_director = BeatDirector.new()
		beat_director.name = "BeatDirector"
		add_child(beat_director)
	beat_director.bind_player(_player)
	if _path.has_method(&"apply_guide_beat"):
		var callable := Callable(_path, &"apply_guide_beat")
		if not beat_director.beat_started.is_connected(callable):
			beat_director.beat_started.connect(callable)
	if beat_director.current_beat != null and _path.has_method(&"apply_guide_beat"):
		_path.call(&"apply_guide_beat", beat_director.current_beat)


func _handle_road_gap() -> void:
	if _cutscene_running or _leaving:
		return
	_cutscene_running = true
	_ensure_beat_director()
	_player.input_enabled = false
	_player.forced_velocity = Vector3.ZERO
	await _await_sequence(road_gap_sequence)
	beat_director.transition_to_beat(&"N15")
	_player.input_enabled = true
	_cutscene_running = false


func _handle_sword_discarded() -> void:
	if _cutscene_running or _leaving:
		return
	_cutscene_running = true
	_ensure_beat_director()
	beat_director.activate_checkpoint(&"CP-N15c")
	_player.input_enabled = false
	await _await_sequence(sword_sequence)
	# Меч оставлен на камне: дальнейший бой на тропе идёт без оружия.
	_player.set_unarmed(true)
	_player.input_enabled = true
	_cutscene_running = false


func _handle_rest() -> void:
	if _cutscene_running or _leaving:
		return
	_cutscene_running = true
	_ensure_beat_director()
	beat_director.transition_to_beat(&"N16")
	_player.input_enabled = false
	_player.forced_velocity = Vector3.ZERO
	var seat: Node3D = _path.get_spawn(&"AlcoveSeat")
	if seat:
		_player.global_position = seat.global_position + Vector3(0, 0.05, 0)
	_player.camera_rig.yaw = -0.18
	_player.camera_rig.pitch = deg_to_rad(-18.0)
	_path.place_party_at_alcove()
	await _tween_dusk(Color(0.015, 0.02, 0.05, 0.62), 1.0)
	await _await_sequence(alcove_sequence)
	_path.show_tyrant_sighting()
	await _pause(2.2)
	_path.tyrant_sighting.visible = false
	beat_director.transition_to_beat(&"N17")
	_dialogue.line_started.connect(_on_shifty_dialogue_line)
	await _await_sequence(shifty_sequence)
	_dialogue.line_started.disconnect(_on_shifty_dialogue_line)
	# Страховка для нестандартной/укороченной последовательности.
	_path.kill_shifty()
	beat_director.transition_to_beat(&"N18")
	await _begin_shifty_larva()
	_path.begin_dawn()
	await _tween_dusk(Color(0.92, 0.6, 0.4, 0.12), 1.2)
	_player.input_enabled = true
	_cutscene_running = false



func _on_shifty_dialogue_line(_line: DialogueLine, index: int, _count: int) -> void:
	if index == SHIFTY_FALL_LINE_INDEX:
		_path.kill_shifty()


## N18: короткий бой с личинкой, поднявшейся из тела Шифти. Без флага
## shifty_larva_killed N19 не открывается; это отдельное деяние в оценке.
func _begin_shifty_larva() -> void:
	# В fast_mode тестовый прогон не должен ждать реальный бой: фиксируем
	# флаг и идём дальше. Живой бой проверяется отдельной сценой/тестом.
	if fast_mode:
		NightmareRunState.set_flag(&"shifty_larva_killed")
		return
	var larva := _path.call(&"spawn_shifty_larva", _player) as TestEnemy
	if larva == null:
		return
	_player.combat_enabled = true
	_player.input_enabled = true
	_player.allow_sprint = false
	_ui.show_hint("Личинка Шифти. Убей её, пока она не ушла.")
	await larva.health.died
	NightmareRunState.set_flag(&"shifty_larva_killed")
	_player.combat_enabled = false
	_player.allow_sprint = false
	_ui.show_hint("")


func _handle_scholar() -> void:
	if _cutscene_running or _leaving:
		return
	_cutscene_running = true
	_ensure_beat_director()
	beat_director.transition_to_beat(&"N19")
	_player.input_enabled = false
	_player.forced_velocity = Vector3.ZERO
	await _await_sequence(scholar_sequence)
	_path.abandon_scholar()
	_path.hero.global_position = (_path.get_spawn(&"CaveInside") as Node3D).global_position + Vector3(1.2, 0, 1.5)
	_player.input_enabled = true
	_cutscene_running = false
	_ui.show_hint("")


func _handle_cave() -> void:
	if _cutscene_running or _leaving:
		return
	_cutscene_running = true
	_ensure_beat_director()
	beat_director.transition_to_beat(&"N20")
	_player.input_enabled = false
	_player.forced_velocity = Vector3.ZERO
	var inside: Node3D = _path.get_spawn(&"CaveInside")
	if inside:
		_player.global_position = inside.global_position + Vector3(-0.4, 0.05, 1.8)
	_path.hero.global_position = (_path.get_spawn(&"CaveInside") as Node3D).global_position + Vector3(1.2, 0, 0.4)
	var to_hero: Vector3 = _path.hero.global_position - _player.global_position
	_player.camera_rig.yaw = atan2(-to_hero.x, -to_hero.z)
	await _tween_dusk(Color(0.002, 0.003, 0.008, 0.72), 1.0)
	await _await_sequence(cave_sequence)
	_path.mark_confession()
	# Короткий флешбэк Bloodbane: три кадра-реплики и красная вспышка,
	# без выбора и без отдельной E-точки. Это постановка внутри N20.
	NightmareRunState.set_flag(&"bloodbane_flashback_seen")
	_flash_screen(Color(0.55, 0.02, 0.02, 0.65), 0.55)
	await _await_sequence(CAVE_FLASHBACK_SEQUENCE)
	await _pause(0.25)
	_path.wound_sunny()
	if _player.has_method(&"set_wounded"):
		_player.set_wounded(true)
	# Герой уходит к карнизу; в пещере остаются хищники, привлечённые кровью.
	_path.hero.visible = false
	_player.combat_enabled = true
	_player.allow_sprint = true
	_path.begin_cave_survival(_player)
	await _tween_dusk(Color(0.03, 0.025, 0.04, 0.38), 0.9)
	_player.input_enabled = true
	_cutscene_running = false
	_ui.show_hint("Выживи. Выбирайся к выходу.")


func _handle_cave_escape() -> void:
	_ensure_beat_director()
	beat_director.transition_to_beat(&"N21")
	beat_director.activate_checkpoint(&"CP-N21a")
	_path.hero.visible = true
	_path.hero.global_position = (_path.get_spawn(&"HeroStand") as Node3D).global_position
	_path.hero.rotation.y = PI
	var stealth_start: Node3D = _path.get_spawn(&"StealthStart")
	if stealth_start != null:
		_player.global_position = stealth_start.global_position
		_player.velocity = Vector3.ZERO
		_player.camera_rig.yaw = 0.0
	_player.input_enabled = true
	_player.forced_velocity = Vector3.ZERO
	# Бег разрешён как риск: он слышен Тирану на большем радиусе.
	_player.allow_sprint = true
	_cutscene_running = false
	_path.begin_stealth(_player)
	_ui.show_hint("")


func _handle_stealth_completed() -> void:
	_ui.show_hint("")


func _handle_stealth_caught() -> void:
	if _leaving:
		return
	# Тиран убивает; FallRecovery возвращает на CP-N21a. Сцена стелса
	# сбрасывается сразу, чтобы повторный заход начинался с чистой угрозой.
	if _player.health != null:
		_player.health.take_damage(_player.health.max_health)
	var recovery := _player.get_node_or_null("FallRecovery") as FallRecovery
	if recovery != null:
		recovery.recover()
	_path.reset_stealth()
	_path.begin_stealth(_player)
	_ui.show_hint("")


func _handle_hero() -> void:
	if _cutscene_running or _leaving:
		return
	_cutscene_running = true
	_ensure_beat_director()
	beat_director.activate_checkpoint(&"CP-N21b")
	_player.input_enabled = false
	_player.forced_velocity = Vector3.ZERO
	var stand: Node3D = _path.get_spawn(&"HeroStand")
	if stand:
		_player.global_position = stand.global_position + Vector3(0, 0.05, 2.2)
	_player.camera_rig.yaw = 0.0
	await _await_sequence(hero_sequence)
	beat_director.transition_to_beat(&"N22")
	_player.input_enabled = true
	_cutscene_running = false
	_ui.show_hint("")


func _handle_bell() -> void:
	if _cutscene_running or _leaving:
		return
	_cutscene_running = true
	_ensure_beat_director()
	beat_director.transition_to_beat(&"N22")
	_player.input_enabled = false
	_player.forced_velocity = Vector3.ZERO
	_ui.show_hint("")
	_set_music_intensity(1.0)
	_dialogue.line_started.connect(_on_bell_dialogue_line)
	await _await_sequence(bell_sequence)
	_dialogue.line_started.disconnect(_on_bell_dialogue_line)
	# Страховка для пустой/укороченной последовательности: после диалога
	# сцена не должна остаться на полпути между захватом и храмом.
	_path.complete_hero_capture()
	beat_director.transition_to_beat(&"N23")
	# Храм виден: «Found you» один раз, до подхода к храму. Повтор звонка сюда не попадает
	# (bell_rung эмитится только при первом звонке, см. PilgrimPath._ring_bell).
	await _await_sequence(found_you_sequence)
	_player.input_enabled = true
	_cutscene_running = false
	_ui.show_hint("")


func _on_bell_dialogue_line(_line: DialogueLine, index: int, _count: int) -> void:
	match index:
		BELL_TURN_LINE_INDEX:
			_path.turn_hero_toward_bell()
		BELL_CAPTURE_LINE_INDEX:
			_path.begin_hero_capture()
		BELL_CAPTURE_END_LINE_INDEX:
			_path.complete_hero_capture()
			_ensure_beat_director()
			beat_director.transition_to_beat(&"N23")


func _handle_temple() -> void:
	if _leaving:
		return
	_leaving = true
	if beat_director != null and beat_director.current_beat != null:
		beat_director.beat_completed.emit(beat_director.current_beat)
	_player.input_enabled = false

	_player.forced_velocity = Vector3.ZERO
	_ui.show_hint("")
	_set_reverb_profile(&"sanctuary")
	NightmareRunState.set_flag(&"pilgrim_path_completed")
	transition_started.emit()
	if not transition_enabled:
		return
	await _await_sequence(temple_sequence)
	await _fade.fade_to(1.0, 1.4)
	LevelPortal.set_pending_spawn(NEXT_SCENE, NEXT_SPAWN)
	get_tree().change_scene_to_file(NEXT_SCENE)


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


func _await_sequence(sequence: DialogueSequence) -> void:
	_queue_sequence(sequence)
	while _sequence_busy or not _sequence_queue.is_empty():
		await get_tree().process_frame


func _tween_dusk(color: Color, duration: float) -> void:
	if fast_mode or duration <= 0.0:
		_dusk.color = color
		return
	var tween := create_tween()
	tween.tween_property(_dusk, "color", color, duration)
	await tween.finished


func _flash_screen(color: Color, duration: float) -> void:
	if fast_mode:
		return
	_flash.color = color
	var tween := create_tween()
	tween.tween_property(_flash, "color", Color(color.r, color.g, color.b, 0.0), duration)
	await tween.finished


func _pause(seconds: float) -> void:
	if fast_mode or seconds <= 0.0:
		return
	await get_tree().create_timer(seconds).timeout
