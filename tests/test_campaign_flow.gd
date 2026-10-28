extends GutTest
## Сквозная оболочка Первого Кошмара: пролог → перевал → стоянка → засада → святилище.
## Тесты проверяют интеграцию готовых сцен, не переигрывая их механики.

const CAMPAIGN_ENTRY := "res://scenes/campaign/campaign_entry.tscn"
const PASS_SCENE := "res://scenes/campaign/first_nightmare_pass.tscn"
const CAMP_SCENE := "res://scenes/locations/caravan_site/caravan_site.tscn"
const CAMP_ARRIVAL_SCENE := "res://scenes/campaign/caravan_site_arrival.tscn"
const AMBUSH_SCENE := "res://scenes/campaign/caravan_ambush.tscn"
const PILGRIM_SCENE := "res://scenes/campaign/pilgrim_path_arrival.tscn"
const SANCTUARY_SCENE := "res://scenes/campaign/sanctuary_arrival.tscn"
const APPRAISAL_SCENE := "res://scenes/campaign/appraisal_arrival.tscn"
const FINALE_SCENE := "res://scenes/campaign/finale_arrival.tscn"

const ENTRY_SCRIPT := preload("res://scripts/campaign/campaign_entry.gd")
const PASS_SCRIPT := preload("res://scripts/campaign/first_nightmare_pass.gd")
const CAMP_ARRIVAL_SCRIPT := preload("res://scripts/campaign/caravan_site_arrival.gd")
const AMBUSH_SCRIPT := preload("res://scripts/campaign/caravan_ambush.gd")
const PILGRIM_SCRIPT := preload("res://scripts/campaign/pilgrim_path_arrival.gd")
const SANCTUARY_SCRIPT := preload("res://scripts/campaign/sanctuary_arrival.gd")
const APPRAISAL_SCRIPT := preload("res://scripts/campaign/appraisal.gd")


func before_each() -> void:
	NightmareRunState.reset()


func after_each() -> void:
	NightmareRunState.reset()



func _instantiate(path: String, autostart := false, fast := false) -> Node3D:
	var scene := (load(path) as PackedScene).instantiate() as Node3D
	for property in [&"autostart", &"transition_enabled", &"fade_in", &"completion_enabled"]:
		_set_if_present(scene, property, false)
	_set_if_present(scene, &"fast_mode", fast)
	if autostart:
		_set_if_present(scene, &"autostart", true)
	add_child_autofree(scene)
	return scene


func _set_if_present(object: Object, property: StringName, value: Variant) -> void:
	for entry in object.get_property_list():
		if StringName(entry.get("name", "")) == property:
			object.set(property, value)
			return


func test_campaign_chain_points_to_existing_scenes() -> void:
	assert_true(FileAccess.file_exists(String(ProjectSettings.get_setting("application/run/main_scene"))),
		"главная сцена проекта существует")
	assert_true(FileAccess.file_exists(CAMPAIGN_ENTRY), "вход кампании существует")
	assert_true(FileAccess.file_exists(ENTRY_SCRIPT.NEXT_SCENE), "перевал существует")
	assert_true(FileAccess.file_exists(PASS_SCRIPT.NEXT_SCENE), "стоянка каравана существует")
	assert_true(FileAccess.file_exists(CAMP_SCENE), "локация стоянки существует")
	assert_true(FileAccess.file_exists("res://resources/dialogue/caravan/camp_wagon_plan.tres"), "план с повозкой существует")
	assert_true(FileAccess.file_exists("res://resources/dialogue/caravan/camp_wagon_fall.tres"), "постановка падения существует")
	assert_true(FileAccess.file_exists("res://resources/dialogue/caravan/camp_aftermath.tres"), "переход к последствиям существует")
	assert_true(FileAccess.file_exists(CAMP_ARRIVAL_SCRIPT.NEXT_SCENE), "подъём к храму существует")
	assert_true(FileAccess.file_exists(PILGRIM_SCENE), "оболочка подъёма существует")
	assert_true(FileAccess.file_exists(PILGRIM_SCRIPT.NEXT_SCENE), "святилище существует")
	assert_true(FileAccess.file_exists(AMBUSH_SCRIPT.NEXT_SCENE), "старая песочница засады остаётся доступной")
	assert_true(FileAccess.file_exists(SANCTUARY_SCENE), "оболочка святилища существует")
	assert_true(FileAccess.file_exists(SANCTUARY_SCRIPT.NEXT_SCENE), "звёздная оценка существует")
	assert_true(FileAccess.file_exists(APPRAISAL_SCENE), "сцена оценки существует")
	assert_true(FileAccess.file_exists(APPRAISAL_SCRIPT.FINALE_SCENE), "финальная сцена существует")
	assert_true(FileAccess.file_exists(FINALE_SCENE), "финальная сцена загружается по пути")


