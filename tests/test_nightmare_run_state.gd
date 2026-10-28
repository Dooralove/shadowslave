extends GutTest
## Состояние Первого Кошмара: флаги, предметы и снимок для отладки/тестов.

func before_each() -> void:
	NightmareRunState.reset()


func after_each() -> void:
	NightmareRunState.reset()


func test_reset_clears_flags_and_items_and_emits() -> void:
	NightmareRunState.set_flag(&"camp_reached")
	NightmareRunState.set_item(&"key", 2)
	watch_signals(NightmareRunState)
	NightmareRunState.reset()
	assert_signal_emitted(NightmareRunState, "state_reset")
	assert_false(NightmareRunState.has_flag(&"camp_reached"))
	assert_eq(NightmareRunState.get_item_count(&"key"), 0)
	assert_eq(NightmareRunState.snapshot(), {"flags": {}, "items": {}})


func test_flags_are_idempotent_and_require_all() -> void:
	watch_signals(NightmareRunState)
	NightmareRunState.set_flag(&"march_intro_seen")
	NightmareRunState.set_flag(&"march_intro_seen")
	assert_signal_emit_count(NightmareRunState, "flag_changed", 1, "повторная установка не шлёт лишний сигнал")
	assert_true(NightmareRunState.require([&"march_intro_seen"]))
	assert_false(NightmareRunState.require([&"march_intro_seen", &"camp_reached"]))
	NightmareRunState.set_flag(&"camp_reached")
	assert_true(NightmareRunState.require([&"march_intro_seen", &"camp_reached"]))
	NightmareRunState.clear_flag(&"camp_reached")
	assert_false(NightmareRunState.has_flag(&"camp_reached"))


func test_mark_of_divinity_is_flag_attribute_not_item() -> void:
	assert_false(NightmareRunState.ITEM_IDS.has(&"mark_of_divinity"),
		"Mark of Divinity не входит в список предметов")
	assert_false(NightmareRunState.has_flag(&"mark_of_divinity"),
		"до установки атрибут отсутствует")
	watch_signals(NightmareRunState)
	NightmareRunState.set_flag(&"mark_of_divinity")
	assert_true(NightmareRunState.has_flag(&"mark_of_divinity"),
		"Mark of Divinity представлен флагом состояния")
	assert_true(NightmareRunState.get_flag(&"mark_of_divinity"))
	assert_false(NightmareRunState.has_item(&"mark_of_divinity"),
		"Mark of Divinity не появляется в инвентаре")
	assert_eq(NightmareRunState.get_item_count(&"mark_of_divinity"), 0)
	NightmareRunState.set_flag(&"mark_of_divinity")
	assert_signal_emit_count(NightmareRunState, "flag_changed", 1,
		"повторная установка не создаёт побочных сигналов")
	var saved := NightmareRunState.snapshot()
	var saved_flags: Dictionary = saved["flags"]
	var saved_items: Dictionary = saved["items"]
	assert_true(saved_flags.has(&"mark_of_divinity"))
	assert_true(saved_items.is_empty())
	NightmareRunState.clear_flag(&"mark_of_divinity")
	assert_false(NightmareRunState.has_flag(&"mark_of_divinity"),
		"отсутствие флага по-прежнему проверяемо")


func test_items_add_remove_and_counts() -> void:
	watch_signals(NightmareRunState)
	NightmareRunState.add_item(&"key", 2)
	assert_eq(NightmareRunState.get_item_count(&"key"), 2)
	assert_true(NightmareRunState.has_item(&"key"))
	assert_signal_emit_count(NightmareRunState, "item_changed", 1)
	assert_true(NightmareRunState.remove_item(&"key", 2), "предмет списывается, если хватает")
	assert_false(NightmareRunState.has_item(&"key"))
	assert_false(NightmareRunState.remove_item(&"key"), "нельзя списать отсутствующий предмет")
	NightmareRunState.set_item(&"key", -1)
	assert_eq(NightmareRunState.get_item_count(&"key"), 0, "отрицательное количество удаляет предмет")


func test_snapshot_restore_round_trips() -> void:
	NightmareRunState.set_flag(&"larva_killed")
	NightmareRunState.set_item(&"key", 1)
	var saved := NightmareRunState.snapshot()
	NightmareRunState.reset()
	assert_false(NightmareRunState.has_flag(&"larva_killed"))
	NightmareRunState.restore(saved)
	assert_true(NightmareRunState.has_flag(&"larva_killed"))
	assert_eq(NightmareRunState.get_item_count(&"key"), 1)
	assert_eq(NightmareRunState.snapshot(), saved)
