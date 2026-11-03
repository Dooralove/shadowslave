extends GutTest
## Прототипы локаций после Первого Кошмара: сцены собираются, модули
## регистрируются, точки появления и ракурсы на месте, карты связаны сценами.

const ATLAS_PATH := "res://resources/map/map_atlas.tres"

const LOCATIONS := [
	{
		"id": &"police_precinct",
		"scene": "res://scenes/locations/post_nightmare/police_precinct.tscn",
		"map": "res://resources/map/locations/police_precinct.tres",
		"modules": [&"IntakeHall", &"CellBlock", &"Interrogation", &"ReceptionCounter"],
	},
	{
		"id": &"academy_approach",
		"scene": "res://scenes/locations/post_nightmare/academy_approach.tscn",
		"map": "res://resources/map/locations/academy_approach.tres",
		"modules": [&"ApproachRoad", &"DropOffPlaza", &"CheckpointPlaza", &"CheckpointWallWest", &"GuardBooth", &"JettCar"],
	},
	{
		"id": &"academy_gate",
		"scene": "res://scenes/locations/post_nightmare/academy_gate.tscn",
		"map": "res://resources/map/locations/academy_gate.tres",
		"modules": [&"GateTowerWest", &"GateTowerEast", &"InnerRoad", &"AcademyFacade"],
	},
	{
		"id": &"academy_campus",
		"scene": "res://scenes/locations/post_nightmare/academy_campus.tscn",
		"map": "res://resources/map/locations/academy_campus.tres",
		"modules": [&"CampusPath", &"CampusSouthPlaza", &"GalleryRoof", &"Wing-1.0", &"SleeperFacadeWest"],
	},
	{
		"id": &"academy_sleeper_center",
		"scene": "res://scenes/locations/post_nightmare/academy_sleeper_center.tscn",
		"map": "res://resources/map/locations/academy_sleeper_center.tres",
		"modules": [&"Dormitory", &"EntryVestibule", &"CommonRoom", &"ShowerHall", &"Observation", &"DreamWard"],
	},
	{
		"id": &"black_sea_platform",
		"scene": "res://scenes/locations/post_nightmare/black_sea_platform.tscn",
		"map": "res://resources/map/locations/black_sea_platform.tres",
		## Колосс теперь hero-ассет StatueKnightLOD: primitive-модули шеи,
		## плеч, нагрудника и меча больше не строятся. Проверяем реальные
		## модули сцены и отдельно — сам ассет статуи.
		"modules": [&"DistantReef", &"DescentLedge"],
	},
	{
		"id": &"tide_descent",
		"scene": "res://scenes/locations/post_nightmare/tide_descent.tscn",
		"map": "res://resources/map/locations/tide_descent.tres",
		"modules": [&"TopLanding", &"TideStairs", &"ShoulderSlopeWest", &"ArmMassEast", &"BottomLanding", &"BottomGatePostWest"],
	},
	{
		"id": &"coral_labyrinth",
		"scene": "res://scenes/locations/post_nightmare/coral_labyrinth.tscn",
		"map": "res://resources/map/locations/coral_labyrinth.tres",
		"modules": [&"Entrance", &"Hub", &"Shrine", &"EastChamber", &"WestChamber", &"SecretChamber", &"TideLandingFloor"],
	},
]

