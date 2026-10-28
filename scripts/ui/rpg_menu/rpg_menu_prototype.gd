class_name RpgMenuPrototype
extends Control
## Автономный презентационный прототип RPG-меню.
##
## Сцена не связана с прологом, ареной, сохранениями, экономикой или контроллером
## Санни. Все изменения живут в RpgDemoSession и исчезают при перезапуске.
## В игре этот же экран показывает PlayerMenuSystem как модальный слой поверх
## приостановленного игрового процесса.

signal close_requested

const DEMO_CATALOG := preload("res://resources/rpg_menu/demo_catalog.tres")
const ASPECT_TREE := preload("res://resources/rpg_menu/aspect_demo.tres")
const QUEST_CATALOG := preload("res://resources/rpg_menu/quest_demo.tres")
const DESIGN_SIZE := Vector2(1600.0, 900.0)
const DEFAULT_FEEDBACK := "СЕССИЯ ДЕМО · ВСЁ ЛОКАЛЬНО · НЕ СОХРАНЯЕТСЯ"

const START_INDEX := [
	{"code": "01", "label": "ИНВЕНТАРЬ", "state": "РАБОТАЕТ", "tone": &"ready"},
	{"code": "02", "label": "ПЕРСОНАЖ", "state": "РАБОТАЕТ", "tone": &"ready"},
	{"code": "03", "label": "АСПЕКТ / НАВЫКИ", "state": "DEMO-ДЕРЕВО", "tone": &"ready"},
	{"code": "04", "label": "ПАМЯТИ", "state": "ЧЕРНОВИК", "tone": &"draft"},
	{"code": "05", "label": "ЗАДАНИЯ", "state": "DEMO-КВЕСТЫ", "tone": &"ready"},
	{"code": "—", "label": "ТОРГОВЛЯ", "state": "ДЕМО-ВХОД", "tone": &"trade"},
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
var _screens: Dictionary = {}
var _nav_buttons: Dictionary = {}
var _active_section: StringName = &""
var _start_metric_labels: Dictionary = {}


func _ready() -> void:
	theme = RpgMenuTheme.build()
	content.pivot_offset = Vector2.ZERO
	content.resized.connect(_layout_content)
	get_viewport().size_changed.connect(_layout_content)
	_layout_content()

	session = RpgDemoSession.new()
	session.initialize(DEMO_CATALOG)
	session.changed.connect(_on_session_changed)

	_screens = {
		&"inventory": inventory_screen,
		&"character": character_screen,
		&"aspect": aspect_screen,
		&"memories": draft_screen,
		&"journal": quest_screen,
		&"trade": trade_screen,
	}
	_nav_buttons = {
		&"inventory": nav_inventory,
		&"character": nav_character,
		&"aspect": nav_aspect,
		&"memories": nav_memories,
		&"journal": nav_journal,
	}

	start_button.pressed.connect(_on_start_pressed)
	nav_inventory.pressed.connect(show_section.bind(&"inventory"))
	nav_character.pressed.connect(show_section.bind(&"character"))
	nav_aspect.pressed.connect(show_section.bind(&"aspect"))
	nav_memories.pressed.connect(show_section.bind(&"memories"))
	nav_journal.pressed.connect(show_section.bind(&"journal"))
	trade_button.pressed.connect(show_section.bind(&"trade"))
	close_button.pressed.connect(close_menu)
	feedback_timer.timeout.connect(_reset_feedback)

	inventory_screen.feedback_requested.connect(_show_feedback)
	character_screen.feedback_requested.connect(_show_feedback)
	character_screen.item_requested.connect(_on_character_item_requested)
	aspect_screen.feedback_requested.connect(_show_feedback)
	aspect_screen.navigate_requested.connect(_on_navigate_requested)
	trade_screen.feedback_requested.connect(_show_feedback)
	trade_screen.navigate_requested.connect(_on_navigate_requested)
	quest_screen.connect("feedback_requested", _show_feedback)
	quest_screen.connect("navigate_requested", _on_navigate_requested)
	draft_screen.navigate_requested.connect(_on_navigate_requested)

	inventory_screen.setup(session)
	character_screen.setup(session)
	aspect_screen.setup(ASPECT_TREE)
	trade_screen.setup(session)
	quest_screen.setup(QUEST_CATALOG)
	_configure_draft(&"memories")
	_build_start_index()
	_build_start_metrics()
	_on_session_changed()

	start_page.visible = true
	menu_page.visible = false
	_clear_screen_visibility()
	_reset_feedback()
	_start_content_scale_check()
	start_button.grab_focus()


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
	for key in _nav_buttons:
		var button := _nav_buttons[key] as Button
		button.set_pressed_no_signal(key == section)
	trade_button.set_pressed_no_signal(section == &"trade")

	if section == &"memories":
		_configure_draft(&"memories")
	if section == &"aspect":
		aspect_screen.focus_initial()

	match section:
		&"inventory":
			session_index.text = "ИНВЕНТАРЬ · ЛОКАЛЬНЫЙ ДЕМО-НАБОР"
		&"character":
			session_index.text = "ПЕРСОНАЖ · ПРОСМОТР"
		&"aspect":
			session_index.text = "АСПЕКТ / НАВЫКИ · DEMO-ДЕРЕВО"
		&"memories":
			session_index.text = "ПАМЯТИ · ЧЕРНОВИК"
		&"journal":
			session_index.text = "ЗАДАНИЯ · DEMO-ЖУРНАЛ"
		&"trade":
			session_index.text = "ТОРГОВЛЯ · ОТДЕЛЬНЫЙ ДЕМО-ВХОД"
		_:
			session_index.text = "СЕАНС №01 · ДЕМО-ДАННЫЕ"


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
	wallet_label.text = "КОШЕЛЁК · %d ДЕМО-МОНЕТ" % session.demo_coins
	_update_start_metrics()


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
