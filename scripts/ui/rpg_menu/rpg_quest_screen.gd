class_name RpgQuestScreen
extends Control
## Отдельная DEMO-страница журнала заданий. Показывает только записи из
## типизированного ресурса и не связана с квестами игры, сохранениями,
## сюжетом или наградами. Прогресс из интерфейса не меняется.

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

var catalog: Resource
var quests: Array = []
var selected_quest_id: StringName = &""

var _rows: Array = []
var _last_selection_key := &""


func _ready() -> void:
	return_button.pressed.connect(_on_return_pressed)


func setup(data: Resource) -> void:
	catalog = data
	quests.clear()
	if catalog != null:
		for entry in catalog.quests:
			if entry != null:
				quests.append(entry)
	selected_quest_id = quests[0].id if not quests.is_empty() else &""
	refresh()


func refresh() -> void:
	_ensure_selection()
	_refresh_summary()
	_rebuild_rows()
	_refresh_details()


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
	for quest in quests:
		var row = ROW_SCENE.instantiate()
		quest_list.add_child(row)
		row.setup(quest, quest.id == selected_quest_id)
		row.quest_chosen.connect(_on_quest_chosen)
		_rows.append(row)


func _refresh_details() -> void:
	var quest := _selected_quest()
	if quest == null:
		detail_scroll.visible = false
		empty_detail.visible = true
		_last_selection_key = &""
		return

	detail_scroll.visible = true
	empty_detail.visible = false
	detail_source.text = "ВЫБРАННАЯ ЗАПИСЬ · DEMO"
	detail_code.text = "ЗАПИСЬ %s" % String(quest.code)
	detail_status.text = _status_title(int(quest.status))
	detail_status.add_theme_color_override("font_color", _status_color(int(quest.status)))
	detail_title.text = String(quest.title)
	detail_category.text = "КАТЕГОРИЯ · %s" % String(quest.category)
	detail_summary.text = String(quest.summary)
	detail_description.text = String(quest.description)

	var completed := int(quest.completed_objectives())
	var total: int = quest.objectives.size()
	progress_value.text = "%d / %d" % [completed, total]
	quest_progress.max_value = float(maxi(1, total))
	quest_progress.value = float(completed)

	_fill_objectives(quest)
	var note := String(quest.note)
	detail_note.text = (
		"%s\nНаграды, завершение и связь с игрой не подключены." % note
		if not note.is_empty()
		else "Награды, завершение и связь с игрой не подключены."
	)

	var selection_key := StringName(selected_quest_id)
	if _last_selection_key != selection_key:
		detail_scroll.scroll_vertical = 0
		_last_selection_key = selection_key


func _fill_objectives(quest: Resource) -> void:
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
		label.text = String(objective.text)
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


func _selected_quest() -> Resource:
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
	var quest := _selected_quest()
	if quest != null:
		feedback_requested.emit("Выбрана запись: %s." % String(quest.title), &"info")


func _on_return_pressed() -> void:
	navigate_requested.emit(&"inventory")


func _clear_rows(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
