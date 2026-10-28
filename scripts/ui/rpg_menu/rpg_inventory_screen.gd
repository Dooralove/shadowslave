class_name RpgInventoryScreen
extends Control
## Трёхколоночный экран инвентаря: категории и фильтры, сетка, описание.
##
## Экран только отображает состояние RpgDemoSession и сообщает о действиях.
## Демо-данные и правила выбора/экипировки живут вне сцены.

signal feedback_requested(text: String, tone: StringName)

const TILE_SCENE := preload("res://scenes/ui/rpg_menu/item_tile.tscn")
const ICON_ALL := preload("res://assets/ui/rpg_menu/icons/all.svg")
const ICON_WEAPON := preload("res://assets/ui/rpg_menu/icons/sword.svg")
const ICON_ARMOR := preload("res://assets/ui/rpg_menu/icons/armor.svg")
const ICON_CONSUMABLE := preload("res://assets/ui/rpg_menu/icons/potion.svg")
const ICON_RESOURCE := preload("res://assets/ui/rpg_menu/icons/ore.svg")
const ICON_STORY := preload("res://assets/ui/rpg_menu/icons/scroll.svg")

@onready var categories_box: VBoxContainer = %Categories
@onready var search_edit: LineEdit = %SearchEdit
@onready var only_new_button: Button = %OnlyNewButton
@onready var reset_button: Button = %ResetButton
@onready var category_title: Label = %CategoryTitle
@onready var category_caption: Label = %CategoryCaption
@onready var item_count_label: Label = %ItemCountLabel
@onready var grid: GridContainer = %Grid
@onready var grid_scroll: ScrollContainer = %GridScroll
@onready var grid_empty: Control = %GridEmpty
@onready var visible_count_label: Label = %VisibleCountLabel
@onready var weight_label: Label = %WeightLabel
@onready var owned_count_label: Label = %OwnedCountLabel
@onready var detail_scroll: ScrollContainer = %DetailScroll
@onready var detail_content: VBoxContainer = %DetailContent
@onready var empty_detail: Control = %EmptyDetail
@onready var detail_icon: TextureRect = %DetailIcon
@onready var detail_icon_panel: PanelContainer = %DetailIconPanel
@onready var detail_rarity: Label = %DetailRarity
@onready var detail_category: Label = %DetailCategory
@onready var detail_title: Label = %DetailTitle
@onready var detail_meta: Label = %DetailMeta
@onready var detail_description: Label = %DetailDescription
@onready var detail_flavor: Label = %DetailFlavor
@onready var stats_section: Control = %StatsSection
@onready var stats_rows: VBoxContainer = %StatsRows
@onready var properties_section: Control = %PropertiesSection
@onready var properties_rows: VBoxContainer = %PropertiesRows
@onready var actions_section: Control = %ActionsSection
@onready var primary_action: Button = %PrimaryAction
@onready var inspect_action: Button = %InspectAction
@onready var drop_action: Button = %DropAction
@onready var action_hint: Label = %ActionHint

var session: RpgDemoSession
var _category_buttons: Array[Dictionary] = []
var _tiles: Array[RpgItemTile] = []
var _syncing := false
var _last_detail_id: StringName = &""
var _action_available := {}
var _action_reasons := {}


func _ready() -> void:
	search_edit.text_changed.connect(_on_search_changed)
	only_new_button.toggled.connect(_on_only_new_toggled)
	reset_button.pressed.connect(_on_reset_pressed)
	primary_action.pressed.connect(_on_primary_pressed)
	inspect_action.pressed.connect(_on_inspect_pressed)
	drop_action.pressed.connect(_on_drop_pressed)


func setup(data: RpgDemoSession) -> void:
	if session != null and session.changed.is_connected(_on_session_changed):
		session.changed.disconnect(_on_session_changed)
	session = data
	if session == null:
		return
	session.changed.connect(_on_session_changed)
	_build_categories()
	refresh(true)


func refresh(reset_scroll := false) -> void:
	if session == null:
		return

	_syncing = true
	only_new_button.button_pressed = session.only_new
	search_edit.text = session.search_text
	_syncing = false

	_update_category_rows()
	_update_headers()
	_rebuild_grid(reset_scroll)
	_refresh_details()


func select_item_by_id(item_id: StringName) -> void:
	if session == null:
		return
	_syncing = true
	search_edit.text = ""
	only_new_button.button_pressed = false
	_syncing = false
	session.set_category(RpgDemoSession.CATEGORY_ALL)
	session.set_search("")
	session.set_only_new(false)
	session.select_item(item_id)
	refresh(true)
	for tile in _tiles:
		if tile.item != null and tile.item.id == item_id:
			tile.grab_focus()
			break


