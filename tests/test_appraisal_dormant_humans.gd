extends GutTest
## A4: деяние «три дремлющих человека» считается по игровым событиям.
##
## Ветеран — veteran_dead (казнь). Шифти и Учёный — отравление общих фляг
## плюс собственное событие: падение Шифти (shifty_dead) или оставление
## Учёного приманкой (scholar_abandoned). Яд сам по себе смертью не считается.
## Гейт оценки требует все три деяния (CANON-INFERRED, см. 03_ascent_and_climax_canon.md, 5.3).

const APPRAISAL_SCENE := "res://scenes/campaign/appraisal_arrival.tscn"
const LOCATION_SCENE := "res://scenes/locations/pilgrim_path/pilgrim_path.tscn"
const GATE_FLAGS := [&"temple_reached", &"trial_completed"]
const DEED_FLAGS := [&"veteran_dead", &"flasks_poisoned", &"shifty_dead", &"scholar_abandoned"]


func before_each() -> void:
	NightmareRunState.reset()


func after_each() -> void:
	NightmareRunState.reset()


func _grant(flags: Array) -> void:
	for flag in flags:
		NightmareRunState.set_flag(flag)


func _appraisal() -> Control:
	var appraisal := (load(APPRAISAL_SCENE) as PackedScene).instantiate() as Control
	appraisal.redirect_without_gate = false
	add_child_autofree(appraisal)
	return appraisal


func test_no_events_means_no_deeds_and_closed_gate() -> void:
	_grant(GATE_FLAGS)
	var appraisal := _appraisal()
	assert_eq(appraisal.defeated_dormant_humans(), 0)
	assert_false(appraisal.can_appraise(), "без деяний оценка закрыта")


func test_poison_alone_is_not_a_death() -> void:
	NightmareRunState.set_flag(&"flasks_poisoned")
	var appraisal := _appraisal()
	assert_eq(appraisal.defeated_dormant_humans(), 0, "отравление не засчитывает никого")
	assert_false(NightmareRunState.has_flag(&"hero_dead"), "яд не ставит смерть Героя")
	assert_false(NightmareRunState.has_flag(&"shifty_dead"), "яд не ставит смерть Шифти")
	assert_false(NightmareRunState.has_flag(&"scholar_abandoned"), "яд не ставит оставление Учёного")


func test_veteran_counts_by_execution_alone() -> void:
	NightmareRunState.set_flag(&"veteran_dead")
	assert_eq(_appraisal().defeated_dormant_humans(), 1)


func test_shifty_needs_both_poison_and_fall() -> void:
	NightmareRunState.set_flag(&"shifty_dead")
	assert_eq(_appraisal().defeated_dormant_humans(), 0, "падение без отравления не засчитывается")
	NightmareRunState.set_flag(&"flasks_poisoned")
	assert_eq(_appraisal().defeated_dormant_humans(), 1, "падение плюс отравление засчитывает Шифти")


func test_scholar_needs_both_poison_and_abandonment() -> void:
	NightmareRunState.set_flag(&"scholar_abandoned")
	assert_eq(_appraisal().defeated_dormant_humans(), 0, "оставление без отравления не засчитывается")
	NightmareRunState.set_flag(&"flasks_poisoned")
	assert_eq(_appraisal().defeated_dormant_humans(), 1, "оставление плюс отравление засчитывает Учёного")
	assert_false(NightmareRunState.has_flag(&"scholar_dead"), "смерть Учёного не выдумывается")


func test_each_missing_deed_closes_the_gate() -> void:
	for missing in DEED_FLAGS:
		NightmareRunState.reset()
		_grant(GATE_FLAGS)
		for flag in DEED_FLAGS:
			if flag != missing:
				NightmareRunState.set_flag(flag)
		var appraisal := _appraisal()
		assert_false(appraisal.can_appraise(), "без %s оценка закрыта" % missing)


func test_all_deeds_open_the_gate() -> void:
	_grant(GATE_FLAGS)
	_grant(DEED_FLAGS)
	var appraisal := _appraisal()
	assert_eq(appraisal.defeated_dormant_humans(), 3)
	assert_true(appraisal.can_appraise())


