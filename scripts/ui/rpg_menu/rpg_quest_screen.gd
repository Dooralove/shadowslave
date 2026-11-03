class_name RpgQuestScreen
extends Control
## Журнал заданий. Читает живой QuestSystem (Лабиринт), иначе — историю
## CampaignGuide (Первый Кошмар). При отсутствии живых данных показывает
## честное пустое состояние, а не демонстрационный прогресс. Строки и цели
## приходят только из состояния прохождения.

signal feedback_requested(text: String, tone: StringName)
signal navigate_requested(section: StringName)

const ROW_SCENE := preload("res://scenes/ui/rpg_menu/quest_row.tscn")

@onready var active_count: Label = %ActiveCount
@onready var available_count: Label = %AvailableCount
@onready var completed_count: Label = %CompletedCount
@onready var records_count: Label = %RecordsCount
@onready var quest_list: VBoxContainer = %QuestList
@onready var return_button: Button = %ReturnButton
@onready var detail_scroll: ScrollContainer = %DetailScroll
@onready var empty_detail: Control = %EmptyDetail
@onready var detail_source: Label = %DetailSource
@onready var detail_code: Label = %DetailCode
@onready var detail_status: Label = %DetailStatus
@onready var detail_title: Label = %DetailTitle
@onready var detail_category: Label = %DetailCategory
@onready var detail_summary: Label = %DetailSummary
@onready var detail_description: Label = %DetailDescription
@onready var progress_value: Label = %ProgressValue
@onready var quest_progress: ProgressBar = %QuestProgress
@onready var objectives_rows: VBoxContainer = %ObjectivesRows
@onready var detail_note: Label = %DetailNote
@onready var current_panel: PanelContainer = %CurrentPanel
@onready var current_objective: Label = %CurrentObjective
@onready var current_event: Label = %CurrentEvent
@onready var current_journal: Label = %CurrentJournal

var quests: Array = []
var selected_quest_id: StringName = &""


## Совместимость с прежним API: каталог больше не является источником данных.
func setup(_data: Resource) -> void:
	if is_node_ready():
		refresh()

var _rows: Array = []
var _last_selection_key := &""
var _track_button: Button
var _using_quest_system := false
var _using_campaign := false


func _ready() -> void:
	return_button.pressed.connect(_on_return_pressed)
	_build_track_button()
	var guide := get_node_or_null("/root/CampaignGuide")
	if guide != null:
		guide.objective_changed.connect(_on_guide_objective_changed)
		guide.journal_changed.connect(_on_guide_journal_changed)
	_connect_quest_system()
	refresh_current_objective()
	refresh()


func _build_track_button() -> void:
	if return_button == null:
		return
	var parent := return_button.get_parent()
	if parent == null:
		return
	_track_button = Button.new()
	_track_button.name = "TrackButton"
	_track_button.custom_minimum_size = Vector2(0, 38)
	_track_button.theme_type_variation = &"PrimaryButton"
	_track_button.text = "СЛЕЖИТЬ ЗА ЦЕЛЬЮ"
	_track_button.visible = false
	_track_button.pressed.connect(_on_track_pressed)
	parent.add_child(_track_button)
	parent.move_child(_track_button, return_button.get_index())


func _connect_quest_system() -> void:
	var quests_system := get_node_or_null("/root/QuestSystem")
	if quests_system == null:
		return
	if quests_system.has_signal(&"journal_changed") and not quests_system.journal_changed.is_connected(_on_quest_journal_changed):
		quests_system.journal_changed.connect(_on_quest_journal_changed)
	if quests_system.has_signal(&"catalog_loaded") and not quests_system.catalog_loaded.is_connected(_on_quest_catalog_loaded):
		quests_system.catalog_loaded.connect(_on_quest_catalog_loaded)


