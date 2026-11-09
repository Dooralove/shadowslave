extends Node
## Autoload системы целей и подсказок Первого Кошмара.
##
## Источник цели — BeatData текущего события. BeatDirector сообщает о смене
## события и цели; отсюда строка уходит в PrologueUI и журнал. Здесь же живут
## idle-ступени, мировые мысли Санни и правила их сброса. Тексты и тайминги
## лежат в ресурсах: GuideSettings, BeatData.idle_objectives, GuideThought.

signal objective_changed(text: String, base_text: String, idle_step: int)
signal thought_shown(thought_id: StringName, text: String)
signal journal_changed

const SETTINGS_PATH := "res://resources/campaign/guide/guide_settings.tres"
const THOUGHT_DIR := "res://resources/campaign/thoughts/"
const THOUGHT_BUBBLE_SCENE := "res://scenes/guide/thought_bubble.tscn"
const BESTIARY_DIR := "res://resources/campaign/bestiary/"
## Событие открытия записи, привязанное к уже существующим флагам забега.
## Полный боевой бестиарий сможет вызывать те же события напрямую.
const BESTIARY_FLAG_EVENTS := {
	&"larva_grabbed": &"seen",
	&"shifty_larva_killed": &"defeated",
	&"stealth_completed": &"weakness_known",
}

var settings: GuideSettings
var current_beat: BeatData
var base_objective := ""
var display_objective := ""
## Внешняя цель из другой системы. Цели сцены (campaign/post_nightmare/academy)
## важнее базовой цели QuestSystem: квестовый HUD не должен возвращать игрока
## к уже выполненному шагу, пока сцена ведёт его дальше. Пока задана хотя бы
## одна внешняя цель, она имеет приоритет над целью события.
const EXTERNAL_SOURCE_QUEST := &"quest_system"
const EXTERNAL_PRIORITY_QUEST := 0
const EXTERNAL_PRIORITY_SCENE := 10

var external_objective := ""
var _external_source: StringName = &""
var _external_objectives: Dictionary[StringName, String] = {}
var _external_order: Array[StringName] = []
## Сцена, выставившая цель. При переходе в другую сцену такая цель снимается,
## чтобы HUD не показывал «подойдите к ветерану» уже в святилище.
var _external_scene_paths: Dictionary[StringName, String] = {}
var idle_step := 0
var idle_time := 0.0
var history: Array[Dictionary] = []
var journal_entries: Array[Dictionary] = []

var _director: BeatDirector
var _thoughts: Dictionary = {}
var _bubble: ThoughtBubble
var _bestiary_catalog: Dictionary = {}


func _ready() -> void:
	settings = load(SETTINGS_PATH) as GuideSettings
	if settings == null:
		push_warning("CampaignGuide: не найден %s, взяты значения по умолчанию" % SETTINGS_PATH)
		settings = GuideSettings.new()
	_load_thoughts()
	_load_bestiary_entries()
	var run_state := get_node_or_null("/root/NightmareRunState")
	if run_state != null:
		if run_state.has_signal(&"state_reset"):
			run_state.state_reset.connect(reset_campaign)
		if run_state.has_signal(&"state_restored"):
			run_state.state_restored.connect(_on_state_restored)
		if run_state.has_signal(&"flag_changed"):
			run_state.flag_changed.connect(_on_run_flag_changed)
		if run_state.has_signal(&"bestiary_unlocked"):
			run_state.bestiary_unlocked.connect(_on_bestiary_unlocked)
	_sync_bestiary_from_state()


func bind_director(director: BeatDirector) -> void:
	if director == null or director == _director:
		return
	_director = director
	if not director.beat_started.is_connected(_on_beat_started):
		director.beat_started.connect(_on_beat_started)
	if not director.objective_changed.is_connected(_on_objective_changed):
		director.objective_changed.connect(_on_objective_changed)
	if not director.campaign_completed.is_connected(_on_campaign_completed):
		director.campaign_completed.connect(_on_campaign_completed)
	if director.current_beat != null:
		apply_beat(director.current_beat)


func _on_beat_started(beat: BeatData) -> void:
	apply_beat(beat)


func _on_objective_changed(text: String) -> void:
	if current_beat != null and text == base_objective:
		return
	base_objective = text
	idle_step = 0
	idle_time = 0.0
	_refresh_display()
	_emit_objective()


func _on_campaign_completed() -> void:
	clear_current_objective()


