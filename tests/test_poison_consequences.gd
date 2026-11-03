extends GutTest
## Акт II: последствия ночного монтажа в последующих сценах.
## Сам монтаж проверяется в test_poison_flasks; здесь — только сюжетные тексты
## и то, что они не выставляют лишних флагов.

const SHIFTY := "res://resources/dialogue/pilgrim/pilgrim_shifty.tres"
const ALCOVE := "res://resources/dialogue/pilgrim/pilgrim_alcove.tres"
const SCHOLAR := "res://resources/dialogue/pilgrim/pilgrim_scholar.tres"
const CAVE := "res://resources/dialogue/pilgrim/pilgrim_cave.tres"
const SHIFTY_FALL_LINE_INDEX := 4


func before_each() -> void:
	NightmareRunState.reset()


func after_each() -> void:
	NightmareRunState.reset()


func _run_sequence(path: String) -> Array[DialogueLine]:
	var runner := DialogueRunner.new()
	runner.fast_mode = true
	add_child_autofree(runner)
	var seen: Array[DialogueLine] = []
	runner.line_started.connect(func(line: DialogueLine, _index: int, _count: int) -> void: seen.append(line))
	var sequence := load(path) as DialogueSequence
	await runner.run(sequence)
	return seen


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
