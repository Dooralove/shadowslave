class_name RpgMenuPrototype
extends Control
## Автономный презентационный прототип RPG-меню.
##
## Журнал, карта и глоссарий читают живое состояние. Инвентарь, персонаж и
## умения пока остаются прототипами на RpgDemoSession и не выдаются за канон.
## В игре этот же экран показывает PlayerMenuSystem как модальный слой поверх
## приостановленного игрового процесса.

signal close_requested

const DEMO_CATALOG := preload("res://resources/rpg_menu/demo_catalog.tres")
const ASPECT_TREE := preload("res://resources/rpg_menu/aspect_demo.tres")
const GLOSSARY_SCENE := preload("res://scenes/ui/rpg_menu/glossary_screen.tscn")
const MAP_SECTION_SCENE := preload("res://scenes/ui/rpg_menu/map_screen.tscn")
const MEDITATION_SCENE := preload("res://scenes/ui/rpg_menu/meditation_screen.tscn")
const DESIGN_SIZE := Vector2(1600.0, 900.0)
const DEFAULT_FEEDBACK := "ПЕРВЫЙ КОШМАР · МЕНЮ ПУТЕШЕСТВИЯ"
const BEAT_DIR := "res://resources/campaign/beats/"

## Порядок повторяет логику справочника «Ведьмака 3»: сначала знания, затем
## снаряжение и карта, потом задачи, развитие и безопасная пауза.
const NAV_SECTIONS := [
	{"id": &"glossary", "label": "ГЛОССАРИЙ", "icon": "res://assets/ui/rpg_menu/icons/book.svg"},
	{"id": &"memories", "label": "ПАМЯТИ", "icon": "res://assets/ui/rpg_menu/icons/amulet.svg"},
	{"id": &"inventory", "label": "РЮКЗАК", "icon": "res://assets/ui/rpg_menu/icons/armor.svg"},
	{"id": &"map", "label": "КАРТА МИРА", "icon": "res://assets/ui/rpg_menu/icons/map.svg"},
	{"id": &"journal", "label": "ЗАДАНИЯ", "icon": "res://assets/ui/rpg_menu/icons/scroll.svg"},
	{"id": &"character", "label": "ПЕРСОНАЖ", "icon": "res://assets/ui/rpg_menu/icons/cloak.svg"},
	{"id": &"aspect", "label": "УМЕНИЯ", "icon": "res://assets/ui/rpg_menu/icons/dagger.svg"},
	{"id": &"meditation", "label": "МЕДИТАЦИЯ", "icon": "res://assets/ui/rpg_menu/icons/herb.svg"},
]

const START_INDEX := [
	{"code": "01", "label": "ГЛОССАРИЙ / БЕСТИАРИЙ", "state": "РАБОТАЕТ", "tone": &"ready"},
	{"code": "02", "label": "ПАМЯТИ", "state": "ЧЕРНОВИК", "tone": &"draft"},
	{"code": "03", "label": "РЮКЗАК", "state": "ПРОТОТИП", "tone": &"draft"},
	{"code": "04", "label": "КАРТА МИРА", "state": "РАБОТАЕТ", "tone": &"ready"},
	{"code": "05", "label": "ЗАДАНИЯ", "state": "ЖИВОЙ ЖУРНАЛ", "tone": &"ready"},
	{"code": "06", "label": "ПЕРСОНАЖ", "state": "ПРОТОТИП", "tone": &"draft"},
	{"code": "07", "label": "УМЕНИЯ", "state": "ПРОТОТИП", "tone": &"draft"},
	{"code": "08", "label": "МЕДИТАЦИЯ", "state": "РАБОТАЕТ", "tone": &"ready"},
]