## Канонический маршрут и обратные связи. Каждая строка проверяет один
## LevelPortal: откуда, через какой узел, куда и в какой Spawns/<name>.
const TRANSITIONS := [
	["res://scenes/locations/post_nightmare/police_precinct.tscn", &"ToAcademyApproach", "res://scenes/locations/post_nightmare/academy_approach.tscn", &"FromPrecinct"],
	["res://scenes/locations/post_nightmare/academy_approach.tscn", &"ToAcademyGate", "res://scenes/locations/post_nightmare/academy_gate.tscn", &"FromApproach"],
	["res://scenes/locations/post_nightmare/academy_approach.tscn", &"ToPrecinct", "res://scenes/locations/post_nightmare/police_precinct.tscn", &"FromApproach"],
	["res://scenes/locations/post_nightmare/academy_gate.tscn", &"ToApproach", "res://scenes/locations/post_nightmare/academy_approach.tscn", &"FromGate"],
	["res://scenes/locations/post_nightmare/academy_gate.tscn", &"ToCampus", "res://scenes/locations/post_nightmare/academy_campus.tscn", &"FromGate"],
	["res://scenes/locations/post_nightmare/academy_campus.tscn", &"ToGate", "res://scenes/locations/post_nightmare/academy_gate.tscn", &"FromCampus"],
	["res://scenes/locations/post_nightmare/academy_campus.tscn", &"ToSleeper", "res://scenes/locations/post_nightmare/academy_sleeper_center.tscn", &"FromCampus"],
	["res://scenes/locations/post_nightmare/academy_sleeper_center.tscn", &"ToCampus", "res://scenes/locations/post_nightmare/academy_campus.tscn", &"FromSleeper"],
	["res://scenes/locations/post_nightmare/academy_sleeper_center.tscn", &"ToBlackSea", "res://scenes/locations/post_nightmare/black_sea_platform.tscn", &"FromSleeper"],
	["res://scenes/locations/post_nightmare/black_sea_platform.tscn", &"ToCoral", "res://scenes/locations/post_nightmare/tide_descent.tscn", &"FromPlatform"],
	["res://scenes/locations/post_nightmare/tide_descent.tscn", &"ToPlatform", "res://scenes/locations/post_nightmare/black_sea_platform.tscn", &"FromCoral"],
	["res://scenes/locations/post_nightmare/tide_descent.tscn", &"ToCoral", "res://scenes/locations/forgotten_shore_labyrinth/labyrinth_first_fragment.tscn", &"FromDescent"],
	["res://scenes/locations/post_nightmare/coral_labyrinth.tscn", &"ToPlatform", "res://scenes/locations/post_nightmare/tide_descent.tscn", &"FromCoral"],
]


func test_each_location_scene_builds_greybox() -> void:
	for entry in LOCATIONS:
		var packed := load(String(entry.scene)) as PackedScene
		assert_not_null(packed, "сцена %s загружается" % entry.scene)
		if packed == null:
			continue

		var location := packed.instantiate() as GreyboxLocation
		assert_not_null(location, "корень %s использует GreyboxLocation" % entry.id)
		if location == null:
			continue
		add_child_autofree(location)
		await get_tree().process_frame

		assert_eq(location.location_id, entry.id, "id локации совпадает")
		assert_gt(location.module_count(), 12, "у %s достаточно модулей" % entry.id)
		assert_not_null(location.get_node_or_null(^"Generated/Structure"), "структура %s собрана" % entry.id)
		assert_not_null(location.get_node_or_null(^"Generated/Props"), "реквизит %s собран" % entry.id)
		assert_not_null(location.get_node_or_null(^"Generated/Lights"), "свет %s собран" % entry.id)
		assert_not_null(location.get_spawn(&"Start"), "у %s есть Spawns/Start" % entry.id)
		assert_not_null(location.get_node_or_null(^"Player"), "у %s есть игрок" % entry.id)

		for module_id in entry.modules:
			assert_true(location.has_module(module_id), "у %s есть модуль %s" % [entry.id, module_id])

		var camera := location.get_node_or_null(^"Shots/Overview") as Camera3D
		assert_not_null(camera, "у %s есть обзорный ракурс" % entry.id)
		if camera != null:
			assert_gt(absf(camera.rotation.x) + absf(camera.rotation.y), 0.01,
				"камера %s развёрнута на LookAt" % entry.id)


