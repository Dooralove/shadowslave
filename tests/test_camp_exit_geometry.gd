extends GutTest
## Геометрия выхода из лагеря: южная дорога к DawnExit и края площадки.
##
## Движение идёт через физику: Санни толкается forced_velocity на несколько кадров,
## как обычное управление. Точки не телепортируются, падение проверяется по высоте.

const CAMP_ARRIVAL := "res://scenes/campaign/caravan_site_arrival.tscn"
const FLOOR_LIMIT_Y := -0.5
const EXIT_RADIUS := 2.4


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


## Ставит Санни в точку и толкает его скоростью на заданное число физических кадров.
func _push(sunny: SunnyController, from: Vector3, velocity: Vector3, frames: int) -> void:
	sunny.clear_chain_restraint()
	sunny.global_position = from
	sunny.velocity = Vector3.ZERO
	sunny.forced_velocity = velocity
	await wait_physics_frames(frames)
	sunny.forced_velocity = Vector3.ZERO


func test_road_to_exit_is_walkable_without_falling() -> void:
	var wrapper := _spawn_wrapper()
	var sunny := wrapper.get_node("Sunny") as SunnyController
	var site := wrapper.get_node("CaravanSite") as CaravanSite
	await wait_physics_frames(3)
	var exit_point := site.get_interactable(&"dawn_exit")
	assert_not_null(exit_point, "точка выхода существует")

	await _push(sunny, Vector3(0.0, 0.05, 4.2), Vector3(0.0, 0.0, 2.2), 90)
	assert_gt(sunny.global_position.y, FLOOR_LIMIT_Y, "путь по дороге не ведёт в пустоту")
	assert_gt(sunny.global_position.z, 6.0, "Санни доходит до дороги у выхода")
	assert_lt(Vector2(sunny.global_position.x, sunny.global_position.z).distance_to(Vector2(0.0, 6.2)), EXIT_RADIUS,
		"точка выхода достижима обычным движением")


func test_pushing_sideways_off_road_is_blocked() -> void:
	var wrapper := _spawn_wrapper()
	var sunny := wrapper.get_node("Sunny") as SunnyController
	await wait_physics_frames(3)

	await _push(sunny, Vector3(0.0, 0.05, 7.0), Vector3(3.0, 0.0, 0.0), 60)
	assert_gt(sunny.global_position.y, FLOOR_LIMIT_Y, "с дороги в сторону не падают")
	assert_lt(sunny.global_position.x, 2.0, "боковой барьер удерживает на дороге")
	assert_gt(sunny.global_position.z, 6.0, "Санни не возвращён respawn-страховкой к костру")


func test_pushing_west_along_south_edge_is_blocked() -> void:
	var wrapper := _spawn_wrapper()
	var sunny := wrapper.get_node("Sunny") as SunnyController
	await wait_physics_frames(3)

	await _push(sunny, Vector3(-3.0, 0.05, 5.0), Vector3(0.0, 0.0, 3.0), 60)
	assert_gt(sunny.global_position.y, FLOOR_LIMIT_Y, "южный край площадки не даёт упасть")
	assert_lt(sunny.global_position.z, 5.6, "южная граница удерживает у площадки")
	assert_gt(sunny.global_position.z, 4.5, "Санни не возвращён respawn-страховкой к костру")


func test_road_south_end_is_blocked() -> void:
	var wrapper := _spawn_wrapper()
	var sunny := wrapper.get_node("Sunny") as SunnyController
	await wait_physics_frames(3)

	await _push(sunny, Vector3(0.0, 0.05, 7.5), Vector3(0.0, 0.0, 3.0), 90)
	assert_gt(sunny.global_position.y, FLOOR_LIMIT_Y, "дальний конец дороги не даёт упасть")
	assert_lt(sunny.global_position.z, 9.2, "конец дороги удерживает Санни")
	assert_gt(sunny.global_position.z, 7.0, "Санни не возвращён respawn-страховкой к костру")