const DRAFT_CONFIGS := {
	&"memories": {
		"id": &"memories",
		"overline": "РАЗДЕЛ 04 · ПАМЯТИ",
		"title": "ПАМЯТИ",
		"code": "04",
		"description": "Раздел зарезервирован под каталог Памятей, Эхо и связанные с ними ограничения. Сейчас здесь намеренно нет списка предметов, сравнений и действий: данные для этого раздела ещё не определены.",
		"caption": "ЧЕРНОВИК",
		"summary": "Заглушка не заменяет будущий каталог Памятей и не выдаёт тестовые предметы за канонические.",
		"features": [
			"Каталог Памятей с редкостью и описаниями",
			"Эхо и их роль",
			"Сравнение характеристик",
			"Слоты и ограничения экипировки",
		],
		"button": "ОТКРЫТЬ ИНВЕНТАРЬ",
	},
	&"journal": {
		"id": &"journal",
		"overline": "РАЗДЕЛ 05 · ЖУРНАЛ",
		"title": "ЖУРНАЛ",
		"code": "05",
		"description": "Раздел зарезервирован под записи о мире, персонажах и путешествии. Заглушка не создаёт фальшивых задач, наград или отметок прогресса и не связана с историей игры.",
		"caption": "ЧЕРНОВИК",
		"summary": "Журнал не подключён к сюжету, сохранениям и состоянию кампании. Здесь пока нет игровых записей.",
		"features": [
			"Записи о мире и персонажах",
			"Активные задачи и цели",
			"Хронология событий",
			"Поиск и категории записей",
		],
		"button": "ОТКРЫТЬ ИНВЕНТАРЬ",
	},
}

@onready var content: Control = %Content
@onready var start_page: Control = %StartPage
@onready var menu_page: Control = %MenuPage
@onready var workspace: Control = %Workspace
@onready var nav_box: HBoxContainer = %NavBox
@onready var start_button: Button = %StartButton
@onready var start_index_rows: VBoxContainer = %StartIndexRows
@onready var start_metrics: GridContainer = %StartMetrics
@onready var nav_inventory: Button = %NavInventory
@onready var nav_character: Button = %NavCharacter
@onready var nav_aspect: Button = %NavAspect
@onready var nav_memories: Button = %NavMemories
@onready var nav_journal: Button = %NavJournal
@onready var trade_button: Button = %TradeButton
@onready var close_button: Button = %CloseButton
@onready var inventory_screen: RpgInventoryScreen = %InventoryScreen
@onready var character_screen: RpgCharacterScreen = %CharacterScreen
@onready var aspect_screen: RpgAspectScreen = %AspectScreen
@onready var draft_screen: RpgDraftScreen = %DraftScreen
@onready var quest_screen = %QuestScreen
@onready var trade_screen: RpgTradeScreen = %TradeScreen
@onready var feedback_label: Label = %FeedbackLabel
@onready var feedback_marker: ColorRect = %FeedbackMarker
@onready var feedback_timer: Timer = %FeedbackTimer
@onready var wallet_label: Label = %WalletLabel
@onready var session_index: Label = %SessionIndex

var session: RpgDemoSession
var glossary_screen: RpgGlossaryScreen
var map_section: RpgMapScreen
var meditation_screen: RpgMeditationScreen
var nav_glossary: Button
var nav_map: Button
var nav_meditation: Button

var _screens: Dictionary = {}
var _nav_buttons: Dictionary = {}
var _nav_visuals: Dictionary = {}
var _active_section: StringName = &""
var _start_metric_labels: Dictionary = {}
var _summary_labels: Dictionary = {}
var _summary_captions: Dictionary = {}
var _summary_progress: ProgressBar
var _summary_bar: HBoxContainer
var _beat_total := 0