func test_rebuild_is_repeatable() -> void:
	for entry in LOCATIONS:
		var packed := load(String(entry.scene)) as PackedScene
		if packed == null:
			continue
		var location := packed.instantiate() as GreyboxLocation
		if location == null:
			continue
		add_child_autofree(location)
		await get_tree().process_frame
		var before := location.module_count()
		location.rebuild()
		assert_eq(location.module_count(), before, "повторная сборка %s даёт тот же набор" % entry.id)
		assert_not_null(location.get_spawn(&"Start"), "Spawns не затрагиваются пересборкой")


func test_map_definitions_match_scenes() -> void:
	var atlas := load(ATLAS_PATH) as MapAtlas
	assert_not_null(atlas, "атлас загружается")
	if atlas == null:
		return

	for entry in LOCATIONS:
		var map := load(String(entry.map)) as MapDefinition
		assert_not_null(map, "карта %s загружается" % entry.id)
		if map == null:
			continue
		assert_eq(map.id, entry.id, "id карты совпадает")
		assert_true(map.has_world_bounds(), "у карты %s заданы мировые границы" % entry.id)
		assert_true(map.scene_paths.has(String(entry.scene)), "карта %s ссылается на сцену" % entry.id)
		assert_gt(map.markers.size(), 2, "у карты %s есть маркеры" % entry.id)
		assert_gt(map.features.size(), 2, "у карты %s есть геометрия" % entry.id)

		var found := atlas.find_location_for_scene_path(String(entry.scene))
		assert_not_null(found, "атлас находит сцену %s" % entry.id)
		if found != null:
			assert_eq(found.id, entry.id, "атлас возвращает карту %s" % entry.id)

		for marker in map.markers:
			var point := map.marker_point(marker)
			assert_between(point.x, 0.0, 1.0, "маркер %s внутри карты по X" % marker.id)
			assert_between(point.y, 0.0, 1.0, "маркер %s внутри карты по Y" % marker.id)


func test_transition_portals_resolve_to_existing_spawns() -> void:
	for transition in TRANSITIONS:
		var from_scene := String(transition[0])
		var portal_name := StringName(transition[1])
		var packed := load(from_scene) as PackedScene
		assert_not_null(packed, "сцена-источник %s загружается" % from_scene)
		if packed == null:
			continue
		var location := packed.instantiate()
		var portal := location.get_node_or_null("Portals/%s" % portal_name) as LevelPortal
		assert_not_null(portal, "%s содержит портал %s" % [from_scene, portal_name])
		if portal == null:
			location.free()
			continue
		assert_eq(portal.destination_scene, String(transition[2]),
			"портал %s ведёт в ожидаемую сцену" % portal_name)
		assert_eq(portal.destination_spawn, StringName(transition[3]),
			"портал %s ведёт в ожидаемый spawn" % portal_name)
		assert_true(portal.preload_destination, "портал %s прогревает сцену" % portal_name)
		assert_gt(portal.fade_in_duration, 0.0, "портал %s открывает кадр назначения" % portal_name)
		if portal_name == &"ToBlackSea":
			assert_gt(portal.fade_out_duration, 1.0, "переход в сон намеренно длинный")
		else:
			assert_lt(portal.fade_out_duration, 0.6, "обычный проход короткий")

		var destination := load(portal.destination_scene) as PackedScene
		assert_not_null(destination, "сцена назначения %s загружается" % portal.destination_scene)
		if destination != null:
			var destination_root := destination.instantiate()
			assert_not_null(
				destination_root.get_node_or_null("Spawns/%s" % portal.destination_spawn),
				"в %s есть Spawns/%s" % [portal.destination_scene, portal.destination_spawn]
			)
			destination_root.free()
		location.free()


