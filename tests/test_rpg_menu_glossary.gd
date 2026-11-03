extends GutTest
## Единое меню: глоссарий, бестиарий, карта и медитация.
##
## Тесты не зависят от контента отдельной сессии бестиария: они читают
## каталог из resources/campaign/bestiary и проверяют только поведение UI.

const GLOSSARY_SCENE := "res://scenes/ui/rpg_menu/glossary_screen.tscn"
const MAP_SCENE := "res://scenes/ui/rpg_menu/map_screen.tscn"
const MEDITATION_SCENE := "res://scenes/ui/rpg_menu/meditation_screen.tscn"


func before_each() -> void:
	_close_menu()
	var run_state := get_node_or_null("/root/NightmareRunState")
	if run_state != null:
		run_state.reset()
	if get_tree().paused:
		get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func after_each() -> void:
	_close_menu()
	var run_state := get_node_or_null("/root/NightmareRunState")
	if run_state != null:
		run_state.reset()
	if get_tree().paused:
		get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# Дать queue_free() из перестроения списков отработать до проверки orphans.
	await get_tree().process_frame
	await get_tree().process_frame


func _close_menu() -> void:
	var menu := get_node_or_null("/root/PlayerMenuSystem")
	if menu != null and menu.is_open():
		menu.close_menu()


func _spawn(path: String) -> Control:
	var screen := (load(path) as PackedScene).instantiate() as Control
	add_child_autofree(screen)
	await get_tree().process_frame
	await get_tree().process_frame
	return screen


func _titles(entries: Array) -> Array[String]:
	var result: Array[String] = []
	for entry in entries:
		result.append(String(entry.get("title", "")))
	return result


func _ids(entries: Array) -> Array[StringName]:
	var result: Array[StringName] = []
	for entry in entries:
		result.append(StringName(entry.get("id", &"")))
	return result


func test_glossary_lists_bestiary_entries() -> void:
	var screen := await _spawn(GLOSSARY_SCENE)
	assert_eq(screen.get_active_tab(), &"bestiary")
	var entries: Array = screen.get_visible_entries()
	assert_gt(entries.size(), 0, "бестиарий читается из resources/campaign/bestiary")
	for entry in entries:
		assert_false(StringName(entry.get("id", &"")).is_empty(), "у записи есть id")
		assert_false(String(entry.get("category", "")).is_empty(), "у записи есть категория")


func test_locked_entry_does_not_reveal_text() -> void:
	var screen := await _spawn(GLOSSARY_SCENE)
	var entries: Array = screen.get_visible_entries()
	var locked_id := &""
	for entry in entries:
		if bool(entry.get("locked", false)):
			locked_id = StringName(entry.get("id", &""))
			break
	if locked_id == &"":
		# Все записи уже открыты предыдущим тестом — снимаем один флаг.
		NightmareRunState.reset()
		screen.refresh()
		entries = screen.get_visible_entries()
		for entry in entries:
			if bool(entry.get("locked", false)):
				locked_id = StringName(entry.get("id", &""))
				break
	assert_false(locked_id.is_empty(), "в каталоге есть закрытая запись")
	assert_true(screen.select_entry(locked_id), "закрытую запись можно выбрать")
	var selected: Dictionary = screen.get_selected_entry()
	assert_true(bool(selected.get("locked", false)), "запись остаётся закрытой")
	assert_true(String(selected.get("text", "")).is_empty(), "текст не подставляется в строку списка")
	assert_true(String(selected.get("weakness", "")).is_empty(), "слабость не раскрывается")


func test_unlocking_bestiary_reveals_entry() -> void:
	NightmareRunState.unlock_bestiary(&"larva", &"seen")
	var screen := await _spawn(GLOSSARY_SCENE)
	screen.refresh()
	assert_true(screen.select_entry(&"larva"), "личинка есть в каталоге")
	var selected: Dictionary = screen.get_selected_entry()
	assert_false(bool(selected.get("locked", true)), "запись открыта")
	assert_eq(String(selected.get("title", "")), "Личинка")
	assert_false(String(selected.get("text", "")).is_empty(), "описание доступно")
	assert_false(String(selected.get("weakness", "")).is_empty(), "слабость доступна")


func test_training_tab_has_rules_and_controls() -> void:
	var screen := await _spawn(GLOSSARY_SCENE)
	screen.set_tab(&"training")
	var entries: Array = screen.get_visible_entries()
	var titles := _titles(entries)
	assert_true(titles.has("Правила Кошмара"), "правила кампании попадают в обучение")
	assert_true(titles.has("Управление"), "справка управления строится из Input Map")


func test_places_tab_does_not_spoil_future_regions() -> void:
	var screen := await _spawn(GLOSSARY_SCENE)
	screen.set_tab(&"places")
	var entries: Array = screen.get_visible_entries()
	var ids := _ids(entries)
	assert_true(ids.has(&"caravan_road"), "места Первого Кошмара доступны")
	assert_false(ids.has(&"academy_approach"), "места будущих глав не раскрываются")


func test_player_menu_opens_glossary_and_closes() -> void:
	var menu := get_node_or_null("/root/PlayerMenuSystem")
	assert_not_null(menu)
	assert_true(menu.open_menu(&"glossary"), "меню открывается на глоссарии")
	assert_true(menu.is_open(), "меню открыто")
	assert_eq(menu.screen.get_active_section(), &"glossary")
	assert_true(menu.screen.is_section_visible(&"glossary"), "виден глоссарий")
	assert_true(menu.screen.nav_glossary.button_pressed, "верхняя вкладка глоссария выбрана")
	assert_true(get_tree().paused, "игра на паузе")
	menu.close_menu()
	assert_false(menu.is_open(), "меню закрывается")
	assert_false(get_tree().paused, "пауза снята")


func test_menu_summary_counts_unlocked_bestiary() -> void:
	NightmareRunState.unlock_bestiary(&"larva", &"seen")
	var menu := get_node_or_null("/root/PlayerMenuSystem")
	assert_not_null(menu)
	assert_true(menu.open_menu(&"glossary"))
	await get_tree().process_frame
	var label := menu.screen._summary_labels.get(&"bestiary", null) as Label
	assert_not_null(label, "сводка бестиария существует")
	assert_true(label.text.contains("1 /"), "счётчик открытых записей обновился: %s" % label.text)


func test_reset_clears_recent_articles() -> void:
	NightmareRunState.unlock_bestiary(&"larva", &"seen")
	var menu := get_node_or_null("/root/PlayerMenuSystem")
	assert_not_null(menu)
	assert_true(menu.open_menu(&"glossary"))
	await get_tree().process_frame
	var glossary: RpgGlossaryScreen = menu.screen.glossary_screen
	assert_true(glossary.select_entry(&"larva"))
	assert_gt(glossary.get_recent_entries().size(), 0, "открытая статья попадает в недавние")
	NightmareRunState.reset()
	await get_tree().process_frame
	assert_eq(glossary.get_recent_entries().size(), 0, "сброс кампании очищает недавние статьи")


func test_map_section_uses_atlas() -> void:
	var screen := await _spawn(MAP_SCENE)
	assert_not_null(screen.atlas, "атлас загружен")
	assert_true(screen.get_mode() in ["world", "region"], "карта открывается в одном из режимов")


func test_meditation_screen_is_safe_without_player() -> void:
	var screen := await _spawn(MEDITATION_SCENE)
	assert_false(screen.is_return_available(), "без игрока возврат недоступен")
