class_name RpgGlossaryScreen
extends Control
## Глоссарий игрока: бестиарий, обучение, персонажи и места.
##
## Экран намеренно не создаёт лор сам: бестиарий читается из
## resources/campaign/bestiary, обучение — из журнала кампании и Input Map,
## места — из MapAtlas. Записи персонажей подхватываются из
## resources/campaign/glossary/characters, когда отдельная сессия их добавит.
##
## Закрытые записи бестиария показываются как «???» и не раскрывают текст,
## слабость или название. Открытие идёт через NightmareRunState/CampaignGuide.

signal feedback_requested(text: String, tone: StringName)

const BESTIARY_DIR := "res://resources/campaign/bestiary/"
const JOURNAL_DIR := "res://resources/campaign/journal/"
const CHARACTER_DIR := "res://resources/campaign/glossary/characters/"
const MAP_ATLAS_PATH := "res://resources/map/map_atlas.tres"

const SUB_TABS := [
	{"id": &"bestiary", "label": "БЕСТИАРИЙ", "code": "01"},
	{"id": &"training", "label": "ОБУЧЕНИЕ", "code": "02"},
	{"id": &"characters", "label": "ПЕРСОНАЖИ", "code": "03"},
	{"id": &"places", "label": "МЕСТА", "code": "04"},
]

const RECENT_LIMIT := 4

var _active_tab: StringName = &"bestiary"
var _selected_id: StringName = &""
var _entries: Array[Dictionary] = []
var _recent: Array[Dictionary] = []
var _sub_buttons: Dictionary = {}

var _list_title: Label
var _list_count: Label
var _list_box: VBoxContainer
var _recent_box: VBoxContainer
var _recent_empty: Label
var _detail_category: Label
var _detail_title: Label
var _detail_meta: Label
var _detail_body: Label
var _detail_weakness_panel: PanelContainer
var _detail_weakness: Label
var _detail_hint: Label
var _detail_rule: ColorRect


func _ready() -> void:
	theme = RpgMenuTheme.build()
	_build_ui()
	refresh()


func get_active_tab() -> StringName:
	return _active_tab


func get_visible_entries() -> Array[Dictionary]:
	return _entries.duplicate(true)


func get_selected_entry() -> Dictionary:
	for entry in _entries:
		if StringName(entry.get("id", &"")) == _selected_id:
			return entry.duplicate(true)
	return {}


func get_recent_entries() -> Array[Dictionary]:
	return _recent.duplicate(true)


func select_entry(entry_id: StringName) -> bool:
	for entry in _entries:
		if StringName(entry.get("id", &"")) != entry_id:
			continue
		_selected_id = entry_id
		_remember(entry)
		_rebuild_list()
		_rebuild_recent()
		_show_detail(entry)
		return true
	return false


func set_tab(tab_id: StringName) -> void:
	if tab_id == _active_tab:
		return
	for tab in SUB_TABS:
		if StringName(tab["id"]) == tab_id:
			_active_tab = tab_id
			_selected_id = &""
			refresh()
			return


## Сброс кампании не должен оставлять в «Последних статьях» названия
## записей, которые снова стали закрытыми.
func clear_recent() -> void:
	_recent.clear()
	if _recent_box != null:
		_rebuild_recent()


func refresh() -> void:
	_entries = _collect_entries()
	if _entries.is_empty():
		_selected_id = &""
	else:
		var found := false
		for entry in _entries:
			if StringName(entry.get("id", &"")) == _selected_id:
				found = true
				break
		if not found:
			_selected_id = _default_entry_id(_entries)
	_rebuild_recent()
	_rebuild_list()
	_show_detail(get_selected_entry())
	_update_sub_buttons()


