extends GutTest
## Структурная проверка первого greybox-фрагмента Лабиринта.
##
## Проверяет сборку сцены, разделение Generated/Visual и Generated/Collision,
## наличие зон, точек входа, порталов, ракурсов, прилива и опорных точек
## маршрута. Это не заменяет ручной проход: визуальная проверка — отдельно.

const SCENE_PATH := "res://scenes/locations/forgotten_shore_labyrinth/labyrinth_first_fragment.tscn"

const ZONES := [
	&"Z01_Threshold",
	&"Z02_Carcass",
	&"Z03_FirstFork",
	&"Z04_MudHollow",
	&"Z05_BonePassage",
	&"Z06_DryPocket",
	&"Z07_ScoutRidge",
	&"Z08_Clearing",
	&"Z09_BlindTunnel",
	&"Z10_CoralHill",
	&"Z11_TideChannel",
	&"Z12_Isthmus",
	&"Z13_HuntingGrounds",
	&"Z14_BoneBridge",
	&"Z15_HighRefuge",
	&"Z16_PackTerritory",
	&"Z17_StormRun",
	&"Z18_Cliffs",
]

const SPAWNS := [
	&"Start",
	&"FromDescent",
	&"Camp",
	&"CampReturn",
	&"Refuge",
	&"RefugeReturn",
	&"BoneBridge",
	&"StormStart",
	&"CliffBase",
	&"CliffTop",
]

const SHOTS := [
	&"OverviewEast",
	&"OverviewWest",
	&"Entrance",
	&"Carcass",
	&"Fork",
	&"Mud",
	&"Bone",
	&"Ridge",
	&"Clearing",
	&"Camp",
	&"Channel",
	&"Hunting",
	&"Bridge",
	&"Refuge",
	&"Pack",
	&"Storm",
	&"Cliffs",
]

const WAYPOINTS := [
	Vector3(28, 0.2, 0),
	Vector3(19, -1.3, 26),
	Vector3(6, 0.2, 6),
	Vector3(-30, -2.8, -42),
	Vector3(-30, 0.2, 21),
	Vector3(-47, 6.2, 46),
	Vector3(-25, 7.2, -55),
	Vector3(-60, 0.2, 5),
	Vector3(-70, 0.2, 20),
	Vector3(-100, 18.2, -5),
	Vector3(-137, 6.2, -20),
	Vector3(-175, 0.2, 0),
	Vector3(-375, 0.2, 0),
	Vector3(-600, 6.2, 0),
	Vector3(-700, 18.2, -20),
	Vector3(-900, 0.2, 0),
	Vector3(-1175, 8.2, 0),
	Vector3(-1400, 35.2, 0),
]


func _instantiate() -> LabyrinthGreybox:
	var packed := load(SCENE_PATH) as PackedScene
	assert_not_null(packed, "сцена загружается")
	if packed == null:
		return null
	var location := packed.instantiate() as LabyrinthGreybox
	assert_not_null(location, "корень использует LabyrinthGreybox")
	if location == null:
		return null
	# Структурный тест не должен поднимать боевой слой и трогать QuestSystem.
	location.set(&"enable_demo_gameplay", false)
	var director := location.get_node_or_null(^"Gameplay/QuestDirector")
	if director != null:
		director.set(&"enable_gameplay", false)
	add_child_autofree(location)
	await get_tree().process_frame
	await get_tree().physics_frame
	return location


func test_scene_builds_and_separates_layers() -> void:
	var location := await _instantiate()
	if location == null:
		return
	assert_gt(location.module_count(), 100, "собрано достаточно модулей")
	assert_not_null(location.get_node_or_null(^"Generated/Visual"), "есть Generated/Visual")
	assert_not_null(location.get_node_or_null(^"Generated/Collision"), "есть Generated/Collision")
	assert_not_null(location.get_node_or_null(^"Generated/Lights"), "есть Generated/Lights")
	assert_not_null(location.get_node_or_null(^"Generated/Labels"), "есть Generated/Labels")
	for zone in ZONES:
		assert_not_null(location.get_node_or_null(NodePath("Generated/Visual/%s" % zone)), "есть визуальная группа %s" % zone)
		assert_not_null(location.get_node_or_null(NodePath("Generated/Collision/%s" % zone)), "есть коллизия %s" % zone)