func apply_beat(beat: BeatData) -> void:
	current_beat = beat
	idle_time = 0.0
	idle_step = 0
	if beat == null:
		clear_current_objective()
		return
	_clear_stale_objectives_for_beat(beat)
	base_objective = beat.objective
	_refresh_display()
	if not base_objective.strip_edges().is_empty():
		_record_history(beat)
	_emit_objective()


func has_objective() -> bool:
	return not display_objective.strip_edges().is_empty()


func get_display_objective() -> String:
	return display_objective


func get_base_objective() -> String:
	return base_objective


## Цель другой игровой системы или сцены. Источник указывается, чтобы две
## системы не гасили чужие строки. Цель сцены перекрывает базовую цель
## QuestSystem; пустой текст снимает только цель указанного источника.
func set_external_objective(text: String, source: StringName = &"external") -> void:
	var key := source if source != &"" else &"external"
	var value := text.strip_edges()
	if value.is_empty():
		clear_external_objective(key)
		return
	if String(_external_objectives.get(key, "")) == value and key == _external_source:
		return
	_external_objectives[key] = value
	if key != EXTERNAL_SOURCE_QUEST:
		_external_scene_paths[key] = _current_scene_path()
	_touch_external_source(key)
	_refresh_external_objective()
	idle_step = 0
	idle_time = 0.0
	_refresh_display()
	_emit_objective()


func clear_external_objective(source: StringName = &"") -> void:
	var changed := false
	if source == &"":
		if not _external_objectives.is_empty():
			_external_objectives.clear()
			_external_order.clear()
			_external_scene_paths.clear()
			changed = true
	elif _external_objectives.has(source):
		_external_objectives.erase(source)
		_external_order.erase(source)
		_external_scene_paths.erase(source)
		changed = true
	if not changed:
		return
	_refresh_external_objective()
	_refresh_display()
	_emit_objective()


func has_external_objective() -> bool:
	return not external_objective.strip_edges().is_empty()


## Источник, чья внешняя цель сейчас показана. Нужен ObjectiveLine и тестам,
## чтобы отличить цель сцены от базовой цели QuestSystem.
func get_external_source() -> StringName:
	return _external_source


## True, когда показана цель сцены, а не базовая цель QuestSystem.
func has_scene_objective() -> bool:
	return has_external_objective() and _external_source != EXTERNAL_SOURCE_QUEST


func _touch_external_source(source: StringName) -> void:
	_external_order.erase(source)
	_external_order.append(source)


func _external_priority(source: StringName) -> int:
	if source == EXTERNAL_SOURCE_QUEST:
		return EXTERNAL_PRIORITY_QUEST
	return EXTERNAL_PRIORITY_SCENE


func _refresh_external_objective() -> void:
	var next_source: StringName = &""
	var best_priority := -1
	for source in _external_order:
		var value: String = _external_objectives.get(source, "")
		if value.strip_edges().is_empty():
			continue
		var priority := _external_priority(source)
		# При равном приоритете выигрывает источник, заданный последним.
		if priority >= best_priority:
			best_priority = priority
			next_source = source
	_external_source = next_source
	external_objective = String(_external_objectives.get(next_source, "")) if next_source != &"" else ""


func _current_scene_path() -> String:
	if not is_inside_tree():
		return ""
	var scene := get_tree().current_scene
	return scene.scene_file_path if scene != null else ""


## Цели сцены живут только в своей сцене. QuestSystem-цель переживает
## переходы, поэтому её не трогаем.
func _prune_stale_scene_objectives() -> void:
	if _external_scene_paths.is_empty():
		return
	var current_path := _current_scene_path()
	if current_path.is_empty():
		return
	var changed := false
	for source in _external_scene_paths.keys():
		if source == EXTERNAL_SOURCE_QUEST:
			continue
		var owner_path := String(_external_scene_paths[source])
		if owner_path.is_empty() or owner_path == current_path:
			continue
		_external_objectives.erase(source)
		_external_order.erase(source)
		_external_scene_paths.erase(source)
		changed = true
	if not changed:
		return
	_refresh_external_objective()
	_refresh_display()
	_emit_objective()