func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 2)
	margin.add_theme_constant_override("margin_right", 2)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 9)
	margin.add_child(column)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 2)
	column.add_child(tabs)

	for tab in SUB_TABS:
		var button := Button.new()
		button.text = String(tab["label"])
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_ALL
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.theme_type_variation = &"WitcherSubTab"
		button.custom_minimum_size = Vector2(154, 38)
		button.pressed.connect(_on_sub_tab_pressed.bind(StringName(tab["id"])))
		tabs.add_child(button)
		_sub_buttons[StringName(tab["id"])] = button

	var tab_spacer := Control.new()
	tab_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tabs.add_child(tab_spacer)

	var hint := Label.new()
	hint.text = "ГЛОССАРИЙ · ЗАПИСИ ОТКРЫВАЮТСЯ ПО ХОДУ ИСТОРИИ"
	hint.theme_type_variation = &"TinyMutedLabel"
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tabs.add_child(hint)

	var rule := ColorRect.new()
	rule.custom_minimum_size = Vector2(0, 1)
	rule.color = Color(0.27, 0.25, 0.21, 0.65)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(rule)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 18)
	column.add_child(body)

	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(420, 0)
	left.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 7)
	body.add_child(left)

	var recent_head := HBoxContainer.new()
	recent_head.add_theme_constant_override("separation", 8)
	left.add_child(recent_head)
	var recent_title := Label.new()
	recent_title.text = "ПОСЛЕДНИЕ СТАТЬИ"
	recent_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	recent_title.theme_type_variation = &"SectionLabel"
	recent_head.add_child(recent_title)
	var recent_note := Label.new()
	recent_note.text = "В ЭТОМ СЕАНСЕ"
	recent_note.theme_type_variation = &"TinyMutedLabel"
	recent_head.add_child(recent_note)

	_recent_box = VBoxContainer.new()
	_recent_box.add_theme_constant_override("separation", 2)
	left.add_child(_recent_box)
	_recent_empty = Label.new()
	_recent_empty.text = "Пока ничего не открывали."
	_recent_empty.theme_type_variation = &"MutedLabel"
	left.add_child(_recent_empty)

	var middle_rule := ColorRect.new()
	middle_rule.custom_minimum_size = Vector2(0, 1)
	middle_rule.color = Color(0.24, 0.23, 0.20, 0.5)
	middle_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_child(middle_rule)

	var list_head := HBoxContainer.new()
	list_head.add_theme_constant_override("separation", 8)
	left.add_child(list_head)
	_list_title = Label.new()
	_list_title.text = "БЕСТИАРИЙ"
	_list_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_title.theme_type_variation = &"SectionLabel"
	list_head.add_child(_list_title)
	_list_count = Label.new()
	_list_count.theme_type_variation = &"TinyMutedLabel"
	list_head.add_child(_list_count)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(scroll)

	_list_box = VBoxContainer.new()
	_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_box.add_theme_constant_override("separation", 3)
	scroll.add_child(_list_box)

	var right := PanelContainer.new()
	right.theme_type_variation = &"ParchmentPanel"
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(right)

	var parchment_margin := MarginContainer.new()
	parchment_margin.add_theme_constant_override("margin_left", 30)
	parchment_margin.add_theme_constant_override("margin_right", 30)
	parchment_margin.add_theme_constant_override("margin_top", 24)
	parchment_margin.add_theme_constant_override("margin_bottom", 22)
	right.add_child(parchment_margin)

	var detail := VBoxContainer.new()
	detail.add_theme_constant_override("separation", 6)
	parchment_margin.add_child(detail)

	_detail_category = Label.new()
	_detail_category.theme_type_variation = &"ParchmentOverline"
	detail.add_child(_detail_category)

	_detail_title = Label.new()
	_detail_title.theme_type_variation = &"ParchmentTitle"
	_detail_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.add_child(_detail_title)

	_detail_meta = Label.new()
	_detail_meta.theme_type_variation = &"ParchmentMuted"
	_detail_meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.add_child(_detail_meta)

	_detail_rule = ColorRect.new()
	_detail_rule.custom_minimum_size = Vector2(0, 1)
	_detail_rule.color = Color(0.35, 0.29, 0.19, 0.5)
	_detail_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail.add_child(_detail_rule)

	_detail_body = Label.new()
	_detail_body.theme_type_variation = &"ParchmentBody"
	_detail_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail.add_child(_detail_body)

	_detail_weakness_panel = PanelContainer.new()
	_detail_weakness_panel.theme_type_variation = &"ParchmentInset"
	detail.add_child(_detail_weakness_panel)
	var weakness_box := VBoxContainer.new()
	weakness_box.add_theme_constant_override("separation", 2)
	_detail_weakness_panel.add_child(weakness_box)
	var weakness_caption := Label.new()
	weakness_caption.text = "СЛАБОСТЬ / ПОВАДКА"
	weakness_caption.theme_type_variation = &"ParchmentOverline"
	weakness_box.add_child(weakness_caption)
	_detail_weakness = Label.new()
	_detail_weakness.theme_type_variation = &"ParchmentBody"
	_detail_weakness.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	weakness_box.add_child(_detail_weakness)

	_detail_hint = Label.new()
	_detail_hint.theme_type_variation = &"ParchmentHint"
	_detail_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.add_child(_detail_hint)