## Строка цели в журнале — та же, что на HUD. Приоритет: QuestSystem, затем
## CampaignGuide. Демо-цели здесь не изобретаются.
func refresh_current_objective() -> void:
	var quests_system := get_node_or_null("/root/QuestSystem")
	if quests_system != null and quests_system.has_method(&"is_scope_active") and bool(quests_system.call(&"is_scope_active")):
		var text := String(quests_system.call(&"get_tracked_objective_text")).strip_edges()
		current_panel.visible = not text.is_empty()
		if not current_panel.visible:
			return
		current_objective.visible = true
		current_objective.text = text
		var quest: Variant = quests_system.call(&"get_tracked_quest")
		var active_total := (quests_system.call(&"get_active_quests") as Array).size()
		var event_text := "ЗАБЫТЫЙ БЕРЕГ · АКТИВНЫХ ЗАДАНИЙ: %d" % active_total
		if quest != null:
			var code := String(quest.get(&"code")).strip_edges()
			if not code.is_empty():
				event_text = "ЗАБЫТЫЙ БЕРЕГ · ЗАДАНИЕ %s · %s" % [code, String(quest.get(&"title"))]
		current_event.text = event_text
		current_journal.visible = false
		current_journal.text = ""
		return

	var guide := get_node_or_null("/root/CampaignGuide")
	if guide == null:
		current_panel.visible = false
		return
	var text := String(guide.get(&"display_objective")).strip_edges()
	var entries: Array = guide.call(&"get_journal_entries")
	current_panel.visible = not text.is_empty() or not entries.is_empty()
	if not current_panel.visible:
		return
	current_objective.visible = not text.is_empty()
	current_objective.text = text
	var beat_id := StringName(guide.call(&"get_current_beat_id"))
	var title := String(guide.call(&"get_current_beat_title"))
	if beat_id != &"":
		current_event.text = "СОБЫТИЕ · %s · %s" % [String(beat_id), title]
	else:
		current_event.text = "ПЕРВЫЙ КОШМАР"
	if entries.is_empty():
		current_journal.visible = false
		current_journal.text = ""
	else:
		var lines: Array[String] = []
		for entry in entries:
			var entry_title := String(entry.get("title", ""))
			var entry_text := String(entry.get("text", ""))
			if String(entry.get("kind", "")) == "bestiary":
				entry_title = "Бестиарий · %s" % entry_title
				var event_label := String(entry.get("event_label", "")).strip_edges()
				if not event_label.is_empty():
					entry_title += " · %s" % event_label
			lines.append("%s\n%s" % [entry_title, entry_text])
		current_journal.text = "\n\n".join(lines)
		current_journal.visible = true


func _on_guide_journal_changed() -> void:
	refresh_current_objective()


func _on_guide_objective_changed(_text: String, _base_text: String, _idle_step: int) -> void:
	refresh_current_objective()


func _on_quest_journal_changed() -> void:
	# Полный список перестраивается при открытии вкладки. Иначе старт
	# нескольких заданий подряд создаёт десятки промежуточных строк.
	refresh_current_objective()


func _on_quest_catalog_loaded(_scope: StringName) -> void:
	refresh()


func refresh() -> void:
	_load_live_source()
	_ensure_selection()
	_refresh_summary()
	_rebuild_rows()
	_refresh_details()


func _load_live_source() -> void:
	_using_quest_system = false
	_using_campaign = false
	quests.clear()

	var quests_system := get_node_or_null("/root/QuestSystem")
	if quests_system != null and quests_system.has_method(&"is_scope_active") and bool(quests_system.call(&"is_scope_active")):
		_using_quest_system = true
		var entries: Variant = quests_system.call(&"get_journal_entries")
		if entries is Array:
			quests.assign(entries)
		return

	var guide := get_node_or_null("/root/CampaignGuide")
	if guide != null and guide.has_method(&"get_history"):
		var history: Array = guide.call(&"get_history")
		if not history.is_empty():
			_using_campaign = true
			var current_beat := StringName(guide.call(&"get_current_beat_id"))
			for index in range(history.size() - 1, -1, -1):
				var record: Dictionary = history[index]
				quests.append(_campaign_record(record, index == history.size() - 1, current_beat))
			return


