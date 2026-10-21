extends GutTest
## Локации среза: загрузка, точки появления, ракурсы, взаимодействия и триггеры, которых ждёт режиссёр.

const REQUIRED_SPAWNS := {
	&"park": [&"BenchSit", &"BenchStand", &"BinThrow", &"PickSpot"],
	&"lobby": [&"Counter"],
	&"containment": [&"Chair"],
	&"void": [&"Center"],
	&"mountain": [&"Viewpoint"],
	&"caravan": [&"Chain"],
}
const REQUIRED_SHOTS := {
	&"park": [&"BenchShot", &"DozeShot"],
	&"lobby": [&"DeskShot", &"AlarmShot"],
	&"containment": [&"RoomShot", &"DoorShot"],
	&"mountain": [&"Orbit", &"RoadShot"],
}


func _spawn(key: StringName) -> SliceLocation:
	var location := (load(SliceDirector.LOCATIONS[key]) as PackedScene).instantiate() as SliceLocation
	add_child_autofree(location)
	return location


func test_every_location_loads_as_slice_location() -> void:
	for key in SliceDirector.LOCATIONS:
		var location := _spawn(key)
		assert_not_null(location, "%s — SliceLocation" % key)


func test_required_spawns() -> void:
	for key in REQUIRED_SPAWNS:
		var location := _spawn(key)
		for spawn in REQUIRED_SPAWNS[key]:
			assert_not_null(location.get_spawn(spawn), "%s: точка %s" % [key, spawn])


func test_shots_look_at_their_targets() -> void:
	for key in REQUIRED_SHOTS:
		var location := _spawn(key)
		for shot_name in REQUIRED_SHOTS[key]:
			var camera := location.shot(shot_name)
			assert_not_null(camera, "%s: ракурс %s" % [key, shot_name])
			if camera == null:
				continue
			var target := (camera.get_node(^"LookAt") as Node3D).global_position
			var forward := -camera.global_basis.z
			var to_target := (target - camera.global_position).normalized()
			assert_almost_eq(forward.dot(to_target), 1.0, 0.001, "%s: %s смотрит на LookAt" % [key, shot_name])


func test_park_interactions_and_trigger() -> void:
	var park := _spawn(&"park")
	for id in [&"coffee", &"bin", &"station_door"]:
		var interactable := park.get_interactable(id)
		assert_not_null(interactable, "точка %s" % id)
		if interactable:
			assert_false(interactable.enabled, "%s включает сценарий" % id)
	var trigger := park.get_trigger(&"station_entrance")
	assert_not_null(trigger)
	assert_false(trigger.enabled)
	assert_eq(trigger.collision_mask, 2, "триггер видит слой игрока")


func test_coffee_reachable_from_bench() -> void:
	var park := _spawn(&"park")
	var seat := park.get_spawn(&"BenchSit").global_position + Vector3(0, 0.9, 0)
	var coffee := park.get_interactable(&"coffee")
	coffee.enabled = true
	assert_true(coffee.can_interact_from(seat), "кофе достаётся, не вставая")
	var door := park.get_interactable(&"station_door")
	door.enabled = true
	assert_false(door.can_interact_from(seat), "до участка надо дойти")


func test_location_signals_are_forwarded() -> void:
	var park := _spawn(&"park")
	watch_signals(park)
	var coffee := park.get_interactable(&"coffee")
	coffee.enabled = true
	coffee.interact()
	assert_signal_emitted_with_parameters(park, "interacted", [&"coffee"])
	var trigger := park.get_trigger(&"station_entrance")
	trigger.enabled = true
	trigger.fire()
	assert_signal_emitted_with_parameters(park, "triggered", [&"station_entrance"])


func test_caravan_march_goes_uphill() -> void:
	var caravan := _spawn(&"caravan")
	var march := caravan.march_velocity()
	assert_almost_eq(march.length(), caravan.march_speed, 0.001)
	assert_lt(march.z, 0.0, "вперёд по дороге")
	assert_gt(march.y, 0.0, "вверх по склону")


func test_march_is_zero_elsewhere() -> void:
	assert_eq(_spawn(&"park").march_velocity(), Vector3.ZERO)
