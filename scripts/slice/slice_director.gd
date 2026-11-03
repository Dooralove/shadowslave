class_name SliceDirector
extends Node3D
## Режиссёр вертикального среза «Nightmare Begins» (гл. 1 и начало гл. 2).
## Биты B01–B16 идут строго по порядку; переход — только по событию: взаимодействие,
## триггер, конец диалога или постановки. Сценарий не знает ни моделей, ни клипов:
## персонажем управляет CinematicActor, локацией — интерфейс SliceLocation.

signal beat_changed(beat: Beat)
signal slice_finished
signal _event(id: StringName)

enum Beat {
	NONE,
	B01_OPENING,
	B02_FIRST_SIPS,
	B03_DOZE,
	B04_FINISH_AND_STAND,
	B05_BIN,
	B06_CROSS_STREET,
	B07_ENTER_STATION,
	B08_DESK,
	B09_CODE_BLACK,
	B10_RESTRAINED,
	B11_POLICEMAN,
	B12_BRIEFING,
	B13_DARKNESS,
	B14_VISION,
	B15_CARAVAN,
	B16_RUNES,
	FINISHED,
}

## Режимы управления: свободно; только обзор; ничего; шаг в цепи с обзором.
enum Mode { FREE, LOOK, LOCKED, CHAINED }

const LOCATIONS := {
	&"park": "res://scenes/slice/locations/park/park_street_art.tscn",
	&"lobby": "res://scenes/slice/locations/station_lobby_art.tscn",
	&"containment": "res://scenes/slice/locations/containment_room_art.tscn",
	&"void": "res://scenes/slice/locations/spell_void.tscn",
	&"mountain": "res://scenes/slice/locations/mountain_vision_art.tscn",
	&"caravan": "res://scenes/slice/locations/caravan_road_art.tscn",
}
const DIALOGUE_DIR := "res://resources/dialogue/prologue/"
const RULES_JOURNAL := preload("res://resources/campaign/journal/rules_of_nightmare.tres")
## Приветствие Заклинания (гл. 1 и 2), пересказ.
const SPELL_GREETING := "Аспирант! Добро пожаловать в Заклинание Кошмара. Приготовься к Первому испытанию…"

@export var autostart := true
## Мгновенные переходы и постановки (для тестов); диалоги с «далее» всё равно ждут нажатия.
@export var fast_mode := false
@export var status_sheet: StatusSheet
## Подмена сцены локации по ключу из LOCATIONS (варианты художественных проходов); пусто — штатные сцены.
@export var location_overrides: Dictionary[StringName, String] = {}

var beat := Beat.NONE
var mode := Mode.LOCKED
var location: SliceLocation
var awaiting := &""
var beat_director: BeatDirector

@onready var slot: Node3D = $LocationSlot
@onready var player: SunnyController = $Sunny
@onready var actor: CinematicActor = $Sunny/CinematicActor
@onready var interactor: Interactor = $Sunny/Interactor
@onready var runner: DialogueRunner = $DialogueRunner
@onready var ui: PrologueUI = $UI
@onready var perf_probe: PerfProbe = $PerfProbe


func _ready() -> void:
	_ensure_beat_director()
	runner.subtitles = ui.subtitles
	runner.line_started.connect(_on_line_started)
	interactor.focus_changed.connect(ui.prompt.show_for)
	if autostart:
		start()


func _ensure_beat_director() -> void:
	if beat_director != null:
		return
	beat_director = get_node_or_null("BeatDirector") as BeatDirector
	if beat_director == null:
		beat_director = BeatDirector.new()
		beat_director.name = "BeatDirector"
		add_child(beat_director)
	beat_director.bind_player(player)



func start() -> void:
	runner.fast_mode = fast_mode
	_run()


## Сообщает о событии; засчитывается только то, которого сценарий ждёт сейчас.
func notify(id: StringName) -> void:
	if id != &"" and id == awaiting:
		awaiting = &""
		_event.emit(id)


func say(sequence_name: StringName) -> void:
	var sequence := load(DIALOGUE_DIR + String(sequence_name) + ".tres") as DialogueSequence
	await runner.run(sequence)


func set_mode(new_mode: Mode, march := Vector3.ZERO) -> void:
	mode = new_mode
	player.input_enabled = mode == Mode.FREE
	player.forced_velocity = march if mode == Mode.CHAINED else Vector3.ZERO
	player.camera_rig.look_enabled = mode != Mode.LOCKED
	interactor.enabled = mode == Mode.FREE or mode == Mode.LOOK
	# Сидя, пристёгнутым и в постановках тело не участвует в физике (не падает со скамейки).
	var physics := mode == Mode.FREE or mode == Mode.CHAINED
	player.set_physics_process(physics)
	if not physics:
		player.velocity = Vector3.ZERO