func _ready() -> void:
	theme = RpgMenuTheme.build()
	content.pivot_offset = Vector2.ZERO
	content.resized.connect(_layout_content)
	get_viewport().size_changed.connect(_layout_content)
	_layout_content()

	session = RpgDemoSession.new()
	session.initialize(DEMO_CATALOG)
	var player := get_tree().get_first_node_in_group(&"player")
	if player != null:
		var equipment := player.get_node_or_null(^"Equipment") as EquipmentComponent
		if equipment != null:
			session.set_equipment_component(equipment)
	session.changed.connect(_on_session_changed)

	_build_section_screens()
	_screens = {
		&"glossary": glossary_screen,
		&"inventory": inventory_screen,
		&"character": character_screen,
		&"aspect": aspect_screen,
		&"memories": draft_screen,
		&"journal": quest_screen,
		&"map": map_section,
		&"meditation": meditation_screen,
		&"trade": trade_screen,
	}
	_build_summary_bar()
	_build_nav()
	# Демонстрационная торговля не входит в демо-маршрут и не должна
	# выглядеть как рабочая экономика в живом прохождении.
	trade_button.visible = get_tree().get_first_node_in_group(&"player") == null

	start_button.pressed.connect(_on_start_pressed)
	trade_button.pressed.connect(show_section.bind(&"trade"))
	close_button.pressed.connect(close_menu)
	feedback_timer.timeout.connect(_reset_feedback)

	inventory_screen.feedback_requested.connect(_show_feedback)
	character_screen.feedback_requested.connect(_show_feedback)
	character_screen.item_requested.connect(_on_character_item_requested)
	aspect_screen.feedback_requested.connect(_show_feedback)
	aspect_screen.navigate_requested.connect(_on_navigate_requested)
	glossary_screen.feedback_requested.connect(_show_feedback)
	trade_screen.feedback_requested.connect(_show_feedback)
	trade_screen.navigate_requested.connect(_on_navigate_requested)
	quest_screen.connect("feedback_requested", _show_feedback)
	quest_screen.connect("navigate_requested", _on_navigate_requested)
	draft_screen.navigate_requested.connect(_on_navigate_requested)
	meditation_screen.feedback_requested.connect(_show_feedback)
	meditation_screen.return_requested.connect(_on_meditation_return)

	inventory_screen.setup(session)
	character_screen.setup(session)
	aspect_screen.setup(ASPECT_TREE)
	trade_screen.setup(session)
	map_section.setup(_map_atlas())
	_configure_draft(&"memories")
	_connect_run_state()
	_build_start_index()
	_build_start_metrics()
	_on_session_changed()

	start_page.visible = true
	menu_page.visible = false
	_clear_screen_visibility()
	_reset_feedback()
	_start_content_scale_check()
	start_button.grab_focus()


func _build_section_screens() -> void:
	glossary_screen = GLOSSARY_SCENE.instantiate() as RpgGlossaryScreen
	map_section = MAP_SECTION_SCENE.instantiate() as RpgMapScreen
	meditation_screen = MEDITATION_SCENE.instantiate() as RpgMeditationScreen
	for screen in [glossary_screen, map_section, meditation_screen]:
		if screen == null:
			continue
		screen.visible = false
		workspace.add_child(screen)
		(screen as Control).set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _build_summary_bar() -> void:
	var root_column := menu_page.get_node("MenuMargin/RootColumn") as VBoxContainer
	if root_column == null:
		return
	_summary_bar = HBoxContainer.new()
	_summary_bar.name = "SummaryBar"
	_summary_bar.custom_minimum_size = Vector2(0, 24)
	_summary_bar.add_theme_constant_override("separation", 18)
	root_column.add_child(_summary_bar)
	root_column.move_child(_summary_bar, 0)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_summary_bar.add_child(spacer)

	for item in [
		{"key": &"items", "caption": "ПРЕДМЕТЫ", "value": "0"},
		{"key": &"bestiary", "caption": "ЗАПИСИ", "value": "0 / 0"},
		{"key": &"beat", "caption": "СОБЫТИЕ", "value": "—"},
	]:
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 0)
		box.custom_minimum_size = Vector2(96, 0)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_summary_bar.add_child(box)

		var caption := Label.new()
		caption.text = String(item["caption"])
		caption.theme_type_variation = &"SummaryCaption"
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(caption)
		_summary_captions[item["key"]] = caption

		var value := Label.new()
		value.text = String(item["value"])
		value.theme_type_variation = &"SummaryValue"
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(value)
		_summary_labels[item["key"]] = value

	_summary_progress = ProgressBar.new()
	_summary_progress.custom_minimum_size = Vector2(120, 4)
	_summary_progress.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_summary_progress.show_percentage = false
	_summary_progress.max_value = 100.0
	_summary_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_summary_bar.add_child(_summary_progress)


