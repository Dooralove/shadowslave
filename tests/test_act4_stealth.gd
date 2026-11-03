extends GutTest
## N21: шум, слепой Тиран, тени и исключение колокольчика.

const LOCATION_SCENE := "res://scenes/locations/pilgrim_path/pilgrim_path.tscn"
const WRAPPER_SCENE := "res://scenes/campaign/pilgrim_path_arrival.tscn"


func before_each() -> void:
	NightmareRunState.reset()


func after_each() -> void:
	NightmareRunState.reset()


func _make_location() -> PilgrimPath:
	var site := (load(LOCATION_SCENE) as PackedScene).instantiate() as PilgrimPath
	add_child_autofree(site)
	await wait_physics_frames(1)
	return site


func _make_player(site: PilgrimPath, position: Vector3) -> Node3D:
	var player := Node3D.new()
	player.name = "FakeSunny"
	site.add_child(player)
	player.global_position = position
	return player


func _make_fast_wrapper() -> Node3D:
	var wrapper := (load(WRAPPER_SCENE) as PackedScene).instantiate() as Node3D
	for property in [&"fade_in", &"transition_enabled"]:
		for entry in wrapper.get_property_list():
			if StringName(entry.get("name", "")) == property:
				wrapper.set(property, false)
				break
	for entry in wrapper.get_property_list():
		if StringName(entry.get("name", "")) == &"fast_mode":
			wrapper.set(&"fast_mode", true)
			break
	add_child_autofree(wrapper)
	await wait_physics_frames(1)
	return wrapper


func _start(position := Vector3(2.0, 4.15, -58.0)) -> Dictionary:
	var site := await _make_location()
	var player := _make_player(site, position)
	var section := site.get_stealth()
	assert_not_null(section)
	if section == null:
		return {"site": site, "section": null, "player": player}
	NightmareRunState.set_flag(&"cave_escaped")
	site.begin_stealth(player)
	return {"site": site, "section": section, "player": player}


func test_noise_tres_has_radius_loudness_and_types() -> void:
	var site := await _make_location()
	var section := site.get_stealth()
	assert_not_null(section)
	if section == null:
		return
	var step := section.noise_system.get_event(&"step")
	var run := section.noise_system.get_event(&"run")
	var rockfall := section.noise_system.get_event(&"rockfall")
	var bell := section.noise_system.get_event(&"bell")
	assert_not_null(step)
	assert_not_null(run)
	assert_not_null(rockfall)
	assert_not_null(bell)
	if step == null or run == null or rockfall == null or bell == null:
		return
	assert_eq(step.radius, 3.0)
	assert_eq(step.loudness, 0.35)
	assert_eq(run.radius, 7.0)
	assert_eq(rockfall.radius, 11.0)
	assert_true(bell.is_bell, "колокольчик помечен как исключение")
	assert_eq(bell.radius, 18.0)
	assert_true(step.is_audible_from(Vector3(0, 4.15, -55), Vector3(2.9, 4.15, -55)))
	assert_false(step.is_audible_from(Vector3(0, 4.15, -55), Vector3(3.1, 4.15, -55)))


func test_blind_tyrant_hears_only_within_radius() -> void:
	var made := await _start()
	var section := made["section"] as StealthSection
	if section == null:
		return
	var tyrant := section.get_tyrant()
	assert_not_null(tyrant)
	assert_true(section.active)
	assert_true(tyrant.active)
	# В радиусе шага — реагирует и запоминает точку.
	section.emit_noise(&"step", Vector3(-0.8, 4.15, -54.8))
	assert_not_null(tyrant.last_event)
	assert_eq(tyrant.last_event.id, &"step")
	assert_almost_eq(tyrant.target_position.z, -54.8, 0.01)
	# За радиусом — событие есть, но Тиран его не слышит.
	tyrant.last_event = null
	section.emit_noise(&"step", Vector3(20.0, 4.15, -54.8))
	assert_null(tyrant.last_event)
	# Бег слышен дальше шага.
	section.emit_noise(&"run", Vector3(-0.8, 4.15, -49.9))
	assert_not_null(tyrant.last_event)
	assert_eq(tyrant.last_event.id, &"run")


