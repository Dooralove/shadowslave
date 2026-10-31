extends GutTest
## C8: сквозная проверка канонического маршрута Первого Кошмара.
##
## Тест проходит 18 шагов от чистого состояния кампании до финальной
## карточки. Диалоги и длинные твины не проигрываются: проверяются
## переходы, флаги, одноразовые взаимодействия и отсутствие преждевременного
## завершения. Визуальная приёмка вынесена в отдельный отчёт.

const ENTRY_SCENE := "res://scenes/campaign/campaign_entry.tscn"
const PASS_SCENE := "res://scenes/campaign/first_nightmare_pass.tscn"
const CAMP_WRAPPER := "res://scenes/campaign/caravan_site_arrival.tscn"
const CAMP_LOCATION := "res://scenes/locations/caravan_site/caravan_site.tscn"
const PILGRIM_LOCATION := "res://scenes/locations/pilgrim_path/pilgrim_path.tscn"
const SANCTUARY_WRAPPER := "res://scenes/campaign/sanctuary_arrival.tscn"
const APPRAISAL_SCENE := "res://scenes/campaign/appraisal_arrival.tscn"
const FINALE_SCENE := "res://scenes/campaign/finale_arrival.tscn"

const PASS_SCRIPT := preload("res://scripts/campaign/first_nightmare_pass.gd")
const CAMP_SCRIPT := preload("res://scripts/campaign/caravan_site_arrival.gd")
const PILGRIM_SCRIPT := preload("res://scripts/campaign/pilgrim_path_arrival.gd")
const SANCTUARY_SCRIPT := preload("res://scripts/campaign/sanctuary_arrival.gd")
const APPRAISAL_SCRIPT := preload("res://scripts/campaign/appraisal.gd")
const FINALE_SCRIPT := preload("res://scripts/campaign/finale.gd")


func before_each() -> void:
	NightmareRunState.reset()


func after_each() -> void:
	NightmareRunState.reset()


func _spawn(path: String, overrides := {}) -> Node:
	var scene := (load(path) as PackedScene).instantiate()
	for property in overrides:
		scene.set(property, overrides[property])
	add_child_autofree(scene)
	await wait_physics_frames(1)
	return scene


func _despawn(scene: Node) -> void:
	if is_instance_valid(scene):
		scene.queue_free()
		await wait_process_frames(1)


func _interact(site: Node3D, id: StringName) -> void:
	var point := site.call(&"get_interactable", id) as Interactable
	assert_not_null(point, "точка взаимодействия %s существует" % id)
	if point != null:
		assert_true(point.enabled, "точка %s доступна" % id)
		point.interact()


func _flag(flag: StringName) -> bool:
	return NightmareRunState.has_flag(flag)


func test_route_spine_links_all_canonical_scenes() -> void:
	var route := [
		ENTRY_SCENE,
		PASS_SCENE,
		CAMP_WRAPPER,
		CAMP_SCRIPT.NEXT_SCENE,
		PILGRIM_SCRIPT.NEXT_SCENE,
		SANCTUARY_SCRIPT.NEXT_SCENE,
		APPRAISAL_SCRIPT.FINALE_SCENE,
		FINALE_SCENE,
	]
	for path in route:
		assert_true(FileAccess.file_exists(path), "сцена маршрута существует: %s" % path)

	assert_eq(PASS_SCRIPT.NEXT_SCENE, CAMP_WRAPPER)
	assert_eq(CAMP_SCRIPT.NEXT_SCENE, "res://scenes/campaign/pilgrim_path_arrival.tscn")
	assert_eq(PILGRIM_SCRIPT.NEXT_SCENE, SANCTUARY_WRAPPER)
	assert_eq(SANCTUARY_SCRIPT.NEXT_SCENE, APPRAISAL_SCENE)
	assert_eq(APPRAISAL_SCRIPT.FINALE_SCENE, FINALE_SCENE)
	assert_eq(FINALE_SCRIPT.CAMPAIGN_ENTRY, ENTRY_SCENE)