func _build_nav() -> void:
	if nav_box == null:
		return
	for child in nav_box.get_children():
		nav_box.remove_child(child)
		# Кнопки из сцены заменяются один раз в _ready, вне обработки их
		# сигналов, поэтому освобождаем сразу — без orphan-узлов.
		child.free()
	_nav_buttons.clear()
	_nav_visuals.clear()

	for item in NAV_SECTIONS:
		var section := StringName(item["id"])
		var icon_path := String(item["icon"])
		var icon := load(icon_path) as Texture2D
		var button := Button.new()
		button.name = "Nav%s" % String(section).capitalize()
		button.text = ""
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_ALL
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.theme_type_variation = &"WitcherTab"
		button.custom_minimum_size = Vector2(0, 54)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(show_section.bind(section))
		nav_box.add_child(button)

		var margin := MarginContainer.new()
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		margin.add_theme_constant_override("margin_left", 4)
		margin.add_theme_constant_override("margin_right", 4)
		margin.add_theme_constant_override("margin_top", 3)
		margin.add_theme_constant_override("margin_bottom", 3)
		button.add_child(margin)

		var line := VBoxContainer.new()
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.alignment = BoxContainer.ALIGNMENT_CENTER
		line.add_theme_constant_override("separation", 1)
		margin.add_child(line)

		var icon_rect := TextureRect.new()
		icon_rect.texture = icon
		icon_rect.custom_minimum_size = Vector2(20, 20)
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_child(icon_rect)

		var label := Label.new()
		label.text = String(item["label"])
		label.theme_type_variation = &"TinyMutedLabel"
		label.add_theme_font_size_override("font_size", 9)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_child(label)

		_nav_buttons[section] = button
		_nav_visuals[section] = {"icon": icon_rect, "label": label}

	# Совместимость с тестами и внешними вызовами: те же имена, что были
	# в сцене до перехода на восемь категорий.
	nav_glossary = _nav_buttons.get(&"glossary") as Button
	nav_inventory = _nav_buttons.get(&"inventory") as Button
	nav_character = _nav_buttons.get(&"character") as Button
	nav_aspect = _nav_buttons.get(&"aspect") as Button
	nav_memories = _nav_buttons.get(&"memories") as Button
	nav_journal = _nav_buttons.get(&"journal") as Button
	nav_map = _nav_buttons.get(&"map") as Button
	nav_meditation = _nav_buttons.get(&"meditation") as Button


func _update_nav_styles() -> void:
	for section in _nav_buttons:
		var button := _nav_buttons[section] as Button
		var visual: Dictionary = _nav_visuals.get(section, {})
		var active := StringName(section) == _active_section
		button.set_pressed_no_signal(active)
		var icon := visual.get("icon", null) as TextureRect
		var label := visual.get("label", null) as Label
		if icon != null:
			icon.modulate = RpgMenuTheme.INK if active else RpgMenuTheme.MUTED
		if label != null:
			label.add_theme_color_override(
				"font_color",
				RpgMenuTheme.INK if active else RpgMenuTheme.MUTED
			)


func _map_atlas() -> MapAtlas:
	var map_system := get_node_or_null("/root/MapSystem")
	if map_system != null and map_system.get(&"atlas") is MapAtlas:
		return map_system.get(&"atlas") as MapAtlas
	return load("res://resources/map/map_atlas.tres") as MapAtlas


