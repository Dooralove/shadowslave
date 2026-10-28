extends GutTest
## Партия 5: арт-варианты лобби и изолятора подключаются сценами-наследниками без изменения сценария
## (как парк S3.1). Проверяются игровые точки, отключение CSG, модели в узлах, которыми управляет постановка,
## ракурсы и пол. План — docs/art/integration_plan.md, §2.

const LOBBY := "res://scenes/slice/locations/station_lobby.tscn"
const LOBBY_ART := "res://scenes/slice/locations/station_lobby_art.tscn"
const CELL := "res://scenes/slice/locations/containment_room.tscn"
const CELL_ART := "res://scenes/slice/locations/containment_room_art.tscn"
const PROLOGUE_ART := "res://scenes/slice/locations/park/prologue_park_art.tscn"
const PROLOGUE := "res://scenes/slice/prologue.tscn"


func _spawn(path: String) -> SliceLocation:
	var location := (load(path) as PackedScene).instantiate() as SliceLocation
	add_child_autofree(location)
	return location


func _base(path: String) -> Node3D:
	var node := (load(path) as PackedScene).instantiate() as Node3D
	autofree(node)
	return node


func _floor_y(location: Node3D, point: Vector3) -> float:
	var space := location.get_world_3d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(point + Vector3.UP * 1.2, point + Vector3.DOWN))
	return INF if hit.is_empty() else (hit.position as Vector3).y


func test_lobby_gameplay_points_unchanged() -> void:
	var art := _spawn(LOBBY_ART)
	var base := _base(LOBBY)
	for path in [^"Spawns/Counter", ^"Spawns/Entrance", ^"Markers/OfficerMarks/MarkA", ^"Markers/OfficerMarks/MarkB",
			^"DeskOfficer", ^"Officers/OfficerA", ^"Officers/OfficerB", ^"Shots/DeskShot", ^"Shots/AlarmShot"]:
		assert_true(art.has_node(path), "узел %s" % path)
		assert_eq((art.get_node(path) as Node3D).position, (base.get_node(path) as Node3D).position, "%s не сдвинут" % path)


func test_lobby_csg_props_replaced() -> void:
	var art := _spawn(LOBBY_ART)
	for name in ["ArmorW1", "ArmorN2", "Counter", "Terminal", "TurretNW", "PanelA", "EntranceDoor"]:
		assert_false((art.get_node("Geometry/" + name) as Node3D).visible, "%s скрыт" % name)
	assert_false((art.get_node("Geometry/Counter") as CSGShape3D).use_collision, "старая стойка без коллизии")
	for name in ["Counter", "Terminal", "TurretNW", "PlateN1", "PlateW1", "PlateE3", "Entrance", "LightA"]:
		assert_true(art.has_node("Art/" + name), "модель %s" % name)


func test_lobby_floor_and_counter_collision() -> void:
	var art := _spawn(LOBBY_ART)
	await wait_physics_frames(2)
	assert_almost_eq(_floor_y(art, Vector3(0.9, 0, -1.9)), 0.0, 0.02, "пол у точки Counter")
	assert_almost_eq(_floor_y(art, Vector3(0, 0, 4.0)), 0.0, 0.02, "пол у входа")
	assert_gt(_floor_y(art, Vector3(0, 0, -2.65)), 1.0, "бронефронт стойки твёрдый (ступенька 1,1 м)")
	assert_almost_eq(_floor_y(art, Vector3(0, 0, -3.1)), 0.76, 0.02, "рабочая поверхность дежурного")


func test_cell_gameplay_points_unchanged() -> void:
	var art := _spawn(CELL_ART)
	var base := _base(CELL)
	for path in [^"Spawns/Chair", ^"Chair", ^"Markers/CuffMarks/CuffA", ^"Markers/CuffMarks/CuffB", ^"Shots/DoorShot"]:
		assert_true(art.has_node(path), "узел %s" % path)
		assert_eq((art.get_node(path) as Node3D).position, (base.get_node(path) as Node3D).position, "%s не сдвинут" % path)


