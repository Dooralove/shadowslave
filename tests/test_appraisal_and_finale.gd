extends GutTest
## S14–S15: звёздная оценка, Divine Aspect / True Name и финальная карточка.

const APPRAISAL_SCENE := "res://scenes/campaign/appraisal_arrival.tscn"
const FINALE_SCENE := "res://scenes/campaign/finale_arrival.tscn"
const APPRAISAL_CATALOG := "res://resources/spell/appraisal_messages.tres"
const AWAKENING_CATALOG := "res://resources/spell/awakening_messages.tres"
const CAMPAIGN_ENTRY := "res://scenes/campaign/campaign_entry.tscn"


func before_each() -> void:
	NightmareRunState.reset()


func after_each() -> void:
	NightmareRunState.reset()


func _grant_finale_gate() -> void:
	NightmareRunState.set_flag(&"temple_reached")
	NightmareRunState.set_flag(&"trial_completed")
	NightmareRunState.set_flag(&"appraisal_completed")


func _instantiate_finale(overrides := {}) -> Control:
	var finale := (load(FINALE_SCENE) as PackedScene).instantiate() as Control
	finale.fade_in = false
	finale.fast_mode = false
	finale.line_delay = 0.08
	finale.restart_enabled = true
	finale.transition_enabled = false
	for property in overrides:
		finale.set(property, overrides[property])
	return finale


func _restart_event() -> InputEventAction:
	var event := InputEventAction.new()
	event.action = &"restart"
	event.pressed = true
	return event


func test_appraisal_catalog_keeps_canonical_order() -> void:
	var catalog := load(APPRAISAL_CATALOG) as SpellMessageCatalog
	assert_not_null(catalog)
	var messages := catalog.get_valid_messages()
	assert_eq(messages.size(), 19)
	assert_eq(messages[0].id, &"appraisal_memory_shroud")
	assert_eq(messages[8].id, &"appraisal_final")
	assert_string_contains(messages[8].text, "glorious")
	assert_eq(messages[10].id, &"appraisal_true_name")
	assert_eq(messages[10].text, "Ты получил True Name: Lost from Light.")
	assert_eq(messages[14].id, &"appraisal_rank")
	assert_eq(messages[15].text, "Aspect Name: Shadow Slave.")
	assert_eq(messages[18].id, &"appraisal_awakening")
	var awakening := load(AWAKENING_CATALOG) as SpellMessageCatalog
	assert_not_null(awakening)
	assert_eq(awakening.get_valid_messages().size(), 6)


func test_appraisal_awards_divine_aspect_and_true_name_once() -> void:
	NightmareRunState.set_flag(&"temple_reached")
	NightmareRunState.set_flag(&"trial_completed")
	# Состояния трёх деяний; их выдача реальными событиями проверяется в
	# test_appraisal_dormant_humans.gd (сквозной путь — в test_full_route).
	NightmareRunState.set_flag(&"veteran_dead")
	NightmareRunState.set_flag(&"flasks_poisoned")
	NightmareRunState.set_flag(&"shifty_dead")
	NightmareRunState.set_flag(&"scholar_abandoned")
	var appraisal := (load(APPRAISAL_SCENE) as PackedScene).instantiate() as Control
	appraisal.fade_in = false
	appraisal.transition_enabled = false
	appraisal.fast_mode = true
	appraisal.start_delay = 0.0
	appraisal.end_delay = 0.0
	watch_signals(appraisal)
	add_child_autofree(appraisal)
	await wait_seconds(0.5)

	assert_true(appraisal.is_completed(), "оценка завершается после всех строк")
	assert_signal_emitted(appraisal, "finished")
	assert_true(NightmareRunState.has_flag(&"appraisal_started"))
	assert_true(NightmareRunState.has_flag(&"appraisal_completed"))
	assert_true(NightmareRunState.has_flag(&"final_appraisal_glorious"))
	assert_true(NightmareRunState.has_flag(&"true_name_lost_from_light"))
	assert_true(NightmareRunState.has_flag(&"aspect_shadow_slave"))
	assert_true(NightmareRunState.has_flag(&"shadow_bond_known"))
	assert_true(NightmareRunState.has_flag(&"first_seal_broken"))
	assert_true(NightmareRunState.has_item(&"puppeteer_shroud"),
		"оценка выдаёт Memory Puppeteer's Shroud")
	assert_false(NightmareRunState.has_flag(&"first_nightmare_completed"),
		"оценка не подменяет подтверждение смерти Тирана")


