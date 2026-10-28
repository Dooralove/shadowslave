extends GutTest
## Короткие внутренние реплики Санни: данные, выбор, UI и игровые хуки.

const DEFAULT_BARKS := "res://data/dialogues/sunny_barks.json"
const BARK_UI_SCENE := "res://scenes/ui/bark_ui.tscn"
const AMBUSH_SCENE := "res://scenes/locations/ambush_site/ambush_site.tscn"
const SANCTUARY_SCENE := "res://scenes/locations/shadow_sanctuary/shadow_sanctuary.tscn"
const LEGACY_PATH := "user://test_legacy_barks.json"
const INVALID_PATH := "user://test_invalid_barks.json"
const MISSING_PATH := "user://test_missing_barks.json"


func before_each() -> void:
	DialogueManager.set_barks_suppressed(false)
	DialogueManager.load_barks(DEFAULT_BARKS)


func after_each() -> void:
	DialogueManager.set_barks_suppressed(false)
	DialogueManager.load_barks(DEFAULT_BARKS)
	_remove_user_file(LEGACY_PATH)
	_remove_user_file(INVALID_PATH)


func _write_user_file(path: String, text: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(text)
	file.close()
	return true


func _remove_user_file(path: String) -> void:
	if not FileAccess.file_exists(path):
		return
	var dir := DirAccess.open("user://")
	if dir:
		dir.remove(path.trim_prefix("user://"))


## Ошибки загрузчика в тестах ожидаемые: они проверяют безопасный отказ.
func _mark_expected_errors_handled() -> void:
	for error in get_errors():
		error.handled = true


func test_default_catalog_has_thirty_complete_records() -> void:
	var barks := DialogueManager.get_all_barks()
	assert_eq(barks.size(), 30, "в источнике 30 реплик")
	var ids := {}
	for bark in barks:
		assert_false(bark.id == &"", "id заполнен")
		assert_false(bark.text.strip_edges().is_empty(), "%s: текст не пуст" % bark.id)
		assert_eq(bark.speaker, &"sunny", "%s: говорит Санни" % bark.id)
		assert_false(bark.context == &"", "%s: контекст заполнен" % bark.id)
		assert_false(ids.has(bark.id), "%s: id уникален" % bark.id)
		ids[bark.id] = true


func test_gameplay_contexts_are_indexed() -> void:
	for context in [
		&"march_start",
		&"danger",
		&"ambush",
		&"cover",
		&"escape",
		&"caravan_chain",
		&"caravan_guard",
		&"caravan_auro",
		&"caravan_cold",
		&"caravan_threat",
		&"caravan_survival",
	]:
		assert_true(DialogueManager.has_context(context), "%s индексируется" % context)
		assert_gt(DialogueManager.get_bark_count(context), 0, "%s не пуст" % context)


func test_context_aliases_map_to_canonical_names() -> void:
	assert_eq(DialogueManager.get_bark_count(&"march"), DialogueManager.get_bark_count(&"march_start"))
	assert_eq(DialogueManager.get_bark_count(&"threat"), DialogueManager.get_bark_count(&"danger"))
	assert_eq(DialogueManager.get_bark_count(&"hiding"), DialogueManager.get_bark_count(&"cover"))
	assert_eq(DialogueManager.get_bark_count(&"run"), DialogueManager.get_bark_count(&"escape"))


func test_shrine_and_altar_are_empty_and_safe() -> void:
	for context in [&"shrine_approach", &"altar"]:
		assert_false(DialogueManager.has_context(context), "%s пока без данных" % context)
		assert_eq(DialogueManager.get_bark_count(context), 0)
		assert_null(DialogueManager.get_bark(context), "%s: ничего не выбрано" % context)
		assert_null(DialogueManager.request_bark(context), "%s: ничего не показано" % context)


func test_selection_does_not_repeat_while_alternatives_exist() -> void:
	var previous := &""
	for _i in 20:
		var bark := DialogueManager.get_bark(&"cover")
		assert_not_null(bark)
		if bark == null:
			return
		if previous != &"":
			assert_ne(bark.id, previous, "соседние реплики не повторяются")
		previous = bark.id


func test_unknown_context_returns_empty_values() -> void:
	assert_false(DialogueManager.has_context(&"no_such_context"))
	assert_eq(DialogueManager.get_bark_count(&"no_such_context"), 0)
	assert_null(DialogueManager.get_bark(&"no_such_context"))
	assert_eq(DialogueManager.get_random_bark(&"no_such_context"), "")


func test_unknown_context_emits_no_signal() -> void:
	var received: Array[BarkLine] = []
	var handler := func(bark: BarkLine) -> void: received.append(bark)
	DialogueManager.bark_requested.connect(handler)
	assert_null(DialogueManager.request_bark(&"altar"))
	DialogueManager.bark_requested.disconnect(handler)
	assert_eq(received.size(), 0)


func test_suppression_blocks_barks_until_released() -> void:
	watch_signals(DialogueManager)
	DialogueManager.set_barks_suppressed(true)
	assert_signal_emitted(DialogueManager, "bark_cleared", "активная реплика скрывается")
	assert_null(DialogueManager.show_bark(&"march_start"))
	assert_signal_emit_count(DialogueManager, "bark_requested", 0)

	var forced := DialogueManager.show_bark(&"march_start", true)
	assert_not_null(forced, "force нужен для отладки и тестов")
	assert_signal_emit_count(DialogueManager, "bark_requested", 1)

	DialogueManager.set_barks_suppressed(false)
	assert_not_null(DialogueManager.show_bark(&"march_start"))
	assert_signal_emit_count(DialogueManager, "bark_requested", 2)


func test_legacy_category_format_still_loads() -> void:
	assert_true(_write_user_file(LEGACY_PATH, JSON.stringify({
		"caravan_old": ["Первая старая реплика.", "Вторая старая реплика."],
	})))
	assert_true(DialogueManager.load_barks(LEGACY_PATH))
	assert_eq(DialogueManager.get_all_barks().size(), 2)
	assert_eq(DialogueManager.get_bark_count(&"caravan_old"), 2)
	assert_eq(DialogueManager.get_bark(&"caravan_old").speaker, &"sunny")
	assert_string_contains(DialogueManager.get_random_bark(&"caravan_old"), "старая")


func test_malformed_json_keeps_previous_database() -> void:
	var before := DialogueManager.get_bark_count(&"danger")
	assert_true(_write_user_file(INVALID_PATH, "{ this is not json"))
	assert_false(DialogueManager.load_barks(INVALID_PATH), "битый JSON отклонён")
	_mark_expected_errors_handled()
	assert_eq(DialogueManager.get_bark_count(&"danger"), before, "прежняя база сохранена")
	assert_gt(before, 0)


func test_missing_file_keeps_previous_database() -> void:
	var before := DialogueManager.get_all_barks().size()
	assert_false(DialogueManager.load_barks(MISSING_PATH), "отсутствующий файл отклонён")
	_mark_expected_errors_handled()
	assert_eq(DialogueManager.get_all_barks().size(), before, "прежняя база сохранена")


func test_record_without_required_fields_is_skipped() -> void:
	assert_true(_write_user_file(INVALID_PATH, JSON.stringify({
		"barks": [
			{"id": "TEST_OK", "speaker": "sunny", "context": "danger", "text": "Нормальная реплика."},
			{"id": "TEST_BAD", "speaker": "sunny", "context": "danger"},
		],
	})))
	assert_true(DialogueManager.load_barks(INVALID_PATH))
	assert_eq(DialogueManager.get_all_barks().size(), 1, "неполная запись пропущена")
	var bark := DialogueManager.get_bark(&"danger")
	assert_not_null(bark)
	assert_eq(bark.id, &"TEST_OK")


func test_bark_ui_presents_and_hides_line() -> void:
	var bark_ui := (load(BARK_UI_SCENE) as PackedScene).instantiate() as BarkUI
	add_child_autofree(bark_ui)
	await wait_process_frames(1)

	var bark := BarkLine.new()
	bark.id = &"TEST_UI"
	bark.speaker = &"sunny"
	bark.context = &"danger"
	bark.text = "Проверка реплики."

	bark_ui.present(bark, 60.0)
	assert_true(bark_ui.visible)
	assert_true(bark_ui.subtitles.visible)
	assert_eq(bark_ui.subtitles.text_label.text, bark.text)
	assert_eq(bark_ui.subtitles.speaker_label.text, "Санни")
	assert_false(bark_ui.subtitles.continue_hint.visible, "реплика не ждёт нажатия")

	bark_ui.hide_bark()
	assert_false(bark_ui.visible)
	assert_false(bark_ui.subtitles.visible)


func test_ambush_controller_requests_ambush_cover_and_escape_barks() -> void:
	var site := (load(AMBUSH_SCENE) as PackedScene).instantiate() as AmbushController
	add_child_autofree(site)
	await wait_physics_frames(1)
	var king := site.get_node("MountainKing") as MountainKing
	king.set_physics_process(false)
	king.attack.set_physics_process(false)

	var received: Array[BarkLine] = []
	var handler := func(bark: BarkLine) -> void: received.append(bark)
	DialogueManager.bark_requested.connect(handler)

	var player := Node3D.new()
	player.add_to_group(&"player")
	add_child_autofree(player)

	site.start_ambush()
	assert_eq(received.size(), 1)
	if received.size() > 0:
		assert_true(received[0].matches_context(&"ambush"), "старт засады")

	site._on_wagon_cover_body_entered(player)
	assert_eq(received.size(), 2)
	if received.size() > 1:
		assert_true(received[1].matches_context(&"cover"), "вход в укрытие")

	site.open_escape_path()
	assert_eq(received.size(), 3)
	if received.size() > 2:
		assert_true(received[2].matches_context(&"escape"), "открыт путь побега")

	DialogueManager.bark_requested.disconnect(handler)


func test_sanctuary_controller_requests_cover_and_altar_contexts() -> void:
	var sanctuary := (load(SANCTUARY_SCENE) as PackedScene).instantiate() as SanctuaryController
	add_child_autofree(sanctuary)
	await wait_physics_frames(1)

	var received: Array[BarkLine] = []
	var handler := func(bark: BarkLine) -> void: received.append(bark)
	DialogueManager.bark_requested.connect(handler)

	sanctuary.enter_crevice()
	assert_eq(received.size(), 1)
	if received.size() > 0:
		assert_true(received[0].matches_context(&"cover"), "укрытие в расщелине")

	# Для алтаря в источнике нет реплик: запрос не должен ничего показать.
	sanctuary.offer_blood()
	assert_eq(received.size(), 1, "алтарь пока без реплик")

	DialogueManager.bark_requested.disconnect(handler)