func _connect_run_state() -> void:
	var run_state := get_node_or_null("/root/NightmareRunState")
	if run_state == null:
		return
	if run_state.has_signal(&"bestiary_unlocked") and not run_state.is_connected(&"bestiary_unlocked", _on_run_bestiary_unlocked):
		run_state.connect(&"bestiary_unlocked", _on_run_bestiary_unlocked)
	if run_state.has_signal(&"item_changed") and not run_state.is_connected(&"item_changed", _on_run_item_changed):
		run_state.connect(&"item_changed", _on_run_item_changed)
	if run_state.has_signal(&"flag_changed") and not run_state.is_connected(&"flag_changed", _on_run_flag_changed):
		run_state.connect(&"flag_changed", _on_run_flag_changed)
	if run_state.has_signal(&"state_reset") and not run_state.is_connected(&"state_reset", _on_run_state_reset):
		run_state.connect(&"state_reset", _on_run_state_reset)
	if run_state.has_signal(&"state_restored") and not run_state.is_connected(&"state_restored", _on_run_state_reset):
		run_state.connect(&"state_restored", _on_run_state_reset)
	if run_state.has_signal(&"beat_changed") and not run_state.is_connected(&"beat_changed", _on_run_beat_changed):
		run_state.connect(&"beat_changed", _on_run_beat_changed)


func _on_run_bestiary_unlocked(_entry_id: StringName, _event_id: StringName) -> void:
	_refresh_after_run_state()


func _on_run_item_changed(_id: StringName, _count: int) -> void:
	_refresh_after_run_state()


func _on_run_flag_changed(_name: StringName, _value: bool) -> void:
	_refresh_after_run_state()


func _on_run_beat_changed(_beat_id: StringName) -> void:
	_refresh_after_run_state()


func _on_run_state_reset() -> void:
	if glossary_screen != null:
		glossary_screen.clear_recent()
	_refresh_after_run_state()


func _refresh_after_run_state() -> void:
	if glossary_screen != null:
		glossary_screen.refresh()
	if meditation_screen != null:
		meditation_screen.refresh()
	_refresh_summary()


func _refresh_summary() -> void:
	if _summary_labels.is_empty():
		return
	var run_state := get_node_or_null("/root/NightmareRunState")
	var quests := get_node_or_null("/root/QuestSystem")
	if quests != null and quests.has_method(&"is_scope_active") and bool(quests.call(&"is_scope_active")):
		var shards := 0
		if run_state != null and run_state.has_method(&"get_currency"):
			shards = int(run_state.call(&"get_currency", &"soul_shard"))
		var journal: Variant = quests.call(&"get_journal_entries")
		var total := (journal as Array).size() if journal is Array else 0
		var completed := 0
		if journal is Array:
			for entry in journal:
				if int(entry.get(&"status")) == 2:
					completed += 1
		var tracked: Variant = quests.call(&"get_tracked_quest")
		var target := "—"
		if tracked != null:
			var code := String(tracked.get(&"code")).strip_edges()
			target = code if not code.is_empty() else String(tracked.get(&"title"))
		_set_summary_caption(&"items", "ОСКОЛКИ")
		_set_summary_caption(&"bestiary", "ЗАДАНИЯ")
		_set_summary_caption(&"beat", "ЦЕЛЬ")
		(_summary_labels[&"items"] as Label).text = str(shards)
		(_summary_labels[&"bestiary"] as Label).text = "%d / %d" % [completed, total]
		(_summary_labels[&"beat"] as Label).text = target
		if _summary_progress != null:
			_summary_progress.value = (float(completed) / float(maxi(total, 1))) * 100.0
		return

	_set_summary_caption(&"items", "ПРЕДМЕТЫ")
	_set_summary_caption(&"bestiary", "БЕСТИАРИЙ")
	_set_summary_caption(&"beat", "СОБЫТИЕ")
	var items := 0
	if run_state != null and run_state.has_method(&"get_item_count"):
		var ids: Variant = run_state.get(&"ITEM_IDS")
		if ids is Array:
			for id in ids:
				items += int(run_state.call(&"get_item_count", id))
	(_summary_labels[&"items"] as Label).text = str(items)

	var bestiary_unlocked := 0
	var bestiary_total := 0
	var guide := get_node_or_null("/root/CampaignGuide")
	var entries: Variant = []
	if guide != null and guide.has_method(&"get_bestiary_entries"):
		entries = guide.call(&"get_bestiary_entries")
		if entries is Array:
			bestiary_total = entries.size()
	if run_state != null and run_state.has_method(&"get_bestiary_ids"):
		var ids: Variant = run_state.call(&"get_bestiary_ids")
		if ids is Array:
			bestiary_unlocked = ids.size()
	elif entries is Array and guide != null and guide.has_method(&"has_bestiary_entry"):
		for entry in entries:
			if entry is Resource and bool(guide.call(&"has_bestiary_entry", entry.get(&"id"))):
				bestiary_unlocked += 1
	if bestiary_total == 0:
		var dir := DirAccess.open("res://resources/campaign/bestiary/")
		if dir != null:
			for file in dir.get_files():
				if file.ends_with(".tres"):
					bestiary_total += 1
	(_summary_labels[&"bestiary"] as Label).text = "%d / %d" % [bestiary_unlocked, bestiary_total]

	var beat := &""
	if run_state != null and run_state.has_method(&"get_current_beat"):
		beat = StringName(run_state.call(&"get_current_beat"))
	(_summary_labels[&"beat"] as Label).text = String(beat) if beat != &"" else "—"
	if _summary_progress != null:
		if _beat_total <= 0:
			_beat_total = _count_beats()
		var beat_index := _beat_index(beat)
		_summary_progress.value = (
			clampf(float(beat_index) / float(maxi(_beat_total, 1)), 0.0, 1.0) * 100.0
			if beat_index > 0
			else 0.0
		)


