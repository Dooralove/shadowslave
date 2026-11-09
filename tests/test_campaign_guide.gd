extends GutTest
## Система целей и подсказок: источник цели — BeatData, строка меняется по
## objective_changed, idle-ступени уточняют её и сбрасываются на действии,
## мысли лежат в GuideThought-ресурсах, журнал показывает ту же цель.

const N12_PATH := "res://resources/campaign/beats/n12.tres"
const N14_PATH := "res://resources/campaign/beats/n14.tres"
const N15_PATH := "res://resources/campaign/beats/n15.tres"
const N16_PATH := "res://resources/campaign/beats/n16.tres"
const SETTINGS_PATH := "res://resources/campaign/guide/guide_settings.tres"
const OBJECTIVE_LINE_SCENE := "res://scenes/ui/objective_line.tscn"


func before_each() -> void:
	QuestSystem.deactivate_scope()
	NightmareRunState.reset()
	CampaignGuide.reset_campaign()
	CampaignGuide.settings = load(SETTINGS_PATH) as GuideSettings


func after_each() -> void:
	QuestSystem.deactivate_scope()
	NightmareRunState.reset()
	CampaignGuide.reset_campaign()
	CampaignGuide.settings = load(SETTINGS_PATH) as GuideSettings


func _beat(path: String) -> BeatData:
	return load(path) as BeatData


func test_objective_comes_from_beat_data_and_changes_through_director() -> void:
	var director := BeatDirector.new()
	add_child_autofree(director)
	watch_signals(CampaignGuide)

	assert_true(director.start_beat(&"N14", true))
	assert_eq(CampaignGuide.get_current_beat_id(), &"N14")
	assert_eq(CampaignGuide.display_objective, "Подняться за Героем по старой тропе")
	assert_signal_emitted_with_parameters(CampaignGuide, "objective_changed", [
		"Подняться за Героем по старой тропе",
		"Подняться за Героем по старой тропе",
		0,
	])

	director.transition_to_beat(&"N15")
	assert_eq(CampaignGuide.get_current_beat_id(), &"N15")
	assert_eq(CampaignGuide.base_objective, "Подняться за Героем по старой тропе")
	assert_eq(CampaignGuide.history.size(), 2, "журнал получает новую цель события")
	assert_eq(CampaignGuide.history.back()["beat_id"], &"N15")


func test_idle_steps_concretize_objective_and_reset_on_action() -> void:
	var beat := _beat(N14_PATH)
	CampaignGuide.apply_beat(beat)
	var custom := GuideSettings.new()
	custom.idle_seconds = 1.0
	custom.idle_step_seconds = 1.0
	custom.max_idle_steps = 3
	CampaignGuide.settings = custom

	CampaignGuide.advance_idle(0.9, true)
	assert_eq(CampaignGuide.idle_step, 0, "до N секунд цель не меняется")
	assert_eq(CampaignGuide.display_objective, beat.objective)

	CampaignGuide.advance_idle(0.2, true)
	assert_eq(CampaignGuide.idle_step, 1, "первая ступень после N секунд")
	assert_eq(CampaignGuide.display_objective, beat.idle_objectives[0])

	CampaignGuide.advance_idle(1.0, true)
	assert_eq(CampaignGuide.idle_step, 2)
	assert_eq(CampaignGuide.display_objective, beat.idle_objectives[1])

	CampaignGuide.advance_idle(1.0, true)
	assert_eq(CampaignGuide.idle_step, 3)
	assert_eq(CampaignGuide.display_objective, beat.idle_objectives[2])

	CampaignGuide.advance_idle(0.1, false)
	assert_eq(CampaignGuide.idle_step, 0, "осмысленное действие сбрасывает ступени")
	assert_eq(CampaignGuide.display_objective, beat.objective)


func test_idle_resets_when_the_beat_changes() -> void:
	var custom := GuideSettings.new()
	custom.idle_seconds = 0.5
	custom.idle_step_seconds = 0.5
	CampaignGuide.settings = custom
	CampaignGuide.apply_beat(_beat(N14_PATH))
	CampaignGuide.advance_idle(0.6, true)
	assert_eq(CampaignGuide.idle_step, 1)

	CampaignGuide.apply_beat(_beat(N15_PATH))
	assert_eq(CampaignGuide.idle_step, 0, "новая цель начинается без старого уточнения")
	assert_eq(CampaignGuide.display_objective, _beat(N15_PATH).objective)


