extends GutTest
## Быстрый слот: снимок NightmareRunState, квестов и позиции игрока.

const TEST_PATH := "user://test_shadowslave_save.bin"


func before_each() -> void:
	NightmareRunState.reset()
	QuestSystem.deactivate_scope()
	SaveSystem.set("save_path", TEST_PATH)
	SaveSystem.delete_save()


func after_each() -> void:
	SaveSystem.delete_save()
	SaveSystem.set("save_path", SaveSystem.DEFAULT_SAVE_PATH)
	QuestSystem.deactivate_scope()
	NightmareRunState.reset()


func test_save_round_trip_keeps_quests_and_currency() -> void:
	QuestSystem.activate_scope(&"forgotten_shore")
	NightmareRunState.set_flag(&"shore_fork_reached")
	QuestSystem.notify_event(&"killed", &"wounded_scavenger", 1)
	NightmareRunState.set_currency(&"soul_shard", 9)
	NightmareRunState.unlock_memory(&"azure_blade")
	NightmareRunState.set_checkpoint(&"CP-SHORE-CAMP", Vector3(-100, 18, -5), true)

	assert_true(SaveSystem.save_game("test"), "снимок записан")
	assert_true(SaveSystem.has_save(), "файл существует")
	var payload := SaveSystem.read_save()
	assert_false(payload.is_empty(), "снимок читается")
	if payload.is_empty():
		return

	NightmareRunState.reset()
	assert_false(NightmareRunState.has_flag(&"shore_fork_reached"))
	var state_value: Variant = payload["run_state"]
	assert_true(state_value is Dictionary)
	if state_value is Dictionary:
		NightmareRunState.restore(state_value)

	assert_true(NightmareRunState.has_flag(&"shore_fork_reached"), "флаги восстановлены")
	assert_true(QuestSystem.is_completed(&"first_blood"), "задание восстановлено")
	assert_eq(NightmareRunState.get_currency(&"soul_shard"), 9)
	assert_true(NightmareRunState.has_memory(&"azure_blade"))
	assert_eq(NightmareRunState.get_checkpoint_id(), &"CP-SHORE-CAMP")


func test_missing_or_corrupt_save_returns_empty() -> void:
	assert_true(SaveSystem.read_save().is_empty(), "без файла снимка нет")
	var file := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	assert_not_null(file)
	if file != null:
		file.store_string("not a save")
		file.close()
	assert_true(SaveSystem.read_save().is_empty(), "повреждённый файл не загружается")
	assert_false(SaveSystem.load_game("test"), "load_game сообщает об ошибке")