## Событие из другой сцены не должно тянуть за собой старую цель сцены даже
## в QA-обвязке, где current_scene остаётся хостом. В обычной игре цель уже
## снята _prune_stale_scene_objectives при смене сцены.
func _clear_stale_objectives_for_beat(beat: BeatData) -> void:
	if beat == null or beat.scene_path.is_empty():
		return
	var changed := false
	for source in _external_scene_paths.keys():
		if source == EXTERNAL_SOURCE_QUEST:
			continue
		var owner_path := String(_external_scene_paths[source])
		if owner_path == beat.scene_path:
			continue
		var text := String(_external_objectives.get(source, "")).strip_edges()
		if text == beat.objective.strip_edges():
			continue
		_external_objectives.erase(source)
		_external_order.erase(source)
		_external_scene_paths.erase(source)
		changed = true
	if changed:
		_refresh_external_objective()


func _refresh_display() -> void:
	if not external_objective.strip_edges().is_empty():
		display_objective = external_objective
		idle_step = 0
		return
	if idle_step <= 0:
		display_objective = base_objective


func get_current_beat_id() -> StringName:
	return current_beat.id if current_beat != null else &""


func get_current_beat_title() -> String:
	return current_beat.title if current_beat != null else ""


func get_history() -> Array[Dictionary]:
	return history.duplicate(true)


## Запись журнала, например «Правила Кошмара» после брифинга P03.
## Загружает BestiaryEntry-ресурсы один раз. Каталог остаётся данными, а не
## отдельной системой: журнал получает только открытые записи.
func _load_bestiary_entries() -> void:
	_bestiary_catalog.clear()
	var dir := DirAccess.open(BESTIARY_DIR)
	if dir == null:
		push_warning("CampaignGuide: нет каталога бестиария %s" % BESTIARY_DIR)
		return
	for file in dir.get_files():
		if not file.ends_with(".tres"):
			continue
		var entry := load(BESTIARY_DIR + file) as BestiaryEntry
		if entry == null or not entry.is_valid():
			push_warning("CampaignGuide: некорректная запись бестиария %s" % file)
			continue
		if _bestiary_catalog.has(entry.id):
			push_warning("CampaignGuide: повторный id бестиария %s" % entry.id)
			continue
		_bestiary_catalog[entry.id] = entry


func get_bestiary_entry(entry_id: StringName) -> BestiaryEntry:
	return _bestiary_catalog.get(StringName(entry_id), null) as BestiaryEntry


func get_bestiary_entries() -> Array[BestiaryEntry]:
	var result: Array[BestiaryEntry] = []
	for value in _bestiary_catalog.values():
		var entry := value as BestiaryEntry
		if entry != null:
			result.append(entry)
	result.sort_custom(func(a: BestiaryEntry, b: BestiaryEntry) -> bool:
		return String(a.id) < String(b.id)
	)
	return result


## Открывает все записи, привязанные к событию. Возвращает реально открытые id,
## поэтому повторный вызов безопасен и не создаёт дублей.
func unlock_bestiary_by_event(event_id: StringName) -> Array[StringName]:
	var unlocked: Array[StringName] = []
	var event_key := StringName(event_id)
	for entry in get_bestiary_entries():
		if entry.unlock_event != event_key:
			continue
		if unlock_bestiary_entry(entry.id, event_key):
			unlocked.append(entry.id)
	return unlocked


func unlock_bestiary_entry(entry_id: StringName, event_id: StringName = &"") -> bool:
	var entry := get_bestiary_entry(entry_id)
	if entry == null:
		return false
	var resolved_event := event_id
	if resolved_event == &"":
		resolved_event = entry.unlock_event
	if not event_id.is_empty() and entry.unlock_event != resolved_event:
		return false
	if NightmareRunState.has_bestiary(entry.id):
		return false
	var unlocked := NightmareRunState.unlock_bestiary(entry.id, resolved_event)
	if unlocked:
		_append_bestiary_journal(entry, resolved_event)
	return unlocked


## Удобные входы для будущих триггеров: запись можно открыть по id или
## ресурсом, но источником истины остаётся id в NightmareRunState.
func unlock_bestiary(entry_id: StringName, event_id: StringName = &"") -> bool:
	return unlock_bestiary_entry(entry_id, event_id)


func add_bestiary_entry(entry: BestiaryEntry, event_id: StringName = &"") -> bool:
	if entry == null:
		return false
	return unlock_bestiary_entry(entry.id, event_id)


func has_bestiary_entry(entry_id: StringName) -> bool:
	return NightmareRunState.has_bestiary(entry_id)


func get_unlocked_bestiary_ids() -> Array[StringName]:
	return NightmareRunState.get_bestiary_ids()