func test_entry_resets_run_state_and_marks_prologue_complete() -> void:
	NightmareRunState.set_flag(&"stale_run")
	var entry := _instantiate(CAMPAIGN_ENTRY, false)
	entry.start()
	assert_false(NightmareRunState.has_flag(&"stale_run"), "новый запуск кампании очищает прошлые флаги")
	assert_false(NightmareRunState.has_flag(&"prologue_completed"), "до финала пролога флаг не ставится")
	var prologue := entry.get_node("Prologue") as SliceDirector
	prologue.slice_finished.emit()
	await wait_process_frames(1)
	assert_true(NightmareRunState.has_flag(&"prologue_completed"), "финал пролога отмечает переход к S01")



func test_campaign_prologue_sets_mark_of_divinity_at_b16() -> void:
	var entry := _instantiate(CAMPAIGN_ENTRY, false)
	var prologue := entry.get_node("Prologue") as SliceDirector
	prologue.fast_mode = true
	entry.start()
	assert_false(NightmareRunState.has_flag(&"mark_of_divinity"),
		"старт кампании не выдаёт Mark of Divinity до B16")

	for i in 300:
		if prologue.beat >= SliceDirector.Beat.B16_RUNES:
			break
		if prologue.runner.running:
			prologue.runner.advance()
		elif prologue.ui.rune_status.showing:
			prologue.ui.rune_status.close()
		elif prologue.awaiting != &"":
			prologue.notify(prologue.awaiting)
		await wait_process_frames(1)

	assert_eq(prologue.beat, SliceDirector.Beat.B16_RUNES, "кампания дошла до экрана рун")
	assert_true(prologue.ui.rune_status.showing, "экран статуса открыт")
	assert_true(NightmareRunState.has_flag(&"mark_of_divinity"),
		"обычная кампания устанавливает Mark of Divinity на B16")
	assert_false(NightmareRunState.has_item(&"mark_of_divinity"),
		"Mark of Divinity не появляется в инвентаре")
	assert_string_contains("\n".join(prologue.ui.rune_status.row_texts()), "Mark of Divinity")


func test_entry_wraps_prologue_and_replaces_end_card() -> void:
	var entry := _instantiate(CAMPAIGN_ENTRY, false)
	var prologue := entry.get_node("Prologue") as SliceDirector
	assert_not_null(prologue, "пролог остаётся готовой сценой внутри оболочки")
	assert_false(prologue.autostart, "оболочка сама решает, когда запускать пролог")
	assert_false(entry.get_node("Transition").visible, "карточка перехода скрыта до финала")

	prologue.ui.show_end_card()
	prologue.slice_finished.emit()
	await wait_process_frames(1)

	assert_false(prologue.ui.end_card.visible, "карточка вертикального среза скрыта")
	assert_true(entry.get_node("Transition").visible, "показана карточка Первого Кошмара")
	assert_true(entry.is_finished(), "оболочка зафиксировала финал пролога")


func test_pass_reuses_caravan_road_and_places_player_on_chain() -> void:
	var pass_scene := _instantiate(PASS_SCENE, false)
	var caravan: Node3D = pass_scene.get_node("CaravanRoad")
	var sunny := pass_scene.get_node("Sunny") as SunnyController
	assert_not_null(caravan, "дорога каравана переиспользуется")
	assert_not_null(sunny, "на перевале есть управляемый Санни")
	var spawn: Node3D = caravan.get_spawn(&"Chain")
	assert_not_null(spawn)
	assert_lt(sunny.global_position.distance_to(spawn.global_position), 0.1, "Санни стоит в цепи")

	var exit := pass_scene.get_node("CaravanRoad/Road/Triggers/CampArrival") as Area3D
	assert_not_null(exit, "у перевала есть зона прибытия в лагерь")
	assert_eq(exit.collision_mask, 2, "зона прибытия видит игрока")
	assert_false(exit.monitorable, "зона не является целью физических запросов")
	assert_almost_eq(exit.position.z, -36.0, 0.01, "зона стоит в конце марша")

	var note := pass_scene.get_node("PrototypeNote/Root/Note") as Label
	assert_not_null(note)
	assert_string_contains(note.text, "S01", "марш отмечен как реализованный сегмент")
	assert_eq(pass_scene.march_beats.size(), 4, "в S01 четыре обязательных знакомства")
	assert_true(pass_scene.march_beats[-1].completes_intro, "последняя реплика завершает знакомство")



