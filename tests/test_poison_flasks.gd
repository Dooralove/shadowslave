extends GutTest
## Акт II: ночной монтаж Bloodbane, отсутствие E-точки и сохранение оценки.

const CAMP_ARRIVAL := "res://scenes/campaign/caravan_site_arrival.tscn"
const CAMP_SCENE := "res://scenes/locations/caravan_site/caravan_site.tscn"
const NIGHT_MONTAGE := "res://resources/dialogue/caravan/camp_night_montage.tres"
const SUNNY_POC := "res://assets/characters/sunny_realistic_poc/sunny_waking_poc.tscn"
const N11_BEAT := "res://resources/campaign/beats/n11.tres"


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


func _wait_until(predicate: Callable, max_frames := 180) -> bool:
	for i in max_frames:
		if predicate.call():
			return true
		await wait_process_frames(1)
	return false


func _advance_to_aftermath(site: CaravanSite, wrapper: Node3D) -> bool:
	if not await _wait_until(func() -> bool: return site.get_interactable(&"camp_rations").enabled):
		return false
	site.get_interactable(&"camp_rations").interact()
	if not await _wait_until(func() -> bool: return site.phase == CaravanSite.PHASE_LARVA):
		return false
	site.get_interactable(&"chain_larva").interact()
	if not await _wait_until(func() -> bool: return site.get_interactable(&"hero_key").enabled):
		return false
	site.get_interactable(&"hero_key").interact()
	if not await _wait_until(func() -> bool: return site.second_larva != null):
		return false
	site.second_larva.health.take_damage(site.second_larva.health.max_health)
	if not await _wait_until(func() -> bool: return site.get_interactable(&"wagon_wedges").enabled):
		return false
	site.get_interactable(&"wagon_wedges").interact()
	site.get_interactable(&"wagon_loop").interact()
	site.get_interactable(&"wagon_push").interact()
	await wait_process_frames(1)
	var timing := wrapper.get_node("TimingChallenge") as TimingChallenge
	if timing == null:
		return false
	timing.press_at_ratio(0.5)
	if not await _wait_until(func() -> bool: return site.phase == CaravanSite.PHASE_AFTERMATH):
		return false
	return await _wait_until(func() -> bool: return NightmareRunState.has_flag(&"tasks_assigned"))


func _collect_flasks(site: CaravanSite) -> void:
	for id in [&"flask_a", &"flask_b", &"flask_c"]:
		site.get_interactable(id).interact()


func _take_veteran(site: CaravanSite) -> bool:
	site.get_interactable(&"veteran").interact()
	if not await _wait_until(func() -> bool: return site.get_interactable(&"veteran_sword").enabled):
		return false
	site.get_interactable(&"veteran_sword").interact()
	return await _wait_until(func() -> bool: return NightmareRunState.has_flag(&"veteran_dead"))


func test_poison_button_is_gone_but_flags_remain_available() -> void:
	var wrapper := _spawn_wrapper()
	var site := wrapper.get_node("CaravanSite") as CaravanSite
	var sunny := wrapper.get_node("Sunny") as SunnyController
	await wait_process_frames(2)
	assert_null(site.get_node_or_null("Interactables/PoisonFlasks"), "E-точка отравления удалена")
	assert_null(site.get_interactable(&"poison_flasks"))
	assert_null(site.get_interactable(&"night_fire"), "ночь запускается триггером, а не кнопкой")
	assert_false(NightmareRunState.has_flag(&"flasks_poisoned"))
	assert_false(sunny.get_node("BloodSpots").are_spots_visible(), "до ночи пятен нет")


