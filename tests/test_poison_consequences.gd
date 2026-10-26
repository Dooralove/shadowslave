extends GutTest
## B1-B: последствия отравления общих фляг.
##
## Камп-часть проходит через реальные взаимодействия (как в test_poison_flasks).
## Для алькова, Шифти, Учёного и пещеры проверяется содержимое последовательностей
## и порядок реплик при запуске через DialogueRunner: флаги этих эпизодов не
## выставляются вручную.

const CAMP_ARRIVAL := "res://scenes/campaign/caravan_site_arrival.tscn"
const SHIFTY := "res://resources/dialogue/pilgrim/pilgrim_shifty.tres"
const ALCOVE := "res://resources/dialogue/pilgrim/pilgrim_alcove.tres"
const SCHOLAR := "res://resources/dialogue/pilgrim/pilgrim_scholar.tres"
const CAVE := "res://resources/dialogue/pilgrim/pilgrim_cave.tres"
const NIGHT_POISON := "res://resources/dialogue/caravan/camp_night_poison.tres"
## Индекс строки «Он падает назад» в pilgrim_shifty.tres (см. PilgrimAlcoveArrival).
const SHIFTY_FALL_LINE_INDEX := 4


func before_each() -> void:
	NightmareRunState.reset()


func after_each() -> void:
	NightmareRunState.reset()


func _spawn_wrapper() -> Node3D:
	var scene := (load(CAMP_ARRIVAL) as PackedScene).instantiate() as Node3D
	scene.transition_enabled = false
	scene.fade_in = false
	scene.fast_mode = true
	scene.debug_direct_scene = true
	add_child_autofree(scene)
	return scene


func _wait_until(predicate: Callable, max_frames := 90) -> bool:
	for i in max_frames:
		if predicate.call():
			return true
		await wait_process_frames(1)
	return false


func _press(site: CaravanSite, id: StringName) -> void:
	site.get_interactable(id).interact()


func _advance_to_aftermath(site: CaravanSite) -> bool:
	if not await _wait_until(func() -> bool: return site.get_interactable(&"camp_attack") != null):
		return false
	_press(site, &"camp_rations")
	_press(site, &"camp_bloodbane")
	_press(site, &"camp_wagon")
	_press(site, &"camp_attack")
	if not await _wait_until(func() -> bool: return site.phase == CaravanSite.PHASE_LARVA):
		return false
	_press(site, &"chain_larva")
	if not await _wait_until(func() -> bool: return site.get_interactable(&"hero_key").enabled):
		return false
	_press(site, &"hero_key")
	if not await _wait_until(func() -> bool: return site.get_interactable(&"wagon_wedges").enabled):
		return false
	_press(site, &"wagon_wedges")
	_press(site, &"wagon_loop")
	_press(site, &"wagon_push")
	if not await _wait_until(func() -> bool: return site.phase == CaravanSite.PHASE_AFTERMATH, 240):
		return false
	return await _wait_until(func() -> bool: return NightmareRunState.has_flag(&"tasks_assigned"))


## Реальный путь до отравления: осмотр, фляги, ветеран и отравление через Interactable.
func _poison_through_interaction(site: CaravanSite) -> bool:
	if not await _advance_to_aftermath(site):
		return false
	_press(site, &"flask_a")
	_press(site, &"flask_b")
	_press(site, &"flask_c")
	_press(site, &"poison_flasks")
	return NightmareRunState.has_flag(&"flasks_poisoned")


func _run_sequence(path: String) -> Array[DialogueLine]:
	var runner := DialogueRunner.new()
	runner.fast_mode = true
	add_child_autofree(runner)
	var seen: Array[DialogueLine] = []
	runner.line_started.connect(func(line: DialogueLine, _index: int, _count: int) -> void: seen.append(line))
	var sequence := load(path) as DialogueSequence
	await runner.run(sequence)
	return seen


func test_night_symptoms_show_shifty_and_scholar_before_night_and_not_sunny() -> void:
	var wrapper := _spawn_wrapper()
	var site := wrapper.get_node("CaravanSite") as CaravanSite
	assert_true(await _poison_through_interaction(site), "отравление выполнено реальным взаимодействием")
	_press(site, &"veteran")
	assert_true(await _wait_until(func() -> bool: return site.get_interactable(&"veteran_sword").enabled))
	_press(site, &"veteran_sword")
	assert_true(await _wait_until(func() -> bool: return NightmareRunState.has_flag(&"veteran_dead")))

	var runner := wrapper.get_node("DialogueRunner") as DialogueRunner
	var speakers: Array[StringName] = []
	var texts: Array[String] = []
	runner.line_started.connect(func(line: DialogueLine, _index: int, _count: int) -> void:
		speakers.append(line.speaker)
		texts.append(line.text))
	_press(site, &"night_fire")
	assert_true(await _wait_until(func() -> bool: return NightmareRunState.has_flag(&"night_started")))
	assert_true(await _wait_until(func() -> bool: return site.phase == CaravanSite.PHASE_DAWN, 240))

	var first_night_line := texts.find("Огонь трещит. Четверо сидят спиной к теплу, лицом к темноте.")
	var symptom_index := texts.find("Ещё глоток... горько, но пить хочется.")
	assert_gt(symptom_index, -1, "Шифти показывает симптомы в ночь")
	assert_lt(symptom_index, first_night_line, "симптомы идут до обычной ночной сцены")
	assert_true(speakers.has(&"scholar"), "Учёный показывает симптомы")
	var sunny_symptom := false
	for i in speakers.size():
		if speakers[i] == &"sunny" and (texts[i].contains("мутит") or texts[i].contains("горько")):
			sunny_symptom = true
	assert_false(sunny_symptom, "Санни симптомов не получает")
	assert_true(NightmareRunState.has_flag(&"flasks_poisoned"), "флаг отравления сохраняется после ночи")
	assert_true(NightmareRunState.has_flag(&"sunny_flask_clean"))
	assert_eq(NightmareRunState.get_item_count(&"flasks"), 3, "фляги не расходуются")


