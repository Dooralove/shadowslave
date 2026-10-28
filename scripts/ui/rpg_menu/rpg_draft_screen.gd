class_name RpgDraftScreen
extends Control
## Честная заглушка для ещё не реализованных разделов меню.
##
## Не изображает готовые списки, награды или прогресс. Показывает только
## название раздела, статус «Черновик» и запланированный объём работы.

signal navigate_requested(section: StringName)

@onready var section_overline: Label = %SectionOverline
@onready var section_title: Label = %SectionTitle
@onready var section_ghost: Label = %SectionGhost
@onready var section_description: Label = %SectionDescription
@onready var planned_features: VBoxContainer = %PlannedFeatures
@onready var draft_caption: Label = %DraftCaption
@onready var draft_summary: Label = %DraftSummary
@onready var inventory_button: Button = %InventoryButton

var _section := &""


func _ready() -> void:
	inventory_button.pressed.connect(_on_inventory_pressed)


func setup(config: Dictionary) -> void:
	_section = StringName(config.get("id", &""))
	section_overline.text = String(config.get("overline", "РАЗДЕЛ · ЧЕРНОВИК"))
	section_title.text = String(config.get("title", "РАЗДЕЛ"))
	section_ghost.text = String(config.get("code", "—"))
	section_description.text = String(config.get("description", "Раздел ещё не реализован."))
	draft_caption.text = String(config.get("caption", "ЧЕРНОВИК"))
	draft_summary.text = String(config.get("summary", "Заглушка не имитирует готовую механику."))
	inventory_button.text = String(config.get("button", "ОТКРЫТЬ ИНВЕНТАРЬ"))
	_rebuild_features(config.get("features", []))


func _rebuild_features(features: Array) -> void:
	for child in planned_features.get_children():
		planned_features.remove_child(child)
		child.queue_free()

	var index := 1
	for feature in features:
		var panel := PanelContainer.new()
		panel.theme_type_variation = &"SubPanel"
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		planned_features.add_child(panel)

		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 10)
		panel.add_child(row)

		var number := Label.new()
		number.text = "%02d" % index
		number.custom_minimum_size = Vector2(22, 0)
		number.theme_type_variation = &"TinyMutedLabel"
		number.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(number)

		var marker := Label.new()
		marker.text = "◆"
		marker.theme_type_variation = &"TinyMutedLabel"
		marker.add_theme_color_override("font_color", RpgMenuTheme.BRONZE_DIM)
		marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(marker)

		var label := Label.new()
		label.text = String(feature)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.theme_type_variation = &"MutedLabel"
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(label)

		var plan := Label.new()
		plan.text = "ПЛАН"
		plan.theme_type_variation = &"TinyMutedLabel"
		plan.add_theme_color_override("font_color", RpgMenuTheme.BRONZE_DIM)
		plan.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(plan)
		index += 1


func _on_inventory_pressed() -> void:
	navigate_requested.emit(&"inventory")