func test_real_pilgrim_events_set_the_shifty_and_scholar_states() -> void:
	# Настоящие методы локации: падение Шифти и оставление Учёного.
	var site := (load(LOCATION_SCENE) as PackedScene).instantiate() as PilgrimPath
	add_child_autofree(site)
	await wait_process_frames(2)
	site.kill_shifty()
	assert_true(NightmareRunState.has_flag(&"shifty_dead"), "падение Шифти ставит shifty_dead")
	NightmareRunState.set_flag(&"flasks_poisoned")
	site.abandon_scholar()
	assert_true(NightmareRunState.has_flag(&"scholar_abandoned"), "оставление ставит scholar_abandoned")
	assert_false(NightmareRunState.has_flag(&"hero_dead"), "оставление не ставит смерть Героя")
	assert_eq(_appraisal().defeated_dormant_humans(), 2, "два деяния из трёх без ветерана")


func test_deeds_survive_snapshot_restore_for_re_entry() -> void:
	_grant(GATE_FLAGS)
	_grant(DEED_FLAGS)
	var snapshot := NightmareRunState.snapshot()
	NightmareRunState.reset()
	assert_eq(_appraisal().defeated_dormant_humans(), 0, "новый прогон начинается без деяний")
	NightmareRunState.restore(snapshot)
	var appraisal := _appraisal()
	assert_eq(appraisal.defeated_dormant_humans(), 3, "состояние деяний восстанавливается после перехода")
	assert_true(appraisal.can_appraise())


func test_n13_beat_staging_sets_flasks_poisoned_and_unlocks_appraisal() -> void:
	_grant(GATE_FLAGS)
	NightmareRunState.set_flag(&"veteran_dead")
	NightmareRunState.set_flag(&"shifty_dead")
	NightmareRunState.set_flag(&"scholar_abandoned")
	assert_eq(_appraisal().defeated_dormant_humans(), 1, "без постановки N13 засчитан только ветеран")

	var director := BeatDirector.new()
	add_child_autofree(director)
	assert_true(director.stage_beat(&"N13"))
	assert_true(NightmareRunState.has_flag(&"flasks_poisoned"), "постановка N13 выставляет flasks_poisoned")
	assert_true(NightmareRunState.has_flag(&"sunny_flask_clean"))

	var appraisal := _appraisal()
	assert_eq(appraisal.defeated_dormant_humans(), 3, "с постановкой N13 засчитаны все три дремлющих человека")
	assert_true(appraisal.can_appraise())


func test_second_camp_larva_is_not_a_dormant_human_deed() -> void:
	NightmareRunState.set_flag(&"second_larva_killed")
	assert_eq(_appraisal().defeated_dormant_humans(), 0, "вторая личинка на стоянке не входит в оценку людей")


func test_three_scenarios_humans_larva_and_second_larva() -> void:
	# Сценарий 1: без flasks_poisoned собственное падение/оставление не считается,
	# остаётся только казнённый ветеран.
	NightmareRunState.set_flag(&"veteran_dead")
	NightmareRunState.set_flag(&"shifty_dead")
	NightmareRunState.set_flag(&"scholar_abandoned")
	var appraisal := _appraisal()
	assert_eq(appraisal.defeated_dormant_humans(), 1, "без flasks_poisoned — только ветеран")

	# Сценарий 2: отравление включает Шифти и Учёного, итого три дремлющих.
	NightmareRunState.set_flag(&"flasks_poisoned")
	assert_eq(appraisal.defeated_dormant_humans(), 3, "три дремлющих человека от flasks_poisoned")

	# Сценарий 3: личинка из тела Шифти — отдельное лишнее деяние, вторая
	# личинка на стоянке в счёт не входит.
	NightmareRunState.set_flag(&"shifty_larva_killed")
	assert_eq(appraisal.defeated_dormant_humans(), 3, "личинка не подменяет трёх людей")
	assert_eq(appraisal.defeated_larva(), 1, "личинка Шифти учитывается отдельно")
	assert_eq(appraisal.defeated_creatures(), 4, "три человека + личинка Шифти")
	NightmareRunState.set_flag(&"second_larva_killed")
	assert_eq(appraisal.defeated_creatures(), 4, "вторая личинка на стоянке не учитывается")


func test_night_montage_flag_keeps_the_three_dormant_count() -> void:
	_grant(GATE_FLAGS)
	NightmareRunState.set_flag(&"veteran_dead")
	NightmareRunState.set_flag(&"shifty_dead")
	NightmareRunState.set_flag(&"scholar_abandoned")
	var site := (load("res://scenes/locations/caravan_site/caravan_site.tscn") as PackedScene).instantiate() as CaravanSite
	add_child_autofree(site)
	await wait_process_frames(2)
	site.stage_bloodbane_montage()
	assert_true(NightmareRunState.has_flag(&"flasks_poisoned"))
	assert_eq(_appraisal().defeated_dormant_humans(), 3, "монтаж не меняет счёт трёх дремлющих")