func test_appraisal_requires_completed_trial() -> void:
	var appraisal := (load(APPRAISAL_SCENE) as PackedScene).instantiate() as Control
	appraisal.redirect_without_gate = false
	add_child_autofree(appraisal)
	await wait_seconds(0.1)

	assert_false(appraisal.can_appraise(), "без испытания оценка закрыта")
	assert_false(appraisal.is_completed(), "оценка не запускается")
	assert_false(NightmareRunState.has_flag(&"appraisal_started"),
		"оценка не начинает выдачу наград")
	assert_true((appraisal.get_node("%Hint") as Label).visible,
		"игрок видит причину закрытого гейта")


func test_finale_records_completion_only_after_awakening() -> void:
	_grant_finale_gate()
	var finale := _instantiate_finale({"line_delay": 0.12})
	var awakening := load(AWAKENING_CATALOG) as SpellMessageCatalog
	var all_lines := awakening.get_valid_messages()
	watch_signals(finale)
	add_child_autofree(finale)

	assert_false(NightmareRunState.has_flag(&"awakening_completed"),
		"пробуждение не завершено сразу после входа")
	assert_false(NightmareRunState.has_flag(&"first_nightmare_finished"),
		"Кошмар не завершён сразу после входа")
	assert_false(NightmareRunState.has_flag(&"first_nightmare_completed"),
		"финальный гейт не выставлен до реплик")
	assert_false(finale.is_completed())
	assert_false(finale.is_ready_for_restart())
	assert_false((finale.get_node("%Card") as Control).visible,
		"карточка не показана до реплик")

	await wait_seconds(0.15)
	assert_false(NightmareRunState.has_flag(&"awakening_completed"),
		"пробуждение не завершено во время реплик")
	assert_false(NightmareRunState.has_flag(&"first_nightmare_finished"),
		"Кошмар не завершён во время реплик")
	assert_false(NightmareRunState.has_flag(&"first_nightmare_completed"),
		"финальный гейт не выставлен во время реплик")
	assert_false(finale.is_completed())
	assert_false(finale.is_ready_for_restart())
	assert_false((finale.get_node("%Card") as Control).visible,
		"карточка не появляется во время реплик")
	assert_false((finale.get_node("%Line") as Label).text.is_empty(),
		"реплика пробуждения уже воспроизводится")
	assert_signal_emit_count(finale, "completed", 0)

	finale._unhandled_input(_restart_event())
	assert_true(NightmareRunState.has_flag(&"temple_reached"),
		"R до карточки не сбрасывает кампанию")
	assert_true(NightmareRunState.has_flag(&"trial_completed"))
	assert_true(NightmareRunState.has_flag(&"appraisal_completed"))
	assert_false(NightmareRunState.has_flag(&"first_nightmare_completed"))
	assert_false(finale.is_ready_for_restart())

	await wait_seconds(0.9)
	assert_true(NightmareRunState.has_flag(&"awakening_completed"),
		"пробуждение завершается после последней реплики")
	assert_true(NightmareRunState.has_flag(&"first_nightmare_finished"))
	assert_true(NightmareRunState.has_flag(&"first_nightmare_completed"),
		"финальный гейт выставляется после реплик")
	assert_true(finale.is_completed())
	assert_true(finale.is_ready_for_restart())
	assert_true((finale.get_node("%Card") as Control).visible,
		"карточка появляется после реплик")
	assert_eq((finale.get_node("%Line") as Label).text, all_lines.back().text,
		"к моменту карточки показана последняя реплика")
	assert_signal_emit_count(finale, "completed", 1)
	assert_false(NightmareRunState.has_flag(&"flaw_name_known"),
		"имя Flaw остаётся скрытым на границе главы 16")

	finale.restart_enabled = false
	finale._unhandled_input(_restart_event())
	assert_true(NightmareRunState.has_flag(&"first_nightmare_completed"),
		"запрещённый R не сбрасывает завершённый Кошмар")
	assert_true(NightmareRunState.has_flag(&"temple_reached"))

	finale.restart_enabled = true
	finale._unhandled_input(_restart_event())
	assert_false(NightmareRunState.has_flag(&"temple_reached"),
		"разрешённый R сбрасывает состояние кампании")
	assert_false(NightmareRunState.has_flag(&"trial_completed"))
	assert_false(NightmareRunState.has_flag(&"appraisal_completed"))
	assert_false(NightmareRunState.has_flag(&"awakening_completed"))
	assert_false(NightmareRunState.has_flag(&"first_nightmare_finished"))
	assert_false(NightmareRunState.has_flag(&"first_nightmare_completed"))
	assert_true(finale.is_completed(),
		"сброс не отменяет уже показанный финал")
	assert_signal_emit_count(finale, "completed", 1)


