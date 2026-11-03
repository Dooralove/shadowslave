extends GutTest
## P01–N10: проверки нового потока пролога и Акта I без тропы после засады.

const CAMP_SCENE := "res://scenes/locations/caravan_site/caravan_site.tscn"
const CAMP_WRAPPER := "res://scenes/campaign/caravan_site_arrival.tscn"
const RULES_JOURNAL := "res://resources/campaign/journal/rules_of_nightmare.tres"
const MOUNTAIN_VISION := "res://scenes/slice/locations/mountain_vision.tscn"


func before_each() -> void:
	NightmareRunState.reset()
	CampaignGuide.reset_campaign()


func after_each() -> void:
	NightmareRunState.reset()
	CampaignGuide.reset_campaign()


func _wait_until(predicate: Callable, max_frames := 90) -> bool:
	for i in max_frames:
		if predicate.call():
			return true
		await wait_process_frames(1)
	return false


func _spawn_site() -> CaravanSite:
	var site := (load(CAMP_SCENE) as PackedScene).instantiate() as CaravanSite
	add_child_autofree(site)
	await wait_process_frames(2)
	return site


func _spawn_wrapper() -> Node3D:
	var wrapper := (load(CAMP_WRAPPER) as PackedScene).instantiate() as Node3D
	wrapper.transition_enabled = false
	wrapper.fade_in = false
	wrapper.fast_mode = true
	wrapper.debug_direct_scene = true
	add_child_autofree(wrapper)
	await wait_process_frames(2)
	return wrapper


func test_rockfall_warns_and_can_kill_inside_but_spares_outside() -> void:
	var site := await _spawn_site()
	var body := Node3D.new()
	body.add_to_group(&"player")
	var health := HealthComponent.new()
	health.name = "Health"
	health.max_health = 100.0
	body.add_child(health)
	add_child_autofree(body)
	body.global_position = site.rockfall.global_position

	site.begin_rockfall_warning()
	assert_true(site.rockfall.is_warning_active(), "пыль и звук включают предупреждение")
	assert_true(site.resolve_rockfall(), "игрок внутри зоны получает удар")
	assert_true(health.is_dead(), "удар камнепада смертелен")

	health.revive()
	body.global_position = site.rockfall.global_position + Vector3(100.0, 0.0, 0.0)
	site.begin_rockfall_warning()
	assert_false(site.resolve_rockfall(), "вне зоны камнепад не задевает игрока")
	assert_false(health.is_dead())


func test_second_larva_finishes_at_threshold_not_before() -> void:
	var site := await _spawn_site()
	var target := Node3D.new()
	add_child_autofree(target)
	var enemy := site.spawn_second_larva(target)
	assert_not_null(enemy)
	var finished := [0]
	site.second_larva_finished.connect(func() -> void: finished[0] += 1)
	var maximum := enemy.health.max_health

	enemy.health.take_damage(maximum * 0.64)
	assert_false(NightmareRunState.has_flag(&"second_larva_killed"), "выше 35% Герой ещё не добивает")
	assert_true(enemy.visible)
	assert_eq(finished[0], 0)

	enemy.health.take_damage(maximum * 0.02)
	assert_true(NightmareRunState.has_flag(&"second_larva_killed"), "на 35% Герой завершает бой")
	assert_false(enemy.visible)
	assert_eq(finished[0], 1)


func test_wagon_puzzle_requires_order_and_one_throw_per_attempt() -> void:
	var site := await _spawn_site()
	site.begin_wagon_phase()
	var pushes := [0]
	site.wagon_push_requested.connect(func() -> void: pushes[0] += 1)

	assert_true(site.get_interactable(&"wagon_wedges").enabled)
	assert_false(site.get_interactable(&"wagon_loop").enabled)
	assert_false(site.get_interactable(&"wagon_push").enabled)

	site.get_interactable(&"wagon_wedges").interact()
	assert_true(site.get_interactable(&"wagon_loop").enabled)
	assert_false(site.get_interactable(&"wagon_push").enabled)

	site.get_interactable(&"wagon_loop").interact()
	assert_true(site.get_interactable(&"wagon_push").enabled)
	site.get_interactable(&"wagon_push").interact()
	site.get_interactable(&"wagon_push").interact()
	assert_eq(pushes[0], 1, "один бросок за попытку")

	site.reset_wagon_throw()
	assert_true(site.get_interactable(&"wagon_push").enabled, "после отката бросок доступен снова")
	site.get_interactable(&"wagon_push").interact()
	assert_eq(pushes[0], 2)