func focus_initial() -> void:
	if not _tiles.is_empty():
		_tiles[0].grab_focus()
	elif not _category_buttons.is_empty():
		(_category_buttons[0]["button"] as Button).grab_focus()


func _build_categories() -> void:
	for child in categories_box.get_children():
		child.queue_free()
	_category_buttons.clear()

	var rows := [
		{"id": RpgDemoSession.CATEGORY_ALL, "label": "ВСЕ ПРЕДМЕТЫ", "icon": ICON_ALL, "index": "01"},
		{"id": RpgDemoItem.Category.WEAPON, "label": "ОРУЖИЕ", "icon": ICON_WEAPON, "index": "02"},
		{"id": RpgDemoItem.Category.ARMOR, "label": "ЭКИПИРОВКА", "icon": ICON_ARMOR, "index": "03"},
		{"id": RpgDemoItem.Category.CONSUMABLE, "label": "РАСХОДНИКИ", "icon": ICON_CONSUMABLE, "index": "04"},
		{"id": RpgDemoItem.Category.RESOURCE, "label": "РЕСУРСЫ", "icon": ICON_RESOURCE, "index": "05"},
		{"id": RpgDemoItem.Category.STORY, "label": "СЮЖЕТНЫЕ", "icon": ICON_STORY, "index": "06"},
	]

	for row in rows:
		var button := _make_category_button(
			int(row["id"]),
			String(row["label"]),
			row["icon"] as Texture2D,
			String(row["index"])
		)
		categories_box.add_child(button)


func _make_category_button(category: int, label_text: String, icon_texture: Texture2D, index_text: String) -> Button:
	var button := Button.new()
	button.theme_type_variation = &"CategoryButton"
	button.toggle_mode = true
	button.custom_minimum_size = Vector2(0, 37)
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(_on_category_pressed.bind(category))

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 10)
	button.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var line := HBoxContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_theme_constant_override("separation", 8)
	margin.add_child(line)

	var index_label := Label.new()
	index_label.text = index_text
	index_label.custom_minimum_size = Vector2(20, 0)
	index_label.theme_type_variation = &"TinyMutedLabel"
	index_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(index_label)

	var icon := TextureRect.new()
	icon.texture = icon_texture
	icon.custom_minimum_size = Vector2(17, 17)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(icon)

	var name_label := Label.new()
	name_label.text = label_text
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.theme_type_variation = &"BodyLabel"
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(name_label)

	var count_label := Label.new()
	count_label.text = "0"
	count_label.theme_type_variation = &"MicroLabel"
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count_label.custom_minimum_size = Vector2(22, 0)
	count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(count_label)

	_category_buttons.append({
		"id": category,
		"button": button,
		"icon": icon,
		"name": name_label,
		"count": count_label,
		"index": index_label,
	})
	return button


func _update_category_rows() -> void:
	for row in _category_buttons:
		var category := int(row["id"])
		var active := session.active_category == category
		var button := row["button"] as Button
		var icon := row["icon"] as TextureRect
		var name_label := row["name"] as Label
		var count_label := row["count"] as Label
		var index_label := row["index"] as Label

		button.button_pressed = active
		count_label.text = str(session.count_category(category))
		name_label.add_theme_color_override(
			"font_color",
			RpgMenuTheme.TEXT_BRIGHT if active else RpgMenuTheme.MUTED
		)
		count_label.add_theme_color_override(
			"font_color",
			RpgMenuTheme.BRONZE_BRIGHT if active else RpgMenuTheme.DIM
		)
		index_label.add_theme_color_override(
			"font_color",
			RpgMenuTheme.BRONZE if active else RpgMenuTheme.DIM
		)
		icon.modulate = RpgMenuTheme.BRONZE_BRIGHT if active else RpgMenuTheme.MUTED


func _update_headers() -> void:
	var visible := session.get_visible_items()
	category_title.text = RpgMenuTheme.category_title(session.active_category)
	category_caption.text = "ДЕМОНСТРАЦИОННЫЙ НАБОР · НЕ КАНОН"
	item_count_label.text = "%d ПРЕДМ." % visible.size()
	visible_count_label.text = "ПОКАЗАНО %d ИЗ %d" % [visible.size(), session.items.size()]
	weight_label.text = "ОБЩИЙ ВЕС: %s ДЕМО-ЕД." % _format_weight(session.total_weight())
	owned_count_label.text = "ЗАПИСЕЙ В НАБОРЕ: %d" % session.items.size()