func test_eighteen_step_route_reaches_finale_without_premature_completion() -> void:
	# Шаг 1. Кампания начинается с чистого состояния.
	NightmareRunState.set_flag(&"stale_debug_flag")
	var entry = await _spawn(ENTRY_SCENE, {"autostart": false, "transition_enabled": false})
	entry.start()
	assert_false(_flag(&"stale_debug_flag"), "старт кампании сбрасывает прежнее состояние")
	assert_false(entry.is_finished())

	# Шаг 2. Пролог завершён, открыт марш.
	entry._on_slice_finished()
	assert_true(entry.is_finished())
	assert_true(_flag(&"prologue_completed"))
	await _despawn(entry)

	# Шаг 3. Марш в цепях и прибытие к лагерю.
	var pass_scene = await _spawn(PASS_SCENE, {
		"autostart": false,
		"transition_enabled": false,
		"fast_mode": true,
		"debug_direct_scene": false,
	})
	pass_scene.start()
	var pass_sunny := pass_scene.get_node("Sunny") as SunnyController
	assert_true(pass_sunny.chain_restrained, "на марше цепь активна")
	pass_scene._begin_transition()
	assert_true(pass_scene.has_started_transition())
	assert_true(_flag(&"march_intro_seen"))
	assert_true(_flag(&"camp_reached"))
	assert_false(pass_sunny.chain_restrained, "у лагеря цепь снимает ограничение")
	await _despawn(pass_scene)

	# Шаг 4. Лагерь принимает игрока на привязи.
	var camp_wrapper = await _spawn(CAMP_WRAPPER, {
		"transition_enabled": false,
		"fade_in": false,
		"fast_mode": true,
		"debug_direct_scene": false,
	})
	var camp_sunny := camp_wrapper.get_node("Sunny") as SunnyController
	assert_true(camp_sunny.chain_restrained, "в лагере Санни привязан к повозке")
	assert_true(_flag(&"chain_restrained"))
	assert_eq(camp_wrapper.get_phase(), &"CAMP")
	await _despawn(camp_wrapper)

	# Шаг 5. Три якоря лагеря открывают нападение.
	var camp = await _spawn(CAMP_LOCATION)
	camp.begin_camp()
	_interact(camp, &"camp_rations")
	_interact(camp, &"camp_bloodbane")
	_interact(camp, &"camp_wagon")
	assert_true(_flag(&"camp_rations_taken"))
	assert_true(_flag(&"camp_bloodbane_seen"))
	assert_true(_flag(&"camp_wagon_examined"))
	assert_true(_flag(&"camp_explored"))
	assert_true((camp.call(&"get_interactable", &"camp_attack") as Interactable).enabled)

	# Шаг 6. Нападение начинается только после осмотра лагеря.
	_interact(camp, &"camp_attack")
	assert_true(_flag(&"attack_started"))
	assert_true(_flag(&"camp_completed"))
	assert_eq(camp.phase, &"ATTACK")

	# Шаг 7. Личинка, ключ и освобождение от цепи.
	camp.begin_larva_phase()
	var larva_grabbed := [false]
	camp.larva_grabbed.connect(func() -> void: larva_grabbed[0] = true)
	_interact(camp, &"chain_larva")
	assert_true(larva_grabbed[0], "личинка захвачена цепью")
	camp.kill_larva()
	camp.show_four_larvae()
	assert_true(camp.four_larvae.visible, "четыре личинки появляются после убийства первой")
	camp.show_key()
	_interact(camp, &"hero_key")
	assert_eq(NightmareRunState.get_item_count(&"key"), 1)
	camp.release_chains()
	assert_true(_flag(&"chains_released"))
	assert_false(_flag(&"chain_restrained"))
	assert_false(NightmareRunState.has_item(&"key"))
	camp.finish_episode()

	# Шаг 8. Повозка, клинья, петля и падение Тирана без подтверждения смерти.
	camp.begin_wagon_phase()
	assert_false(camp.four_larvae.visible, "личинки скрыты на шаге плана с повозкой")
	for larva in camp.four_larvae.get_children():
		assert_false((larva as Node3D).visible, "ни одна личинка не остаётся в кадре плана с повозкой")
	_interact(camp, &"wagon_wedges")
	_interact(camp, &"wagon_loop")
	_interact(camp, &"wagon_push")
	assert_true(_flag(&"wagon_wedges_removed"))
	assert_true(_flag(&"wagon_loop_ready"))
	camp.stage_tyrant_for_wagon()
	camp.animate_wagon_fall(true)
	assert_true(_flag(&"wagon_fall_seen"))
	assert_true(_flag(&"tyrant_fall_seen"))
	assert_true(_flag(&"tyrant_alive_suspected"))
	assert_false(_flag(&"tyrant_death_confirmed"))

	# Шаг 9. Выжившие, фляги, ветеран и Silver Bell.
	camp.show_aftermath()
	assert_eq(camp.phase, &"AFTERMATH")
	assert_false(camp.four_larvae.visible, "AFTERMATH не возвращает личинок")
	camp.begin_aftermath_search()
	assert_true(_flag(&"survivors_council_done"))
	assert_true(_flag(&"tasks_assigned"))
	_interact(camp, &"flask_a")
	_interact(camp, &"flask_b")
	_interact(camp, &"flask_c")
	assert_eq(camp.collected_flasks(), 3)
	_interact(camp, &"poison_flasks")
	assert_true(_flag(&"flasks_poisoned"))
	assert_true(_flag(&"sunny_flask_clean"))
	assert_eq(NightmareRunState.get_item_count(&"flasks"), 3, "отравление не расходует фляги")
	_interact(camp, &"veteran")
	_interact(camp, &"veteran_sword")
	assert_true(_flag(&"veteran_sword_taken"))
	assert_true(NightmareRunState.has_item(&"sword"))
	camp.execute_veteran()
	assert_true(_flag(&"veteran_dead"))
	assert_true(_flag(&"silver_bell_obtained"))
	assert_true(_flag(&"has_cloak"))
	assert_true(_flag(&"has_boots"))
	assert_true(NightmareRunState.has_item(&"silver_bell"))
	assert_true(NightmareRunState.has_item(&"cloak"))
	assert_true(NightmareRunState.has_item(&"boots"))

	# Шаг 10. Ночь у огня и рассвет.
	_interact(camp, &"night_fire")
	assert_true(_flag(&"night_started"))
	assert_eq(camp.phase, &"NIGHT")
	assert_false(camp.four_larvae.visible, "NIGHT не возвращает личинок")
	camp.begin_dawn()
	assert_true(_flag(&"night_passed"))
	assert_eq(camp.phase, &"DAWN")
	assert_false(camp.four_larvae.visible, "DAWN не возвращает личинок")
	_interact(camp, &"dawn_exit")
	assert_true(_flag(&"dawn_departure"))
	assert_eq(camp.phase, &"COMPLETE")
	await _despawn(camp)

	# Шаг 11. Разрушенная дорога и брошенный меч.
	var path = await _spawn(PILGRIM_LOCATION)
	_interact(path, &"road_gap")
	assert_true(_flag(&"road_gap_seen"))
	_interact(path, &"sword")
	assert_true(_flag(&"sword_discarded"))
	assert_false((path.get_node("Props/Sword") as Node3D).visible)
	assert_false(NightmareRunState.has_item(&"sword"))

	# Шаг 12. Альков, ночь, слепота и смерть Шифти.
	_interact(path, &"rest")
	assert_true(_flag(&"alcove_reached"))
	path.kill_shifty()
	path.begin_dawn()
	assert_true(_flag(&"shifty_dead"))
	assert_true(_flag(&"dawn_ascent"))
	assert_false((path.get_node("NPCs/Shifty") as Node3D).visible)
	assert_false((path.get_node("NPCs/ShiftyBody") as Node3D).visible,
		"тело Шифти не показывается")
	assert_true((path.get_node("Props/BloodStain") as Node3D).visible,
		"на камне остаётся кровь")

	# Шаг 13. Учёный разоблачён и оставлен.
	_interact(path, &"scholar")
	assert_true(_flag(&"scholar_confronted"))
	path.abandon_scholar()
	assert_true(_flag(&"scholar_abandoned"))
	assert_false((path.get_node("NPCs/Scholar") as Node3D).visible)

	# Шаг 14. Пещера, признание, ранение и выход.
	_interact(path, &"cave")
	assert_true(_flag(&"cave_entered"))
	path.mark_confession()
	path.wound_sunny()
	assert_true(_flag(&"scholar_confession_seen"))
	assert_true(_flag(&"wound_taken"))
	_interact(path, &"cave_exit")
	assert_true(_flag(&"cave_escaped"))

	# Шаг 15. Герой, Silver Bell, захват и вход в храм.
	_interact(path, &"hero")
	assert_true(_flag(&"hero_confrontation_seen"))
	assert_true((path.get_node("NPCs/Hero") as Node3D).visible, "до звонка Герой виден")
	assert_false((path.get_node("NPCs/TyrantAtHero") as Node3D).visible)
	_interact(path, &"bell")
	assert_true(_flag(&"silver_bell_used"))
	assert_true(NightmareRunState.has_item(&"silver_bell"), "Колокольчик остаётся Памятью")
	assert_false(_flag(&"hero_taken"), "звонок не начинает захват до реплики")
	assert_false(_flag(&"hero_dead"))
	assert_false((path.call(&"get_trigger", &"temple") as TriggerZone).enabled,
		"храм закрыт до завершения захвата")

	# Оболочка вызывает эти шаги на репликах bell_sequence. Здесь проверяется
	# итоговое состояние маршрута; порядок реплик проверяет test_pilgrim_path.
	path.call(&"turn_hero_toward_bell")
	path.call(&"begin_hero_capture")
	assert_true(_flag(&"hero_taken"))
	assert_false(_flag(&"hero_dead"), "hero_dead не ставится вместе с hero_taken")
	assert_false((path.get_node("NPCs/Hero") as Node3D).visible)
	assert_true((path.get_node("NPCs/TyrantAtHero") as Node3D).visible)
	assert_false((path.get_node("Props/TempleGlow") as Node3D).visible)
	assert_false((path.call(&"get_trigger", &"temple") as TriggerZone).enabled)

	path.call(&"complete_hero_capture")
	assert_true(_flag(&"hero_dead"))
	assert_false((path.get_node("NPCs/TyrantAtHero") as Node3D).visible,
		"после захвата Тиран скрыт")
	assert_true((path.get_node("Props/TempleGlow") as Node3D).visible,
		"после захвата храм подсвечен")
	assert_true((path.call(&"get_trigger", &"temple") as TriggerZone).enabled)
	# Mark of Divinity выставляется на B16 штатно (slice_director); пролог в маршруте не проигрывается.
	NightmareRunState.set_flag(&"mark_of_divinity")
	path.reach_temple()
	assert_true(_flag(&"temple_reached"))
	assert_false(_flag(&"first_nightmare_completed"))
	await _despawn(path)

	# Шаг 16. Алтарь, семь строк, смерть Тирана и завершение испытания.
	var sanctuary_wrapper = await _spawn(SANCTUARY_WRAPPER, {
		"transition_enabled": false,
		"fade_in": false,
	})
	var sanctuary := sanctuary_wrapper.get_node("Sanctuary") as SanctuaryController
	var ritual := sanctuary.get_node("AltarRitual") as AltarRitual
	var altar := sanctuary.get_node("Interactables/AltarOffering") as Interactable
	_configure_fast_ritual(ritual)
	altar.interact()
	await wait_seconds(0.5)
	assert_true(sanctuary_wrapper.is_completed(), "оболочка завершает испытание после смерти Тирана")
	assert_true(_flag(&"trial_completed"))
	assert_true(_flag(&"tyrant_death_confirmed"))
	assert_true(NightmareRunState.has_item(&"shadow_blessing"),
		"святилище выдаёт благословение тени")
	assert_false(_flag(&"first_nightmare_completed"),
		"смерть Тирана не завершает Первый Кошмар до оценки")
	await _despawn(sanctuary_wrapper)

	# Шаг 17. Оценка, True Name, Shadow Slave и First Seal.
	var appraisal = await _spawn(APPRAISAL_SCENE, {
		"fade_in": false,
		"transition_enabled": false,
		"fast_mode": true,
		"start_delay": 0.0,
		"end_delay": 0.0,
	})
	await wait_seconds(0.5)
	assert_true(appraisal.is_completed())
	assert_true(_flag(&"appraisal_completed"))
	assert_true(_flag(&"true_name_lost_from_light"))
	assert_true(_flag(&"aspect_shadow_slave"))
	assert_true(_flag(&"first_seal_broken"))
	assert_false(_flag(&"first_nightmare_completed"),
		"оценка не выставляет финальный флаг")
	await _despawn(appraisal)

	# Шаг 18. Пробуждение и финальная карточка.
	var finale = await _spawn(FINALE_SCENE, {
		"fade_in": false,
		"fast_mode": true,
		"restart_enabled": false,
	})
	await wait_seconds(0.4)
	assert_true(finale.is_ready_for_restart())
	assert_true((finale.get_node("%Card") as Control).visible)
	assert_true(_flag(&"awakening_completed"))
	assert_true(_flag(&"first_nightmare_finished"))
	assert_true(_flag(&"first_nightmare_completed"),
		"финальный флаг выставляется только в S15")
	await _despawn(finale)


