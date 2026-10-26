extends GutTest
## Сценарий среза «Nightmare Begins»: порядок битов B01–B16, переходы только по ожидаемым событиям,
## режимы управления. Режиссёр работает в быстром режиме: переходы и постановки мгновенные,
## а реплики с «далее» по-прежнему ждут нажатия.

const PROLOGUE := "res://scenes/slice/prologue.tscn"

var director: SliceDirector
var beats: Array = []


func before_each() -> void:
	NightmareRunState.reset()
	beats.clear()
	director = (load(PROLOGUE) as PackedScene).instantiate() as SliceDirector
	director.autostart = false
	director.fast_mode = true
	director.beat_changed.connect(func(beat: SliceDirector.Beat) -> void: beats.append(beat))
	add_child_autofree(director)


func after_each() -> void:
	NightmareRunState.reset()


## Один шаг «игрока»: пролистать реплику, закрыть руны или выполнить ожидаемое действие.
func _step() -> void:
	if director.runner.running:
		director.runner.advance()
	elif director.ui.rune_status.showing:
		director.ui.rune_status.close()
	elif director.awaiting != &"":
		director.notify(director.awaiting)


func _run_until(target: SliceDirector.Beat, max_steps := 200) -> void:
	for i in max_steps:
		if director.beat >= target:
			return
		_step()
		await wait_process_frames(1)


func test_full_playthrough_visits_every_beat_in_order() -> void:
	watch_signals(director)
	director.start()
	await _run_until(SliceDirector.Beat.FINISHED)
	var expected := range(SliceDirector.Beat.B01_OPENING, SliceDirector.Beat.FINISHED + 1)
	assert_eq(beats, expected, "все биты по порядку, без пропусков и повторов")
	assert_signal_emitted(director, "slice_finished")
	assert_true(director.ui.end_card.visible, "финальная карточка показана")
	assert_eq(director.location.name, &"CaravanRoad", "срез заканчивается на дороге каравана")


func test_cutscene_blocks_script_in_real_time() -> void:
	director.fast_mode = false
	director.start()
	await wait_until(func() -> bool: return director.awaiting == &"interact:coffee", 3.0)
	director.notify(&"interact:coffee")
	director.runner.advance()
	director.notify(&"interact:coffee")
	director.runner.advance()
	assert_eq(director.beat, SliceDirector.Beat.B03_DOZE)
	assert_true(director.location.shot(&"DozeShot").current, "идёт постановка дремоты")
	await wait_seconds(1.0)
	assert_false(director.runner.running, "реплика ждёт конца постановки")
	assert_eq(director.beat, SliceDirector.Beat.B03_DOZE)


func test_unexpected_events_do_not_advance() -> void:
	director.start()
	assert_eq(director.beat, SliceDirector.Beat.B02_FIRST_SIPS)
	assert_eq(director.awaiting, &"interact:coffee")
	director.notify(&"trigger:station_entrance")
	director.notify(&"interact:station_door")
	director.notify(&"open_status")
	await wait_process_frames(2)
	assert_eq(director.beat, SliceDirector.Beat.B02_FIRST_SIPS, "чужие события игнорируются")
	assert_eq(director.awaiting, &"interact:coffee")


func test_only_current_interaction_is_enabled() -> void:
	director.start()
	assert_true(director.location.get_interactable(&"coffee").enabled)
	assert_false(director.location.get_interactable(&"bin").enabled, "урна ждёт своей очереди")
	assert_false(director.location.get_interactable(&"station_door").enabled)
	assert_false(director.location.get_trigger(&"station_entrance").enabled)
	director.notify(&"interact:coffee")
	assert_true(director.runner.running, "после глотка идёт реплика")
	assert_false(director.location.get_interactable(&"coffee").enabled, "во время реплики взаимодействие выключено")


