extends GutTest
## Каталог заданий, автозапуск по флагам, прогресс целей, награды и снимок.

const CATALOG_PATH := "res://resources/quests/quest_catalog.tres"


func before_each() -> void:
	QuestSystem.deactivate_scope()
	NightmareRunState.reset()


func after_each() -> void:
	QuestSystem.deactivate_scope()
	NightmareRunState.reset()


func _activate() -> void:
	QuestSystem.activate_scope(&"forgotten_shore")


func test_catalog_has_valid_unique_quests() -> void:
	var catalog := load(CATALOG_PATH) as QuestCatalog
	assert_not_null(catalog, "каталог загружается")
	if catalog == null:
		return
	assert_eq(catalog.quests.size(), 12, "в каталоге семь базовых и пять SQ-FS заданий")
	var seen := {}
	for item in catalog.quests:
		var quest := item as QuestDefinition
		assert_not_null(quest, "запись является QuestDefinition")
		if quest == null:
			continue
		assert_true(quest.is_valid(), "задание %s валидно" % quest.id)
		assert_false(seen.has(quest.id), "id %s уникален" % quest.id)
		seen[quest.id] = true
		assert_false(quest.objectives.is_empty(), "у %s есть цели" % quest.id)


func test_scope_starts_main_and_exploration_quests() -> void:
	_activate()
	assert_true(QuestSystem.is_active(&"first_day"), "основное задание стартует")
	assert_true(QuestSystem.is_active(&"crystal_cache"), "исследование стартует")
	assert_false(QuestSystem.is_active(&"first_blood"), "первый бой ждёт развилки")
	assert_eq(QuestSystem.get_tracked_quest().id, &"first_day", "отслеживается основное")


func test_flag_starts_followup_quest() -> void:
	_activate()
	NightmareRunState.set_flag(&"shore_fork_reached")
	assert_true(QuestSystem.is_active(&"first_blood"), "флаг развилки открывает первый бой")
	assert_eq(QuestSystem.get_objective_progress(&"first_blood", &"kill_scavenger"), 0)


func test_kill_completes_quest_and_grants_currency() -> void:
	_activate()
	NightmareRunState.set_flag(&"shore_fork_reached")
	QuestSystem.notify_event(&"killed", &"wounded_scavenger", 1)
	assert_true(QuestSystem.is_completed(&"first_blood"), "убийство закрывает задание")
	assert_true(NightmareRunState.has_flag(&"wounded_scavenger_slain"), "флаг смерти выставлен")
	assert_eq(NightmareRunState.get_currency(&"soul_shard"), 2, "награда начислена")
	assert_true(QuestSystem.is_active(&"azure_blade"), "следующее задание стартовало")


func test_blade_completion_unlocks_memory_once() -> void:
	_activate()
	NightmareRunState.set_flag(&"shore_fork_reached")
	QuestSystem.notify_event(&"killed", &"wounded_scavenger", 1)
	QuestSystem.notify_event(&"interacted", &"azure_blade", 1)
	assert_true(QuestSystem.is_completed(&"azure_blade"), "клинок закрывает задание")
	assert_true(NightmareRunState.has_memory(&"azure_blade"), "Память открыта")
	assert_eq(NightmareRunState.get_currency(&"soul_shard"), 3, "награды сложены")
	assert_false(QuestSystem.complete_quest(&"azure_blade", true), "повторно завершить нельзя")
	assert_eq(NightmareRunState.get_currency(&"soul_shard"), 3, "повторной награды нет")


func test_crystal_cache_collects_three_events() -> void:
	_activate()
	QuestSystem.notify_event(&"collected", &"soul_shard", 1)
	QuestSystem.notify_event(&"collected", &"soul_shard", 1)
	assert_eq(QuestSystem.get_objective_progress(&"crystal_cache", &"collect_shards"), 2)
	assert_false(QuestSystem.is_completed(&"crystal_cache"), "двух осколков мало")
	QuestSystem.notify_event(&"collected", &"soul_shard", 1)
	assert_true(QuestSystem.is_completed(&"crystal_cache"), "три осколка закрывают задание")
	assert_eq(NightmareRunState.get_currency(&"soul_shard"), 3, "награда за осколки")


func test_journal_and_tracking_use_live_state() -> void:
	_activate()
	NightmareRunState.set_flag(&"shore_fork_reached")
	QuestSystem.notify_event(&"killed", &"wounded_scavenger", 1)
	var entries := QuestSystem.get_journal_entries()
	var found: QuestJournalEntry = null
	for entry in entries:
		if entry.id == &"first_blood":
			found = entry
			break
	assert_not_null(found, "задание есть в журнале")
	if found != null:
		assert_eq(found.status, 2, "завершённое задание помечено")
		assert_eq(found.completed_objectives(), 1)
		assert_eq(found.total_objectives(), 1)
	assert_true(QuestSystem.set_tracked_quest(&"azure_blade"), "активное задание можно отслеживать")
	assert_true(QuestSystem.get_tracked_objective_text().contains("Азурный"), "строка цели обновилась")


func test_deactivate_scope_clears_external_objective() -> void:
	_activate()
	assert_true(CampaignGuide.has_external_objective(), "активный scope даёт внешнюю цель")
	QuestSystem.deactivate_scope()
	assert_false(CampaignGuide.has_external_objective(), "выход из Лабиринта снимает внешнюю цель")
	assert_eq(QuestSystem.active_scope, &"", "scope выключен")


func test_snapshot_restore_keeps_quest_progress_and_rewards() -> void:
	_activate()
	NightmareRunState.set_flag(&"shore_fork_reached")
	QuestSystem.notify_event(&"killed", &"wounded_scavenger", 1)
	var saved := NightmareRunState.snapshot()
	var saved_currency := NightmareRunState.get_currency(&"soul_shard")
	NightmareRunState.reset()
	assert_false(QuestSystem.is_completed(&"first_blood"), "reset очищает задания")
	NightmareRunState.restore(saved)
	assert_true(QuestSystem.is_completed(&"first_blood"), "состояние задания восстановлено")
	assert_eq(NightmareRunState.get_currency(&"soul_shard"), saved_currency, "валюта восстановлена")
	assert_eq(NightmareRunState.get_quest_state(&"first_blood"), &"completed")
	assert_true(NightmareRunState.is_quest_reward_claimed(&"first_blood"), "награда не выдаётся повторно")