func _rebuild_grid(reset_scroll: bool) -> void:
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	_tiles.clear()

	if reset_scroll:
		grid_scroll.scroll_vertical = 0

	var visible := session.get_visible_items()
	for item in visible:
		var tile := TILE_SCENE.instantiate() as RpgItemTile
		grid.add_child(tile)
		tile.setup(item)
		tile.set_selected(item.id == session.selected_item_id)
		tile.item_chosen.connect(_on_item_chosen)
		_tiles.append(tile)

	grid.visible = not visible.is_empty()
	grid_empty.visible = visible.is_empty()


func _refresh_details() -> void:
	var item := session.get_selected_item()
	if item == null:
		detail_scroll.visible = false
		empty_detail.visible = true
		actions_section.visible = false
		_last_detail_id = &""
		return

	detail_scroll.visible = true
	empty_detail.visible = false
	actions_section.visible = true

	detail_icon.texture = item.icon
	detail_icon.visible = item.icon != null
	detail_icon_panel.visible = item.icon != null
	detail_rarity.text = RpgMenuTheme.rarity_title(item.rarity)
	detail_rarity.add_theme_color_override("font_color", RpgMenuTheme.rarity_color(item.rarity))
	var category_text := RpgMenuTheme.category_title(item.category)
	if not item.equip_slot.is_empty():
		category_text += " · СЛОТ: %s" % RpgMenuTheme.slot_title(item.equip_slot)
	detail_category.text = category_text
	detail_title.text = item.display_name

	var meta := "КОЛИЧЕСТВО: %d · ВЕС: %s" % [item.quantity, _format_weight(item.stack_weight())]
	if item.equipped:
		meta += " · ЭКИПИРОВАНО"
	detail_meta.text = meta
	detail_description.text = item.description
	detail_flavor.text = "«%s»" % item.flavor if not item.flavor.is_empty() else ""
	detail_flavor.visible = not item.flavor.is_empty()

	_fill_stats(item)
	_fill_properties(item)
	_update_actions(item)

	if _last_detail_id != item.id:
		detail_scroll.scroll_vertical = 0
		_last_detail_id = item.id


func _fill_stats(item: RpgDemoItem) -> void:
	for child in stats_rows.get_children():
		stats_rows.remove_child(child)
		child.queue_free()

	var stat_index := 0
	for entry in item.stats:
		if not entry is RpgDemoStat:
			continue
		var stat := entry as RpgDemoStat
		if stat_index > 0:
			var divider := ColorRect.new()
			divider.custom_minimum_size = Vector2(0, 1)
			divider.color = Color(0.2, 0.195, 0.18, 0.38)
			divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
			stats_rows.add_child(divider)
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 8)
		var label := Label.new()
		label.text = stat.label
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.theme_type_variation = &"MutedLabel"
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(label)
		var value := Label.new()
		value.text = stat.value
		value.theme_type_variation = &"BodyLabel"
		value.add_theme_font_size_override("font_size", 13)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(value)
		stats_rows.add_child(row)
		stat_index += 1

	stats_section.visible = stat_index > 0


func _fill_properties(item: RpgDemoItem) -> void:
	for child in properties_rows.get_children():
		properties_rows.remove_child(child)
		child.queue_free()

	for property_text in item.properties:
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 7)
		var marker := Label.new()
		marker.text = "◆"
		marker.theme_type_variation = &"TinyMutedLabel"
		marker.add_theme_color_override("font_color", RpgMenuTheme.BRONZE_DIM)
		marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(marker)
		var label := Label.new()
		label.text = property_text
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.theme_type_variation = &"MutedLabel"
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(label)
		properties_rows.add_child(row)

	properties_section.visible = not item.properties.is_empty()