func _campaign_record(record: Dictionary, is_current: bool, current_beat: StringName) -> QuestJournalEntry:
	var entry := QuestJournalEntry.new()
	entry.id = StringName(record.get("beat_id", &""))
	entry.code = String(record.get("beat_id", ""))
	entry.title = String(record.get("title", "Событие"))
	entry.category = "СЮЖЕТ"
	entry.status = 0 if is_current else 2
	entry.summary = String(record.get("text", ""))
	entry.description = "Событие кампании «Первый Кошмар»."
	entry.note = "Текущее событие прохождения." if is_current else "Событие завершено."
	var objective := QuestJournalObjective.new()
	objective.id = StringName("beat_%s" % String(record.get("beat_id", "")))
	objective.text = String(record.get("text", ""))
	objective.required = 1
	objective.progress = 1 if not is_current else 0
	objective.completed = not is_current
	entry.objectives.append(objective)
	if is_current and current_beat != &"" and String(current_beat) != entry.code:
		entry.status = 2
		entry.objectives[0].completed = true
		entry.objectives[0].progress = 1
	return entry


func _ensure_selection() -> void:
	if quests.is_empty():
		selected_quest_id = &""
		return
	for quest in quests:
		if quest.id == selected_quest_id:
			return
	selected_quest_id = quests[0].id


func _refresh_summary() -> void:
	var active := 0
	var available := 0
	var completed := 0
	for quest in quests:
		match int(quest.status):
			0:
				active += 1
			1:
				available += 1
			_:
				completed += 1
	active_count.text = str(active)
	available_count.text = str(available)
	completed_count.text = str(completed)
	records_count.text = "%d %s" % [quests.size(), _records_word(quests.size())]


func _records_word(count: int) -> String:
	if count % 10 == 1 and count % 100 != 11:
		return "ЗАПИСЬ"
	if count % 10 >= 2 and count % 10 <= 4 and (count % 100 < 12 or count % 100 > 14):
		return "ЗАПИСИ"
	return "ЗАПИСЕЙ"


func _rebuild_rows() -> void:
	_clear_rows(quest_list)
	_rows.clear()
	if quests.is_empty():
		var empty := Label.new()
		empty.text = "Записей пока нет. Журнал заполнится по мере прохождения."
		empty.theme_type_variation = &"MutedLabel"
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.custom_minimum_size = Vector2(0, 72)
		empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		quest_list.add_child(empty)
		return
	for quest in quests:
		var row = ROW_SCENE.instantiate()
		quest_list.add_child(row)
		row.setup(quest, quest.id == selected_quest_id)
		row.quest_chosen.connect(_on_quest_chosen)
		_rows.append(row)


func _refresh_details() -> void:
	var quest: Variant = _selected_quest()
	if quest == null:
		detail_scroll.visible = false
		empty_detail.visible = true
		_last_selection_key = &""
		_update_track_button()
		return

	detail_scroll.visible = true
	empty_detail.visible = false
	if _using_quest_system:
		detail_source.text = "ЖУРНАЛ ЛАБИРИНТА"
	elif int(quest.status) == 0:
		detail_source.text = "АКТИВНАЯ ЗАПИСЬ · КАМПАНИЯ"
	else:
		detail_source.text = "АРХИВ · КАМПАНИЯ"
	detail_code.text = "ЗАПИСЬ %s" % String(quest.code)
	detail_status.text = _status_title(int(quest.status))
	detail_status.add_theme_color_override("font_color", _status_color(int(quest.status)))
	detail_title.text = String(quest.title)
	detail_category.text = "КАТЕГОРИЯ · %s" % String(quest.category)
	detail_summary.text = String(quest.summary)
	detail_description.text = String(quest.description)

	var completed := int(quest.completed_objectives())
	var total: int = quest.objectives.size()
	if total <= 0:
		progress_value.text = "—"
		quest_progress.visible = false
	else:
		progress_value.text = "%d / %d" % [completed, total]
		quest_progress.visible = true
		quest_progress.max_value = float(total)
		quest_progress.value = float(completed)

	_fill_objectives(quest)
	var note := String(quest.note)
	if note.is_empty():
		note = "Прогресс обновляется из игрового состояния." if _using_quest_system else "Событие кампании."
	detail_note.text = note

	var selection_key := StringName(selected_quest_id)
	if _last_selection_key != selection_key:
		detail_scroll.scroll_vertical = 0
		_last_selection_key = selection_key
	_update_track_button()