func test_spawns_portals_shots_and_landmarks() -> void:
	var location := await _instantiate()
	if location == null:
		return
	for spawn in SPAWNS:
		assert_not_null(location.get_spawn(spawn), "есть Spawns/%s" % spawn)
	for shot in SHOTS:
		assert_not_null(location.get_node_or_null(NodePath("Shots/%s" % shot)), "есть Shots/%s" % shot)
	assert_not_null(location.get_node_or_null(^"Portals/ToDescent"), "есть портал возврата")
	var to_descent := location.get_node_or_null(^"Portals/ToDescent") as LevelPortal
	assert_not_null(to_descent)
	if to_descent != null:
		assert_eq(to_descent.destination_scene, "res://scenes/locations/post_nightmare/tide_descent.tscn", "портал ведёт в tide_descent")
		assert_eq(to_descent.destination_spawn, &"FromCoral", "портал ведёт на FromCoral")
	var to_west := location.get_node_or_null(^"Portals/ToWest") as LevelPortal
	assert_not_null(to_west, "есть западный портал")
	if to_west != null:
		assert_false(to_west.enabled, "западный портал выключен: финал идёт через FinalZone")
		assert_eq(
			to_west.destination_scene,
			"res://scenes/campaign/post_nightmare_finale.tscn",
			"западный портал ведёт в финальную карточку"
		)
	assert_not_null(location.get_node_or_null(^"Gameplay/Triggers/FinalZone"), "есть FinalZone Z18")
	assert_not_null(location.get_node_or_null(^"Gameplay/Triggers/DemoEndZone"), "есть DemoEndZone Z10")
	for landmark in [&"Statue", &"CampPillar", &"WesternSpire", &"BoneBridge", &"StormWall", &"Cliffs"]:
		var node := location.get_node_or_null(NodePath("Landmarks/%s" % landmark)) as Node3D
		assert_not_null(node, "есть ориентир %s" % landmark)
		if node != null:
			assert_gt(node.get_child_count(), 0, "ориентир %s собран" % landmark)


func test_tide_nodes_exist() -> void:
	var location := await _instantiate()
	if location == null:
		return
	assert_not_null(location.get_node_or_null(^"Tide/WaterPlane"), "есть вода")
	assert_not_null(location.get_node_or_null(^"Tide/TideController"), "есть TideController")
	var gates := get_tree().get_nodes_in_group(&"tide_gate")
	assert_gt(gates.size(), 0, "есть приливные шлюзы")


func test_tide_cycle_opens_and_closes_gates() -> void:
	var location := await _instantiate()
	if location == null:
		return
	var water := location.get_node_or_null(^"Tide/WaterPlane") as MeshInstance3D
	var tide := location.get_node_or_null(^"Tide/TideController")
	assert_not_null(water)
	assert_not_null(tide)
	if water == null or tide == null:
		return
	await get_tree().process_frame
	tide.set_phase(0.5)
	await get_tree().process_frame
	assert_gt(water.position.y, 2.0, "высокая вода поднята")
	var gates := get_tree().get_nodes_in_group(&"tide_gate")
	assert_gt(gates.size(), 0, "шлюзы существуют")
	for gate in gates:
		assert_eq((gate as StaticBody3D).collision_layer, 1, "шлюз закрыт при высокой воде")
	tide.set_phase(0.0)
	await get_tree().process_frame
	assert_lt(water.position.y, -4.0, "низкая вода опущена")
	for gate in gates:
		assert_eq((gate as StaticBody3D).collision_layer, 0, "шлюз открыт при низкой воде")


func test_rebuild_is_repeatable() -> void:
	var location := await _instantiate()
	if location == null:
		return
	var before := location.module_count()
	location.rebuild()
	await get_tree().process_frame
	assert_eq(location.module_count(), before, "повторная сборка даёт тот же набор модулей")
	assert_not_null(location.get_spawn(&"Start"), "Spawns не теряются при пересборке")
	assert_not_null(location.get_node_or_null(^"Landmarks/Statue"), "Landmarks не теряются при пересборке")


func test_player_starts_on_floor() -> void:
	var location := await _instantiate()
	if location == null:
		return
	var player := location.get_node_or_null(^"Player") as SunnyController
	assert_not_null(player, "есть игрок")
	if player == null:
		return
	var landed := false
	for i in 60:
		await get_tree().physics_frame
		if player.is_on_floor():
			landed = true
			break
	assert_true(landed, "игрок стоит на входном карнизе")
	assert_gt(player.global_position.y, 0.0, "игрок не провалился")