func _set_summary_caption(key: StringName, text: String) -> void:
	var caption := _summary_captions.get(key, null) as Label
	if caption != null:
		caption.text = text


func _count_beats() -> int:
	var dir := DirAccess.open(BEAT_DIR)
	if dir == null:
		return 0
	var count := 0
	for file in dir.get_files():
		if file.ends_with(".tres"):
			count += 1
	return count


func _beat_index(beat: StringName) -> int:
	var text := String(beat)
	if text.is_empty():
		return 0
	var number := text.substr(1).to_int()
	if text.begins_with("N") or text.begins_with("P"):
		return number
	return 0


func _on_meditation_return() -> void:
	var player := get_tree().get_first_node_in_group(&"player")
	var recovery := player.get_node_or_null(^"FallRecovery") if player != null else null
	close_menu()
	if recovery != null and recovery.has_method(&"recover"):
		recovery.call(&"recover")
		_show_feedback("Возврат к последней точке.", &"success")


func get_active_section() -> StringName:
	return _active_section


func is_section_visible(section: StringName) -> bool:
	return _screens.has(section) and (_screens[section] as Control).visible


func open_menu(section: StringName = &"inventory") -> void:
	start_page.visible = false
	menu_page.visible = true
	show_section(section)


func close_menu() -> void:
	if not menu_page.visible:
		return
	menu_page.visible = false
	start_page.visible = true
	_active_section = &""
	_clear_screen_visibility()
	feedback_timer.stop()
	_reset_feedback()
	start_button.grab_focus()
	close_requested.emit()