func _fill_objectives(quest: Variant) -> void:
	_clear_rows(objectives_rows)
	if quest.objectives.is_empty():
		var empty := Label.new()
		empty.text = "Цели не заданы."
		empty.theme_type_variation = &"MutedLabel"
		objectives_rows.add_child(empty)
		return

	for objective in quest.objectives:
		if objective == null:
			continue
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 7)
		objectives_rows.add_child(row)

		var marker := Label.new()
		marker.text = "✓" if objective.completed else "◇"
		marker.custom_minimum_size = Vector2(14, 0)
		marker.theme_type_variation = &"TinyMutedLabel"
		marker.add_theme_color_override(
			"font_color",
			RpgMenuTheme.SUCCESS if objective.completed else RpgMenuTheme.BRONZE_DIM
		)
		marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(marker)

		var label := Label.new()
		var text := String(objective.text)
		var required_value: Variant = objective.get(&"required")
		if required_value != null and int(required_value) > 1:
			var progress_value: Variant = objective.get(&"progress")
			text += "  ·  %d / %d" % [
				int(progress_value) if progress_value != null else 0,
				int(required_value)
			]
		label.text = text
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.theme_type_variation = &"MutedLabel"
		label.add_theme_font_size_override("font_size", 13)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_color_override(
			"font_color",
			RpgMenuTheme.DIM if objective.completed else RpgMenuTheme.TEXT
		)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(label)


func _selected_quest() -> Variant:
	for quest in quests:
		if quest.id == selected_quest_id:
			return quest
	return null


func _status_title(status: int) -> String:
	match status:
		0:
			return "◆ АКТИВНО"
		1:
			return "◇ ДОСТУПНО"
		_:
			return "✓ ЗАВЕРШЕНО"


func _status_color(status: int) -> Color:
	match status:
		0:
			return RpgMenuTheme.BRONZE_BRIGHT
		1:
			return RpgMenuTheme.MUTED
		_:
			return RpgMenuTheme.SUCCESS


func _on_quest_chosen(quest_id: StringName) -> void:
	selected_quest_id = quest_id
	refresh()
	for row in _rows:
		if row != null and row.quest != null and StringName(row.quest.id) == quest_id:
			row.grab_focus()
			break
	var quest: Variant = _selected_quest()
	if quest != null:
		feedback_requested.emit("Выбрана запись: %s." % String(quest.title), &"info")


func _on_track_pressed() -> void:
	var quests_system := get_node_or_null("/root/QuestSystem")
	if quests_system == null or not quests_system.has_method(&"set_tracked_quest"):
		return
	if bool(quests_system.call(&"set_tracked_quest", selected_quest_id)):
		feedback_requested.emit("Цель отслеживается на HUD.", &"success")
		refresh_current_objective()
		_update_track_button()


func _update_track_button() -> void:
	if _track_button == null:
		return
	var quest: Variant = _selected_quest()
	var can_track := false
	if _using_quest_system and quest != null and int(quest.status) == 0:
		var quests_system := get_node_or_null("/root/QuestSystem")
		if quests_system != null:
			var tracked: Variant = quests_system.call(&"get_tracked_quest")
			var tracked_id := StringName(tracked.get(&"id")) if tracked != null else &""
			can_track = tracked_id != StringName(quest.id)
			_track_button.text = "СЛЕЖИТЬ ЗА ЦЕЛЬЮ" if can_track else "ЦЕЛЬ УЖЕ ОТСЛЕЖИВАЕТСЯ"
	_track_button.visible = _using_quest_system and quest != null and int(quest.status) == 0
	_track_button.disabled = not can_track


func _on_return_pressed() -> void:
	navigate_requested.emit(&"inventory")


func _clear_rows(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
