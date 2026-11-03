extends GutTest
## Слой событий (beat system) под список событий v2 (P01–N26):
## ресурсы BeatData, BeatDirector, 14 чекпоинтов перед опасностями,
## постановка flasks_poisoned без кнопки и возврат при смерти/падении.

const SUNNY_SCENE := "res://scenes/characters/sunny.tscn"
const PROLOGUE_SCENE := "res://scenes/slice/prologue.tscn"

const EXPECTED_IDS: Array[StringName] = [
	&"P01", &"P02", &"P03", &"P04",
	&"N05", &"N06", &"N07", &"N08", &"N09", &"N10",
	&"N11", &"N12", &"N13",
	&"N14", &"N15", &"N16", &"N17", &"N18", &"N19",
	&"N20", &"N21", &"N22", &"N23",
	&"N24", &"N25", &"N26",
]

const EXPECTED_CHECKPOINTS: Array[StringName] = [
	&"CP-N08",
	&"CP-N09",
	&"CP-N10a",
	&"CP-N10b",
	&"CP-N15a",
	&"CP-N15b",
	&"CP-N15c",
	&"CP-N15d",
	&"CP-N17",
	&"CP-N18",
	&"CP-N20",
	&"CP-N21a",
	&"CP-N21b",
	&"CP-N23",
]


func before_each() -> void:
	NightmareRunState.reset()


func after_each() -> void:
	NightmareRunState.reset()


func test_all_twenty_six_beat_resources_load_and_match_v2_sheet() -> void:
	var beats := BeatDirector.load_default_beats()
	assert_eq(beats.size(), 26, "в списке v2 ровно 26 событий")
	var loaded_ids: Array[StringName] = []
	var seen_types: Dictionary = {}
	for beat in beats:
		assert_not_null(beat)
		if beat == null:
			continue
		assert_true(beat.is_valid(), "событие %s валидно" % beat.id)
		assert_true(FileAccess.file_exists(beat.scene_path), "%s ссылается на существующую сцену %s" % [beat.id, beat.scene_path])
		assert_false(beat.part.is_empty(), "%s указывает часть/акт" % beat.id)
		assert_false(beat.part_title.is_empty(), "%s указывает название акта" % beat.id)
		assert_between(beat.canonical_block, 1, 20, "%s привязан к каноническому блоку 01–20" % beat.id)
		assert_false(beat.objective.contains("\n"), "%s: цель строго одной строкой" % beat.id)
		loaded_ids.append(beat.id)
		seen_types[beat.get_type_name()] = true

	assert_eq(loaded_ids, EXPECTED_IDS, "порядок событий строго P01–N26")
	for type_name in ["игра", "катсцена", "интерактивная катсцена", "склейка"]:
		assert_true(seen_types.has(type_name), "представлен тип события: %s" % type_name)


func test_fourteen_hazard_checkpoints_are_defined_across_beats() -> void:
	var director := BeatDirector.new()
	add_child_autofree(director)
	var checkpoints := director.get_all_checkpoints()
	assert_eq(checkpoints.size(), 14, "расставлено 14 чекпоинтов перед опасностями")
	assert_eq(checkpoints, EXPECTED_CHECKPOINTS, "идентификаторы чекпоинтов совпадают со списком v2 (§3)")
	for cid in checkpoints:
		var owner_beat := director.find_beat_for_checkpoint(cid)
		assert_not_null(owner_beat, "чекпоинт %s привязан к событию" % cid)
		if owner_beat != null:
			assert_true(owner_beat.has_checkpoint(cid))


func test_beat_director_walks_all_beats_in_order_and_emits_signals() -> void:
	var director := BeatDirector.new()
	add_child_autofree(director)

	var started_ids: Array[StringName] = []
	var completed_ids: Array[StringName] = []
	var objectives: Array[String] = []
	var campaign_done := [false]

	director.beat_started.connect(func(beat: BeatData) -> void: started_ids.append(beat.id))
	director.beat_completed.connect(func(beat: BeatData) -> void: completed_ids.append(beat.id))
	director.objective_changed.connect(func(obj: String) -> void: objectives.append(obj))
	director.campaign_completed.connect(func() -> void: campaign_done[0] = true)

	assert_false(director.start_beat(&"N06", false), "без входного флага prologue_completed нельзя войти в N06")

	var first := director.start_campaign(&"P01", false)
	assert_not_null(first)
	assert_eq(first.id, &"P01")
	assert_eq(director.current_objective, "Допить кофе → Перейти улицу")

	for step in 26:
		assert_not_null(director.current_beat)
		director.complete_current_beat(true)

	assert_eq(started_ids, EXPECTED_IDS, "все 26 событий стартовали строго по порядку")
	assert_eq(completed_ids, EXPECTED_IDS, "все 26 событий завершились строго по порядку")
	assert_eq(objectives.size(), 26, "на каждое событие обновлялась строка цели")
	assert_true(campaign_done[0], "после N26 эмитится campaign_completed")
	assert_true(NightmareRunState.has_flag(&"first_nightmare_completed"))


func test_n13_staging_sets_flasks_poisoned_without_button() -> void:
	var director := BeatDirector.new()
	add_child_autofree(director)

	assert_false(NightmareRunState.has_flag(&"flasks_poisoned"))
	assert_false(NightmareRunState.has_flag(&"sunny_flask_clean"))

	assert_true(director.complete_beat(&"N07", false))
	assert_true(NightmareRunState.has_flag(&"camp_bloodbane_seen"), "N07 ставит camp_bloodbane_seen постановкой")

	assert_true(director.complete_beat(&"N13", false))
	assert_true(NightmareRunState.has_flag(&"flasks_poisoned"), "N13 ставит flasks_poisoned постановкой, а не кнопкой")
	assert_true(NightmareRunState.has_flag(&"sunny_flask_clean"), "N13 ставит sunny_flask_clean постановкой")