func test_journal_panel_shows_the_same_current_objective() -> void:
	var screen := (load("res://scenes/ui/rpg_menu/quest_screen.tscn") as PackedScene).instantiate() as RpgQuestScreen
	add_child_autofree(screen)
	await wait_process_frames(1)
	var panel := screen.get_node("%CurrentPanel") as Control
	var label := screen.get_node("%CurrentObjective") as Label
	assert_false(panel.visible, "без кампании текущая цель скрыта")

	CampaignGuide.apply_beat(_beat(N15_PATH))
	await wait_process_frames(1)
	assert_true(panel.visible, "журнал показывает текущую цель")
	assert_eq(label.text, _beat(N15_PATH).objective)


func test_journal_entry_appears_without_an_objective() -> void:
	var screen := (load("res://scenes/ui/rpg_menu/quest_screen.tscn") as PackedScene).instantiate() as RpgQuestScreen
	add_child_autofree(screen)
	await wait_process_frames(1)
	CampaignGuide.add_journal_entry(load("res://resources/campaign/journal/rules_of_nightmare.tres") as JournalEntryData)
	await wait_process_frames(1)
	var panel := screen.get_node("%CurrentPanel") as Control
	var journal := screen.get_node("%CurrentJournal") as Label
	assert_true(panel.visible, "запись журнала показывает панель даже без цели")
	assert_true(journal.visible)
	assert_string_contains(journal.text, "Правила Кошмара")


func test_thoughts_are_resources_and_do_not_name_buttons() -> void:
	var thought := CampaignGuide.get_thought(&"thought_gap")
	assert_not_null(thought, "мысль загружается из resources/campaign/thoughts")
	assert_false(thought.text.strip_edges().is_empty())
	assert_string_contains(thought.text, "провал")
	for text in CampaignGuide.get_thought_texts():
		var lower := text.to_lower()
		assert_false(lower.contains("нажми"), "мысль не велит нажимать: %s" % text)
		assert_false(lower.contains("кнопк"), "мысль не называет кнопку: %s" % text)
		assert_false(text.contains(" E "), "мысль не называет клавишу E: %s" % text)


func test_objective_line_appears_and_fades_softly() -> void:
	var line := (load("res://scenes/ui/objective_line.tscn") as PackedScene).instantiate() as ObjectiveLine
	add_child_autofree(line)
	await wait_process_frames(1)
	assert_false(line.is_showing(), "строка скрыта до цели")

	line.show_objective("Подняться к храму", 0, true)
	assert_true(line.is_showing())
	assert_eq(line.get_objective_text(), "Подняться к храму")
	assert_eq(line.modulate.a, 1.0)

	line.hide_objective(true)
	assert_false(line.is_showing())
	assert_eq(line.modulate.a, 0.0)


func test_thought_trigger_waits_for_its_beat_and_creates_world_bubble() -> void:
	var trigger := ThoughtTrigger.new()
	trigger.thought_id = &"thought_gap"
	trigger.beat_id = &"N14"
	add_child_autofree(trigger)
	watch_signals(trigger)

	CampaignGuide.apply_beat(_beat(N15_PATH))
	trigger.fire()
	assert_signal_not_emitted(trigger, "thought_triggered", "мысль не звучит раньше своего события")

	CampaignGuide.apply_beat(_beat(N14_PATH))
	trigger.fire()
	assert_signal_emitted(trigger, "thought_triggered", "в своём событии мысль срабатывает")

	var sunny := (load("res://scenes/characters/sunny.tscn") as PackedScene).instantiate() as SunnyController
	add_child_autofree(sunny)
	await wait_physics_frames(1)
	sunny.attack.set_physics_process(false)
	assert_true(CampaignGuide.show_thought(&"thought_gap"))
	var bubble := CampaignGuide.get_bubble()
	assert_not_null(bubble, "мысль создаётся в мире")
	if bubble != null:
		assert_eq(bubble.target, sunny)
		assert_string_contains(bubble.text, "провал")


