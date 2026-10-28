extends GutTest
## Регрессии навигации между сценами: LevelPortal, передача именованной
## точки входа и защита от повторного перехода.
##
## Тесты не меняют игровые сцены и не запускают настоящую смену сцены:
## RecordingPortal переопределяет только низкоуровневый commit. Это проверяет
## контракт перехода, не ломая дерево GUT.

const DEST_SCENE := "res://scenes/campaign/campaign_entry.tscn"
const CAMPAIGN_ENTRY := "res://scenes/campaign/campaign_entry.tscn"
const PASS_SCENE := "res://scenes/campaign/first_nightmare_pass.tscn"
const CAMP_SCENE := "res://scenes/campaign/caravan_site_arrival.tscn"
const PILGRIM_SCENE := "res://scenes/campaign/pilgrim_path_arrival.tscn"
const SANCTUARY_SCENE := "res://scenes/campaign/sanctuary_arrival.tscn"
const SUNNY_SCENE := "res://scenes/characters/sunny_waking.tscn"


class RecordingPortal extends LevelPortal:
	var committed: Array[String] = []
	var commit_error := OK
	var reported_errors: Array[String] = []

	func _commit_scene_change(scene_path: String) -> int:
		committed.append(scene_path)
		return commit_error

	# Явно управляем слоем в тестах, чтобы отсутствие FadeLayer было
	# детерминированным и не зависело от дерева GUT.
	func _resolve_fade_layer() -> FadeLayer:
		return fade_layer

	# Ожидаемые ошибки конфигурации проверяются assert'ами, а не падают
	# как необработанные ошибки GUT.
	func _report_error(message: String) -> void:
		reported_errors.append(message)


class CutsceneHost extends Node3D:
	var played: Array[StringName] = []

	func play_cutscene(id: StringName, _fast: bool) -> void:
		played.append(id)


func before_each() -> void:
	NightmareRunState.reset()
	LevelPortal.clear_pending_spawn()
	LevelPortal.clear_active_transition()


func after_each() -> void:
	NightmareRunState.reset()
	LevelPortal.clear_pending_spawn()
	LevelPortal.clear_active_transition()


func _make_fade() -> FadeLayer:
	var fade := FadeLayer.new()
	fade.color = Color(0, 0, 0, 0)
	add_child_autofree(fade)
	return fade


func _make_sunny() -> SunnyController:
	var sunny := (load(SUNNY_SCENE) as PackedScene).instantiate() as SunnyController
	add_child_autofree(sunny)
	return sunny


func _make_portal(spawn: StringName = &"Landing") -> RecordingPortal:
	var portal := RecordingPortal.new()
	portal.destination_scene = DEST_SCENE
	portal.destination_spawn = spawn
	portal.trigger_on_body = false
	portal.fade_out_duration = 0.0
	portal.fade_layer = _make_fade()
	add_child_autofree(portal)
	return portal


func _make_wrapper(path: String, fast := true) -> Node3D:
	var wrapper := (load(path) as PackedScene).instantiate() as Node3D
	for property in [&"fade_in", &"transition_enabled", &"autostart"]:
		_set_if_present(wrapper, property, false)
	_set_if_present(wrapper, &"fast_mode", fast)
	add_child_autofree(wrapper)
	return wrapper


func _set_if_present(object: Object, property: StringName, value: Variant) -> void:
	for entry in object.get_property_list():
		if StringName(entry.get("name", "")) == property:
			object.set(property, value)
			return


func _names(values: Array) -> Array[StringName]:
	var result: Array[StringName] = []
	for value in values:
		result.append(StringName(value))
	return result


func test_portal_requests_scene_once_and_locks_input() -> void:
	var sunny := _make_sunny()
	var portal := _make_portal()
	watch_signals(portal)

	assert_true(await portal.activate(sunny), "валидный переход запускается")
	assert_eq(portal.committed.size(), 1)
	assert_eq(portal.committed[0], DEST_SCENE)
	assert_false(sunny.input_enabled, "ввод заблокирован на время перехода")
	assert_true(portal.is_used())
	assert_true(portal.is_running())
	assert_eq(LevelPortal.take_pending_spawn(DEST_SCENE), &"Landing",
		"точка входа передана следующей сцене")

	assert_false(await portal.activate(sunny), "повторный вызов игнорируется")
	assert_eq(portal.committed.size(), 1, "сцена запрошена ровно один раз")
	assert_signal_emit_count(portal, "transition_started", 1)
	assert_signal_emit_count(portal, "transition_finished", 1)


