extends GutTest
## B1-A: интерактивное отравление общих фляг у костра лагеря.
##
## Все действия идут через Interactable.interact() или через сигнал
## interacted локации: это тот же путь, по которому игра обрабатывает нажатие E.
## Флаги вручную не выставляются, кроме одного защитного теста без осмотра Bloodbane.

const CAMP_ARRIVAL := "res://scenes/campaign/caravan_site_arrival.tscn"
const CAMP_SCENE := "res://scenes/locations/caravan_site/caravan_site.tscn"


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


func _capture_hints(site: CaravanSite) -> Array[String]:
	var hints: Array[String] = []
	site.hint_requested.connect(func(text: String) -> void: hints.append(text))
	return hints


## Нажатие по точке взаимодействия тем же путём, что и в игре.
func _press(site: CaravanSite, id: StringName) -> void:
	site.get_interactable(id).interact()


## Выполняет реальный путь до фазы AFTERMATH без поблажек на флаги.
func _advance_to_aftermath(site: CaravanSite) -> bool:
	if not await _wait_until(func() -> bool: return site.get_interactable(&"camp_attack") != null):
		return false
	_press(site, &"camp_rations")
	_press(site, &"camp_bloodbane")
	_press(site, &"camp_wagon")
	_press(site, &"camp_attack")
	if not await _wait_until(func() -> bool: return site.phase == CaravanSite.PHASE_LARVA):
		return false
	_press(site, &"chain_larva")
	if not await _wait_until(func() -> bool: return site.get_interactable(&"hero_key").enabled):
		return false
	_press(site, &"hero_key")
	if not await _wait_until(func() -> bool: return site.get_interactable(&"wagon_wedges").enabled):
		return false
	_press(site, &"wagon_wedges")
	_press(site, &"wagon_loop")
	_press(site, &"wagon_push")
	if not await _wait_until(func() -> bool: return site.phase == CaravanSite.PHASE_AFTERMATH, 240):
		return false
	return await _wait_until(func() -> bool: return NightmareRunState.has_flag(&"tasks_assigned"))


func _collect_flasks(site: CaravanSite) -> void:
	_press(site, &"flask_a")
	_press(site, &"flask_b")
	_press(site, &"flask_c")


func _take_veteran_dead(site: CaravanSite) -> bool:
	_press(site, &"veteran")
	if not await _wait_until(func() -> bool: return site.get_interactable(&"veteran_sword").enabled):
		return false
	_press(site, &"veteran_sword")
	return await _wait_until(func() -> bool: return NightmareRunState.has_flag(&"veteran_dead"))


func test_no_poison_flags_on_plain_camp_start() -> void:
	var wrapper := _spawn_wrapper()
	var site := wrapper.get_node("CaravanSite") as CaravanSite
	await wait_process_frames(2)
	assert_false(NightmareRunState.has_flag(&"flasks_poisoned"), "флаг не ставится при обычном запуске")
	assert_false(NightmareRunState.has_flag(&"sunny_flask_clean"))
	assert_false(site.get_interactable(&"poison_flasks").enabled, "отравление закрыто до нападения")


func test_bloodbane_inspection_is_recorded_and_names_the_poison() -> void:
	var wrapper := _spawn_wrapper()
	var site := wrapper.get_node("CaravanSite") as CaravanSite
	await wait_process_frames(2)
	var hints := _capture_hints(site)
	_press(site, &"camp_bloodbane")
	assert_true(NightmareRunState.has_flag(&"camp_bloodbane_seen"), "осмотр фиксируется")
	assert_true(hints.back().contains("Смертельный яд"), "осмотр называет яд смертельным")
	_press(site, &"camp_bloodbane")
	assert_eq(hints.size(), 1, "повторный осмотр ничего не добавляет")


func test_poison_unavailable_before_attack() -> void:
	var wrapper := _spawn_wrapper()
	var site := wrapper.get_node("CaravanSite") as CaravanSite
	await wait_process_frames(2)
	_press(site, &"camp_bloodbane")
	var hints := _capture_hints(site)
	assert_false(site.get_interactable(&"poison_flasks").enabled)
	# Даже прямой сигнал взаимодействия не должен обойти условия.
	site.interacted.emit(&"poison_flasks")
	assert_false(NightmareRunState.has_flag(&"flasks_poisoned"))
	assert_false(NightmareRunState.has_flag(&"sunny_flask_clean"))
	assert_eq(hints.back(), "Сначала нужно пережить нападение.")


func test_poison_requires_three_flasks() -> void:
	var wrapper := _spawn_wrapper()
	var site := wrapper.get_node("CaravanSite") as CaravanSite
	assert_true(await _advance_to_aftermath(site))
	var hints := _capture_hints(site)
	assert_false(site.get_interactable(&"poison_flasks").enabled, "без фляг действие закрыто")
	site.interacted.emit(&"poison_flasks")
	assert_false(NightmareRunState.has_flag(&"flasks_poisoned"))
	assert_eq(hints.back(), "Сначала соберите три фляги у мёртвых солдат.")

	_press(site, &"flask_a")
	_press(site, &"flask_b")
	assert_false(site.get_interactable(&"poison_flasks").enabled, "с двумя флягами действие закрыто")
	site.interacted.emit(&"poison_flasks")
	assert_false(NightmareRunState.has_flag(&"flasks_poisoned"))

	_press(site, &"flask_c")
	assert_true(site.get_interactable(&"poison_flasks").enabled, "с тремя флягами действие открыто")


