class_name RpgQuestRow
extends Button
## Компактная строка демонстрационного журнала заданий.
## Только отображает запись и сообщает о выборе; прогресс не меняет.

signal quest_chosen(quest_id: StringName)

@onready var code: Label = %Code
@onready var category: Label = %Category
@onready var quest_title: Label = %QuestTitle
@onready var progress: Label = %Progress
@onready var status_label: Label = %Status

var quest: Resource


func _ready() -> void:
	pressed.connect(_on_pressed)
	custom_minimum_size.y = 82.0


func setup(data: Resource, selected: bool) -> void:
	quest = data
	if quest == null:
		return

	code.text = String(quest.code)
	category.text = String(quest.category)
	quest_title.text = String(quest.title)
	var completed := int(quest.completed_objectives())
	var total: int = quest.objectives.size()
	progress.text = "ЦЕЛИ · %d / %d" % [completed, total]

	var status := int(quest.status)
	status_label.text = _status_title(status)
	var status_color := _status_color(status)
	status_label.add_theme_color_override("font_color", status_color)
	quest_title.add_theme_color_override(
		"font_color",
		RpgMenuTheme.MUTED if status == 2 else RpgMenuTheme.TEXT_BRIGHT
	)
	progress.add_theme_color_override(
		"font_color",
		RpgMenuTheme.SUCCESS if status == 2 else RpgMenuTheme.MUTED
	)
	button_pressed = selected
	tooltip_text = "%s\n%s\nЦели: %d из %d" % [quest.title, quest.summary, completed, total]


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


func _on_pressed() -> void:
	if quest != null:
		quest_chosen.emit(quest.id)