func test_only_one_portal_can_request_scene_change() -> void:
	var first := _make_portal()
	var second := _make_portal()

	assert_true(await first.activate(), "первый портал запускает переход")
	assert_false(await second.activate(), "второй портал не дублирует смену сцены")
	assert_eq(first.committed.size(), 1)
	assert_eq(second.committed.size(), 0)


func test_interactable_door_activates_portal() -> void:
	var door := Interactable.new()
	door.enabled = true
	add_child_autofree(door)

	var portal := RecordingPortal.new()
	portal.destination_scene = DEST_SCENE
	portal.destination_spawn = &"Landing"
	portal.trigger_on_body = false
	portal.fade_layer = _make_fade()
	portal.fade_out_duration = 0.0
	portal.interactable = door
	add_child_autofree(portal)

	door.interact()
	await wait_process_frames(1)

	assert_eq(portal.committed.size(), 1, "E у двери запускает тот же переход")
	assert_eq(portal.committed[0], DEST_SCENE)


func test_body_enter_triggers_walkthrough_portal() -> void:
	var portal := RecordingPortal.new()
	portal.destination_scene = DEST_SCENE
	portal.destination_spawn = &"Landing"
	portal.trigger_on_body = true
	portal.body_trigger_ignore_frames = 0
	portal.fade_layer = _make_fade()
	portal.fade_out_duration = 0.0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2, 2, 2)
	shape.shape = box
	portal.add_child(shape)
	add_child_autofree(portal)

	var sunny := _make_sunny()
	sunny.global_position = Vector3(0, 0, 4)
	await wait_physics_frames(1)
	sunny.global_position = Vector3.ZERO
	await wait_physics_frames(3)

	assert_eq(portal.committed.size(), 1, "физический вход в проход срабатывает")
	assert_eq(portal.collision_mask, 2, "Area3D видит слой игрока")


func test_spawn_inside_trigger_does_not_restart_transition() -> void:
	var portal := RecordingPortal.new()
	portal.destination_scene = DEST_SCENE
	portal.destination_spawn = &"Landing"
	portal.trigger_on_body = true
	portal.fade_layer = _make_fade()
	portal.fade_out_duration = 0.0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2, 2, 2)
	shape.shape = box
	portal.add_child(shape)
	add_child_autofree(portal)

	var sunny := _make_sunny()
	sunny.global_position = Vector3.ZERO
	await wait_physics_frames(12)
	assert_eq(portal.committed.size(), 0, "появление внутри триггера не зацикливает переход")

	sunny.global_position = Vector3(0, 0, 4)
	await wait_physics_frames(2)
	sunny.global_position = Vector3.ZERO
	await wait_physics_frames(3)
	assert_eq(portal.committed.size(), 1, "после выхода и входа портал снова доступен")


func test_portal_restores_input_when_fade_layer_is_missing() -> void:
	var sunny := _make_sunny()
	var portal := RecordingPortal.new()
	portal.destination_scene = DEST_SCENE
	portal.trigger_on_body = false
	add_child_autofree(portal)
	watch_signals(portal)

	assert_false(await portal.activate(sunny), "без FadeLayer переход запрещён")
	assert_true(sunny.input_enabled, "управление возвращено после отмены")
	assert_eq(portal.committed.size(), 0, "сцена не запрашивалась")
	assert_eq(portal.reported_errors.size(), 1, "ошибка конфигурации диагностирована")
	assert_signal_emitted(portal, "transition_aborted")


func test_aborted_transition_releases_global_guard() -> void:
	var sunny := _make_sunny()
	var invalid := RecordingPortal.new()
	invalid.destination_scene = DEST_SCENE
	invalid.trigger_on_body = false
	add_child_autofree(invalid)

	assert_false(await invalid.activate(sunny), "невалидный портал отменяется")
	var valid := _make_portal()
	assert_true(await valid.activate(sunny), "после отмены другой портал может сработать")