func _configure_fast_ritual(ritual: AltarRitual) -> void:
	var catalog := SpellMessageCatalog.new()
	catalog.messages = [
		_message(&"altar_sacrifice", "Ты предложил себя в жертву богам."),
		_message(&"altar_gods_dead", "Боги мертвы и не могут тебя услышать."),
		_message(&"altar_mark_of_divinity", "Твоя душа несёт знак божественности."),
		_message(&"altar_temple_slave", "Ты — храмовый раб."),
		_message(&"altar_shadow_god_stirs", "Бог Тени пробуждается в вечном сне."),
		_message(&"altar_blessing_beyond_grave", "Он посылает благословение из-за пределов смерти."),
		_message(&"altar_child_of_shadows", "Дитя Теней, прими своё благословение!"),
		_message(&"altar_tyrant_slain", "Ты убил пробуждённого тирана — Горного Короля."),
		_message(&"altar_wake_up", "Просыпайся, Санлесс! Твой кошмар окончен."),
		_message(&"altar_prepare_appraisal", "Приготовься к оценке…"),
	]
	ritual.messages = catalog
	ritual.spell_overlay = null
	ritual.start_delay = 0.0
	ritual.line_gap = 0.0
	ritual.finale_delay = 0.0
	ritual.fast_mode = true


func _message(id: StringName, text: String) -> SpellMessage:
	var message := SpellMessage.new()
	message.id = id
	message.text = text
	message.duration = 0.0
	return message