func test_night_poison_sequence_is_skipped_without_poison() -> void:
	# Ночь без отравления заблокирована в CaravanSite; здесь проверяется сам
	# условный запуск симптомов, когда флага нет.
	var wrapper := _spawn_wrapper()
	var runner := wrapper.get_node("DialogueRunner") as DialogueRunner
	var texts: Array[String] = []
	runner.line_started.connect(func(line: DialogueLine, _index: int, _count: int) -> void: texts.append(line.text))
	await wait_process_frames(2)
	wrapper.call(&"_handle_night")
	await wait_process_frames(2)
	assert_false(texts.any(func(t: String) -> bool: return t.contains("Ещё глоток")), "без отравления симптомов нет")


func test_shifty_weakness_is_shown_before_his_fall() -> void:
	var seen := await _run_sequence(SHIFTY)
	assert_gt(seen.size(), SHIFTY_FALL_LINE_INDEX, "последовательность доходит до падения")
	assert_true((seen[0] as DialogueLine).text.contains("мутные"), "до падения Шифти виден признак ослабления")
	assert_true((seen[SHIFTY_FALL_LINE_INDEX] as DialogueLine).text.contains("Он падает назад"),
		"падение остаётся на прежнем индексе")
	for index in range(SHIFTY_FALL_LINE_INDEX + 1, seen.size()):
		var text := (seen[index] as DialogueLine).text
		assert_false(text.contains("мутные") or text.contains("дышит поверхностно") or text.contains("держится"),
			"после падения текст о состоянии Шифти не звучит")
	assert_false(NightmareRunState.has_flag(&"shifty_dead"), "последовательность сама флаг смерти не ставит")


func test_alcove_water_comes_from_shared_flasks_not_sunny() -> void:
	var seen := await _run_sequence(ALCOVE)
	var water_lines: Array[String] = []
	for line in seen:
		if (line as DialogueLine).text.contains("фляг") or (line as DialogueLine).text.contains("Вода"):
			water_lines.append((line as DialogueLine).text)
	assert_true(water_lines.any(func(t: String) -> bool: return t.contains("Общие фляги")), "вода из общих фляг")
	assert_false(seen.any(func(line: DialogueLine) -> bool: return line.text.contains("У Санни")),
		"собственная чистая фляга Санни не источник воды")


func test_scholar_symptoms_come_first_and_do_not_set_abandon_or_death() -> void:
	var seen := await _run_sequence(SCHOLAR)
	assert_gt(seen.size(), 2)
	assert_eq((seen[0] as DialogueLine).speaker, &"narration")
	assert_true((seen[0] as DialogueLine).text.contains("держится за живот"), "Учёный отравлен до встречи")
	assert_false(NightmareRunState.has_flag(&"scholar_abandoned"), "симптомы не выставляют оставление")
	assert_false(NightmareRunState.has_flag(&"hero_dead"), "симптомы Учёного не выставляют смерть")


func test_cave_confession_matches_the_poison_actions() -> void:
	var seen := await _run_sequence(CAVE)
	var confession := seen.filter(func(line: DialogueLine) -> bool: return line.text.contains("Bloodbane"))
	assert_eq(confession.size(), 1, "признание о Bloodbane есть")
	assert_true((confession[0] as DialogueLine).text.contains("отравил фляги"), "признание называет совершённое действие")
	assert_true(seen.any(func(line: DialogueLine) -> bool: return line.text.contains("Шифти выпил больше всех")),
		"пещера повторяет канон: Шифти пил больше всех")
	assert_true(seen.any(func(line: DialogueLine) -> bool: return line.text.contains("Яд меня не убьёт")),
		"Герой не погибает от яда")
	assert_false(NightmareRunState.has_flag(&"hero_dead"), "Герой не получает флаг смерти от яда")


func test_night_poison_resource_loads_with_expected_speakers() -> void:
	var seen := await _run_sequence(NIGHT_POISON)
	assert_eq(seen.size(), 5)
	assert_true(seen.any(func(line: DialogueLine) -> bool: return line.speaker == &"shifty"))
	assert_true(seen.any(func(line: DialogueLine) -> bool: return line.speaker == &"scholar"))
	assert_false(seen.any(func(line: DialogueLine) -> bool: return line.speaker == &"sunny"))