func test_checkpoint_persists_in_run_state_and_recovers_on_fall_and_death() -> void:
	var sunny := (load(SUNNY_SCENE) as PackedScene).instantiate() as SunnyController
	add_child_autofree(sunny)
	sunny.global_position = Vector3(0.0, 0.05, 0.0)
	sunny.attack.set_physics_process(false)
	var recovery := sunny.get_node("FallRecovery") as FallRecovery

	var director := BeatDirector.new()
	add_child_autofree(director)
	director.bind_player(sunny)

	assert_true(director.start_beat(&"N08", true))
	assert_eq(NightmareRunState.get_checkpoint_id(), &"CP-N08")
	assert_eq(recovery.get_checkpoint_id(), &"CP-N08")
	var cp_n08 := director.get_active_checkpoint_position()
	assert_eq(recovery.recovery_point(), cp_n08)

	# Переключение на вторую точку внутри N10 (перед броском петли).
	assert_true(director.start_beat(&"N10", true))
	assert_eq(recovery.get_checkpoint_id(), &"CP-N10a")
	var cp_n10b := director.activate_checkpoint(&"CP-N10b")
	assert_eq(NightmareRunState.get_checkpoint_id(), &"CP-N10b")
	assert_eq(recovery.get_checkpoint_id(), &"CP-N10b")
	assert_eq(recovery.recovery_point(), cp_n10b)

	# Снимок и восстановление состояния кампании сохраняют чекпоинт и событие.
	var snap := NightmareRunState.snapshot()
	NightmareRunState.reset()
	assert_false(NightmareRunState.has_checkpoint())
	NightmareRunState.restore(snap)
	assert_eq(NightmareRunState.get_current_beat(), &"N10")
	assert_eq(NightmareRunState.get_checkpoint_id(), &"CP-N10b")
	assert_eq(NightmareRunState.get_checkpoint_position(), cp_n10b)

	# Смерть от урона мгновенно возвращает на CP-N10b без загрузочного экрана.
	sunny.global_position = Vector3(8.0, 0.05, 4.0)
	watch_signals(recovery)
	sunny.health.take_damage(sunny.health.max_health)
	assert_signal_emitted_with_parameters(recovery, "recovered", [cp_n10b])
	assert_false(sunny.is_dead(), "после возврата на чекпоинт Санни снова жив")
	assert_eq(sunny.health.current_health, sunny.health.max_health)
	assert_true(sunny.controls_enabled, "управление возвращено сразу")
	assert_eq(sunny.global_position, cp_n10b)


func test_no_false_recovery_during_cutscenes_or_scripted_teleports() -> void:
	var sunny := (load(SUNNY_SCENE) as PackedScene).instantiate() as SunnyController
	add_child_autofree(sunny)
	sunny.global_position = Vector3(0.0, 0.05, 0.0)
	sunny.attack.set_physics_process(false)
	var recovery := sunny.get_node("FallRecovery") as FallRecovery

	var director := BeatDirector.new()
	add_child_autofree(director)
	director.bind_player(sunny)
	assert_true(director.start_beat(&"N15", true))
	var cp_n15b := director.activate_checkpoint(&"CP-N15b")
	watch_signals(recovery)

	# 1. Катсцена (input_enabled = false) со смещением вниз глубже fall_limit.
	sunny.input_enabled = false
	sunny.global_position = Vector3(1.0, -35.0, -5.0)
	await wait_physics_frames(20)
	assert_signal_not_emitted(recovery, "recovered", "во время катсцены ложного возврата нет")
	assert_eq(recovery.get_checkpoint_id(), &"CP-N15b", "чекпоинт сохраняется после катсцены")

	# 2. Скриптовый телепорт при включённом вводе.
	sunny.input_enabled = true
	sunny.global_position = Vector3(1.0, 4.15, -26.0)
	await wait_physics_frames(5)
	assert_signal_not_emitted(recovery, "recovered", "при скриптовом перемещении ложного возврата нет")
	assert_eq(recovery.get_checkpoint_id(), &"CP-N15b", "чекпоинт сохраняется после телепорта")
	assert_eq(recovery.recovery_point(), cp_n15b)


func test_slice_director_syncs_prologue_beats_p01_to_n05() -> void:
	var slice := (load(PROLOGUE_SCENE) as PackedScene).instantiate() as SliceDirector
	slice.autostart = false
	slice.fast_mode = true
	add_child_autofree(slice)

	var seen_v2: Array[StringName] = []
	slice.beat_director.beat_started.connect(func(beat: BeatData) -> void: seen_v2.append(beat.id))
	slice.start()

	for step in 220:
		if slice.beat >= SliceDirector.Beat.FINISHED:
			break
		if slice.runner.running:
			slice.runner.advance()
		elif slice.ui.rune_status.showing:
			slice.ui.rune_status.close()
		elif slice.awaiting != &"":
			slice.notify(slice.awaiting)
		await wait_process_frames(1)

	var expected_prologue: Array[StringName] = [&"P01", &"P02", &"P03", &"P04", &"N05"]
	assert_eq(seen_v2, expected_prologue, "SliceDirector проводит события P01–N05")