func _collect_entries() -> Array[Dictionary]:
	match _active_tab:
		&"training":
			return _collect_training()
		&"characters":
			return _collect_characters()
		&"places":
			return _collect_places()
		_:
			return _collect_bestiary()


func _collect_bestiary() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var resources: Array[Resource] = []
	var guide := get_node_or_null("/root/CampaignGuide")
	if guide != null and guide.has_method(&"get_bestiary_entries"):
		var value: Variant = guide.call(&"get_bestiary_entries")
		if value is Array:
			for item in value:
				if item is Resource:
					resources.append(item)
	if resources.is_empty():
		resources = _load_bestiary_from_disk()

	for entry in resources:
		var entry_id := StringName(entry.get(&"id"))
		if entry_id == &"":
			continue
		var unlocked := _is_bestiary_unlocked(entry_id)
		var event_id := StringName(entry.get(&"unlock_event"))
		var event_label := String(entry.get(&"event_label"))
		var category := String(entry.get(&"category"))
		if category.strip_edges().is_empty():
			category = "Первый Кошмар"
		result.append({
			"id": entry_id,
			"tab": &"bestiary",
			"category": category.to_upper(),
			"title": String(entry.get(&"title")) if unlocked else "",
			"text": String(entry.get(&"text")) if unlocked else "",
			"weakness": String(entry.get(&"weakness")) if unlocked else "",
			"meta": "ОТКРЫТО · %s" % event_label if unlocked and not event_label.is_empty() else "",
			"locked": not unlocked,
			"unlock_event": event_id,
			"unlock_hint": _unlock_hint(event_id),
		})
	_sort_entries(result)
	return result


func _load_bestiary_from_disk() -> Array[Resource]:
	var result: Array[Resource] = []
	var dir := DirAccess.open(BESTIARY_DIR)
	if dir == null:
		return result
	for file in dir.get_files():
		if not file.ends_with(".tres"):
			continue
		var entry := load(BESTIARY_DIR + file) as Resource
		if entry != null:
			result.append(entry)
	return result


func _is_bestiary_unlocked(entry_id: StringName) -> bool:
	var guide := get_node_or_null("/root/CampaignGuide")
	if guide != null and guide.has_method(&"has_bestiary_entry"):
		return bool(guide.call(&"has_bestiary_entry", entry_id))
	var run_state := get_node_or_null("/root/NightmareRunState")
	if run_state != null and run_state.has_method(&"has_bestiary"):
		return bool(run_state.call(&"has_bestiary", entry_id))
	return false


func _unlock_hint(event_id: StringName) -> String:
	match event_id:
		&"seen":
			return "Запись откроется при первой встрече с существом."
		&"defeated":
			return "Запись откроется после победы над существом."
		&"weakness_known":
			return "Запись откроется, когда станет известна слабость."
		_:
			return "Запись откроется по ходу истории."


func _collect_training() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var rules := load(JOURNAL_DIR + "rules_of_nightmare.tres") as Resource
	if rules != null:
		result.append(_journal_entry(rules, &"training", "ОБУЧЕНИЕ"))
	var seen := {}
	for entry in result:
		seen[StringName(entry["id"])] = true

	var guide := get_node_or_null("/root/CampaignGuide")
	if guide != null and guide.has_method(&"get_journal_entries"):
		var value: Variant = guide.call(&"get_journal_entries")
		if value is Array:
			for record in value:
				if not record is Dictionary:
					continue
				if String(record.get("kind", "")) == "bestiary":
					continue
				var entry_id := StringName(record.get("id", &""))
				if entry_id == &"" or seen.has(entry_id):
					continue
				result.append({
					"id": entry_id,
					"tab": &"training",
					"category": "ОБУЧЕНИЕ",
					"title": String(record.get("title", "")),
					"text": String(record.get("text", "")),
					"weakness": "",
					"meta": "ЗАПИСЬ ЖУРНАЛА",
					"locked": false,
					"unlock_event": &"",
					"unlock_hint": "",
				})
				seen[entry_id] = true

	var controls := _controls_entry()
	if controls.get("id", &"") != &"":
		result.append(controls)
	return result