func test_timing_challenge_resolves_once_with_success_or_miss() -> void:
	var timing := TimingChallenge.new()
	add_child_autofree(timing)
	var results: Array[bool] = []
	timing.resolved.connect(func(success: bool) -> void: results.append(success))

	timing.start()
	assert_true(timing.is_active())
	timing.press_at_ratio(0.5)
	assert_eq(results, [true], "точка в зелёном окне — успех")
	timing.press_at_ratio(0.5)
	assert_eq(results.size(), 1, "после броска повторное нажатие игнорируется")

	timing.start()
	timing.press_at_ratio(0.05)
	assert_eq(results, [true, false], "промах вне окна")


func test_tyrant_attention_zone_catches_too_close_movement() -> void:
	var site := await _spawn_site()
	var caught := [0]
	site.tyrant_attention_caught.connect(func() -> void: caught[0] += 1)
	site.begin_wagon_phase()
	assert_true(site.is_tyrant_attention_active(), "в N10 Тиран следит за зоной")
	var player := Node3D.new()
	player.add_to_group(&"player")
	add_child_autofree(player)
	player.global_position = site.tyrant.global_position
	await wait_process_frames(2)
	assert_eq(caught[0], 1, "вход в зону внимания засчитывается")
	assert_false(site.is_tyrant_attention_active(), "после срабатывания зона снимается")


func test_wagon_miss_returns_to_cp_n10b_and_reenables_throw() -> void:
	var wrapper := await _spawn_wrapper()
	var site := wrapper.get_node("CaravanSite") as CaravanSite
	var sunny := wrapper.get_node("Sunny") as SunnyController
	var recovery := sunny.get_node("FallRecovery") as FallRecovery
	NightmareRunState.set_flag(&"wagon_wedges_removed")
	NightmareRunState.set_flag(&"wagon_loop_ready")
	site.begin_wagon_phase()
	wrapper.beat_director.activate_checkpoint(&"CP-N10b")
	var expected := NightmareRunState.get_checkpoint_position()
	wrapper._wagon_running = true
	wrapper._handle_throw_miss()
	assert_eq(recovery.get_checkpoint_id(), &"CP-N10b")
	assert_true(sunny.global_position.distance_to(expected) < 0.5, "Санни вернулся на чекпоинт перед броском")
	assert_true(site.get_interactable(&"wagon_push").enabled, "петля остаётся готовой к повторному броску")


func test_berries_are_a_cutscene_without_new_tasks() -> void:
	var site := await _spawn_site()
	var sequences := [0]
	site.sequence_requested.connect(func(_sequence: DialogueSequence) -> void: sequences[0] += 1)
	site.begin_camp()
	site.get_interactable(&"camp_rations").interact()
	await wait_process_frames(3)

	assert_true(NightmareRunState.has_flag(&"camp_rations_taken"))
	assert_true(sequences[0] >= 1)
	assert_false(NightmareRunState.has_flag(&"camp_explored"), "ягоды не открывают чек-лист")
	assert_false(site.get_interactable(&"camp_attack").enabled)
	assert_false(NightmareRunState.has_flag(&"tasks_assigned"), "катсцена не создаёт задач")
	assert_eq(CampaignGuide.get_journal_entries().size(), 0)


func test_rules_of_nightmare_are_a_journal_entry() -> void:
	var entry := load(RULES_JOURNAL) as JournalEntryData
	assert_not_null(entry)
	assert_true(entry.is_valid())
	CampaignGuide.add_journal_entry(entry)
	assert_true(CampaignGuide.has_journal_entry(&"rules_of_nightmare"))
	assert_eq(CampaignGuide.get_journal_entries().size(), 1)
	CampaignGuide.add_journal_entry(entry)
	assert_eq(CampaignGuide.get_journal_entries().size(), 1, "повтор не дублирует запись")


func test_future_camp_vision_contains_wagon_chocks_and_bones() -> void:
	var location := (load(MOUNTAIN_VISION) as PackedScene).instantiate() as Node3D
	add_child_autofree(location)
	await wait_process_frames(1)
	var camp := location.get_node_or_null("Road/FutureCamp") as Node3D
	assert_not_null(camp, "P04 содержит кадр будущей стоянки")
	assert_false(camp.visible, "кадр скрыт до видения")
	assert_not_null(camp.get_node_or_null("Wagon"))
	assert_not_null(camp.get_node_or_null("ChockL"))
	assert_not_null(camp.get_node_or_null("ChockR"))
	assert_not_null(camp.get_node_or_null("BoneA"))
