class_name RuneStatusUI
extends PanelContainer
## Экран статуса Заклинания: руны видит только Санни. Закрывается тем же действием, что и открылся.

signal closed

@onready var rows: VBoxContainer = %Rows

var showing := false
var _opened_frame := -1


func _ready() -> void:
	visible = false


func present(sheet: StatusSheet) -> void:
	fill(sheet)
	visible = true
	showing = true
	_opened_frame = Engine.get_process_frames()
	await closed


func fill(sheet: StatusSheet) -> void:
	for child in rows.get_children():
		child.free()
	_add_row("Имя", sheet.name_rune)
	_add_row("Истинное имя", sheet.true_name)
	_add_row("Ранг", sheet.rank)
	_add_row("Ядро души", sheet.soul_core)
	_add_row("Воспоминания", sheet.memories)
	_add_row("Эхо", sheet.echoes)
	var attributes := PackedStringArray()
	for attribute in sheet.attributes:
		attributes.append("[%s]" % attribute)
	_add_row("Атрибуты", ", ".join(attributes))
	_add_row("Аспект", "[%s]" % sheet.aspect)
	_add_row("Описание Аспекта", sheet.aspect_description)


func close() -> void:
	if not showing:
		return
	showing = false
	visible = false
	closed.emit()


func row_texts() -> PackedStringArray:
	var texts := PackedStringArray()
	for child in rows.get_children():
		texts.append((child as Label).text)
	return texts


func _add_row(title: String, value: String) -> void:
	var label := Label.new()
	label.text = "%s: %s" % [title, value]
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rows.add_child(label)


func _unhandled_input(event: InputEvent) -> void:
	if not showing or Engine.get_process_frames() == _opened_frame:
		return
	if event.is_action_pressed(&"open_status") or event.is_action_pressed(&"advance_dialogue"):
		get_viewport().set_input_as_handled()
		close()