func _journal_entry(entry: Resource, tab: StringName, category: String) -> Dictionary:
	return {
		"id": StringName(entry.get(&"id")),
		"tab": tab,
		"category": category,
		"title": String(entry.get(&"title")),
		"text": String(entry.get(&"text")),
		"weakness": "",
		"meta": "ЗАПИСЬ ЖУРНАЛА",
		"locked": false,
		"unlock_event": &"",
		"unlock_hint": "",
	}


func _controls_entry() -> Dictionary:
	var actions := [
		{"label": "Меню персонажа", "action": &"open_character"},
		{"label": "Рюкзак", "action": &"open_inventory"},
		{"label": "Карта", "action": &"open_map"},
		{"label": "Море Души", "action": &"open_soul_sea"},
		{"label": "Статус", "action": &"open_status"},
		{"label": "Закрыть / освободить мышь", "action": &"release_mouse"},
	]
	var lines: Array[String] = []
	for entry in actions:
		var action := StringName(entry["action"])
		if not InputMap.has_action(action):
			continue
		var keys: Array[String] = []
		for event in InputMap.action_get_events(action):
			var text := _event_text(event)
			if not text.is_empty() and not keys.has(text):
				keys.append(text)
		if not keys.is_empty():
			lines.append("%s — %s" % [String(entry["label"]), " / ".join(keys)])
	if lines.is_empty():
		return {}
	return {
		"id": &"controls",
		"tab": &"training",
		"category": "ОБУЧЕНИЕ",
		"title": "Управление",
		"text": "Клавиши читаются из Input Map проекта.\n\n" + "\n".join(lines),
		"weakness": "",
		"meta": "СПРАВКА · INPUT MAP",
		"locked": false,
		"unlock_event": &"",
		"unlock_hint": "",
	}


func _event_text(event: InputEvent) -> String:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		var code := key_event.physical_keycode
		if code == 0:
			code = key_event.keycode
		return OS.get_keycode_string(code)
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		match mouse_event.button_index:
			MOUSE_BUTTON_LEFT:
				return "ЛКМ"
			MOUSE_BUTTON_RIGHT:
				return "ПКМ"
			MOUSE_BUTTON_MIDDLE:
				return "СКМ"
			_:
				return "Мышь %d" % mouse_event.button_index
	if event is InputEventJoypadButton:
		return "Геймпад %d" % (event as InputEventJoypadButton).button_index
	if event is InputEventJoypadMotion:
		return "Стик"
	return ""


func _collect_characters() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var dir := DirAccess.open(CHARACTER_DIR)
	if dir == null:
		return result
	for file in dir.get_files():
		if not file.ends_with(".tres"):
			continue
		var entry := load(CHARACTER_DIR + file) as Resource
		if entry == null:
			continue
		var entry_id := StringName(entry.get(&"id"))
		if entry_id == &"":
			continue
		result.append({
			"id": entry_id,
			"tab": &"characters",
			"category": "ПЕРСОНАЖИ",
			"title": String(entry.get(&"title")),
			"text": String(entry.get(&"text")),
			"weakness": "",
			"meta": "ЗАПИСЬ ГЛОССАРИЯ",
			"locked": false,
			"unlock_event": &"",
			"unlock_hint": "",
		})
	_sort_entries(result)
	return result


func _collect_places() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var atlas := load(MAP_ATLAS_PATH) as MapAtlas
	if atlas == null:
		return result
	var region := _current_place_region(atlas)
	for location in atlas.locations:
		if location == null:
			continue
		if region != null and not region.has_location(location.id):
			continue
		var location_region := atlas.region_for_location(location.id)
		var meta := "ВНЕ РЕГИОНОВ"
		if location_region != null:
			meta = String(location_region.title).to_upper()
		result.append({
			"id": location.id,
			"tab": &"places",
			"category": "МЕСТА",
			"title": String(location.title),
			"text": String(location.description),
			"weakness": "",
			"meta": meta,
			"locked": false,
			"unlock_event": &"",
			"unlock_hint": "",
		})
	return result