func place_player(spawn: StringName) -> void:
	var marker := location.get_spawn(spawn)
	if marker == null:
		push_error("No spawn '%s' in %s" % [spawn, location.name])
		return
	player.global_position = marker.global_position
	player.velocity = Vector3.ZERO
	var yaw := marker.global_rotation.y
	player.visual.rotation.y = yaw
	player.camera_rig.yaw = yaw
	player.camera_rig.set_pitch(player.camera_rig.pitch)


func use_player_camera() -> void:
	player.camera_rig.camera.make_current()


func _run() -> void:
	ui.fade.color.a = 1.0

	_set_beat(Beat.B01_OPENING)
	_audio_scene(&"park", &"park")
	_load(&"park", &"BenchSit")
	set_mode(Mode.LOOK)
	actor.begin()
	actor.play(&"sit_idle", 0.0)
	ui.drowsiness.intensity = 0.15
	await _fade(0.0, 1.5)

	# Глоток: горько; ещё глоток: лучше бы мяса, зато не усну.
	_set_beat(Beat.B02_FIRST_SIPS)
	await _interaction(&"coffee", "Отпить")
	await say(&"sip_1")
	await _interaction(&"coffee", "Отпить")
	await say(&"sip_2")

	_set_beat(Beat.B03_DOZE)
	set_mode(Mode.LOCKED)
	await _cutscene(&"doze")
	await say(&"doze")

	_set_beat(Beat.B04_FINISH_AND_STAND)
	set_mode(Mode.LOCKED)
	await _cutscene(&"stand_up")
	actor.end()
	await say(&"tall_people")
	set_mode(Mode.FREE)

	_set_beat(Beat.B05_BIN)
	ui.show_hint("Выбросить стаканчик")
	await _interaction(&"bin", "Выбросить стаканчик")
	ui.show_hint("")
	set_mode(Mode.LOCKED)
	actor.begin()
	await _cutscene(&"bin")
	actor.end()
	set_mode(Mode.FREE)

	_set_beat(Beat.B06_CROSS_STREET)
	ui.show_hint("Перейти улицу к полицейскому участку")
	location.set_trigger_enabled(&"station_entrance", true)
	await _gate(&"trigger:station_entrance")
	ui.show_hint("")

	_set_beat(Beat.B07_ENTER_STATION)
	await _interaction(&"station_door", "Войти в участок")
	set_mode(Mode.LOCKED)
	await _fade(1.0, 0.8)

	_set_beat(Beat.B08_DESK)
	_audio_scene(&"lobby", &"lobby")
	_load(&"lobby", &"Counter")
	set_mode(Mode.LOOK)
	await _fade(0.0, 0.8)
	await say(&"desk")

	_set_beat(Beat.B09_CODE_BLACK)
	set_mode(Mode.LOCKED)
	await _cutscene(&"code_black")
	await _fade(1.0, 0.8)

	# «Несколько минут спустя»: путь в подвал в тексте не описан, поэтому сразу пристёгивание.
	_set_beat(Beat.B10_RESTRAINED)
	_audio_scene(&"cell", &"cell")
	_load(&"containment", &"Chair")
	set_mode(Mode.LOCKED)
	actor.begin()
	actor.play(&"restrained_idle", 0.0)
	ui.drowsiness.intensity = 0.25
	# Переход оформлен подписью: путь в подвал канон не описывает (гл. 1, «несколько минут спустя»).
	ui.show_hint("Несколько минут спустя. Изолятор в подвале участка.")
	await _fade(0.0, 1.0)
	await _cutscene(&"restrain")
	ui.show_hint("")

	_set_beat(Beat.B11_POLICEMAN)
	await _cutscene(&"policeman_enters")
	use_player_camera()

	# Сонливость растёт с каждой репликой брифинга (_on_line_started).
	_set_beat(Beat.B12_BRIEFING)
	set_mode(Mode.LOOK)
	await say(&"briefing")
	var guide := get_node_or_null("/root/CampaignGuide")
	if guide != null and guide.has_method(&"add_journal_entry"):
		guide.call(&"add_journal_entry", RULES_JOURNAL)
	NightmareRunState.set_flag(&"journal_rules_known")

	_set_beat(Beat.B13_DARKNESS)
	set_mode(Mode.LOCKED)
	_audio_scene(&"void", &"void")
	await _fade(1.0, 1.5)
	_load(&"void", &"Center")
	player.visual.visible = false
	ui.drowsiness.intensity = 0.0
	await _fade(0.0, 1.2)
	await _cutscene(&"spell")
	await _spell()

	_set_beat(Beat.B14_VISION)
	_audio_scene(&"mountain", &"mountain")
	_load(&"mountain", &"Viewpoint")
	location.use_shot(&"Orbit")
	await _fade(0.0, 1.5)
	await _cutscene(&"vision")
	await _fade(1.0, 1.0)

	# Санни осознаёт себя уже идущим в цепи — после повторного приветствия Заклинания.
	_set_beat(Beat.B15_CARAVAN)
	_audio_scene(&"caravan", &"caravan")
	_load(&"caravan", &"Chain")
	player.visual.visible = true
	actor.end()
	await _spell()
	set_mode(Mode.CHAINED, location.march_velocity())
	location.start_march()
	await _fade(0.0, 1.0)
	await say(&"caravan")
	ui.show_hint("Сосредоточиться на мысли о статусе — Tab")
	await _gate(&"open_status")
	ui.show_hint("")

	# Экран рун — конец сюжетного диапазона среза. Mark of Divinity —
	# врождённый атрибут Санни, а не предмет; в срезе он впервые
	# раскрывается именно здесь, на B16. Повторная установка безопасна.
	_set_beat(Beat.B16_RUNES)
	NightmareRunState.set_flag(&"mark_of_divinity")
	await ui.rune_status.present(status_sheet)
	set_mode(Mode.LOCKED)
	location.stop_march()
	await _fade(1.0, 1.5)
	ui.show_end_card()
	_set_beat(Beat.FINISHED)
	slice_finished.emit()