func show_section(section: StringName) -> void:
	if not _screens.has(section):
		return
	_active_section = section
	feedback_timer.stop()
	_reset_feedback()
	for screen in _screens.values():
		(screen as Control).visible = false
	var active_screen := _screens[section] as Control
	active_screen.visible = true
	_update_nav_styles()
	trade_button.set_pressed_no_signal(section == &"trade")
	wallet_label.visible = section == &"trade"

	if section == &"memories":
		_configure_draft(&"memories")
	if section == &"aspect":
		aspect_screen.focus_initial()
	if section == &"glossary":
		glossary_screen.refresh()
	if section == &"map":
		map_section.refresh_from_game()
	if section == &"meditation":
		meditation_screen.refresh()
	if section == &"journal":
		quest_screen.refresh()
	_refresh_summary()
	_apply_demo_summary_override()

	match section:
		&"glossary":
			session_index.text = "ГЛОССАРИЙ · БЕСТИАРИЙ / ОБУЧЕНИЕ / МЕСТА"
		&"inventory":
			session_index.text = "РЮКЗАК · ЛОКАЛЬНЫЙ ДЕМО-НАБОР"
		&"character":
			session_index.text = "ПЕРСОНАЖ · СТАТУС И СНАРЯЖЕНИЕ"
		&"aspect":
			session_index.text = "УМЕНИЯ · DEMO-ДЕРЕВО"
		&"memories":
			session_index.text = "ПАМЯТИ · ЧЕРНОВИК"
		&"journal":
			session_index.text = "ЗАДАНИЯ · ЖУРНАЛ КАМПАНИИ"
		&"map":
			session_index.text = "КАРТА МИРА · РЕГИОН И МЕСТА"
		&"meditation":
			session_index.text = "МЕДИТАЦИЯ · ТОЧКА ВОЗВРАТА"
		&"trade":
			session_index.text = "ТОРГОВЛЯ · ОТДЕЛЬНЫЙ ДЕМО-ВХОД"
		_:
			session_index.text = "ПЕРВЫЙ КОШМАР · МЕНЮ ПУТЕШЕСТВИЯ"


func _unhandled_input(event: InputEvent) -> void:
	if not menu_page.visible:
		return
	if event.is_action_pressed(&"release_mouse") or event.is_action_pressed(&"ui_cancel"):
		close_menu()
		get_viewport().set_input_as_handled()


func _configure_draft(section: StringName) -> void:
	var config: Dictionary = DRAFT_CONFIGS.get(section, DRAFT_CONFIGS[&"memories"])
	draft_screen.setup(config)


func _build_start_index() -> void:
	for child in start_index_rows.get_children():
		start_index_rows.remove_child(child)
		child.queue_free()

	for index in START_INDEX.size():
		var entry: Dictionary = START_INDEX[index]
		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2(0, 28)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 9)

		var code := Label.new()
		code.text = String(entry["code"])
		code.custom_minimum_size = Vector2(22, 0)
		code.theme_type_variation = &"TinyMutedLabel"
		code.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(code)

		var label := Label.new()
		label.text = String(entry["label"])
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.theme_type_variation = &"BodyLabel"
		label.add_theme_font_size_override("font_size", 13)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(label)

		var tone := StringName(entry["tone"])
		var marker := Label.new()
		marker.text = "◆"
		marker.theme_type_variation = &"TinyMutedLabel"
		marker.add_theme_color_override(
			"font_color",
			RpgMenuTheme.BRONZE if tone == &"ready" or tone == &"trade" else RpgMenuTheme.DIM
		)
		marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(marker)

		var state := Label.new()
		state.text = String(entry["state"])
		state.theme_type_variation = &"TinyMutedLabel"
		state.add_theme_color_override(
			"font_color",
			RpgMenuTheme.BRONZE_BRIGHT if tone == &"ready" else (
				RpgMenuTheme.BRONZE if tone == &"trade" else RpgMenuTheme.DIM
			)
		)
		state.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		state.custom_minimum_size = Vector2(86, 0)
		state.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(state)
		start_index_rows.add_child(row)

		if index < START_INDEX.size() - 1:
			var divider := ColorRect.new()
			divider.custom_minimum_size = Vector2(0, 1)
			divider.color = Color(0.22, 0.21, 0.19, 0.36)
			divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
			start_index_rows.add_child(divider)


