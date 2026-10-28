extends GutTest
## S02–S03: лагерь, одноразовые взаимодействия, нападение, личинка и освобождение.

const CAMP_ARRIVAL := "res://scenes/campaign/caravan_site_arrival.tscn"
const CAMP_SCENE := "res://scenes/locations/caravan_site/caravan_site.tscn"
const CAMP_MESSAGES := "res://resources/spell/caravan_site_messages.tres"
const DIALOGUE_DIR := "res://resources/dialogue/caravan/"
const CAMP_SEQUENCES := [
	&"camp_arrival",
	&"camp_rations",
	&"camp_bloodbane",
	&"camp_wagon",
	&"camp_hero_gaze",
	&"camp_attack",
	&"camp_metamorphosis",
	&"camp_larva_kill",
	&"camp_key_throw",
	&"camp_unlock",
	&"camp_complete",
	&"camp_wagon_plan",
	&"camp_wagon_fall",
	&"camp_aftermath",
	&"camp_veteran",
	&"camp_veteran_kill",
	&"camp_veteran_loot",
	&"camp_night",
	&"camp_dawn",
]


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


func _advance_to_aftermath(site: CaravanSite, wrapper: Node3D) -> bool:
	if not await _wait_until(func() -> bool: return site.get_interactable(&"camp_attack") != null):
		return false
	site.get_interactable(&"camp_rations").interact()
	site.get_interactable(&"camp_bloodbane").interact()
	site.get_interactable(&"camp_wagon").interact()
	site.get_interactable(&"camp_attack").interact()
	if not await _wait_until(func() -> bool: return site.phase == CaravanSite.PHASE_LARVA):
		return false
	site.get_interactable(&"chain_larva").interact()
	if not await _wait_until(func() -> bool: return site.get_interactable(&"hero_key").enabled):
		return false
	site.get_interactable(&"hero_key").interact()
	if not await _wait_until(func() -> bool: return site.get_interactable(&"wagon_wedges").enabled):
		return false
	site.get_interactable(&"wagon_wedges").interact()
	site.get_interactable(&"wagon_loop").interact()
	site.get_interactable(&"wagon_push").interact()
	if not await _wait_until(func() -> bool: return site.phase == CaravanSite.PHASE_AFTERMATH, 240):
		return false
	if not await _wait_until(func() -> bool: return NightmareRunState.has_flag(&"tasks_assigned")):
		return false
	return true


func test_survivor_tasks_veteran_bell_night_and_dawn() -> void:
	var wrapper := _spawn_wrapper()
	var site := wrapper.get_node("CaravanSite") as CaravanSite
	var sunny := wrapper.get_node("Sunny") as SunnyController
	assert_true(await _advance_to_aftermath(site, wrapper))
	assert_true(NightmareRunState.has_flag(&"survivors_council_done"))
	assert_true(NightmareRunState.has_flag(&"tasks_assigned"))
	assert_eq(site.collected_flasks(), 0)
	assert_true(site.get_interactable(&"flask_a").enabled)
	assert_true(site.get_interactable(&"veteran").enabled)
	assert_true(site.get_interactable(&"night_fire").enabled, "костёр виден, но ночь блокируется подсказкой")
	assert_false(NightmareRunState.has_flag(&"night_started"))

	for id in [&"flask_a", &"flask_b", &"flask_c"]:
		site.get_interactable(id).interact()
	await wait_process_frames(2)
	assert_eq(site.collected_flasks(), 3)
	assert_eq(NightmareRunState.get_item_count(&"flasks"), 3)
	assert_false(site.get_interactable(&"flask_a").enabled)
	assert_true(site.get_interactable(&"veteran").enabled)
	assert_true(site.get_interactable(&"poison_flasks").enabled, "после трёх фляг доступно отравление")
	assert_false(NightmareRunState.has_flag(&"flasks_poisoned"), "отравление не выполняется само")

	site.get_interactable(&"veteran").interact()
	assert_true(await _wait_until(func() -> bool: return NightmareRunState.has_flag(&"veteran_found")))
	assert_true(await _wait_until(func() -> bool: return site.get_interactable(&"veteran_sword").enabled))
	assert_true(site.veteran_sword.visible)
	assert_true(sunny.input_enabled)

	site.get_interactable(&"veteran_sword").interact()
	assert_true(await _wait_until(func() -> bool: return NightmareRunState.has_flag(&"veteran_dead")))
	assert_true(NightmareRunState.has_flag(&"silver_bell_obtained"))
	assert_true(NightmareRunState.has_flag(&"has_cloak"))
	assert_true(NightmareRunState.has_flag(&"has_boots"))
	assert_eq(NightmareRunState.get_item_count(&"silver_bell"), 1)
	assert_eq(NightmareRunState.get_item_count(&"cloak"), 1)
	assert_eq(NightmareRunState.get_item_count(&"boots"), 1)
	assert_eq(NightmareRunState.get_item_count(&"sword"), 1)
	assert_false(site.veteran.visible, "ветеран не воскресает")
	assert_true(site.get_interactable(&"night_fire").enabled)
	assert_true(sunny.input_enabled)

	# Ночь без отравления не начинается и объясняет, чего не хватает.
	var hints: Array[String] = []
	site.hint_requested.connect(func(text: String) -> void: hints.append(text))
	site.get_interactable(&"night_fire").interact()
	assert_false(NightmareRunState.has_flag(&"night_started"), "ночь без отравления не начинается")
	assert_eq(hints.back(), "Сначала отравьте общие фляги Bloodbane.")

	site.get_interactable(&"poison_flasks").interact()
	assert_true(NightmareRunState.has_flag(&"flasks_poisoned"))
	assert_true(NightmareRunState.has_flag(&"sunny_flask_clean"))
	assert_eq(NightmareRunState.get_item_count(&"flasks"), 3, "фляги не расходуются")

	site.get_interactable(&"night_fire").interact()
	assert_true(await _wait_until(func() -> bool: return NightmareRunState.has_flag(&"night_started")))
	assert_true(await _wait_until(func() -> bool: return site.phase == CaravanSite.PHASE_DAWN, 240))
	assert_true(NightmareRunState.has_flag(&"night_passed"))
	assert_true(site.get_interactable(&"dawn_exit").enabled)
	assert_true(sunny.input_enabled)

	site.get_interactable(&"dawn_exit").interact()
	assert_true(await _wait_until(func() -> bool: return wrapper.has_started_transition()))
	assert_true(NightmareRunState.has_flag(&"dawn_departure"))
	assert_true(NightmareRunState.has_flag(&"camp_aftermath_completed"))
	assert_eq(site.phase, CaravanSite.PHASE_COMPLETE)