func _update_actions(item: RpgDemoItem) -> void:
	_action_available.clear()
	_action_reasons.clear()

	var primary_label := "ИСПОЛЬЗОВАТЬ"
	var primary_available := false
	var primary_reason := ""

	if item.is_gear():
		primary_label = "СНЯТЬ" if item.equipped else "ЭКИПИРОВАТЬ"
		primary_available = true
	elif item.category == RpgDemoItem.Category.CONSUMABLE:
		primary_available = session.can_use(item)
		primary_reason = "Расходник закончился." if not primary_available else ""
	elif item.category == RpgDemoItem.Category.RESOURCE:
		primary_reason = "Ресурс нельзя использовать напрямую."
	else:
		primary_reason = "Сюжетный предмет нельзя использовать."

	var drop_available := session.can_drop(item)
	var drop_reason := ""
	if not drop_available:
		if item.category == RpgDemoItem.Category.STORY:
			drop_reason = "Сюжетный предмет нельзя выбросить в прототипе."
		elif item.equipped:
			drop_reason = "Сначала снимите предмет."
		else:
			drop_reason = "Действие недоступно для этого предмета."

	_action_available = {
		"primary": primary_available,
		"inspect": true,
		"drop": drop_available,
	}
	_action_reasons = {
		"primary": primary_reason,
		"inspect": "",
		"drop": drop_reason,
	}

	primary_action.text = primary_label
	primary_action.theme_type_variation = &"PrimaryButton" if primary_available else &"UnavailableActionButton"
	primary_action.tooltip_text = primary_reason if not primary_available else "Изменить состояние демонстрационного предмета."
	drop_action.theme_type_variation = &"DangerButton" if drop_available else &"UnavailableActionButton"
	drop_action.tooltip_text = drop_reason if not drop_available else "Удалить одну единицу из демо-набора."
	inspect_action.tooltip_text = "Показать короткую заметку о предмете."

	var hint := ""
	var hint_color := RpgMenuTheme.MUTED
	if not primary_available and not primary_reason.is_empty():
		hint = "Недоступно: %s" % primary_reason
		hint_color = RpgMenuTheme.RUST
	elif not drop_available and not drop_reason.is_empty():
		hint = "Недоступно: %s" % drop_reason
		hint_color = RpgMenuTheme.RUST
	else:
		hint = "Действия меняют только локальный демо-набор."
	action_hint.text = hint
	action_hint.add_theme_color_override("font_color", hint_color)


func _on_category_pressed(category: int) -> void:
	if session == null:
		return
	session.set_category(category)
	refresh(true)
	feedback_requested.emit(
		"%s · %d" % [RpgMenuTheme.category_title(category), session.count_category(category)],
		&"info"
	)


func _on_search_changed(text: String) -> void:
	if _syncing or session == null:
		return
	session.set_search(text)
	refresh(true)


func _on_only_new_toggled(enabled: bool) -> void:
	if _syncing or session == null:
		return
	session.set_only_new(enabled)
	refresh(true)


func _on_reset_pressed() -> void:
	if session == null:
		return
	_syncing = true
	search_edit.text = ""
	only_new_button.button_pressed = false
	_syncing = false
	session.set_category(RpgDemoSession.CATEGORY_ALL)
	session.set_search("")
	session.set_only_new(false)
	refresh(true)
	feedback_requested.emit("Фильтры сброшены. Показан весь демо-набор.", &"info")


func _on_item_chosen(item_id: StringName) -> void:
	if session == null:
		return
	if not session.select_item(item_id):
		return
	for tile in _tiles:
		tile.set_selected(tile.item != null and tile.item.id == item_id)
	_refresh_details()


func _on_primary_pressed() -> void:
	var item := session.get_selected_item() if session != null else null
	if item == null:
		return
	if not bool(_action_available.get("primary", false)):
		_warn(String(_action_reasons.get("primary", "Действие недоступно.")))
		return

	if item.is_gear():
		if item.equipped:
			if session.unequip_item(item):
				feedback_requested.emit("Снято: %s." % item.display_name, &"success")
		else:
			if session.equip_item(item):
				feedback_requested.emit("Экипировано: %s." % item.display_name, &"success")
	elif item.category == RpgDemoItem.Category.CONSUMABLE:
		var name := item.display_name
		var remaining := item.quantity - 1
		if session.consume_item(item):
			if remaining > 0:
				feedback_requested.emit("Использовано: %s. Осталось: %d." % [name, remaining], &"success")
			else:
				feedback_requested.emit("Использована последняя порция: %s." % name, &"success")


func _on_inspect_pressed() -> void:
	var item := session.get_selected_item() if session != null else null
	if item == null:
		return
	var detail := item.flavor.strip_edges()
	if detail.is_empty():
		detail = item.description.strip_edges()
	feedback_requested.emit("Осмотр: %s" % detail, &"info")


func _on_drop_pressed() -> void:
	var item := session.get_selected_item() if session != null else null
	if item == null:
		return
	if not bool(_action_available.get("drop", false)):
		_warn(String(_action_reasons.get("drop", "Действие недоступно.")))
		return
	var name := item.display_name
	if session.drop_item(item):
		feedback_requested.emit("Удалено из демо-набора: %s (×1)." % name, &"info")


func _on_session_changed() -> void:
	refresh(false)


func _warn(text: String) -> void:
	feedback_requested.emit(text, &"warning")


func _format_weight(value: float) -> String:
	return String.num(value, 1).replace(".", ",")
