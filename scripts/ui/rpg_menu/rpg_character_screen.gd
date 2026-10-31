class_name RpgCharacterScreen
extends Control
## Профиль персонажа: канонические поля StatusSheet, демонстрационные
## характеристики и шесть слотов снаряжения рядом с 3D-превью POC-модели.
##
## Экран не меняет персонажа и не подменяет модель экипировкой. Слоты только
## открывают соответствующий предмет в демонстрационном инвентаре.

signal feedback_requested(text: String, tone: StringName)
signal item_requested(item_id: StringName)
signal empty_slot_requested(slot_label: String)

const SLOT_ORDER: Array[StringName] = [&"weapon", &"chest", &"cloak", &"hands", &"feet", &"accessory"]
const SLOT_LABELS := {
	&"weapon": "ОРУЖИЕ",
	&"chest": "ДОСПЕХ",
	&"cloak": "ПЛАЩ",
	&"hands": "ПЕРЧАТКИ",
	&"feet": "ОБУВЬ",
	&"accessory": "АКСЕССУАР",
}

@onready var character_name: Label = %CharacterName
@onready var name_rune: Label = %NameRune
@onready var true_name: Label = %TrueName
@onready var canonical_note: Label = %CanonicalNote
@onready var rank_value: Label = %RankValue
@onready var soul_core_value: Label = %SoulCoreValue
@onready var aspect_value: Label = %AspectValue
@onready var aspect_description: Label = %AspectDescription
@onready var attributes_value: Label = %AttributesValue
@onready var memories_echoes: Label = %MemoriesEchoes
@onready var demo_stats: VBoxContainer = %DemoStats
@onready var equipped_count: Label = %EquippedCount
@onready var equipped_weight: Label = %EquippedWeight
@onready var slots_grid: GridContainer = %SlotsGrid
@onready var empty_slots_hint: Label = %EmptySlotsHint
@onready var preview_container: SubViewportContainer = %PreviewContainer
@onready var preview_stage: Node3D = %PreviewStage
@onready var reset_preview: Button = %ResetPreview
@onready var model_note: Label = %ModelNote

var session: RpgDemoSession
var _slot_controls: Array[RpgEquipmentSlot] = []
var _dragging_preview := false


func _ready() -> void:
	for child in slots_grid.get_children():
		if child is RpgEquipmentSlot:
			var slot := child as RpgEquipmentSlot
			slot.slot_activated.connect(_on_slot_activated)
			_slot_controls.append(slot)
	reset_preview.pressed.connect(_on_reset_preview)
	preview_container.gui_input.connect(_on_preview_input)
	preview_container.mouse_default_cursor_shape = Control.CURSOR_DRAG
	_clear_children(demo_stats)


func setup(data: RpgDemoSession) -> void:
	if session != null and session.changed.is_connected(_on_session_changed):
		session.changed.disconnect(_on_session_changed)
	session = data
	if session == null:
		return
	session.changed.connect(_on_session_changed)
	_refresh()


func _refresh() -> void:
	if session == null or session.catalog == null:
		return
	_refresh_identity()
	_refresh_demo_stats()
	_refresh_equipment()


func _refresh_identity() -> void:
	var sheet := session.catalog.status_sheet
	var catalog := session.catalog
	character_name.text = catalog.character_name.to_upper()
	if sheet == null:
		name_rune.text = "РУНА · —"
		true_name.text = "ИСТИННОЕ ИМЯ · —"
		canonical_note.text = "Канонический StatusSheet не подключён."
		rank_value.text = "—"
		soul_core_value.text = "—"
		aspect_value.text = "—"
		aspect_description.text = "Нет данных."
		attributes_value.text = "—"
		memories_echoes.text = "ПАМЯТИ · —   ОТГОЛОСКИ · —"
		return

	name_rune.text = "РУНА · %s" % sheet.name_rune.to_upper()
	true_name.text = "ИСТИННОЕ ИМЯ · %s" % sheet.true_name
	canonical_note.text = catalog.character_note
	rank_value.text = sheet.rank.to_upper()
	soul_core_value.text = sheet.soul_core.to_upper()
	aspect_value.text = sheet.aspect.to_upper()
	aspect_description.text = sheet.aspect_description
	attributes_value.text = "  ·  ".join(sheet.attributes)
	memories_echoes.text = "ПАМЯТИ · %s    ОТГОЛОСКИ · %s" % [sheet.memories, sheet.echoes]


func _refresh_demo_stats() -> void:
	_clear_children(demo_stats)
	for entry in session.catalog.demo_stats:
		if not entry is RpgDemoStat:
			continue
		var stat := entry as RpgDemoStat
		var row := VBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 3)

		var line := HBoxContainer.new()
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var label := Label.new()
		label.text = stat.label.to_upper()
		label.theme_type_variation = &"TinyMutedLabel"
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_child(label)
		var value := Label.new()
		value.text = stat.value
		value.theme_type_variation = &"BronzeLabel"
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_child(value)
		row.add_child(line)

		if stat.fill >= 0.0:
			var bar := ProgressBar.new()
			bar.custom_minimum_size = Vector2(0, 4)
			bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
			bar.show_percentage = false
			bar.max_value = 1.0
			bar.step = 0.01
			bar.value = clampf(stat.fill, 0.0, 1.0)
			row.add_child(bar)

		demo_stats.add_child(row)


func _refresh_equipment() -> void:
	var equipped := 0
	var total_weight := 0.0
	for slot in _slot_controls:
		var item := session.find_equipped(slot.slot_id)
		slot.setup(item)
		if item != null:
			equipped += 1
			total_weight += item.stack_weight()

	equipped_count.text = "ЭКИПИРОВАНО %d / %d" % [equipped, _slot_controls.size()]
	equipped_weight.text = "ВЕС: %s ДЕМО-ЕД." % String.num(total_weight, 1).replace(".", ",")
	empty_slots_hint.text = (
		"Все демо-слоты заполнены. Нажмите на слот, чтобы открыть предмет."
		if equipped == _slot_controls.size()
		else "Пустые слоты отмечены. В демо-наборе нет предмета для каждого слота."
	)
	model_note.text = "POC-МОДЕЛЬ БЕЗ ПЕРЕОДЕВАНИЯ · ЭКИПИРОВКА %d / %d" % [
		equipped,
		_slot_controls.size(),
	]


func _on_slot_activated(slot_id: StringName, item_id: StringName) -> void:
	if not item_id.is_empty():
		item_requested.emit(item_id)
		return
	var label := String(SLOT_LABELS.get(slot_id, "СЛОТ"))
	empty_slot_requested.emit(label)
	feedback_requested.emit("Слот «%s» пуст: в демо-наборе нет подходящего предмета." % label, &"warning")


func _on_preview_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			_dragging_preview = mouse_event.pressed
			preview_container.mouse_default_cursor_shape = (
				Control.CURSOR_DRAG if _dragging_preview else Control.CURSOR_POINTING_HAND
			)
			accept_event()
	elif event is InputEventMouseMotion and _dragging_preview:
		var motion := event as InputEventMouseMotion
		if preview_stage.has_method("rotate_by"):
			preview_stage.call("rotate_by", -motion.relative.x * 0.012)
		accept_event()


func _on_reset_preview() -> void:
	if preview_stage.has_method("reset_view"):
		preview_stage.call("reset_view")
	feedback_requested.emit("Ракурс модели сброшен.", &"info")


func _on_session_changed() -> void:
	_refresh_equipment()


func _clear_children(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