func _append_bestiary_journal(entry: BestiaryEntry, event_id: StringName) -> void:
	if entry == null or has_journal_entry(entry.id):
		return
	journal_entries.append(entry.journal_record(event_id))
	journal_changed.emit()


func _on_bestiary_unlocked(entry_id: StringName, event_id: StringName) -> void:
	var entry := get_bestiary_entry(entry_id)
	if entry != null:
		_append_bestiary_journal(entry, event_id)


func _on_run_flag_changed(flag_name: StringName, value: bool) -> void:
	if not value:
		return
	var event_value: Variant = BESTIARY_FLAG_EVENTS.get(StringName(flag_name), &"")
	var event_id := StringName(event_value)
	if event_id != &"":
		unlock_bestiary_by_event(event_id)


func _on_state_restored() -> void:
	_sync_bestiary_from_state()


## После restore журнал пересобирается из сохранённых bestiary id. Общие записи
## журнала (например, «Правила Кошмара») при этом не затираются.
func _sync_bestiary_from_state() -> void:
	var preserved: Array[Dictionary] = []
	for record in journal_entries:
		if String(record.get("kind", "")) != "bestiary":
			preserved.append(record)
	journal_entries = preserved
	for entry_id in NightmareRunState.get_bestiary_ids():
		var entry := get_bestiary_entry(entry_id)
		if entry != null:
			_append_bestiary_journal(entry, NightmareRunState.get_bestiary_event(entry_id))
	# Совместимость со старыми снимками: запись могла быть открыта флагом,
	# но ещё не попасть в новый список bestiary.
	for flag_name in BESTIARY_FLAG_EVENTS:
		if NightmareRunState.has_flag(flag_name):
			unlock_bestiary_by_event(StringName(BESTIARY_FLAG_EVENTS[flag_name]))
	journal_changed.emit()


## Запись журнала, например «Правила Кошмара» после брифинга P03.
func add_journal_entry(entry: JournalEntryData) -> void:
	if entry == null or not entry.is_valid() or has_journal_entry(entry.id):
		return
	journal_entries.append({
		"id": entry.id,
		"title": entry.title,
		"text": entry.text,
	})
	journal_changed.emit()


func has_journal_entry(entry_id: StringName) -> bool:
	for entry in journal_entries:
		if StringName(entry.get("id", &"")) == entry_id:
			return true
	return false


func get_journal_entries() -> Array[Dictionary]:
	return journal_entries.duplicate(true)


func clear_current_objective() -> void:
	base_objective = ""
	display_objective = ""
	external_objective = ""
	_external_source = &""
	_external_objectives.clear()
	_external_order.clear()
	_external_scene_paths.clear()
	idle_step = 0
	idle_time = 0.0
	_emit_objective()


func reset_campaign() -> void:
	current_beat = null
	history.clear()
	journal_entries.clear()
	journal_changed.emit()
	clear_current_objective()
	if _bubble != null and is_instance_valid(_bubble):
		_bubble.hide_text(true)


## Вызывается из _physics_process и из тестов. idle=false — осмысленное действие.
func advance_idle(delta: float, idle: bool) -> void:
	if not external_objective.strip_edges().is_empty():
		idle_time = 0.0
		if idle_step != 0:
			_set_idle_step(0)
		return
	if current_beat == null or base_objective.strip_edges().is_empty():
		if idle_step != 0:
			_set_idle_step(0)
		idle_time = 0.0
		return
	var steps: Array[String] = current_beat.idle_objectives
	if steps.is_empty():
		if idle_step != 0:
			_set_idle_step(0)
		idle_time = 0.0
		return
	if not idle:
		if idle_time > 0.0 or idle_step != 0:
			idle_time = 0.0
			_set_idle_step(0)
		return

	idle_time += maxf(delta, 0.0)
	var first := maxf(settings.idle_seconds, 0.0)
	var interval := maxf(settings.idle_step_seconds, 0.0)
	var desired := 0
	if idle_time >= first:
		desired = 1
	if idle_time >= first + interval:
		desired = 2
	if idle_time >= first + interval * 2.0:
		desired = 3
	desired = mini(desired, mini(settings.max_idle_steps, steps.size()))
	if desired != idle_step:
		_set_idle_step(desired)