func test_pass_restrains_lateral_movement_until_exit() -> void:
	var pass_scene := _instantiate(PASS_SCENE, false)
	var sunny := pass_scene.get_node("Sunny") as SunnyController
	var caravan := pass_scene.get_node("CaravanRoad") as SliceLocation
	assert_false(sunny.chain_restrained, "до марша ограничения цепи нет")

	pass_scene.start()
	assert_true(sunny.chain_restrained, "на перевале включён боковой коридор")
	var route := caravan.march_velocity()
	route.y = 0.0
	route = route.normalized()
	assert_almost_eq(sunny.get_chain_route().dot(route), 1.0, 0.001, "коридор идёт вдоль дороги")

	pass_scene._on_exit_body_entered(sunny)
	assert_false(sunny.chain_restrained, "выход с перевала снимает ограничение")


func test_pass_exit_starts_transition_only_once() -> void:
	var pass_scene := _instantiate(PASS_SCENE, false)
	var sunny := pass_scene.get_node("Sunny") as SunnyController
	assert_false(pass_scene.has_started_transition())
	pass_scene._on_exit_body_entered(sunny)
	pass_scene._on_exit_body_entered(sunny)
	assert_true(pass_scene.has_started_transition(), "выход запускает переход")
	assert_false(sunny.input_enabled, "управление блокируется на время перехода")
	assert_true(NightmareRunState.has_flag(&"camp_reached"), "лагерь отмечается достигнутым")


func test_camp_wrapper_starts_tethered_and_disables_cinematic_tyrant() -> void:
	var wrapper := _instantiate(CAMP_ARRIVAL_SCENE, false, true)
	var site := wrapper.get_node("CaravanSite") as CaravanSite
	var sunny := wrapper.get_node("Sunny") as SunnyController
	assert_not_null(site)
	assert_not_null(sunny)
	assert_eq(site.phase, CaravanSite.PHASE_CAMP)
	assert_true(sunny.is_camp_tethered(), "в лагере действует радиальная цепь")
	assert_true(sunny.chain_restrained)
	assert_false(sunny.allow_sprint)
	assert_false(sunny.allow_jump)
	assert_false(sunny.combat_enabled)
	assert_true(site.get_interactable(&"camp_rations").enabled)
	assert_false(site.get_interactable(&"camp_attack").enabled)
	assert_false(site.tyrant.is_ai_enabled(), "Горный Король в лагере — только кинематографическая модель")
	assert_false(site.tyrant.is_physics_processing())
	assert_eq(site.tyrant.collision_layer, 0)
	assert_eq(site.tyrant.collision_mask, 0)


func test_ambush_wrapper_listens_to_existing_episode_completion() -> void:
	var wrapper := _instantiate(AMBUSH_SCENE, false)
	var ambush := wrapper.get_node("AmbushSiteDemo/AmbushSite") as AmbushController
	assert_not_null(ambush, "готовая сцена засады остаётся внутри оболочки")
	assert_true(
		ambush.episode_completed.is_connected(Callable(wrapper, "_on_episode_completed")),
		"оболочка слушает существующий сигнал завершения эпизода"
	)
	assert_false(wrapper.has_started_transition())
	ambush._enter_state(AmbushController.State.ESCAPED)
	assert_true(wrapper.has_started_transition(), "побег из засады ведёт к святилищу")


func test_sanctuary_wrapper_completes_after_ritual_death() -> void:
	var wrapper := _instantiate(SANCTUARY_SCENE, false)
	var sanctuary := wrapper.get_node("Sanctuary") as SanctuaryController
	var ritual := sanctuary.get_node("AltarRitual") as AltarRitual
	var objective := wrapper.get_node("Objective/Root") as Control
	assert_true(objective.visible, "перед алтарём показана цель")
	assert_true(
		ritual.finished.is_connected(Callable(wrapper, "_on_trial_finished")),
		"оболочка ждёт завершения ритуала после смерти Тирана"
	)
	assert_false(wrapper.is_completed())
	assert_eq(sanctuary.nightmare_state, SanctuaryController.NightmareState.DORMANT)

	watch_signals(sanctuary)
	ritual.finished.emit()
	await wait_process_frames(1)

	assert_true(wrapper.is_completed(), "оболочка завершает испытание после ритуала")
	assert_true(sanctuary.is_completed())
	assert_signal_emitted(sanctuary, "trial_completed")
	assert_true(NightmareRunState.has_flag(&"trial_completed"))
	assert_true(NightmareRunState.has_flag(&"tyrant_death_confirmed"))
	assert_false(NightmareRunState.has_flag(&"first_nightmare_completed"),
		"финальный флаг выставляется только после оценки и пробуждения")
	assert_false(objective.visible, "цель убирается после завершения")
	assert_false(wrapper.get_node("Transition/Card").visible, "старая карточка не дублирует сообщение Заклятия")