func test_bench_is_look_only() -> void:
	director.start()
	assert_eq(director.mode, SliceDirector.Mode.LOOK)
	assert_false(director.player.input_enabled, "на скамейке ходить нельзя")
	assert_true(director.interactor.enabled, "но можно отпить кофе")
	assert_false(director.player.is_physics_processing(), "сидящее тело не падает со скамейки")
	assert_true(director.actor.active, "поза задаётся постановкой")


func test_free_walk_has_no_combat_sprint_or_jump() -> void:
	director.start()
	await _run_until(SliceDirector.Beat.B05_BIN)
	assert_eq(director.mode, SliceDirector.Mode.FREE)
	assert_true(director.player.input_enabled)
	assert_true(director.player.is_physics_processing())
	assert_false(director.player.combat_enabled)
	assert_false(director.player.allow_sprint)
	assert_false(director.player.allow_jump)
	assert_false(director.player.try_attack(), "в прологе нет боя")


func test_restrained_scene_locks_movement_but_allows_look() -> void:
	director.start()
	await _run_until(SliceDirector.Beat.B12_BRIEFING)
	assert_eq(director.location.name, &"ContainmentRoom")
	assert_eq(director.mode, SliceDirector.Mode.LOOK)
	assert_false(director.player.input_enabled)
	assert_true(director.player.camera_rig.look_enabled)
	assert_true(director.actor.active, "Санни пристёгнут к стулу")


func test_briefing_raises_drowsiness() -> void:
	director.start()
	await _run_until(SliceDirector.Beat.B12_BRIEFING)
	var start := director.ui.drowsiness.intensity
	for i in 8:
		director.runner.advance()
	assert_gt(director.ui.drowsiness.intensity, start, "сонливость растёт с каждой репликой брифинга")


func test_caravan_marches_in_chain() -> void:
	director.start()
	await _run_until(SliceDirector.Beat.B15_CARAVAN)
	assert_eq(director.location.name, &"CaravanRoad")
	assert_eq(director.mode, SliceDirector.Mode.CHAINED)
	assert_false(director.player.input_enabled, "темп задаёт цепь")
	assert_true(director.player.camera_rig.look_enabled, "оглядеться можно")
	assert_eq(director.player.forced_velocity, director.location.march_velocity())
	assert_ne(director.player.forced_velocity, Vector3.ZERO)
	assert_true(director.player.visual.visible, "Санни снова виден")
	assert_false(director.actor.active, "походку выбирает аниматор передвижения")


func test_status_opens_only_after_caravan_lines() -> void:
	var caravan_lines: Array[String] = []
	director.runner.line_started.connect(func(line: DialogueLine, _i: int, _n: int) -> void:
		if director.beat == SliceDirector.Beat.B15_CARAVAN:
			caravan_lines.append(line.text))
	director.start()
	await _run_until(SliceDirector.Beat.B15_CARAVAN)
	assert_eq(director.awaiting, &"open_status")
	assert_false(director.runner.running)
	assert_false(NightmareRunState.has_flag(&"mark_of_divinity"),
		"Mark of Divinity не раскрыт до экрана рун B16")
	var caravan := load(SliceDirector.DIALOGUE_DIR + "caravan.tres") as DialogueSequence
	assert_eq(caravan_lines.size(), caravan.lines.size(), "статус ждёт, пока Санни осознает, где он")
	assert_true(director.ui.hint.visible, "подсказка, как вызвать статус")
	await _run_until(SliceDirector.Beat.B16_RUNES)
	assert_true(director.ui.rune_status.showing, "руны на экране")
	assert_true(NightmareRunState.has_flag(&"mark_of_divinity"),
		"B16 устанавливает Mark of Divinity как флаг-атрибут")
	assert_false(NightmareRunState.has_item(&"mark_of_divinity"),
		"Mark of Divinity не попадает в инвентарь")
	assert_string_contains("\n".join(director.ui.rune_status.row_texts()), "Mark of Divinity")
	assert_string_contains("\n".join(director.ui.rune_status.row_texts()), "Temple Slave")