## Не показываем в глоссарии места будущих глав: сначала регион текущей
## сцены, затем регион Первого Кошмара, затем первый доступный регион.
func _current_place_region(atlas: MapAtlas) -> MapRegion:
	var map_system := get_node_or_null("/root/MapSystem")
	if map_system != null and map_system.has_method(&"resolve_current_location"):
		var value: Variant = map_system.call(&"resolve_current_location")
		if value is MapDefinition:
			var current := atlas.region_for_location(value.id)
			if current != null:
				return current
	var first_nightmare := atlas.get_region(&"region_first_nightmare")
	if first_nightmare != null:
		return first_nightmare
	for candidate in atlas.regions:
		if candidate != null and candidate.is_playable():
			return candidate
	return null


func _sort_entries(entries: Array[Dictionary]) -> void:
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_locked := bool(a.get("locked", false))
		var b_locked := bool(b.get("locked", false))
		if a_locked != b_locked:
			return not a_locked
		return String(a.get("title", "")).nocasecmp_to(String(b.get("title", ""))) < 0
	)


func _default_entry_id(entries: Array[Dictionary]) -> StringName:
	for entry in entries:
		if not bool(entry.get("locked", false)):
			return StringName(entry.get("id", &""))
	if not entries.is_empty():
		return StringName(entries[0].get("id", &""))
	return &""


func _remember(entry: Dictionary) -> void:
	if bool(entry.get("locked", false)):
		return
	var key := "%s:%s" % [String(entry.get("tab", &"")), String(entry.get("id", &""))]
	var filtered: Array[Dictionary] = []
	for recent in _recent:
		var recent_key := "%s:%s" % [String(recent.get("tab", &"")), String(recent.get("id", &""))]
		if recent_key != key:
			filtered.append(recent)
	filtered.push_front(entry.duplicate(true))
	while filtered.size() > RECENT_LIMIT:
		filtered.pop_back()
	_recent = filtered


func _rebuild_recent() -> void:
	for child in _recent_box.get_children():
		_recent_box.remove_child(child)
		child.queue_free()
	_recent_empty.visible = _recent.is_empty()
	for entry in _recent:
		_recent_box.add_child(_make_row(entry, true))


func _rebuild_list() -> void:
	for child in _list_box.get_children():
		_list_box.remove_child(child)
		child.queue_free()
	_list_title.text = _tab_title()
	_list_count.text = "%d %s" % [_entries.size(), _records_word(_entries.size())]
	if _entries.is_empty():
		var empty := Label.new()
		empty.text = _empty_text()
		empty.theme_type_variation = &"MutedLabel"
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_list_box.add_child(empty)
		return
	for entry in _entries:
		_list_box.add_child(_make_row(entry, false))


func _make_row(entry: Dictionary, recent: bool) -> Button:
	var button := Button.new()
	button.toggle_mode = true
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.theme_type_variation = &"ListButton"
	button.custom_minimum_size = Vector2(0, 42 if recent else 49)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(_on_row_pressed.bind(entry))
	if not recent:
		button.set_pressed_no_signal(StringName(entry.get("id", &"")) == _selected_id)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 11)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	button.add_child(margin)

	var line := HBoxContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_theme_constant_override("separation", 8)
	margin.add_child(line)

	var text_box := VBoxContainer.new()
	text_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.add_theme_constant_override("separation", 0)
	line.add_child(text_box)

	var title := Label.new()
	var locked := bool(entry.get("locked", false))
	title.text = "???" if locked else String(entry.get("title", ""))
	title.theme_type_variation = &"BodyLabel"
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override(
		"font_color",
		RpgMenuTheme.DIM if locked else RpgMenuTheme.TEXT
	)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_box.add_child(title)

	var category := Label.new()
	category.text = String(entry.get("category", ""))
	category.theme_type_variation = &"TinyMutedLabel"
	category.add_theme_color_override("font_color", RpgMenuTheme.BRONZE_DIM)
	category.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_box.add_child(category)

	if not recent:
		var marker := Label.new()
		marker.text = "◇" if locked else "◆"
		marker.theme_type_variation = &"TinyMutedLabel"
		marker.add_theme_color_override(
			"font_color",
			RpgMenuTheme.BRONZE_DIM if locked else RpgMenuTheme.BRONZE_BRIGHT
		)
		marker.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_child(marker)

	return button