func test_all_camp_dialogue_and_spell_resources_load() -> void:
	var runner := DialogueRunner.new()
	autofree(runner)
	for sequence_name in CAMP_SEQUENCES:
		var sequence := load(DIALOGUE_DIR + sequence_name + ".tres") as DialogueSequence
		assert_not_null(sequence, "%s загружается" % sequence_name)
		if sequence == null:
			continue
		assert_gt(sequence.lines.size(), 0, "%s не пуста" % sequence_name)
		for line in sequence.lines:
			assert_true(line is DialogueLine)
			assert_false((line as DialogueLine).text.strip_edges().is_empty())
			assert_true(runner.speaker_names.has((line as DialogueLine).speaker), "%s: говорящий %s" % [sequence_name, (line as DialogueLine).speaker])
	var catalog := load(CAMP_MESSAGES) as SpellMessageCatalog
	assert_not_null(catalog)
	var larva_message := catalog.get_message(&"larva_slain")
	assert_not_null(larva_message, "есть сообщение о личинке")
	assert_true(larva_message.is_valid())
	assert_null(catalog.get_message(&"tyrant_death"), "в S03 нет сообщения о смерти Горного Короля")


func test_camp_scene_has_required_cast_and_props() -> void:
	var site := (load(CAMP_SCENE) as PackedScene).instantiate() as CaravanSite
	add_child_autofree(site)
	assert_not_null(site.get_spawn(&"Chain"))
	assert_not_null(site.get_spawn(&"ChainAnchor"))
	assert_not_null(site.get_node_or_null("NPCs/Hero"))
	assert_not_null(site.get_node_or_null("NPCs/Veteran"))
	assert_not_null(site.get_node_or_null("NPCs/Scholar"))
	assert_not_null(site.get_node_or_null("NPCs/ShiftySlave"))
	assert_not_null(site.get_node_or_null("Props/Wagon"))
	assert_not_null(site.get_node_or_null("Props/ChainLoop"))
	assert_not_null(site.get_node_or_null("Props/VeteranSword"))
	assert_not_null(site.get_node_or_null("Props/Fire"))
	assert_eq(site.get_node("Props/FourLarvae").get_child_count(), 4, "после личинки появляются четыре твари")
	assert_false(site.tyrant.visible, "Горный Король скрыт до нападения")
	assert_false(site.tyrant.is_ai_enabled())
	assert_false(site.tyrant.is_physics_processing(), "кинематографическая модель не падает без коллизий")
	await wait_process_frames(3)
	assert_gt(site.tyrant.global_position.y, -1.0, "Горный Король остаётся на площадке")


