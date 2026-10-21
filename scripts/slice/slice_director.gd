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
	&"park": "res://scenes/slice/locations/park_street.tscn",
	&"lobby": "res://scenes/slice/locations/station_lobby.tscn",
	&"containment": "res://scenes/slice/locations/containment_room.tscn",
	&"void": "res://scenes/slice/locations/spell_void.tscn",
	&"mountain": "res://scenes/slice/locations/mountain_vision.tscn",
	&"caravan": "res://scenes/slice/locations/caravan_road.tscn",
}
const DIALOGUE_DIR := "res://resources/dialogue/prologue/"
## Приветствие Заклинания (гл. 1 и 2), пересказ.
const SPELL_GREETING := "Аспирант! Добро пожаловать в Заклинание Кошмара. Приготовься к Первому испытанию…"

@export var autostart := true
## Мгновенные переходы и постановки (для тестов); диалоги с «далее» всё равно ждут нажатия.
@export var fast_mode := false
@export var status_sheet: StatusSheet

var beat := Beat.NONE
var mode := Mode.LOCKED
var location: SliceLocation
var awaiting := &""

@onready var slot: Node3D = $LocationSlot
@onready var player: SunnyController = $Sunny
@onready var actor: CinematicActor = $Sunny/CinematicActor
@onready var interactor: Interactor = $Sunny/Interactor
@onready var runner: DialogueRunner = $DialogueRunner
@onready var ui: PrologueUI = $UI
@onready var perf_probe: PerfProbe = $PerfProbe


func _ready() -> void:
	runner.subtitles = ui.subtitles
	runner.line_started.connect(_on_line_started)
	interactor.focus_changed.connect(ui.prompt.show_for)
	if autostart:
		start()


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
	set_mode(Mode.LOOK)
	await _interaction(&"coffee", "Допить")
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
	_load(&"containment", &"Chair")
	set_mode(Mode.LOCKED)
	actor.begin()
	actor.play(&"restrained_idle", 0.0)
	ui.drowsiness.intensity = 0.25
	await _fade(0.0, 1.0)
	await _cutscene(&"restrain")

	_set_beat(Beat.B11_POLICEMAN)
	await _cutscene(&"policeman_enters")
	use_player_camera()

	# Сонливость растёт с каждой репликой брифинга (_on_line_started).
	_set_beat(Beat.B12_BRIEFING)
	set_mode(Mode.LOOK)
	await say(&"briefing")

	_set_beat(Beat.B13_DARKNESS)
	set_mode(Mode.LOCKED)
	await _fade(1.0, 1.5)
	_load(&"void", &"Center")
	player.visual.visible = false
	ui.drowsiness.intensity = 0.0
	await _spell()

	_set_beat(Beat.B14_VISION)
	_load(&"mountain", &"Viewpoint")
	location.use_shot(&"Orbit")
	await _fade(0.0, 1.5)
	await _cutscene(&"vision")
	await _fade(1.0, 1.0)

	# Санни осознаёт себя уже идущим в цепи — после повторного приветствия Заклинания.
	_set_beat(Beat.B15_CARAVAN)
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

	# Экран рун — конец сюжетного диапазона среза.
	_set_beat(Beat.B16_RUNES)
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
	beat_changed.emit(beat)


func _load(key: StringName, spawn: StringName) -> void:
	if location:
		slot.remove_child(location)
		location.queue_free()
	location = (load(LOCATIONS[key]) as PackedScene).instantiate() as SliceLocation
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


func _on_line_started(_line: DialogueLine, index: int, count: int) -> void:
	if beat == Beat.B12_BRIEFING:
		ui.drowsiness.intensity = lerpf(0.25, 0.9, float(index) / maxf(1.0, count - 1.0))


func _unhandled_input(event: InputEvent) -> void:
	if awaiting == &"open_status" and event.is_action_pressed(&"open_status"):
		get_viewport().set_input_as_handled()
		notify(&"open_status")