func test_night_waits_for_flasks_and_veteran_then_stages_poisoning() -> void:
	var wrapper := _spawn_wrapper()
	var site := wrapper.get_node("CaravanSite") as CaravanSite
	var sunny := wrapper.get_node("Sunny") as SunnyController
	assert_true(await _advance_to_aftermath(site, wrapper))
	_collect_flasks(site)
	assert_eq(site.collected_flasks(), 3)

	# Без ветерана ночь не начинается и флаг отравления не ставится.
	site.request_night()
	assert_false(NightmareRunState.has_flag(&"flasks_poisoned"))
	assert_eq(site.phase, CaravanSite.PHASE_AFTERMATH)

	assert_true(await _take_veteran(site))
	var edge := site.get_node("Triggers/NightEdgeSouth") as TriggerZone
	assert_true(edge.enabled, "край открыт после задач")
	edge.fire()
	assert_true(NightmareRunState.has_flag(&"flasks_poisoned"), "флаг ставит постановка N13")
	assert_true(NightmareRunState.has_flag(&"sunny_flask_clean"))
	assert_true(await _wait_until(func() -> bool: return site.phase == CaravanSite.PHASE_DAWN))
	assert_true(NightmareRunState.has_flag(&"night_passed"))
	var spots := sunny.get_node("BloodSpots") as SunnyBloodSpots
	assert_true(spots.are_spots_visible(), "на рассвете видны пятна на пальцах")
	assert_gt(spots.get_child_count(), 0, "пятна созданы на скелете")


func test_council_has_one_line_objective() -> void:
	var beat := load(N11_BEAT) as BeatData
	assert_not_null(beat)
	assert_false(beat.objective.strip_edges().is_empty())
	assert_false(beat.objective.contains("\n"), "цель совета — одна строка")


func test_night_montage_does_not_name_the_poison_or_the_button() -> void:
	var sequence := load(NIGHT_MONTAGE) as DialogueSequence
	assert_not_null(sequence)
	for line in sequence.lines:
		var text := (line as DialogueLine).text
		assert_false(text.contains("яд"), "монтаж не называет яд")
		assert_false(text.contains("отрав"), "монтаж не описывает отравление")
		assert_false(text.contains("Bloodbane"), "монтаж не называет Bloodbane")
		assert_false(text.contains("фляг"), "монтаж не описывает действие с флягами")
		assert_false(text.contains("пятн"), "пятна остаются визуальной подсказкой")


func test_veteran_remains_an_e_action_in_the_council_search() -> void:
	var wrapper := _spawn_wrapper()
	var site := wrapper.get_node("CaravanSite") as CaravanSite
	assert_true(await _advance_to_aftermath(site, wrapper))
	_collect_flasks(site)
	assert_true(site.get_interactable(&"veteran").enabled)
	site.get_interactable(&"veteran").interact()
	assert_true(await _wait_until(func() -> bool: return site.get_interactable(&"veteran_sword").enabled))
	assert_true(site.get_interactable(&"veteran_sword").enabled, "E остаётся на подъёме меча")
	site.get_interactable(&"veteran_sword").interact()
	assert_true(await _wait_until(func() -> bool: return NightmareRunState.has_flag(&"veteran_dead")))
	assert_true(NightmareRunState.has_flag(&"silver_bell_obtained"))


func test_spots_follow_sunny_into_the_next_scene_after_dawn() -> void:
	NightmareRunState.set_flag(&"flasks_poisoned")
	NightmareRunState.set_flag(&"night_passed")
	var sunny := (load(SUNNY_POC) as PackedScene).instantiate() as SunnyController
	add_child_autofree(sunny)
	await wait_process_frames(2)
	var spots := sunny.get_node("BloodSpots") as SunnyBloodSpots
	assert_true(spots.are_spots_visible(), "пятна остаются на пути к пещере")
	assert_gt(spots.get_child_count(), 0, "на пальцах есть видимые метки")


func test_poison_state_survives_reload_without_a_poison_button() -> void:
	var wrapper := _spawn_wrapper()
	var site := wrapper.get_node("CaravanSite") as CaravanSite
	assert_true(await _advance_to_aftermath(site, wrapper))
	_collect_flasks(site)
	assert_true(await _take_veteran(site))
	site.request_night()
	assert_true(NightmareRunState.has_flag(&"flasks_poisoned"))
	wrapper.queue_free()
	await wait_process_frames(2)

	var reloaded := (load(CAMP_SCENE) as PackedScene).instantiate() as CaravanSite
	add_child_autofree(reloaded)
	await wait_process_frames(2)
	assert_true(NightmareRunState.has_flag(&"flasks_poisoned"))
	assert_true(NightmareRunState.has_flag(&"sunny_flask_clean"))
	assert_null(reloaded.get_interactable(&"poison_flasks"))