func test_blind_tyrant_moves_toward_noise() -> void:
	var made := await _start(Vector3(2.0, 4.15, -58.0))
	var section := made["section"] as StealthSection
	if section == null:
		return
	var tyrant := section.get_tyrant()
	section.emit_noise(&"step", Vector3(-0.8, 4.15, -54.8))
	assert_not_null(tyrant.last_event)
	var distance_before := tyrant.visual.global_position.distance_to(tyrant.target_position)
	await wait_physics_frames(6)
	var distance_after := tyrant.visual.global_position.distance_to(tyrant.target_position)
	assert_lt(distance_after, distance_before, "Тиран идёт к услышанной точке")


func test_stone_throw_makes_rockfall_noise_at_a_chosen_point() -> void:
	var made := await _start(Vector3(1.0, 4.15, -54.5))
	var site := made["site"] as PilgrimPath
	var section := made["section"] as StealthSection
	if site == null or section == null:
		return
	var stone_point := Vector3(2.55, 4.15, -55.15)
	assert_true(site.throw_stealth_stone(stone_point))
	assert_true(NightmareRunState.has_flag(&"stealth_stone_used"))
	var tyrant := section.get_tyrant()
	assert_not_null(tyrant.last_event)
	assert_eq(tyrant.last_event.id, &"rockfall")
	assert_almost_eq(tyrant.target_position.x, stone_point.x, 0.01)
	assert_almost_eq(tyrant.target_position.z, stone_point.z, 0.01)
	assert_false(site.throw_stealth_stone(stone_point), "камень бросается один раз")


func test_shadow_hides_from_hero_but_not_from_tyrant() -> void:
	var made := await _start(Vector3(1.0, 4.15, -56.0))
	var section := made["section"] as StealthSection
	var player := made["player"] as Node3D
	if section == null or player == null:
		return
	var hidden_zone := section.get_shadow_zones()[0]
	player.global_position = hidden_zone.global_position
	section.call(&"_update_hidden")
	assert_true(section.is_player_hidden(), "в тени Санни скрыт от глаз")
	assert_false(section.is_player_visible_to_hero())

	player.global_position = Vector3(1.0, 4.15, -56.0)
	section.call(&"_update_hidden")
	section.hero.rotation.y = PI
	assert_false(section.is_player_hidden(), "вне тени Санни снова виден")
	assert_true(section.is_player_visible_to_hero(), "Герой смотрит на открытую цель")

	# Тень не спасает от слуха: Тиран всё равно слышит шум.
	player.global_position = hidden_zone.global_position
	section.call(&"_update_hidden")
	section.emit_noise(&"step", hidden_zone.global_position)
	assert_not_null(section.get_tyrant().last_event)


func test_bell_redirects_blind_tyrant_to_hero() -> void:
	var made := await _start()
	var section := made["section"] as StealthSection
	if section == null:
		return
	var tyrant := section.get_tyrant()
	var hero_position := section.hero.global_position
	assert_true(section.emit_bell_rescue(Vector3(2.5, 4.15, -57.0)))
	assert_true(section.bell_rescue)
	assert_not_null(tyrant)
	assert_eq(tyrant.last_event.id, &"bell")
	assert_almost_eq(tyrant.target_position.x, hero_position.x, 0.01)
	assert_almost_eq(tyrant.target_position.z, hero_position.z, 0.01)


func test_checkpoint_before_stealth_and_gate_to_hero() -> void:
	NightmareRunState.set_flag(&"cave_escaped")
	var wrapper := (load(WRAPPER_SCENE) as PackedScene).instantiate() as Node3D
	for property in [&"fade_in", &"transition_enabled"]:
		for entry in wrapper.get_property_list():
			if StringName(entry.get("name", "")) == property:
				wrapper.set(property, false)
				break
	for entry in wrapper.get_property_list():
		if StringName(entry.get("name", "")) == &"fast_mode":
			wrapper.set(&"fast_mode", true)
			break
	add_child_autofree(wrapper)
	await wait_physics_frames(1)
	var path := wrapper.get_node("PilgrimPath") as PilgrimPath
	var recovery := (wrapper.get_node("Sunny") as SunnyController).get_node("FallRecovery") as FallRecovery
	var trigger := path.get_trigger(&"hero") as TriggerZone
	assert_eq(recovery.get_checkpoint_id(), &"CP-N21a")
	assert_false(trigger.enabled, "до стелса проход к Герою закрыт")