func test_camp_interactions_are_one_shot_and_unlock_attack() -> void:
	var wrapper := _spawn_wrapper()
	var site := wrapper.get_node("CaravanSite") as CaravanSite
	var sequence_count := [0]
	site.sequence_requested.connect(func(_sequence: DialogueSequence) -> void: sequence_count[0] += 1)
	var rations := site.get_interactable(&"camp_rations")
	var bloodbane := site.get_interactable(&"camp_bloodbane")
	var wagon := site.get_interactable(&"camp_wagon")
	assert_true(rations.enabled)
	assert_false(site.get_interactable(&"camp_attack").enabled, "до осмотра атака закрыта")

	rations.interact()
	rations.interact()
	assert_eq(sequence_count[0], 1, "повторное взаимодействие не запускает реплику")
	assert_true(NightmareRunState.has_flag(&"camp_rations_taken"))
	assert_false(rations.enabled)
	assert_false(site.get_interactable(&"camp_attack").enabled)

	bloodbane.interact()
	wagon.interact()
	assert_eq(sequence_count[0], 3)
	assert_true(NightmareRunState.has_flag(&"camp_bloodbane_seen"))
	assert_true(NightmareRunState.has_flag(&"camp_wagon_examined"))
	assert_true(NightmareRunState.has_flag(&"camp_explored"))
	assert_true(site.get_interactable(&"camp_attack").enabled, "после осмотра можно вернуться к костру")


func test_attack_larva_key_wagon_fall_and_aftermath() -> void:
	var wrapper := _spawn_wrapper()
	var site := wrapper.get_node("CaravanSite") as CaravanSite
	var sunny := wrapper.get_node("Sunny") as SunnyController
	assert_true(await _wait_until(func() -> bool: return site.get_interactable(&"camp_attack") != null))
	# Все три осмотра выполняются напрямую: проверяется сценарий, а не поиск пути.
	site.get_interactable(&"camp_rations").interact()
	site.get_interactable(&"camp_bloodbane").interact()
	site.get_interactable(&"camp_wagon").interact()
	assert_true(site.get_interactable(&"camp_attack").enabled)

	site.get_interactable(&"camp_attack").interact()
	var reached_larva := await _wait_until(func() -> bool: return site.phase == CaravanSite.PHASE_LARVA)
	assert_true(reached_larva, "нападение доходит до фазы личинки")
	assert_true(NightmareRunState.has_flag(&"attack_started"))
	assert_true(NightmareRunState.has_flag(&"camp_completed"))
	assert_true(NightmareRunState.has_flag(&"broad_slave_dead"))
	assert_true(site.larva.visible)
	assert_false(site.broad_slave.visible)
	assert_false(site.broad_corpse.visible)
	assert_true(site.get_interactable(&"chain_larva").enabled)
	assert_true(sunny.input_enabled, "после постановки игроку возвращают управление")
	assert_false(NightmareRunState.has_flag(&"tyrant_death_seen"), "смерть Короля не выдаётся за случившуюся")

	site.get_interactable(&"chain_larva").interact()
	var reached_key := await _wait_until(func() -> bool: return site.get_interactable(&"hero_key").enabled)
	assert_true(reached_key, "после убийства личинки Герой бросает ключ")
	assert_true(NightmareRunState.has_flag(&"larva_killed"))
	assert_false(site.larva.visible)
	assert_true(site.four_larvae.visible)
	assert_eq(site.four_larvae.get_child_count(), 4)
	for larva in site.four_larvae.get_children():
		assert_true((larva as Node3D).visible, "каждая из четырёх личинок видна в фазе LARVA")
	assert_true(site.key.visible)
	assert_true(site.get_interactable(&"hero_key").enabled)

	site.get_interactable(&"hero_key").interact()
	var reached_wagon := await _wait_until(func() -> bool: return site.get_interactable(&"wagon_wedges").enabled)
	assert_true(reached_wagon, "ключ и освобождение доводят эпизод до плана с повозкой")
	assert_true(NightmareRunState.has_flag(&"chains_released"))
	assert_true(NightmareRunState.has_flag(&"camp_episode_completed"))
	assert_false(sunny.chain_restrained, "после ключа цепь снята")
	assert_false(sunny.is_camp_tethered())
	assert_eq(site.phase, CaravanSite.PHASE_WAGON)
	assert_false(site.four_larvae.visible, "личинки скрыты при переходе к плану с повозкой")
	for larva in site.four_larvae.get_children():
		assert_false((larva as Node3D).visible, "ни одна личинка не остаётся в кадре плана с повозкой")
	assert_false(site.chain.visible)
	assert_eq(NightmareRunState.get_item_count(&"key"), 0, "ключ расходуется")

	assert_true(site.get_interactable(&"wagon_wedges").enabled)
	site.get_interactable(&"wagon_wedges").interact()
	assert_true(NightmareRunState.has_flag(&"wagon_wedges_removed"))
	assert_false(site.get_interactable(&"wagon_wedges").enabled)
	assert_true(site.get_interactable(&"wagon_loop").enabled)
	assert_false(site.get_interactable(&"wagon_push").enabled)

	site.get_interactable(&"wagon_loop").interact()
	assert_true(NightmareRunState.has_flag(&"wagon_loop_ready"))
	assert_false(site.get_interactable(&"wagon_loop").enabled)
	assert_true(site.get_interactable(&"wagon_push").enabled)
	assert_true(site.chain_loop.visible)

	site.get_interactable(&"wagon_push").interact()
	var reached_aftermath := await _wait_until(func() -> bool: return site.phase == CaravanSite.PHASE_AFTERMATH, 240)
	assert_true(reached_aftermath, "повозка и Тиран падают, сцена переходит к последствиям")
	assert_true(NightmareRunState.has_flag(&"wagon_fall_seen"))
	assert_true(NightmareRunState.has_flag(&"tyrant_fall_seen"))
	assert_true(NightmareRunState.has_flag(&"tyrant_alive_suspected"), "падение не считается смертью")
	assert_false(NightmareRunState.has_flag(&"tyrant_death_confirmed"))
	assert_false(NightmareRunState.has_flag(&"tyrant_death_seen"))
	assert_true(NightmareRunState.has_flag(&"aftermath_started"))
	assert_true(NightmareRunState.has_flag(&"survivors_four"))
	assert_false(site.wagon.visible)
	assert_false(site.tyrant.visible)
	assert_false(site.four_larvae.visible)
	for larva in site.four_larvae.get_children():
		assert_false((larva as Node3D).visible, "личинки не возвращаются в AFTERMATH")
	assert_true(site.hero.visible)
	assert_true(site.shifty.visible)
	assert_true(site.scholar.visible)
	assert_true(site.veteran.visible)
	assert_false(site.white_horse.visible)
	assert_false(site.dark_horse.visible)
	for node_path in ["NPCs/SoldierA", "NPCs/SoldierB", "NPCs/SlaveA", "NPCs/SlaveB", "NPCs/SlaveC"]:
		assert_false((site.get_node(node_path) as Node3D).visible, "%s погибает в нападении" % node_path)
	assert_true(sunny.input_enabled, "после падения игроку возвращают управление")
	assert_false(wrapper.has_started_transition(), "сцена не перескакивает через последствия")