func test_transition_spawns_exist_and_face_into_scene() -> void:
	var expected := {
		"res://scenes/locations/post_nightmare/police_precinct.tscn": [&"FromApproach"],
		"res://scenes/locations/post_nightmare/academy_approach.tscn": [&"FromPrecinct", &"FromGate"],
		"res://scenes/locations/post_nightmare/academy_gate.tscn": [&"FromApproach", &"FromCampus"],
		"res://scenes/locations/post_nightmare/academy_campus.tscn": [&"FromGate", &"FromSleeper"],
		"res://scenes/locations/post_nightmare/academy_sleeper_center.tscn": [&"FromCampus", &"FromDream"],
		"res://scenes/locations/post_nightmare/black_sea_platform.tscn": [&"FromSleeper", &"FromCoral"],
		"res://scenes/locations/post_nightmare/tide_descent.tscn": [&"FromPlatform", &"FromCoral"],
		"res://scenes/locations/post_nightmare/coral_labyrinth.tscn": [&"FromPlatform"],
	}
	for scene_path in expected:
		var packed := load(scene_path) as PackedScene
		assert_not_null(packed, "сцена %s загружается" % scene_path)
		if packed == null:
			continue
		var location := packed.instantiate()
		for spawn_name in expected[scene_path]:
			var spawn := location.get_node_or_null("Spawns/%s" % spawn_name) as Node3D
			assert_not_null(spawn, "%s содержит Spawns/%s" % [scene_path, spawn_name])
		location.free()


func test_spawn_marker_rotation_is_applied_to_player() -> void:
	LevelPortal.set_pending_spawn(
		"res://scenes/locations/post_nightmare/academy_gate.tscn",
		&"FromCampus"
	)
	var packed := load("res://scenes/locations/post_nightmare/academy_gate.tscn") as PackedScene
	var location := packed.instantiate() as GreyboxLocation
	add_child_autofree(location)
	await get_tree().process_frame

	var player := location.get_node_or_null(^"Player") as SunnyController
	var spawn := location.get_spawn(&"FromCampus") as Marker3D
	assert_not_null(player)
	assert_not_null(spawn)
	if player != null and spawn != null:
		var player_xz := Vector2(player.global_position.x, player.global_position.z)
		var spawn_xz := Vector2(spawn.global_position.x, spawn.global_position.z)
		assert_almost_eq(player_xz.distance_to(spawn_xz), 0.0, 0.05,
			"игрок стоит на маркере прибытия по горизонтали")
		assert_almost_eq(player.visual.rotation.y, spawn.global_rotation.y, 0.01,
			"модель смотрит по направлению маркера")
		assert_almost_eq(player.camera_rig.yaw, spawn.global_rotation.y, 0.01,
			"камера продолжает направление маркера")


func test_police_precinct_has_m2_content() -> void:
	var packed := load("res://scenes/locations/post_nightmare/police_precinct.tscn") as PackedScene
	assert_not_null(packed)
	if packed == null:
		return
	var location := packed.instantiate() as GreyboxLocation
	add_child_autofree(location)
	await get_tree().process_frame
	assert_not_null(location.get_node_or_null(^"Generated/Props/DeskOfficer"), "дежурный офицер существует")
	assert_not_null(location.get_node_or_null(^"Generated/Props/InterrogationOfficer"), "офицер допросной существует")
	assert_not_null(location.get_node_or_null(^"MirrorInteract"), "зеркало интерактивно")
	assert_not_null(location.get_node_or_null(^"ExitTrigger"), "выход к академии озвучен")


func test_academy_approach_has_m2_content() -> void:
	var packed := load("res://scenes/locations/post_nightmare/academy_approach.tscn") as PackedScene
	assert_not_null(packed)
	if packed == null:
		return
	var location := packed.instantiate() as GreyboxLocation
	add_child_autofree(location)
	await get_tree().process_frame
	assert_not_null(location.get_node_or_null(^"Generated/Props/Jet"), "Джет стоит у машины")
	assert_not_null(location.get_node_or_null(^"Generated/Props/CheckpointGuard"), "на КПП есть охрана")
	assert_not_null(location.get_node_or_null(^"CheckpointInteract"), "КПП интерактивен")
	assert_not_null(location.get_node_or_null(^"JetTrigger"), "диалог с Джет срабатывает по входу")