func test_stealth_completion_unlocks_hero_after_cp_n21a() -> void:
	NightmareRunState.set_flag(&"cave_escaped")
	var wrapper := await _make_fast_wrapper()
	var path := wrapper.get_node("PilgrimPath") as PilgrimPath
	var sunny := wrapper.get_node("Sunny") as SunnyController
	var trigger := path.get_trigger(&"hero") as TriggerZone
	assert_false(trigger.enabled, "до финиша стелса проход закрыт")
	var stand := path.get_spawn(&"HeroStand") as Node3D
	sunny.global_position = stand.global_position
	await wait_physics_frames(3)
	assert_true(NightmareRunState.has_flag(&"stealth_completed"))
	assert_true(NightmareRunState.has_flag(&"hero_confrontation_seen"),
		"после завершения N21 запускается N22")


func test_tyrant_death_returns_to_cp_n21a_and_restarts_stealth() -> void:
	NightmareRunState.set_flag(&"cave_escaped")
	var wrapper := await _make_fast_wrapper()
	var path := wrapper.get_node("PilgrimPath") as PilgrimPath
	var sunny := wrapper.get_node("Sunny") as SunnyController
	assert_true(path.get_stealth().active)
	sunny.global_position = Vector3(0.0, 4.15, -58.0)
	wrapper.call(&"_handle_stealth_caught")
	var cp := (sunny.get_node("FallRecovery") as FallRecovery).recovery_point()
	assert_lt(sunny.global_position.distance_to(cp), 0.05, "возврат на CP-N21a")
	assert_true(path.get_stealth().active, "после возврата стелс снова активен")


func test_tyrant_catch_stops_section() -> void:
	var made := await _start()
	var section := made["section"] as StealthSection
	var player := made["player"] as Node3D
	if section == null or player == null:
		return
	watch_signals(section)
	player.global_position = section.get_tyrant().visual.global_position
	await wait_physics_frames(2)
	assert_false(section.active, "контакт с Тираном завершает стелс")
	assert_signal_emitted(section, "tyrant_caught")


func test_cave_staging_has_short_flashback_and_wounded_state() -> void:
	var wrapper := await _make_fast_wrapper()
	var path := wrapper.get_node("PilgrimPath") as PilgrimPath
	assert_null(path.get_interactable(&"cave"), "пещера не открывается E-точкой")
	await wrapper.call(&"_handle_cave")
	assert_true(NightmareRunState.has_flag(&"bloodbane_flashback_seen"))
	assert_true(NightmareRunState.has_flag(&"wound_taken"))
	var sunny := wrapper.get_node("Sunny") as SunnyController
	assert_true(sunny.is_wounded(), "после удара Санни ранен")
	var feedback := sunny.get_node("ConditionFeedback") as ConditionFeedback
	assert_not_null(feedback)
	if feedback != null:
		assert_gt(feedback.cold, 0.0, "дыхание/виньетка включены")


func test_wounded_state_slows_and_dims_but_does_not_start_combat() -> void:
	NightmareRunState.set_flag(&"wound_taken")
	var wrapper := await _make_fast_wrapper()
	var sunny := wrapper.get_node("Sunny") as SunnyController
	assert_true(sunny.is_wounded())
	sunny.set_wounded(false)
	var base_walk := sunny.walk_speed
	sunny.set_wounded(true)
	var walking := sunny.walk_speed
	assert_lt(walking, base_walk, "раненый идёт медленнее")
	assert_false(sunny.combat_enabled, "на подъёме нет боя")
	assert_false(sunny.allow_sprint, "бег отключён ранением")
	var feedback := sunny.get_node("ConditionFeedback") as ConditionFeedback
	assert_not_null(feedback)
	if feedback != null:
		assert_gt(feedback.cold, 0.0)
		assert_gt(feedback.noise, 0.0)
		assert_false(feedback.get_vignette() == null)
	sunny.set_wounded(false)
	assert_false(sunny.is_wounded())
	assert_almost_eq(sunny.walk_speed, base_walk, 0.01)