func _set_idle_step(step: int) -> void:
	if not external_objective.strip_edges().is_empty():
		idle_step = 0
		_refresh_display()
		_emit_objective()
		return
	var next := maxi(step, 0)
	if current_beat == null or current_beat.idle_objectives.is_empty():
		next = 0
	idle_step = next
	if idle_step > 0:
		var steps: Array[String] = current_beat.idle_objectives
		var index := mini(idle_step - 1, steps.size() - 1)
		display_objective = steps[index]
	else:
		display_objective = base_objective
	_emit_objective()


func _emit_objective() -> void:
	objective_changed.emit(display_objective, base_objective, idle_step)


func _record_history(beat: BeatData) -> void:
	if beat == null or beat.objective.strip_edges().is_empty():
		return
	if not history.is_empty():
		var last: Dictionary = history.back()
		if StringName(last.get("beat_id", &"")) == beat.id:
			last["title"] = beat.title
			last["text"] = beat.objective
			history[history.size() - 1] = last
			return
	history.append({
		"beat_id": beat.id,
		"title": beat.title,
		"text": beat.objective,
	})
	while history.size() > 40:
		history.pop_front()


func _physics_process(delta: float) -> void:
	_prune_stale_scene_objectives()
	if current_beat == null or base_objective.strip_edges().is_empty():
		return
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	if player == null:
		advance_idle(delta, false)
		return
	advance_idle(delta, _player_is_idle(player))


func _player_is_idle(player: Node3D) -> bool:
	if get_tree().paused:
		return false
	if player is SunnyController and not (player as SunnyController).input_enabled:
		return false
	var move := Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	if move.length() > 0.1:
		return false
	if Input.is_action_pressed(&"attack") or Input.is_action_pressed(&"jump"):
		return false
	if Input.is_action_pressed(&"interact") or Input.is_action_pressed(&"advance_dialogue"):
		return false
	var body := player as CharacterBody3D
	if body != null:
		var horizontal := Vector2(body.velocity.x, body.velocity.z).length()
		if horizontal > settings.idle_speed_threshold:
			return false
	return true


func _load_thoughts() -> void:
	_thoughts.clear()
	var dir := DirAccess.open(THOUGHT_DIR)
	if dir == null:
		push_warning("CampaignGuide: нет каталога мыслей %s" % THOUGHT_DIR)
		return
	for file in dir.get_files():
		if not file.ends_with(".tres"):
			continue
		var thought := load(THOUGHT_DIR + file) as GuideThought
		if thought == null or not thought.is_valid():
			push_warning("CampaignGuide: пропущен ресурс мысли %s" % file)
			continue
		_thoughts[thought.id] = thought
		if thought.trigger_id != &"":
			_thoughts[thought.trigger_id] = thought


func get_thought(thought_id: StringName) -> GuideThought:
	return _thoughts.get(StringName(thought_id), null) as GuideThought


func get_thought_text(thought_id: StringName) -> String:
	var thought := get_thought(thought_id)
	return thought.text if thought != null else ""


func get_thought_texts() -> Array[String]:
	var result: Array[String] = []
	for value in _thoughts.values():
		var thought := value as GuideThought
		if thought != null and not result.has(thought.text):
			result.append(thought.text)
	return result


## Показывает мысль по id ресурса. Триггер передаёт только id, текст берётся из ресурса.
func show_thought(thought_id: StringName) -> bool:
	var thought := get_thought(thought_id)
	if thought == null:
		push_warning("CampaignGuide: неизвестная мысль %s" % thought_id)
		return false
	var bubble := _ensure_bubble()
	if bubble == null:
		return false
	bubble.show_text(thought.text, settings.thought_seconds, settings.thought_fade_seconds)
	thought_shown.emit(thought.id, thought.text)
	return true


func _ensure_bubble() -> ThoughtBubble:
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	if player == null:
		return null
	if _bubble != null and is_instance_valid(_bubble):
		_bubble.target = player
		return _bubble
	var packed := load(THOUGHT_BUBBLE_SCENE) as PackedScene
	if packed == null:
		push_warning("CampaignGuide: не найдена сцена мысли %s" % THOUGHT_BUBBLE_SCENE)
		return null
	_bubble = packed.instantiate() as ThoughtBubble
	if _bubble == null:
		return null
	_bubble.top_level = true
	_bubble.target = player
	player.add_child(_bubble)
	_bubble.global_position = player.global_position + _bubble.follow_offset
	return _bubble


func get_bubble() -> ThoughtBubble:
	return _bubble