func test_poison_requires_bloodbane_inspection() -> void:
	# Осмотр нельзя пропустить в обычной игре: нападение открывается только после него.
	# Поэтому здесь защитная проверка снимает флаг уже после нападения.
	var wrapper := _spawn_wrapper()
	var site := wrapper.get_node("CaravanSite") as CaravanSite
	assert_true(await _advance_to_aftermath(site))
	_collect_flasks(site)
	NightmareRunState.clear_flag(&"camp_bloodbane_seen")
	var hints := _capture_hints(site)
	site.interacted.emit(&"poison_flasks")
	assert_false(NightmareRunState.has_flag(&"flasks_poisoned"), "без осмотра Bloodbane яд не применяется")
	assert_eq(hints.back(), "Сначала осмотрите Bloodbane.")


func test_poison_through_interaction_keeps_flasks_and_sets_flags() -> void:
	var wrapper := _spawn_wrapper()
	var site := wrapper.get_node("CaravanSite") as CaravanSite
	assert_true(await _advance_to_aftermath(site))
	_collect_flasks(site)
	assert_eq(NightmareRunState.get_item_count(&"flasks"), 3)
	var hints := _capture_hints(site)

	_press(site, &"poison_flasks")
	assert_true(NightmareRunState.has_flag(&"flasks_poisoned"))
	assert_true(NightmareRunState.has_flag(&"sunny_flask_clean"))
	assert_eq(NightmareRunState.get_item_count(&"flasks"), 3, "количество фляг не меняется")
	assert_false(site.get_interactable(&"poison_flasks").enabled, "действие больше не предлагается")
	assert_eq(hints.back(), "Общие фляги отравлены. Своя фляга осталась чистой.")


func test_repeat_poison_has_no_side_effects() -> void:
	var wrapper := _spawn_wrapper()
	var site := wrapper.get_node("CaravanSite") as CaravanSite
	assert_true(await _advance_to_aftermath(site))
	_collect_flasks(site)
	_press(site, &"poison_flasks")
	var before := NightmareRunState.snapshot()
	var hints := _capture_hints(site)

	_press(site, &"poison_flasks")
	site.interacted.emit(&"poison_flasks")
	assert_eq(NightmareRunState.snapshot(), before, "повтор не меняет флаги и предметы")
	assert_eq(hints.size(), 0, "повтор не выводит подсказку и не запускает реплик")


func test_night_is_blocked_until_poisoned_then_runs() -> void:
	var wrapper := _spawn_wrapper()
	var site := wrapper.get_node("CaravanSite") as CaravanSite
	assert_true(await _advance_to_aftermath(site))
	_collect_flasks(site)
	assert_true(await _take_veteran_dead(site))
	var hints := _capture_hints(site)

	# Костёр доступен, но без отравления ночь не начинается и называет причину.
	assert_true(site.get_interactable(&"night_fire").enabled)
	_press(site, &"night_fire")
	assert_false(NightmareRunState.has_flag(&"night_started"))
	assert_eq(hints.back(), "Сначала отравьте общие фляги Bloodbane.")

	_press(site, &"poison_flasks")
	_press(site, &"night_fire")
	assert_true(await _wait_until(func() -> bool: return NightmareRunState.has_flag(&"night_started")))
	assert_true(await _wait_until(func() -> bool: return site.phase == CaravanSite.PHASE_DAWN, 240))
	assert_true(NightmareRunState.has_flag(&"night_passed"))
	_press(site, &"dawn_exit")
	assert_true(await _wait_until(func() -> bool: return wrapper.has_started_transition()))
	assert_true(NightmareRunState.has_flag(&"dawn_departure"))


func test_fall_off_camp_edge_returns_sunny_to_fire() -> void:
	var wrapper := _spawn_wrapper()
	var site := wrapper.get_node("CaravanSite") as CaravanSite
	var sunny := wrapper.get_node("Sunny") as SunnyController
	await wait_process_frames(2)
	sunny.global_position = Vector3(0.6, -20.0, 6.4)
	await wait_physics_frames(3)
	var seat := site.get_spawn(&"FireSeat")
	assert_gt(sunny.global_position.y, -3.0, "падение с края не уводит Санни в пустоту")
	assert_lt(sunny.global_position.distance_to(seat.global_position), 0.5, "Санни возвращается к костру")


func test_poison_state_survives_scene_reload() -> void:
	var wrapper := _spawn_wrapper()
	var site := wrapper.get_node("CaravanSite") as CaravanSite
	assert_true(await _advance_to_aftermath(site))
	_collect_flasks(site)
	_press(site, &"poison_flasks")
	wrapper.queue_free()
	await wait_process_frames(2)

	# Новая сцена лагеря читает то же состояние кампании.
	var reloaded := (load(CAMP_SCENE) as PackedScene).instantiate() as CaravanSite
	add_child_autofree(reloaded)
	await wait_process_frames(2)
	assert_true(NightmareRunState.has_flag(&"flasks_poisoned"))
	assert_true(NightmareRunState.has_flag(&"sunny_flask_clean"))
	assert_eq(NightmareRunState.get_item_count(&"flasks"), 3)
	assert_false(reloaded.can_poison_flasks(), "повторное отравление невозможно после перезагрузки")

	var snapshot := NightmareRunState.snapshot()
	NightmareRunState.reset()
	assert_false(NightmareRunState.has_flag(&"flasks_poisoned"), "новый прогон начинается без отравления")
	NightmareRunState.restore(snapshot)
	assert_true(NightmareRunState.has_flag(&"flasks_poisoned"), "восстановление сохраняет отравление")
	assert_true(NightmareRunState.has_flag(&"sunny_flask_clean"))