func _set_beat(new_beat: Beat) -> void:
	beat = new_beat
	perf_probe.bucket = StringName(Beat.keys()[beat])
	_sync_v2_beat(new_beat)
	beat_changed.emit(beat)


func _sync_v2_beat(slice_beat: Beat) -> void:
	_ensure_beat_director()
	match slice_beat:
		Beat.B01_OPENING:
			beat_director.start_beat(&"P01", true)
		Beat.B08_DESK:
			beat_director.complete_current_beat(false)
			beat_director.start_beat(&"P02", true)
		Beat.B10_RESTRAINED:
			beat_director.complete_current_beat(false)
			beat_director.start_beat(&"P03", true)
		Beat.B13_DARKNESS:
			beat_director.complete_current_beat(false)
			beat_director.start_beat(&"P04", true)
		Beat.B15_CARAVAN:
			beat_director.complete_current_beat(false)
			beat_director.start_beat(&"N05", true)
		Beat.FINISHED:
			if beat_director.current_beat != null:
				beat_director.beat_completed.emit(beat_director.current_beat)




func _load(key: StringName, spawn: StringName) -> void:
	if location:
		slot.remove_child(location)
		location.queue_free()
	location = (load(location_overrides.get(key, LOCATIONS[key])) as PackedScene).instantiate() as SliceLocation
	slot.add_child(location)
	location.interacted.connect(func(id: StringName) -> void: notify(StringName("interact:" + String(id))))
	location.triggered.connect(func(id: StringName) -> void: notify(StringName("trigger:" + String(id))))
	location.setup(self)
	place_player(spawn)
	use_player_camera()


func _gate(id: StringName) -> void:
	awaiting = id
	await _event


func _interaction(id: StringName, prompt: String) -> void:
	var interactable := location.get_interactable(id)
	interactable.prompt = prompt
	interactable.enabled = true
	await _gate(StringName("interact:" + String(id)))
	interactable.enabled = false
	interactor.refresh()


func _cutscene(id: StringName) -> void:
	# Базовый play_cutscene не корутина, а переопределения в локациях — корутины;
	# анализатор видит только базовый тип, но await на деле ждёт конца постановки.
	@warning_ignore("redundant_await")
	await location.play_cutscene(id, fast_mode)


func _fade(alpha: float, duration: float) -> void:
	await ui.fade.fade_to(alpha, 0.0 if fast_mode else duration)


func _spell() -> void:
	await ui.spell_message.present(SPELL_GREETING, 0.0 if fast_mode else 4.5)


func _audio_scene(zone_id: StringName, music_id: StringName) -> void:
	var director := get_node_or_null(^"/root/AudioDirector")
	if director == null:
		return
	if director.has_method(&"play_music"):
		director.call(&"play_music", music_id, 2.0)
	if director.has_method(&"play_ambience"):
		director.call(&"play_ambience", zone_id, 2.0)
	if director.has_method(&"set_reverb_profile"):
		var profiles := {
			&"park": &"outdoor",
			&"lobby": &"coral_cave",
			&"cell": &"tunnel",
			&"void": &"sanctuary",
			&"mountain": &"storm",
			&"caravan": &"outdoor",
		}
		director.call(&"set_reverb_profile", profiles.get(zone_id, &"outdoor"))


func _on_line_started(_line: DialogueLine, index: int, count: int) -> void:
	if beat == Beat.B12_BRIEFING:
		ui.drowsiness.intensity = lerpf(0.25, 0.9, float(index) / maxf(1.0, count - 1.0))


func _unhandled_input(event: InputEvent) -> void:
	if awaiting == &"open_status" and event.is_action_pressed(&"open_status"):
		get_viewport().set_input_as_handled()
		notify(&"open_status")