func test_walk_up_entry_stairs() -> void:
	var location := await _instantiate()
	if location == null:
		return
	var player := location.get_node_or_null(^"Player") as SunnyController
	assert_not_null(player)
	if player == null:
		return
	player.global_position = Vector3(28, 0.2, 0)
	player.velocity = Vector3.ZERO
	# Останавливаемся до портала ToDescent (x=41), чтобы не менять сцену.
	for i in 600:
		player.forced_velocity = Vector3(5.0, 0, 0)
		await get_tree().physics_frame
		if player.global_position.x > 37.2:
			break
	player.forced_velocity = Vector3.ZERO
	assert_gt(player.global_position.x, 36.0, "игрок поднялся по входной рампе")
	assert_gt(player.global_position.y, 5.0, "игрок на верхнем карнизе")


func test_walk_down_entry_stairs_into_fork() -> void:
	var location := await _instantiate()
	if location == null:
		return
	var player := location.get_node_or_null(^"Player") as SunnyController
	assert_not_null(player)
	if player == null:
		return
	player.global_position = Vector3(38, 6.2, 0)
	player.velocity = Vector3.ZERO
	for i in 600:
		player.forced_velocity = Vector3(-5.0, 0, 0)
		await get_tree().physics_frame
	player.forced_velocity = Vector3.ZERO
	assert_lt(player.global_position.x, 5.0, "игрок прошёл от карниза к развилке")
	assert_lt(player.global_position.y, 1.0, "игрок спустился на пол развилки")


func _walk_to(player: SunnyController, target: Vector3, speed: float, max_frames: int) -> bool:
	for i in max_frames:
		var delta := target - player.global_position
		var flat := Vector2(delta.x, delta.z)
		if flat.length() < 1.0 and absf(delta.y) < 1.4:
			player.forced_velocity = Vector3.ZERO
			return true
		if player.global_position.y < -20.0:
			break
		if flat.length() > 0.01:
			player.forced_velocity = Vector3(flat.x, 0.0, flat.y).normalized() * speed
		await get_tree().physics_frame
	player.forced_velocity = Vector3.ZERO
	return false


func test_walk_camp_to_west_ledge() -> void:
	var location := await _instantiate()
	if location == null:
		return
	var player := location.get_node_or_null(^"Player") as SunnyController
	assert_not_null(player)
	if player == null:
		return
	player.global_position = Vector3(-100, 18.2, -5)
	player.velocity = Vector3.ZERO
	player.forced_velocity = Vector3.ZERO
	for i in 3:
		await get_tree().physics_frame
	assert_true(await _walk_to(player, Vector3(-112, 18.2, -4), 5.0, 300), "обход столба на вершине")
	assert_true(await _walk_to(player, Vector3(-112, 18.2, -10), 5.0, 300), "выход к западному спуску")
	assert_true(await _walk_to(player, Vector3(-128, 12.2, -5), 7.0, 400), "западный спуск, отрезок 2")
	assert_true(await _walk_to(player, Vector3(-125, 6.2, -20), 7.0, 400), "западный спуск, отрезок 1")
	assert_true(await _walk_to(player, Vector3(-145, 6.2, -20), 7.0, 400), "верхний карниз канала")
	assert_lt(player.global_position.x, -135.0, "игрок дошёл до канала")


func test_walk_ridge_to_storm_high_route() -> void:
	var location := await _instantiate()
	if location == null:
		return
	var player := location.get_node_or_null(^"Player") as SunnyController
	assert_not_null(player)
	if player == null:
		return
	player.global_position = Vector3(-1050, 6.2, 85)
	player.velocity = Vector3.ZERO
	player.forced_velocity = Vector3.ZERO
	for i in 3:
		await get_tree().physics_frame
	assert_true(await _walk_to(player, Vector3(-1050, 6.2, 80), 5.0, 300), "разрыв парапета гребня")
	assert_true(await _walk_to(player, Vector3(-1050, 8.2, 0), 8.0, 900), "длинная лестница гребень — гроза")
	assert_true(await _walk_to(player, Vector3(-1070, 8.2, 0), 6.0, 300), "выход на высокую тропу грозы")
	assert_gt(player.global_position.y, 7.0, "игрок на высокой тропе")


func test_walk_z10_climb() -> void:
	var location := await _instantiate()
	if location == null:
		return
	var player := location.get_node_or_null(^"Player") as SunnyController
	assert_not_null(player)
	if player == null:
		return
	player.global_position = Vector3(-85, 1.2, 20)
	player.velocity = Vector3.ZERO
	player.forced_velocity = Vector3.ZERO
	for i in 3:
		await get_tree().physics_frame
	assert_true(await _walk_to(player, Vector3(-105, 18.2, 20), 8.0, 1200), "подъём на коралловый холм")
	assert_gt(player.global_position.y, 17.0, "игрок на вершине холма")