func test_academy_gate_has_checkpoint() -> void:
	var packed := load("res://scenes/locations/post_nightmare/academy_gate.tscn") as PackedScene
	assert_not_null(packed)
	if packed == null:
		return
	var location := packed.instantiate() as GreyboxLocation
	add_child_autofree(location)
	await get_tree().process_frame
	assert_not_null(location.get_node_or_null(^"Generated/Props/GateGuard"), "на воротах есть охрана")
	assert_not_null(location.get_node_or_null(^"GateCheckpointInteract"), "проверка на воротах интерактивна")
	var portal := location.get_node_or_null(^"Portals/ToCampus") as LevelPortal
	assert_not_null(portal, "портал в кампус существует")
	if portal != null:
		assert_false(portal.enabled, "до проверки портал в кампус закрыт")


func test_academy_campus_has_guide() -> void:
	var packed := load("res://scenes/locations/post_nightmare/academy_campus.tscn") as PackedScene
	assert_not_null(packed)
	if packed == null:
		return
	var location := packed.instantiate() as GreyboxLocation
	add_child_autofree(location)
	await get_tree().process_frame
	assert_not_null(location.get_node_or_null(^"Generated/Props/CampusGuide"), "проводник в кампусе существует")
	assert_not_null(location.get_node_or_null(^"CampusGuideInteract"), "проводник интерактивен")


func test_academy_sleeper_center_has_capsule() -> void:
	var packed := load("res://scenes/locations/post_nightmare/academy_sleeper_center.tscn") as PackedScene
	assert_not_null(packed)
	if packed == null:
		return
	var location := packed.instantiate() as GreyboxLocation
	add_child_autofree(location)
	await get_tree().process_frame
	assert_not_null(location.get_node_or_null(^"Generated/Props/InductionMedic"), "медик индукции существует")
	assert_not_null(location.get_node_or_null(^"Generated/Props/Rock"), "Рок существует")
	assert_not_null(location.get_node_or_null(^"Generated/Props/Kasper"), "Каспер существует")
	assert_not_null(location.get_node_or_null(^"Generated/Props/Cassia"), "Кассия существует")
	assert_null(location.get_node_or_null(^"Generated/Props/Julius"), "Джулиус не входит в M1")
	assert_null(location.get_node_or_null(^"JuliusInteract"), "интерактив Джулиуса не входит в M1")
	assert_not_null(location.get_node_or_null(^"CapsuleInteract"), "капсула интерактивна")
	var portal := location.get_node_or_null(^"Portals/ToBlackSea") as LevelPortal
	assert_not_null(portal, "портал в Чёрное море существует")
	if portal != null:
		assert_false(portal.enabled, "до капсулы портал закрыт")


func test_tide_descent_has_warning() -> void:
	var packed := load("res://scenes/locations/post_nightmare/tide_descent.tscn") as PackedScene
	assert_not_null(packed)
	if packed == null:
		return
	var location := packed.instantiate() as GreyboxLocation
	add_child_autofree(location)
	await get_tree().process_frame
	assert_not_null(location.get_node_or_null(^"TideWarningTrigger"), "предупреждение о приливе существует")


func test_black_sea_has_m2_content() -> void:
	var packed := load("res://scenes/locations/post_nightmare/black_sea_platform.tscn") as PackedScene
	assert_not_null(packed)
	if packed == null:
		return
	var location := packed.instantiate() as GreyboxLocation
	add_child_autofree(location)
	await get_tree().process_frame
	assert_not_null(location.get_node_or_null(^"StarsInteract"), "нагрудник можно осмотреть")
	assert_not_null(location.get_node_or_null(^"SwordInteract"), "меч можно осмотреть")
	assert_not_null(location.get_node_or_null(^"DescentInteract"), "спуск интерактивен")
	var portal := location.get_node_or_null(^"Portals/ToCoral") as LevelPortal
	assert_not_null(portal, "портал к спуску существует")
	if portal != null:
		assert_false(portal.enabled, "до осмотра спуск закрыт")


