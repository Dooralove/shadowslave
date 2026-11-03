extends GutTest
## Бестиарий как часть журнала: ресурс BestiaryEntry, событие открытия,
## сохранение в NightmareRunState и отсутствие дублей.

const ENTRY_PATHS := [
	"res://resources/campaign/bestiary/larva.tres",
	"res://resources/campaign/bestiary/shifty_larva.tres",
	"res://resources/campaign/bestiary/mountain_king.tres",
]
const N15_PATH := "res://resources/campaign/beats/n15.tres"


func before_each() -> void:
	NightmareRunState.reset()
	CampaignGuide.reset_campaign()


func after_each() -> void:
	NightmareRunState.reset()
	CampaignGuide.reset_campaign()


func _screen() -> RpgQuestScreen:
	var screen := (load("res://scenes/ui/rpg_menu/quest_screen.tscn") as PackedScene).instantiate() as RpgQuestScreen
	add_child_autofree(screen)
	await wait_process_frames(1)
	return screen


func _journal_id_count(entry_id: StringName) -> int:
	var count := 0
	for record in CampaignGuide.get_journal_entries():
		if StringName(record.get("id", &"")) == entry_id:
			count += 1
	return count


func test_bestiary_entries_are_typed_resources() -> void:
	var expected := {
		&"larva": &"seen",
		&"shifty_larva": &"defeated",
		&"mountain_king": &"weakness_known",
	}
	for path in ENTRY_PATHS:
		var entry := load(path) as BestiaryEntry
		assert_not_null(entry, "запись должна загружаться как BestiaryEntry: %s" % path)
		if entry == null:
			continue
		assert_true(entry.is_valid(), "у записи есть id, заголовок и текст")
		assert_false(entry.text.strip_edges().is_empty())
		assert_false(entry.title.contains("\""), "заголовок не цитирует роман")
		assert_false(entry.text.contains("\""), "описание не цитирует роман")
		assert_eq(entry.unlock_event, expected[entry.id], "событие открытия задано данными")


func test_bestiary_opens_by_seen_defeated_and_weakness_events() -> void:
	var seen := CampaignGuide.unlock_bestiary_by_event(&"seen")
	assert_eq(seen, [&"larva"] as Array[StringName])
	assert_true(CampaignGuide.has_bestiary_entry(&"larva"))
	assert_false(CampaignGuide.has_bestiary_entry(&"shifty_larva"))

	var defeated := CampaignGuide.unlock_bestiary_by_event(&"defeated")
	assert_eq(defeated, [&"shifty_larva"] as Array[StringName])
	assert_true(CampaignGuide.has_bestiary_entry(&"shifty_larva"))

	var weakness := CampaignGuide.unlock_bestiary_by_event(&"weakness_known")
	assert_eq(weakness, [&"mountain_king"] as Array[StringName])
	assert_true(CampaignGuide.has_bestiary_entry(&"mountain_king"))
	assert_eq(NightmareRunState.get_bestiary_ids().size(), 3)


func test_existing_run_flags_open_the_matching_bestiary_records() -> void:
	NightmareRunState.set_flag(&"larva_grabbed")
	assert_true(CampaignGuide.has_bestiary_entry(&"larva"))

	NightmareRunState.set_flag(&"shifty_larva_killed")
	assert_true(CampaignGuide.has_bestiary_entry(&"shifty_larva"))

	NightmareRunState.set_flag(&"stealth_completed")
	assert_true(CampaignGuide.has_bestiary_entry(&"mountain_king"))


func test_bestiary_is_shown_in_journal_with_current_objective() -> void:
	CampaignGuide.apply_beat(load(N15_PATH) as BeatData)
	CampaignGuide.unlock_bestiary_by_event(&"seen")
	var screen := await _screen()
	var panel := screen.get_node("%CurrentPanel") as Control
	var objective := screen.get_node("%CurrentObjective") as Label
	var journal := screen.get_node("%CurrentJournal") as Label
	assert_true(panel.visible)
	assert_eq(objective.text, (load(N15_PATH) as BeatData).objective)
	assert_string_contains(journal.text, "Бестиарий · Личинка")
	assert_string_contains(journal.text, "Увидел")
	assert_string_contains(journal.text, "Личинка")


func test_bestiary_survives_snapshot_restore_without_duplicates() -> void:
	CampaignGuide.unlock_bestiary_by_event(&"seen")
	CampaignGuide.unlock_bestiary_by_event(&"seen")
	CampaignGuide.unlock_bestiary_by_event(&"defeated")
	var snapshot := NightmareRunState.snapshot()
	assert_true(snapshot.has("bestiary"))
	assert_eq(_journal_id_count(&"larva"), 1, "повторное событие не создаёт дубль")
	assert_eq(NightmareRunState.get_bestiary_ids().size(), 2)

	NightmareRunState.reset()
	assert_false(CampaignGuide.has_bestiary_entry(&"larva"))
	NightmareRunState.restore(snapshot)
	assert_true(CampaignGuide.has_bestiary_entry(&"larva"))
	assert_true(CampaignGuide.has_bestiary_entry(&"shifty_larva"))
	assert_eq(_journal_id_count(&"larva"), 1, "restore не дублирует запись")
	assert_eq(_journal_id_count(&"shifty_larva"), 1)
	assert_eq(NightmareRunState.get_bestiary_event(&"larva"), &"seen")
