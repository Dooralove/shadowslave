class_name RpgEquipmentSlot
extends Button
## Карточка слота снаряжения. Показывает предмет или пустой слот и просит
## родительский экран открыть соответствующую запись в инвентаре.

signal slot_activated(slot_id: StringName, item_id: StringName)

@export var slot_id: StringName = &""
@export var slot_label := "СЛОТ"
@export var slot_index := "01"
@export var empty_icon: Texture2D

@onready var icon_panel: PanelContainer = %IconPanel
@onready var icon_rect: TextureRect = %Icon
@onready var slot_code: Label = %SlotCode
@onready var item_name: Label = %ItemName
@onready var meta: Label = %Meta
@onready var open_mark: Label = %OpenMark
@onready var empty_mark: Label = %EmptyMark

var item: RpgDemoItem


func _ready() -> void:
	pressed.connect(_on_pressed)
	slot_code.text = "%s · %s" % [slot_index, slot_label]
	custom_minimum_size.y = 104.0


func setup(data: RpgDemoItem) -> void:
	item = data
	var has_item := item != null
	icon_rect.texture = item.icon if has_item else empty_icon
	icon_rect.visible = icon_rect.texture != null
	icon_rect.modulate = Color.WHITE if has_item else Color(0.5, 0.48, 0.44, 0.42)
	icon_panel.self_modulate = Color.WHITE if has_item else Color(0.76, 0.74, 0.7, 0.65)
	open_mark.visible = has_item
	empty_mark.visible = not has_item

	if has_item:
		item_name.text = item.display_name
		item_name.add_theme_color_override("font_color", RpgMenuTheme.TEXT_BRIGHT)
		# Редкость уже окрашивает строку; отдельное «экипировано» здесь избыточно
		# и не помещается в узкую карточку слота.
		meta.text = RpgMenuTheme.rarity_title(item.rarity)
		meta.add_theme_color_override("font_color", RpgMenuTheme.rarity_color(item.rarity))
		tooltip_text = "%s · %s\nОткрыть «%s» в инвентаре." % [
			slot_label,
			RpgMenuTheme.rarity_title(item.rarity),
			item.display_name,
		]
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	else:
		item_name.text = "Пустой слот"
		item_name.add_theme_color_override("font_color", RpgMenuTheme.MUTED)
		meta.text = "НЕТ ПРЕДМЕТА"
		meta.add_theme_color_override("font_color", RpgMenuTheme.DIM)
		tooltip_text = "Слот «%s» пуст. Нажмите, чтобы открыть экипировку в инвентаре." % slot_label
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _on_pressed() -> void:
	slot_activated.emit(slot_id, item.id if item != null else &"")