func test_cell_models_inside_scripted_nodes() -> void:
	var art := _spawn(CELL_ART)
	assert_true(art.has_node("Geometry/DoorPivot/VaultDoorModel"), "дверь — в узле, который поворачивает постановка")
	assert_false((art.get_node("Geometry/DoorPivot/VaultDoor") as Node3D).visible, "CSG-дверь скрыта")
	assert_true(art.has_node("Chair/ChairModel"), "кресло — в узле Chair")
	assert_true(art.has_node("Chair/Restraints/StrapsModel"), "ремни — в узле, который показывает постановка")
	assert_false((art.get_node("Chair/Restraints") as Node3D).visible, "до пристёгивания ремней не видно")
	for name in ["Floor", "WallNorthL", "WallSouth", "WallWest", "WallEast", "Lintel"]:
		var csg := art.get_node("Geometry/" + name) as CSGShape3D
		assert_false(csg.visible, "%s скрыт" % name)
		assert_false(csg.use_collision, "%s без коллизии" % name)


func test_cell_people_inside_new_room() -> void:
	var art := _spawn(CELL_ART)
	# Бокс по брифу: x ∈ [−1,8; 1,8], z ∈ [−1,25; 3,15]; полицейский стартует в коридоре за дверью.
	for path in [^"Guards/GuardA", ^"Guards/GuardB", ^"Markers/ChairFront", ^"Markers/CuffMarks/CuffA",
			^"Markers/CuffMarks/CuffB", ^"Shots/RoomShot", ^"Shots/DoorShot"]:
		var p := (art.get_node(path) as Node3D).global_position
		assert_true(absf(p.x) < 1.75 and p.z > -1.2 and p.z < 3.1, "%s внутри бокса: %s" % [path, p])
	var cop := (art.get_node("Policeman") as Node3D).global_position
	assert_true(cop.z < -1.5 and cop.z > -7.4 and absf(cop.x) < 0.8, "полицейский в коридоре: %s" % cop)
	# Прямой путь полицейского к ChairFront проходит в проём двери (ширина 1,12 м, ось x = −0,005).
	var front := (art.get_node("Markers/ChairFront") as Node3D).global_position
	var t := (-1.25 - cop.z) / (front.z - cop.z)
	assert_lt(absf(lerpf(cop.x, front.x, t)), 0.45, "путь через проём")


func test_cell_floor_at_zero() -> void:
	var art := _spawn(CELL_ART)
	await wait_physics_frames(2)
	for point in [Vector3(0, 0, 0.3), Vector3(1.2, 0, 2.5), Vector3(0, 0, -3.0)]:
		assert_almost_eq(_floor_y(art, point), 0.0, 0.02, "пол в %s" % point)


func test_shots_look_at_targets() -> void:
	for path in [LOBBY_ART, CELL_ART]:
		var art := _spawn(path)
		for shot in art.get_node("Shots").get_children():
			var camera := shot as Camera3D
			var target := (camera.get_node(^"LookAt") as Node3D).global_position
			var to_target := (target - camera.global_position).normalized()
			assert_almost_eq((-camera.global_basis.z).dot(to_target), 1.0, 0.001, "%s: %s" % [path, camera.name])


func test_both_prologues_use_art_variants() -> void:
	var art := (load(PROLOGUE_ART) as PackedScene).instantiate() as SliceDirector
	art.autostart = false
	add_child_autofree(art)
	art._load(&"lobby", &"Counter")
	assert_eq(art.location.scene_file_path, LOBBY_ART)
	art._load(&"containment", &"Chair")
	assert_eq(art.location.scene_file_path, CELL_ART)
	# Основной пролог (кампания) переключён на арт-варианты 2026-10-26.
	var main := (load(PROLOGUE) as PackedScene).instantiate() as SliceDirector
	main.autostart = false
	add_child_autofree(main)
	main._load(&"lobby", &"Counter")
	assert_eq(main.location.scene_file_path, LOBBY_ART)
	main._load(&"containment", &"Chair")
	assert_eq(main.location.scene_file_path, CELL_ART)


func test_main_prologue_plays_through() -> void:
	var director := (load(PROLOGUE) as PackedScene).instantiate() as SliceDirector
	director.autostart = false
	director.fast_mode = true
	add_child_autofree(director)
	director.start()
	for i in 200:
		if director.beat == SliceDirector.Beat.FINISHED:
			break
		if director.runner.running:
			director.runner.advance()
		elif director.ui.rune_status.showing:
			director.ui.rune_status.close()
		elif director.awaiting != &"":
			director.notify(director.awaiting)
		await wait_process_frames(1)
	assert_eq(director.beat, SliceDirector.Beat.FINISHED, "основной пролог с арт-вариантами проходится до конца")