func test_waypoint_floors() -> void:
	var location := await _instantiate()
	if location == null:
		return
	var player := location.get_node_or_null(^"Player") as SunnyController
	assert_not_null(player)
	if player == null:
		return
	for point in WAYPOINTS:
		player.global_position = point
		player.velocity = Vector3.ZERO
		for i in 30:
			await get_tree().physics_frame
		assert_true(player.is_on_floor(), "пол есть в точке %s" % str(point))
		assert_gt(player.global_position.y, -8.0, "игрок не в воде в точке %s" % str(point))


func test_route_transitions() -> void:
	var location := await _instantiate()
	if location == null:
		return
	var player := location.get_node_or_null(^"Player") as SunnyController
	assert_not_null(player)
	if player == null:
		return
	var points := [
		Vector3(30, 0.2, 0),
		Vector3(-10, 0.2, -7),
		Vector3(-15, 0.2, -12),
		Vector3(-20, -2.8, -35),
		Vector3(-45, -2.8, -30),
		Vector3(-50, 0.2, -15),
		Vector3(-10, 0.2, 7),
		Vector3(-15, 0.2, 15),
		Vector3(-30, 0.2, 21),
		Vector3(-45, 0.2, 20),
		Vector3(-50, 0.2, 15),
		Vector3(-35, 0.2, 30),
		Vector3(-50, 0.2, 30),
		Vector3(-50, 6.2, 40),
		Vector3(-47, 6.2, 46),
		Vector3(0, 7.2, -50),
		Vector3(-25, 7.2, -55),
		Vector3(-50, 7.2, -48),
		Vector3(-55, 0.2, -20),
		Vector3(-55, 0.2, 20),
		Vector3(-70, 0.2, 20),
		Vector3(-85, 0.2, 20),
		Vector3(-85, 0.2, 20),
		Vector3(-95, 1.2, 10),
		Vector3(-85, 1.2, 0),
		Vector3(-105, 18.2, 20),
		Vector3(-105, 18.2, -10),
		Vector3(-110, 18.2, -10),
		Vector3(-120, 15.6, -7.5),
		Vector3(-125, 6.2, -20),
		Vector3(-137, 6.2, -20),
		Vector3(-153, 5.2, -20),
		Vector3(-137, -0.8, 0),
		Vector3(-153, 0.2, 0),
		Vector3(-175, 5.2, -20),
		Vector3(-175, 0.2, 0),
		Vector3(-204, 5.2, -20),
		Vector3(-204, 5.2, -90),
		Vector3(-375, 5.2, -90),
		Vector3(-375, 0.2, 0),
		Vector3(-375, -1.8, 90),
		Vector3(-535, 0.2, 0),
		Vector3(-535, 0.2, 18),
		Vector3(-540, 0.2, 0),
		Vector3(-550, 6.2, 0),
		Vector3(-600, 6.2, 0),
		Vector3(-650, 6.2, 0),
		Vector3(-660, 2.2, 0),
		Vector3(-700, 18.2, -20),
		Vector3(-650, 2.2, -20),
		Vector3(-750, 2.2, -20),
		Vector3(-800, 0.2, -20),
		Vector3(-800, 6.2, 85),
		Vector3(-900, 6.2, 90),
		Vector3(-1050, 0.2, 0),
		Vector3(-1050, 6.2, 85),
		Vector3(-1070, 8.2, 0),
		Vector3(-1175, 8.2, 0),
		Vector3(-1300, 8.2, 0),
		Vector3(-1320, 6.2, 0),
		Vector3(-1335, 11.5, 10),
		Vector3(-1365, 21.6, 5),
		Vector3(-1390, 31.1, -5),
		Vector3(-1400, 35.2, 0),
		Vector3(-1410, 35.2, 0),
	]
	for point in points:
		player.global_position = point
		player.velocity = Vector3.ZERO
		for i in 50:
			await get_tree().physics_frame
		assert_true(player.is_on_floor(), "переход: пол есть в точке %s" % str(point))
		assert_gt(player.global_position.y, -8.0, "переход: игрок не в воде в точке %s" % str(point))


func test_carcass_crab_placeholders_are_hidden() -> void:
	var location := await _instantiate()
	if location == null:
		return
	await wait_process_frames(3)
	var carcass := location.get_node_or_null(^"Generated/Visual/Z02_Carcass")
	assert_not_null(carcass, "Z02_Carcass zone exists")
	if carcass == null:
		return
	var crabs := carcass.find_children("Z02_Crab*", "", true, false)
	assert_gt(crabs.size(), 0, "greybox crab placeholders exist before art pass")
	for node in crabs:
		assert_false(node.is_visible_in_tree(), "crab placeholder hidden: %s" % node.name)
