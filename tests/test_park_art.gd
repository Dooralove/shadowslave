extends GutTest
## S3.1: художественный вариант парка подключается сценой-наследником без изменения сценария.
## Проверяются игровые точки, отключение старой коллизии, новый пол и проходимость пролога.

const PARK_ART := "res://scenes/slice/locations/park/park_street_art.tscn"
const PROLOGUE_ART := "res://scenes/slice/locations/park/prologue_park_art.tscn"
const PROLOGUE := "res://scenes/slice/prologue.tscn"


func _park() -> SliceLocation:
	var park := (load(PARK_ART) as PackedScene).instantiate() as SliceLocation
	add_child_autofree(park)
	return park


func test_gameplay_points_unchanged() -> void:
	var park := _park()
	var base := (load("res://scenes/slice/locations/park_street.tscn") as PackedScene).instantiate() as Node3D
	autofree(base)
	for path in [^"Spawns/BenchSit", ^"Spawns/BenchStand", ^"Spawns/BinThrow", ^"Spawns/PickSpot",
			^"Markers/BinTop", ^"Markers/MissSpot", ^"Interactables/Coffee", ^"Interactables/BinSpot",
			^"Interactables/StationDoor", ^"Triggers/StationEntrance", ^"Props/CoffeeCup"]:
		assert_true(park.has_node(path), "узел %s" % path)
		if park.has_node(path):
			assert_eq((park.get_node(path) as Node3D).position, (base.get_node(path) as Node3D).position, "%s не сдвинут" % path)


func test_graybox_hidden_without_collision() -> void:
	var park := _park()
	assert_false((park.get_node("Geometry") as Node3D).visible)
	assert_false((park.get_node("Skyline") as Node3D).visible)
	for csg in park.get_node("Geometry").find_children("*", "CSGShape3D", true, false):
		assert_false((csg as CSGShape3D).use_collision, "%s без коллизии" % csg.name)


func test_hero_props_in_place() -> void:
	var park := _park()
	var base := (load("res://scenes/slice/locations/park_street.tscn") as PackedScene).instantiate() as Node3D
	autofree(base)
	# S3.2: скамейка и урна — отдельные модели на прежних местах; стаканчик сценария получил модель.
	assert_eq((park.get_node("Art/Bench") as Node3D).position, (base.get_node("Geometry/Bench") as Node3D).position)
	assert_eq((park.get_node("Art/Bin") as Node3D).position * Vector3(1, 0, 1), (base.get_node("Geometry/Bin") as Node3D).position * Vector3(1, 0, 1))
	var cup := park.get_node("Props/CoffeeCup") as MeshInstance3D
	assert_null(cup.mesh, "заглушка-цилиндр снята")
	assert_true(cup.has_node("CupModel"), "модель стаканчика внутри узла, который двигает сценарий")


func test_art_floor_at_zero_along_route() -> void:
	var park := _park()
	await wait_physics_frames(2)
	var space := park.get_world_3d().direct_space_state
	# Скамейка → урна → дорожка → переход → дверь участка.
	for point in [Vector3(0, 0, 3.2), Vector3(2.0, 0, 2.5), Vector3(0.3, 0, -3.0), Vector3(0, 0, -11.5), Vector3(0, 0, -17.5)]:
		var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 2.0, point + Vector3.DOWN)
		var hit := space.intersect_ray(query)
		assert_false(hit.is_empty(), "пол под %s" % point)
		if not hit.is_empty():
			assert_almost_eq(hit.position.y, 0.0, 0.02, "пол на уровне 0 в %s" % point)


func test_director_uses_override_only_when_set() -> void:
	var art := (load(PROLOGUE_ART) as PackedScene).instantiate() as SliceDirector
	art.autostart = false
	add_child_autofree(art)
	art._load(&"park", &"BenchSit")
	assert_eq(art.location.scene_file_path, PARK_ART)
	var main := (load(PROLOGUE) as PackedScene).instantiate() as SliceDirector
	main.autostart = false
	add_child_autofree(main)
	main._load(&"park", &"BenchSit")
	assert_eq(main.location.scene_file_path, "res://scenes/slice/locations/park_street.tscn", "основной пролог без изменений")


func test_art_prologue_plays_through() -> void:
	var director := (load(PROLOGUE_ART) as PackedScene).instantiate() as SliceDirector
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
	assert_eq(director.beat, SliceDirector.Beat.FINISHED, "пролог с новым парком проходится до конца")
