class_name ObjectiveLine
extends Control
## Строка текущей цели: мягко появляется, меняется и гаснет. Держится у
## верхнего края малой строкой, поэтому не перекрывает центр кадра.
##
## Источник выбирается автоматически: активный QuestSystem (Лабиринт) имеет
## приоритет, иначе читается CampaignGuide (пост-Кошмар и Первый Кошмар).
## Это одна строка, а не два конкурирующих HUD.

@export var fade_in_seconds := 0.4
@export var fade_out_seconds := 0.6
@export var update_flash_seconds := 1.3

@onready var _caption: Label = $Box/Caption
@onready var _text: Label = $Box/Text

var _current_text := ""
var _last_step := 0
var _showing := false
var _tween: Tween
var _progress: ProgressBar
var _progress_text: Label
var _base_caption := "ЦЕЛЬ"
var _caption_timer: Timer
var _flash_restore_caption := "ЦЕЛЬ"
var _right_aligned := false


func _ready() -> void:
	if theme == null:
		theme = RpgMenuTheme.build()
	_ensure_progress_nodes()
	_fit_box()
	resized.connect(_fit_box)
	_apply_alignment()
	_caption_timer = Timer.new()
	_caption_timer.one_shot = true
	_caption_timer.timeout.connect(_restore_caption)
	add_child(_caption_timer)
	visible = false
	modulate.a = 0.0

	var guide := get_node_or_null("/root/CampaignGuide")
	if guide != null and guide.has_signal(&"objective_changed"):
		guide.objective_changed.connect(_on_guide_objective_changed)
	_connect_quest_system()
	refresh_from_sources(true)


func set_right_aligned(value: bool) -> void:
	_right_aligned = value
	_apply_alignment()


func _apply_alignment() -> void:
	var alignment := HORIZONTAL_ALIGNMENT_RIGHT if _right_aligned else HORIZONTAL_ALIGNMENT_LEFT
	if _caption != null:
		_caption.horizontal_alignment = alignment
	if _text != null:
		_text.horizontal_alignment = alignment
	if _progress_text != null:
		_progress_text.horizontal_alignment = alignment


func _fit_box() -> void:
	var box := get_node_or_null("Box") as Control
	if box != null:
		box.offset_right = size.x



func _ensure_progress_nodes() -> void:
	if _progress == null:
		_progress = get_node_or_null("Box/Progress") as ProgressBar
	if _progress == null:
		_progress = ProgressBar.new()
		_progress.name = "Progress"
		_progress.custom_minimum_size = Vector2(0, 3)
		_progress.show_percentage = false
		_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_progress.max_value = 1.0
		_progress.visible = false
		$Box.add_child(_progress)
	if _progress_text == null:
		_progress_text = get_node_or_null("Box/ProgressText") as Label
	if _progress_text == null:
		_progress_text = Label.new()
		_progress_text.name = "ProgressText"
		_progress_text.theme_type_variation = &"TinyMutedLabel"
		_progress_text.add_theme_font_size_override("font_size", 10)
		_progress_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_progress_text.visible = false
		$Box.add_child(_progress_text)


func _connect_quest_system() -> void:
	var quests := get_node_or_null("/root/QuestSystem")
	if quests == null:
		return
	if quests.has_signal(&"quest_started") and not quests.quest_started.is_connected(_on_quest_started):
		quests.quest_started.connect(_on_quest_started)
	if quests.has_signal(&"quest_progressed") and not quests.quest_progressed.is_connected(_on_quest_progressed):
		quests.quest_progressed.connect(_on_quest_progressed)
	if quests.has_signal(&"quest_completed") and not quests.quest_completed.is_connected(_on_quest_completed):
		quests.quest_completed.connect(_on_quest_completed)
	if quests.has_signal(&"tracked_quest_changed") and not quests.tracked_quest_changed.is_connected(_on_tracked_quest_changed):
		quests.tracked_quest_changed.connect(_on_tracked_quest_changed)
	if quests.has_signal(&"journal_changed") and not quests.journal_changed.is_connected(_on_quest_journal_changed):
		quests.journal_changed.connect(_on_quest_journal_changed)


## Перечитывает активный источник цели. Вызывается при старте, смене сцены и
## внешними тестами.
func refresh_from_sources(instant := false) -> void:
	# Во время смены сцены HUD может быть уже вне дерева, а QuestSystem
	# ещё рассылает journal_changed. Абсолютный get_node в этот момент
	# запрещён движком.
	if not is_inside_tree():
		return
	var quests := get_node_or_null("/root/QuestSystem")
	if quests != null and quests.has_method(&"is_scope_active") and bool(quests.call(&"is_scope_active")):
		var text := String(quests.call(&"get_tracked_objective_text")).strip_edges()
		if text.is_empty():
			hide_objective(instant)
			return
		var quest: Resource = quests.call(&"get_tracked_quest") as Resource
		var objective: Resource = quests.call(&"get_tracked_objective") as Resource
		_apply_quest_objective(text, quest, objective, instant)
		return

	var guide := get_node_or_null("/root/CampaignGuide")
	if guide == null:
		hide_objective(instant)
		return
	show_objective(
		String(guide.get(&"display_objective")),
		int(guide.get(&"idle_step")),
		instant
	)


