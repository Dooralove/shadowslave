extends GutTest
## Диалоговые данные пролога и проигрыватель реплик.

const DIR := "res://resources/dialogue/prologue/"
## Все последовательности, которые вызывает режиссёр.
const SEQUENCES := [&"sip_1", &"sip_2", &"doze", &"tall_people", &"desk", &"code_black", &"briefing", &"caravan"]


func _line(text: String, duration := 0.0) -> DialogueLine:
	var line := DialogueLine.new()
	line.speaker = &"sunny"
	line.text = text
	line.duration = duration
	return line


func test_every_sequence_is_valid() -> void:
	var runner := DialogueRunner.new()
	autofree(runner)
	for sequence_name in SEQUENCES:
		var sequence := load(DIR + sequence_name + ".tres") as DialogueSequence
		assert_not_null(sequence, "%s загружается" % sequence_name)
		if sequence == null:
			continue
		assert_gt(sequence.lines.size(), 0, "%s не пуста" % sequence_name)
		for line in sequence.lines:
			assert_true(line is DialogueLine, "%s: реплика типа DialogueLine" % sequence_name)
			assert_false((line as DialogueLine).text.strip_edges().is_empty(), "%s: текст не пуст" % sequence_name)
			assert_true(runner.speaker_names.has(line.speaker), "%s: известный говорящий %s" % [sequence_name, line.speaker])


func test_briefing_covers_canon_points() -> void:
	var text := ""
	for line in (load(DIR + "briefing.tres") as DialogueSequence).lines:
		text += (line as DialogueLine).text + "\n"
	for fragment in ["Санлесс", "затмени", "Некому", "иллюзи", "Атрибуты", "Аспект", "не умирай"]:
		assert_string_contains(text, fragment)


func test_caravan_ends_on_status_question() -> void:
	var lines := (load(DIR + "caravan.tres") as DialogueSequence).lines
	assert_string_contains((lines[-1] as DialogueLine).text, "вызывается", "финал — как вызвать статус")
	for line in lines:
		assert_gt((line as DialogueLine).duration, 0.0, "реплики в цепи идут сами, Санни не останавливается")


func test_runner_waits_for_advance_and_skips_timers_in_fast_mode() -> void:
	var runner := DialogueRunner.new()
	add_child_autofree(runner)
	runner.fast_mode = true
	var sequence := DialogueSequence.new()
	sequence.lines = [_line("Первая"), _line("Вторая", 2.0)]
	watch_signals(runner)
	runner.run(sequence)
	assert_true(runner.running)
	assert_signal_emit_count(runner, "line_started", 1, "ждёт «далее» на первой реплике")
	runner.advance()
	assert_signal_emit_count(runner, "line_started", 2)
	assert_signal_emitted(runner, "finished", "реплика с таймером в быстром режиме не ждёт")
	assert_false(runner.running)


func test_display_names() -> void:
	var runner := DialogueRunner.new()
	autofree(runner)
	assert_eq(runner.display_name(&"sunny"), "Санни")
	assert_eq(runner.display_name(&"narration"), "", "повествование без имени")