func test_post_nightmare_finale_scene_exists() -> void:
	var path := "res://scenes/campaign/post_nightmare_finale.tscn"
	assert_true(ResourceLoader.exists(path), "сцена финальной карточки существует")
	if not ResourceLoader.exists(path):
		return
	var card := (load(path) as PackedScene).instantiate()
	add_child_autofree(card)
	await get_tree().process_frame
	assert_not_null(card.get_node_or_null(^"%BackButton"), "кнопка возврата в меню существует")
	assert_true(NightmareRunState.has_flag(&"post_nightmare_completed"), "флаг завершения выставлен")
	NightmareRunState.reset()


func test_m1_finale_offers_continue_to_tech_demo() -> void:
	NightmareRunState.reset()
	NightmareRunState.set_flag(&"demo_mode_m1")
	NightmareRunState.set_flag(&"post_nightmare_demo_completed")
	var path := "res://scenes/campaign/post_nightmare_finale.tscn"
	var card := (load(path) as PackedScene).instantiate()
	add_child_autofree(card)
	await get_tree().process_frame
	var continue_button := card.get_node_or_null(^"%ContinueButton") as Button
	assert_not_null(continue_button, "M1 finale has ContinueButton")
	if continue_button != null:
		assert_true(continue_button.visible, "ContinueButton is visible in M1 mode")
	NightmareRunState.reset()


func test_black_sea_platform_matches_canonical_statue_neck() -> void:
	var packed := load("res://scenes/locations/post_nightmare/black_sea_platform.tscn") as PackedScene
	assert_not_null(packed)
	if packed == null:
		return
	var location := packed.instantiate() as GreyboxLocation
	add_child_autofree(location)
	await get_tree().process_frame

	# Новая сцена использует hero-ассет StatueKnightLOD, а не primitive-модули.
	# Старый контракт модулей заменён проверкой реальных узлов сцены.
	assert_true(location.has_module(&"DescentLedge"), "с шеи начинается спуск")
	assert_true(location.has_module(&"DistantReef"), "дальний риф собран")
	assert_false(location.has_module(&"Pier"), "старого пирса нет")
	assert_false(location.has_module(&"CraneTower"), "старого крана нет")
	assert_false(location.has_module(&"TurretNorth"), "старой турели нет")

	var statue := location.get_node_or_null(^"Generated/Structure/StatueKnightColossus")
	assert_not_null(statue, "статуя-колосс инстанцирована")
	if statue != null:
		for lod in ["LOD0", "LOD1", "LOD2"]:
			assert_not_null(statue.get_node_or_null(NodePath(lod)), "у статуи есть %s" % lod)

	var body := location.get_node_or_null(^"Generated/Structure/NeckPlatformCollision") as StaticBody3D
	assert_not_null(body, "коллизия площадки-шеи существует")
	if body != null:
		var shape: CollisionShape3D = null
		for child in body.get_children():
			if child is CollisionShape3D:
				shape = child as CollisionShape3D
				break
		assert_not_null(shape, "у коллизии есть форма")
		if shape != null:
			var cylinder := shape.shape as CylinderShape3D
			assert_not_null(cylinder, "форма — цилиндр")
			if cylinder != null:
				assert_almost_eq(cylinder.radius, 6.0, 0.05, "радиус шеи 6 м")
				assert_almost_eq(cylinder.height, 2.4, 0.05, "высота коллизии 2.4 м")

	for spawn in [&"Start", &"Platform", &"NeckEdge", &"SwordView"]:
		assert_not_null(location.get_spawn(spawn), "есть Spawns/%s" % spawn)
	assert_not_null(location.get_node_or_null(^"Portals/ToCoral"), "есть портал к спуску")
	for shot in [^"Shots/Overview", ^"Shots/Chest", ^"Shots/Sword", ^"Shots/Descent"]:
		assert_not_null(location.get_node_or_null(shot), "есть ракурс %s" % shot)