func test_portal_requires_flags_before_starting() -> void:
	var sunny := _make_sunny()
	var portal := _make_portal()
	portal.required_flags = _names([&"north_door_open"])

	assert_false(await portal.activate(sunny), "закрытый портал не срабатывает")
	assert_eq(portal.committed.size(), 0)
	assert_true(sunny.input_enabled, "до перехода управление не блокируется")

	NightmareRunState.set_flag(&"north_door_open")
	assert_true(await portal.activate(sunny), "с открытым флагом портал работает")
	assert_eq(portal.committed.size(), 1)


func test_portal_one_shot_flag_survives_reload() -> void:
	var first := _make_portal()
	first.one_shot_flag = &"north_door_used"
	first.set_flags_on_use = _names([&"north_door_opened"])

	assert_true(await first.activate())
	assert_true(NightmareRunState.has_flag(&"north_door_used"))
	assert_true(NightmareRunState.has_flag(&"north_door_opened"))
	LevelPortal.take_pending_spawn(DEST_SCENE)

	var reloaded := RecordingPortal.new()
	reloaded.destination_scene = DEST_SCENE
	reloaded.one_shot_flag = &"north_door_used"
	reloaded.trigger_on_body = false
	reloaded.fade_layer = _make_fade()
	add_child_autofree(reloaded)

	assert_true(reloaded.is_used(), "после перезагрузки портал помнит флаг")
	assert_false(reloaded.is_available(), "повторный проход запрещён")


func test_portal_cutscene_runs_before_scene_request() -> void:
	var host := CutsceneHost.new()
	add_child_autofree(host)
	var portal := RecordingPortal.new()
	portal.destination_scene = DEST_SCENE
	portal.destination_spawn = &"Landing"
	portal.transition_style = LevelPortal.Style.CUTSCENE
	portal.cutscene_id = &"door_open"
	portal.trigger_on_body = false
	portal.fade_out_duration = 0.0
	portal.fade_layer = _make_fade()
	host.add_child(portal)

	assert_true(await portal.activate())
	assert_eq(host.played.size(), 1, "постановка проиграна до загрузки")
	assert_eq(host.played[0], &"door_open")
	assert_eq(portal.committed.size(), 1)
	assert_eq(portal.committed[0], DEST_SCENE)


func test_portal_cutscene_without_host_aborts() -> void:
	var sunny := _make_sunny()
	var portal := RecordingPortal.new()
	portal.destination_scene = DEST_SCENE
	portal.transition_style = LevelPortal.Style.CUTSCENE
	portal.cutscene_id = &"door_open"
	portal.trigger_on_body = false
	portal.fade_layer = _make_fade()
	add_child_autofree(portal)

	assert_false(await portal.activate(sunny), "без постановщика переход отменяется")
	assert_true(sunny.input_enabled)
	assert_eq(portal.committed.size(), 0)
	assert_eq(portal.reported_errors.size(), 1)


func test_pending_spawn_is_consumed_only_by_matching_scene() -> void:
	LevelPortal.set_pending_spawn("res://scene_a.tscn", &"SpawnA")

	assert_eq(LevelPortal.peek_pending_spawn("res://scene_b.tscn"), &"")
	assert_eq(LevelPortal.take_pending_spawn("res://scene_b.tscn"), &"",
		"чужая сцена не забирает точку входа")
	assert_eq(LevelPortal.peek_pending_spawn("res://scene_a.tscn"), &"SpawnA")

	assert_eq(LevelPortal.take_pending_spawn("res://scene_a.tscn"), &"SpawnA")
	assert_eq(LevelPortal.peek_pending_spawn(), &"", "после чтения запрос очищен")


func test_sanctuary_wrapper_places_player_on_entrance_marker() -> void:
	var wrapper := _make_wrapper(SANCTUARY_SCENE)
	var sunny := wrapper.get_node("Sanctuary/Sunny") as SunnyController
	var spawn := wrapper.get_node("Sanctuary/Spawns/SanctuaryEntrance") as Node3D

	assert_not_null(sunny)
	assert_not_null(spawn)
	assert_lt(sunny.global_position.distance_to(spawn.global_position), 0.01,
		"Санни появляется в Spawns/SanctuaryEntrance, а не в старой позиции сцены")
	assert_true(sunny.input_enabled, "после загрузки управление включено")