func _apply_quest_objective(text: String, quest: Resource, objective: Resource, instant: bool) -> void:
	var next := text.strip_edges()
	if next.is_empty():
		hide_objective(instant)
		return
	var code := String(quest.get(&"code")) if quest != null else ""
	var completed := false
	var quest_state := &""
	var quests := get_node_or_null("/root/QuestSystem")
	if quest != null and quests != null and quests.has_method(&"get_state"):
		quest_state = StringName(quests.call(&"get_state", quest.get(&"id")))
		completed = quest_state == &"completed"
	if _right_aligned and quest != null:
		var title_value: Variant = quest.get(&"title")
		var title := String(title_value).strip_edges() if title_value != null else ""
		_base_caption = title.to_upper() if not title.is_empty() else "ЗАДАНИЕ"
	else:
		_base_caption = "ЗАДАНИЕ %s" % code if not code.is_empty() else "ЗАДАНИЕ"
	_update_progress(quest, objective, completed)

	_last_step = 0
	if completed:
		_apply_text(next, _base_caption, instant, false)
		_set_caption("ЗАДАНИЕ ЗАВЕРШЕНО", RpgMenuTheme.SUCCESS)
		return
	_apply_text(next, _base_caption, instant, true)


func _update_progress(quest: Resource, objective: Resource, completed: bool) -> void:
	if _progress == null or _progress_text == null:
		return
	if completed or objective == null or quest == null:
		_progress.visible = false
		_progress_text.visible = false
		return
	var required := int(objective.get(&"required_count"))
	if required <= 1:
		_progress.visible = false
		_progress_text.visible = false
		return
	var quests := get_node_or_null("/root/QuestSystem")
	var progress := 0
	if quests != null and quests.has_method(&"get_objective_progress"):
		progress = int(quests.call(&"get_objective_progress", quest.get(&"id"), objective.get(&"id")))
	_progress.max_value = float(required)
	_progress.value = float(progress)
	_progress.visible = true
	_progress_text.text = "%d / %d" % [progress, required]
	_progress_text.visible = true


func _on_guide_objective_changed(text: String, _base_text: String, idle_step: int) -> void:
	if not is_inside_tree():
		return
	# Если активен QuestSystem, его цель приоритетнее цели события.
	var quests := get_node_or_null("/root/QuestSystem")
	if quests != null and quests.has_method(&"is_scope_active") and bool(quests.call(&"is_scope_active")):
		refresh_from_sources()
		return
	show_objective(text, idle_step)


func _on_quest_started(_quest: QuestDefinition) -> void:
	refresh_from_sources()


func _on_quest_progressed(_quest: QuestDefinition, _objective: QuestObjective, _progress: int, _required: int) -> void:
	refresh_from_sources()


func _on_quest_completed(_quest: QuestDefinition) -> void:
	refresh_from_sources()


func _on_tracked_quest_changed(_quest: QuestDefinition) -> void:
	refresh_from_sources()


func _on_quest_journal_changed() -> void:
	refresh_from_sources()


## Публичная совместимость: ручная строка цели события.
func show_objective(text: String, idle_step := 0, instant := false) -> void:
	_last_step = idle_step
	_base_caption = "УТОЧНЕНИЕ" if idle_step > 0 else "ЦЕЛЬ"
	if _progress != null:
		_progress.visible = false
	if _progress_text != null:
		_progress_text.visible = false
	_apply_text(text, _base_caption, instant, true)


func _apply_text(next_text: String, caption: String, instant: bool, quest_update: bool) -> void:
	var next := next_text.strip_edges()
	if next == _current_text and _showing:
		if _caption.text != "ЦЕЛЬ ОБНОВЛЕНА":
			_caption.text = caption
		return
	_kill_tween()
	_current_text = next
	if next.is_empty():
		_showing = false
		_fade_out(instant)
		return
	_showing = true
	visible = true
	_caption.text = caption
	if instant:
		_text.text = next
		modulate.a = 1.0
		return

	if modulate.a < 0.01:
		_text.text = next
		modulate.a = 0.0
		_tween = create_tween()
		_tween.tween_property(self, "modulate:a", 1.0, fade_in_seconds)
	else:
		_tween = create_tween()
		_tween.tween_property(self, "modulate:a", 0.0, fade_out_seconds * 0.5)
		_tween.tween_callback(func() -> void: _text.text = next)
		_tween.tween_property(self, "modulate:a", 1.0, fade_in_seconds)
	if quest_update:
		_flash_update(caption)


func _flash_update(caption: String) -> void:
	_flash_restore_caption = caption
	_set_caption("ЦЕЛЬ ОБНОВЛЕНА", RpgMenuTheme.BRONZE_BRIGHT)
	_play_update_sound()
	_caption_timer.start(update_flash_seconds)


func _restore_caption() -> void:
	if not _showing:
		return
	_set_caption(_flash_restore_caption, RpgMenuTheme.BRONZE)


func _set_caption(text: String, color: Color) -> void:
	if _caption == null:
		return
	_caption.text = text
	_caption.add_theme_color_override("font_color", color)


func _play_update_sound() -> void:
	var director := get_node_or_null("/root/AudioDirector")
	if director != null and director.is_node_ready() and director.has_method(&"play_ui"):
		director.call(&"play_ui", &"ui_quest_update", -6.0)


func hide_objective(instant := false) -> void:
	_kill_tween()
	_current_text = ""
	_showing = false
	if _caption_timer != null:
		_caption_timer.stop()
	if _progress != null:
		_progress.visible = false
	if _progress_text != null:
		_progress_text.visible = false
	_fade_out(instant)


func is_showing() -> bool:
	return _showing


func get_objective_text() -> String:
	return _current_text


func _fade_out(instant: bool) -> void:
	if instant:
		modulate.a = 0.0
		visible = false
		return
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 0.0, fade_out_seconds)
	_tween.tween_callback(func() -> void: visible = false)


func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