func test_larvae_stay_hidden_when_wagon_phase_is_restored() -> void:
	# Восстановление после завершённого эпизода нападения: сцена загружается
	# с флагами LARVA/WAGON, а запоздалый показ не должен вернуть личинок.
	NightmareRunState.set_flag(&"attack_started")
	NightmareRunState.set_flag(&"camp_completed")
	NightmareRunState.set_flag(&"larva_killed")
	NightmareRunState.set_flag(&"chains_released")
	NightmareRunState.set_flag(&"wagon_wedges_removed")
	var site := (load(CAMP_SCENE) as PackedScene).instantiate() as CaravanSite
	add_child_autofree(site)
	await wait_process_frames(2)
	assert_false(site.four_larvae.visible, "при загрузке завершённого эпизода личинки скрыты")
	for larva in site.four_larvae.get_children():
		assert_false((larva as Node3D).visible, "дочерние личинки скрыты при восстановлении")

	site.show_four_larvae()
	assert_false(site.four_larvae.visible, "запоздалый вызов не показывает личинок вне LARVA")
	for larva in site.four_larvae.get_children():
		assert_false((larva as Node3D).visible, "запоздалый вызов не включает дочерних личинок")

	site.begin_wagon_phase()
	assert_eq(site.phase, CaravanSite.PHASE_WAGON)
	assert_false(site.four_larvae.visible, "восстановленная фаза повозки не показывает личинок")
	for larva in site.four_larvae.get_children():
		assert_false((larva as Node3D).visible, "ни одна личинка не возвращается после восстановления")

	site.show_aftermath()
	assert_false(site.four_larvae.visible, "AFTERMATH не возвращает личинок")
	for larva in site.four_larvae.get_children():
		assert_false((larva as Node3D).visible, "после последствий личинки остаются скрытыми")