func test_pilgrim_wrapper_applies_requested_spawn() -> void:
	LevelPortal.set_pending_spawn(PILGRIM_SCENE, &"AlcoveSeat")
	var wrapper := _make_wrapper(PILGRIM_SCENE)
	var sunny := wrapper.get_node("Sunny") as SunnyController
	var spawn := wrapper.get_node("PilgrimPath/Spawns/AlcoveSeat") as Node3D

	assert_not_null(sunny)
	assert_not_null(spawn)
	assert_lt(sunny.global_position.distance_to(spawn.global_position), 0.01,
		"запрошенная точка входа применена")
	assert_eq(LevelPortal.peek_pending_spawn(), &"", "запрос израсходован")


func test_caravan_wrapper_applies_requested_spawn() -> void:
	LevelPortal.set_pending_spawn(CAMP_SCENE, &"FireSeat")
	var wrapper := _make_wrapper(CAMP_SCENE)
	var sunny := wrapper.get_node("Sunny") as SunnyController
	var spawn := wrapper.get_node("CaravanSite/Spawns/FireSeat") as Node3D

	assert_not_null(sunny)
	assert_not_null(spawn)
	assert_lt(sunny.global_position.distance_to(spawn.global_position + Vector3(0, 0.05, 0)), 0.01,
		"лагерь тоже принимает именованную точку входа")
	assert_eq(LevelPortal.peek_pending_spawn(), &"", "запрос израсходован")


func test_pass_wrapper_falls_back_to_chain_for_unknown_spawn() -> void:
	LevelPortal.set_pending_spawn(PASS_SCENE, &"MissingSpawn")
	var wrapper := _make_wrapper(PASS_SCENE)
	var sunny := wrapper.get_node("Sunny") as SunnyController
	var chain := wrapper.get_node("CaravanRoad/Spawns/Chain") as Node3D

	assert_not_null(sunny)
	assert_not_null(chain)
	assert_lt(sunny.global_position.distance_to(chain.global_position + Vector3(0, 0.05, 0)), 0.01,
		"неизвестный spawn не оставляет игрока в случайной позиции")
	assert_eq(LevelPortal.peek_pending_spawn(), &"", "запрос израсходован")


func test_pilgrim_temple_transition_starts_once() -> void:
	var wrapper := _make_wrapper(PILGRIM_SCENE)
	watch_signals(wrapper)

	wrapper._handle_temple()
	wrapper._handle_temple()
	await wait_process_frames(1)

	assert_true(wrapper.has_started_transition())
	assert_signal_emit_count(wrapper, "transition_started", 1, "переход к храму не дублируется")
	assert_false((wrapper.get_node("Sunny") as SunnyController).input_enabled)


func test_camp_dawn_transition_starts_once() -> void:
	var wrapper := _make_wrapper(CAMP_SCENE)
	watch_signals(wrapper)

	wrapper._handle_dawn()
	wrapper._handle_dawn()
	await wait_process_frames(1)

	assert_true(wrapper.has_started_transition())
	assert_signal_emit_count(wrapper, "transition_started", 1, "рассветный переход не дублируется")


func test_sanctuary_trial_transition_starts_once() -> void:
	var wrapper := _make_wrapper(SANCTUARY_SCENE)
	watch_signals(wrapper)

	wrapper._on_trial_finished()
	wrapper._on_trial_finished()
	await wait_process_frames(1)

	assert_true(wrapper.is_completed())
	assert_signal_emit_count(wrapper, "transition_started", 1, "переход к оценке не дублируется")


func test_campaign_start_clears_stale_pending_spawn() -> void:
	LevelPortal.set_pending_spawn("res://stale_scene.tscn", &"Stale")
	var entry := (load(CAMPAIGN_ENTRY) as PackedScene).instantiate() as Node3D
	entry.autostart = false
	add_child_autofree(entry)

	entry.start()
	assert_eq(LevelPortal.peek_pending_spawn(), &"",
		"новый запуск кампании не наследует чужой spawn")