func test_scene_objective_overrides_quest_objective_and_restores_it() -> void:
	var beat := _beat(N12_PATH)
	CampaignGuide.apply_beat(beat)
	CampaignGuide.set_external_objective("Собрать фляги у мёртвых солдат", &"quest_system")
	assert_eq(CampaignGuide.get_display_objective(), "Собрать фляги у мёртвых солдат")
	assert_eq(CampaignGuide.get_external_source(), &"quest_system")

	CampaignGuide.set_external_objective("Подойти к раненому ветерану", &"campaign")
	assert_eq(CampaignGuide.get_display_objective(), "Подойти к раненому ветерану")
	assert_true(CampaignGuide.has_scene_objective(), "цель сцены активна")

	# Квест может обновляться под сценой, но не возвращает старую цель.
	CampaignGuide.set_external_objective("Собрать фляги: 3/3", &"quest_system")
	assert_eq(CampaignGuide.get_display_objective(), "Подойти к раненому ветерану")

	CampaignGuide.clear_external_objective(&"campaign")
	assert_eq(CampaignGuide.get_display_objective(), "Собрать фляги: 3/3")
	assert_eq(CampaignGuide.get_external_source(), &"quest_system")

	CampaignGuide.clear_external_objective(&"quest_system")
	assert_eq(CampaignGuide.get_display_objective(), beat.objective)


func test_beat_from_new_scene_clears_previous_scene_objective() -> void:
	CampaignGuide.apply_beat(_beat(N15_PATH))
	CampaignGuide.set_external_objective("Испытание завершено.", &"campaign")
	var next_beat := _beat("res://resources/campaign/beats/n24.tres")
	CampaignGuide.apply_beat(next_beat)
	assert_eq(
		CampaignGuide.get_display_objective(),
		next_beat.objective,
		"новое событие из другой сцены не показывает старую цель"
	)


func test_scene_objective_expires_when_scene_changes() -> void:
	var beat := _beat(N15_PATH)
	CampaignGuide.apply_beat(beat)
	var previous := get_tree().current_scene
	var first := (load(OBJECTIVE_LINE_SCENE) as PackedScene).instantiate()
	var second := (load("res://scenes/ui/hud_minimap.tscn") as PackedScene).instantiate()
	# current_scene обязан быть прямым ребёнком root.
	get_tree().root.add_child(first)
	get_tree().root.add_child(second)
	get_tree().current_scene = first
	CampaignGuide.set_external_objective("Подойти к раненому ветерану", &"campaign")
	assert_eq(CampaignGuide.get_display_objective(), "Подойти к раненому ветерану")

	get_tree().current_scene = second
	await wait_physics_frames(2)
	assert_eq(
		CampaignGuide.get_display_objective(),
		beat.objective,
		"цель сцены не переживает переход в другую сцену"
	)
	get_tree().current_scene = previous
	first.queue_free()
	second.queue_free()


func test_objective_line_shows_scene_objective_while_quest_scope_is_active() -> void:
	QuestSystem.activate_scope(&"forgotten_shore")
	CampaignGuide.apply_beat(_beat(N12_PATH))
	CampaignGuide.set_external_objective("Подойти к раненому ветерану", &"campaign")
	var line := (load(OBJECTIVE_LINE_SCENE) as PackedScene).instantiate() as ObjectiveLine
	add_child_autofree(line)
	await wait_process_frames(1)
	assert_string_contains(line.get_objective_text(), "ветерану")

	# Смена отслеживаемого задания не должна перебивать цель сцены.
	assert_true(QuestSystem.set_tracked_quest(&"crystal_cache"))
	await wait_process_frames(1)
	assert_string_contains(line.get_objective_text(), "ветерану")

	CampaignGuide.clear_external_objective(&"campaign")
	await wait_process_frames(1)
	assert_eq(line.get_objective_text(), QuestSystem.get_tracked_objective_text())


func test_guide_settings_are_a_typed_resource() -> void:
	var settings := load(SETTINGS_PATH) as GuideSettings
	assert_not_null(settings, "настройки загружаются типизированным ресурсом")
	if settings != null:
		assert_gt(settings.idle_seconds, 0.0)
		assert_between(settings.max_idle_steps, 2, 3, "ступеней две-три")
		assert_true(settings.is_valid())