func _build_start_metrics() -> void:
	for child in start_metrics.get_children():
		start_metrics.remove_child(child)
		child.queue_free()
	_start_metric_labels.clear()

	var entries := [
		{"key": &"items", "label": "ПРЕДМЕТОВ"},
		{"key": &"slots", "label": "СЛОТОВ"},
		{"key": &"offers", "label": "ЛОТА У ТОРГОВЦА"},
		{"key": &"coins", "label": "ДЕМО-МОНЕТ"},
	]
	for entry in entries:
		var panel := PanelContainer.new()
		panel.theme_type_variation = &"SubPanel"
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		start_metrics.add_child(panel)

		var line := HBoxContainer.new()
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_theme_constant_override("separation", 8)
		panel.add_child(line)

		var value := Label.new()
		value.theme_type_variation = &"DisplayValue"
		value.add_theme_font_size_override("font_size", 24)
		value.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_child(value)

		var label := Label.new()
		label.text = String(entry["label"])
		label.theme_type_variation = &"TinyMutedLabel"
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_child(label)
		_start_metric_labels[entry["key"]] = value
	_update_start_metrics()


func _update_start_metrics() -> void:
	if _start_metric_labels.is_empty():
		return
	(_start_metric_labels[&"items"] as Label).text = str(session.items.size())
	(_start_metric_labels[&"slots"] as Label).text = "6"
	(_start_metric_labels[&"offers"] as Label).text = str(session.offers.size())
	(_start_metric_labels[&"coins"] as Label).text = str(session.demo_coins)


func _on_start_pressed() -> void:
	open_menu(&"inventory")
	_show_feedback("Демо-меню открыто. Выберите раздел в верхней навигации.", &"info")


func _on_character_item_requested(item_id: StringName) -> void:
	if not _screens.has(&"inventory"):
		return
	var item := session.get_item(item_id)
	show_section(&"inventory")
	inventory_screen.select_item_by_id(item_id)
	if item != null:
		_show_feedback("Открыт предмет из снаряжения: %s." % item.display_name, &"info")


func _on_navigate_requested(section: StringName) -> void:
	show_section(section)


func _show_feedback(text: String, tone: StringName) -> void:
	feedback_label.text = text
	var color := RpgMenuTheme.TEXT
	match tone:
		&"success":
			color = RpgMenuTheme.SUCCESS
		&"warning":
			color = RpgMenuTheme.RUST
		_:
			color = RpgMenuTheme.TEXT
	feedback_label.add_theme_color_override("font_color", color)
	feedback_marker.color = RpgMenuTheme.BRONZE_BRIGHT if tone == &"success" else (
		RpgMenuTheme.RUST if tone == &"warning" else RpgMenuTheme.BRONZE_DIM
	)
	feedback_timer.start()


func _reset_feedback() -> void:
	feedback_label.text = DEFAULT_FEEDBACK
	feedback_label.add_theme_color_override("font_color", RpgMenuTheme.DIM)
	feedback_marker.color = RpgMenuTheme.BRONZE_DIM


func _on_session_changed() -> void:
	wallet_label.text = "ДЕМО-КОШЕЛЁК · %d" % session.demo_coins
	_update_start_metrics()
	_refresh_summary()
	_apply_demo_summary_override()


## Верхняя сводка остаётся живой, но на вкладке демо-рюкзака явно
## показывает демо-число, чтобы «0 в состоянии» и «12 в наборе» не читались
## как противоречие.
func _apply_demo_summary_override() -> void:
	if _active_section != &"inventory" or _summary_labels.is_empty() or session == null:
		return
	_set_summary_caption(&"items", "ПРЕДМЕТЫ · ДЕМО")
	(_summary_labels[&"items"] as Label).text = str(session.items.size())


func _clear_screen_visibility() -> void:
	for screen in _screens.values():
		(screen as Control).visible = false


func _layout_content() -> void:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 1.0 or viewport_size.y <= 1.0:
		return
	var factor := minf(viewport_size.x / DESIGN_SIZE.x, viewport_size.y / DESIGN_SIZE.y)
	content.scale = Vector2(factor, factor)
	content.position = (viewport_size - DESIGN_SIZE * factor) * 0.5


func _start_content_scale_check() -> void:
	# На первом кадре окно ещё может иметь размер проекта, затем Godot применит
	# запрошенный --resolution. Повторная раскладка безопасна и не меняет настройки.
	await get_tree().process_frame
	_layout_content()