func test_finale_fast_mode_commits_once_after_lines() -> void:
	_grant_finale_gate()
	var finale := _instantiate_finale({"fast_mode": true})
	watch_signals(finale)
	add_child_autofree(finale)

	assert_false(NightmareRunState.has_flag(&"awakening_completed"),
		"быстрый режим не фиксирует завершение до кадров реплик")
	assert_false(finale.is_completed())
	await wait_seconds(0.4)

	assert_true(finale.is_completed())
	assert_true(finale.is_ready_for_restart(), "финальная карточка готова к рестарту")
	assert_true(NightmareRunState.has_flag(&"awakening_completed"))
	assert_true(NightmareRunState.has_flag(&"first_nightmare_finished"))
	assert_true(NightmareRunState.has_flag(&"first_nightmare_completed"),
		"финальный флаг выставляется только в S15")
	assert_true((finale.get_node("%Card") as Control).visible, "карточка завершения показана")
	assert_signal_emit_count(finale, "completed", 1)

	finale.call(&"_complete_awakening")
	assert_signal_emit_count(finale, "completed", 1, "повторное завершение не дублируется")
	assert_true(NightmareRunState.has_flag(&"first_nightmare_completed"))
	assert_true((finale.get_node("%Card") as Control).visible)
	assert_false(NightmareRunState.has_flag(&"flaw_name_known"),
		"имя Flaw остаётся скрытым на границе главы 16")


func test_finale_requires_appraisal_gate() -> void:
	var finale := (load(FINALE_SCENE) as PackedScene).instantiate() as Control
	finale.redirect_without_gate = false
	add_child_autofree(finale)
	await wait_seconds(0.1)

	assert_false(finale.can_complete(), "без оценки финал закрыт")
	assert_false(finale.is_completed(), "финал не завершён")
	assert_false(finale.is_ready_for_restart(), "карточка не готова")
	assert_false((finale.get_node("%Card") as Control).visible,
		"финальная карточка не показана")
	assert_false(NightmareRunState.has_flag(&"awakening_completed"),
		"пробуждение не начинается в обход оценки")
	assert_false(NightmareRunState.has_flag(&"first_nightmare_completed"),
		"финальный флаг не выставляется в обход оценки")


func test_finale_left_before_awakening_does_not_complete() -> void:
	_grant_finale_gate()
	var finale := _instantiate_finale({"line_delay": 0.1})
	add_child_autofree(finale)
	await wait_seconds(0.02)

	assert_false(NightmareRunState.has_flag(&"awakening_completed"))
	assert_false(NightmareRunState.has_flag(&"first_nightmare_completed"))

	remove_child(finale)
	await wait_seconds(0.3)

	assert_false(NightmareRunState.has_flag(&"awakening_completed"),
		"выход до конца реплик не завершает пробуждение")
	assert_false(NightmareRunState.has_flag(&"first_nightmare_finished"),
		"выход до конца реплик не завершает Кошмар")
	assert_false(NightmareRunState.has_flag(&"first_nightmare_completed"),
		"выход до конца реплик не выставляет финальный гейт")
	assert_false(finale.is_completed())
	finale.queue_free()


func test_finale_reopen_after_completion_keeps_flags() -> void:
	_grant_finale_gate()
	var first := _instantiate_finale({"fast_mode": true})
	watch_signals(first)
	add_child_autofree(first)
	await wait_seconds(0.4)
	assert_true(first.is_completed())
	assert_signal_emit_count(first, "completed", 1)
	assert_true(NightmareRunState.has_flag(&"first_nightmare_completed"))
	first.queue_free()
	await wait_process_frames(1)

	var second := _instantiate_finale({"fast_mode": true})
	watch_signals(second)
	add_child_autofree(second)
	await wait_seconds(0.4)

	assert_true(second.is_completed(), "повторное открытие завершает сцену один раз")
	assert_signal_emit_count(second, "completed", 1)
	assert_true((second.get_node("%Card") as Control).visible)
	assert_true(NightmareRunState.has_flag(&"awakening_completed"))
	assert_true(NightmareRunState.has_flag(&"first_nightmare_finished"))
	assert_true(NightmareRunState.has_flag(&"first_nightmare_completed"),
		"повторное открытие не сбрасывает финальные флаги")