func _show_detail(entry: Dictionary) -> void:
	if entry.is_empty():
		_detail_category.text = "ГЛОССАРИЙ"
		_detail_title.text = "Записей пока нет"
		_detail_meta.text = ""
		_detail_body.text = _empty_text()
		_detail_weakness_panel.visible = false
		_detail_rule.visible = false
		_detail_hint.text = "Новые статьи появятся здесь."
		return

	var locked := bool(entry.get("locked", false))
	var category := String(entry.get("category", ""))
	var tab_title := _tab_title_for(StringName(entry.get("tab", &"")))
	_detail_category.text = category if category == tab_title else "%s · %s" % [tab_title, category]
	_detail_title.text = "НЕИЗВЕСТНАЯ ТВАРЬ" if locked else String(entry.get("title", ""))
	_detail_meta.text = String(entry.get("meta", ""))
	_detail_rule.visible = true
	if locked:
		_detail_body.text = "Запись ещё не открыта. В бестиарии нет ни описания, ни названия, пока Санни не встретит это существо."
		_detail_weakness_panel.visible = false
		_detail_hint.text = String(entry.get("unlock_hint", "Запись откроется по ходу истории."))
		return

	_detail_body.text = String(entry.get("text", ""))
	var weakness := String(entry.get("weakness", "")).strip_edges()
	_detail_weakness_panel.visible = not weakness.is_empty()
	_detail_weakness.text = weakness
	_detail_hint.text = _source_hint(StringName(entry.get("tab", &"")))


func _update_sub_buttons() -> void:
	for tab in SUB_TABS:
		var tab_id := StringName(tab["id"])
		var button := _sub_buttons.get(tab_id, null) as Button
		if button != null:
			button.set_pressed_no_signal(tab_id == _active_tab)


func _tab_title() -> String:
	return _tab_title_for(_active_tab)


func _tab_title_for(tab_id: StringName) -> String:
	match tab_id:
		&"training":
			return "ОБУЧЕНИЕ"
		&"characters":
			return "ПЕРСОНАЖИ"
		&"places":
			return "МЕСТА"
		_:
			return "БЕСТИАРИЙ"


func _source_hint(tab_id: StringName) -> String:
	match tab_id:
		&"training":
			return "ИСТОЧНИК · ЖУРНАЛ КАМПАНИИ"
		&"places":
			return "ИСТОЧНИК · АТЛАС КАРТЫ"
		&"characters":
			return "ИСТОЧНИК · ГЛОССАРИЙ ПЕРСОНАЖЕЙ"
		_:
			return "ИСТОЧНИК · БЕСТИАРИЙ"


func _empty_text() -> String:
	match _active_tab:
		&"characters":
			return "Записи о персонажах ещё не добавлены. Они появятся из отдельной сессии контента."
		&"places":
			return "В атласе пока нет мест."
		&"training":
			return "Статьи обучения ещё не добавлены."
		_:
			return "В бестиарии пока нет записей."


func _records_word(count: int) -> String:
	if count % 10 == 1 and count % 100 != 11:
		return "ЗАПИСЬ"
	if count % 10 >= 2 and count % 10 <= 4 and (count % 100 < 12 or count % 100 > 14):
		return "ЗАПИСИ"
	return "ЗАПИСЕЙ"


func _on_sub_tab_pressed(tab_id: StringName) -> void:
	if tab_id == _active_tab:
		return
	_active_tab = tab_id
	_selected_id = &""
	refresh()
	feedback_requested.emit("Глоссарий: %s." % _tab_title(), &"info")


func _on_row_pressed(entry: Dictionary) -> void:
	var tab_id := StringName(entry.get("tab", &""))
	if tab_id != _active_tab:
		_active_tab = tab_id
		_entries = _collect_entries()
	_selected_id = StringName(entry.get("id", &""))
	var resolved := _find_entry(_selected_id)
	if not resolved.is_empty():
		entry = resolved
	_remember(entry)
	_rebuild_list()
	_rebuild_recent()
	_show_detail(entry)
	_update_sub_buttons()


func _find_entry(entry_id: StringName) -> Dictionary:
	for entry in _entries:
		if StringName(entry.get("id", &"")) == entry_id:
			return entry
	return {}
