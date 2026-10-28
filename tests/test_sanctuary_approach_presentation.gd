extends GutTest
## Подготовка подхода к храму: звук, реплика «Found you», поле костей, видимость стража.
##
## Проверки идут через реальные методы локации и оболочки: захват через _ring_bell()
## и complete_hero_capture(). Условие «Герой на тропе» (FLAG_HERO) выставляется как
## предусловие, потому что предшествующая сцена здесь не проигрывается.

const LOCATION_SCENE := "res://scenes/locations/pilgrim_path/pilgrim_path.tscn"
const WRAPPER_SCENE := "res://scenes/campaign/pilgrim_path_arrival.tscn"
const WIND := "res://assets/audio/sanctuary/wind_whoosh_loop.ogg"


func before_each() -> void:
	NightmareRunState.reset()


func after_each() -> void:
	NightmareRunState.reset()


func _spawn_location() -> PilgrimPath:
	var site := (load(LOCATION_SCENE) as PackedScene).instantiate() as PilgrimPath
	add_child_autofree(site)
	return site


func _spawn_wrapper() -> Node3D:
	var wrapper := (load(WRAPPER_SCENE) as PackedScene).instantiate() as Node3D
	wrapper.transition_enabled = false
	wrapper.fade_in = false
	wrapper.fast_mode = true
	add_child_autofree(wrapper)
	return wrapper


func _wait_until(predicate: Callable, max_frames := 120) -> bool:
	for i in max_frames:
		if predicate.call():
			return true
		await wait_process_frames(1)
	return false


func _count_collision(root: Node) -> int:
	var count := 0
	for child in root.get_children():
		if child is CollisionObject3D or (child is CSGShape3D and (child as CSGShape3D).use_collision):
			count += 1
		count += _count_collision(child)
	return count


func test_live_capture_shows_the_guard_without_reload() -> void:
	# Регрессия B3.1: до исправления страж появлялся только после перезагрузки сцены.
	NightmareRunState.set_flag(&"silver_bell_used")
	NightmareRunState.set_flag(&"silver_bell_obtained")
	var site := _spawn_location()
	await wait_process_frames(2)
	assert_false((site.get_node("Props/TempleGuard") as Node3D).visible, "до захвата страж не виден")
	NightmareRunState.set_flag(&"hero_confrontation_seen")
	NightmareRunState.set_flag(&"silver_bell_used")
	site.complete_hero_capture()
	assert_true((site.get_node("Props/TempleGuard") as Node3D).visible,
		"после живого захвата страж виден у входа без перезагрузки")


func test_guard_presence_sound_plays_once_at_capture() -> void:
	NightmareRunState.set_flag(&"silver_bell_used")
	var site := _spawn_location()
	await wait_process_frames(2)
	site.complete_hero_capture()
	site.complete_hero_capture()
	assert_eq(site.get("_guard_sound_plays"), 1, "звук присутствия стража — один раз за захват")


func test_wind_loop_is_one_positional_source_per_location_instance() -> void:
	var site := _spawn_location()
	await wait_process_frames(2)
	var wind_count := 0
	for child in site.get_children():
		if child is AudioStreamPlayer and String(child.name).begins_with("WindSource"):
			wind_count += 1
	assert_eq(wind_count, 1, "один источник ветра на экземпляр локации, без дублей")
	var player := site.get("_wind_player") as AudioStreamPlayer
	assert_not_null(player)
	assert_true((player.stream as AudioStreamOggVorbis).loop, "ветер зациклен, без обрывов")
	assert_true(player.playing, "ветер звучит на площадке")


func test_wind_is_freed_with_the_location() -> void:
	# Ветер — дочерний узел локации: уход из сцены должен его останавливать, а не оставлять фоном.
	var site := _spawn_location()
	await wait_process_frames(2)
	var player := site.get("_wind_player") as AudioStreamPlayer
	site.free()
	assert_false(is_instance_valid(player), "ветер не переживает выгрузку локации")


func test_threshold_creak_plays_once_when_the_guard_lets_sunny_pass() -> void:
	# A02: «один тихий каменный скрип» при пересечении порога — момент прохода стража.
	NightmareRunState.set_flag(&"mark_of_divinity")
	var site := _spawn_location()
	await wait_process_frames(2)
	site.reach_temple()
	assert_eq(site.get("_creak_plays"), 1, "скрип звучит при проходе стража")
	site.reach_temple()
	assert_eq(site.get("_creak_plays"), 1, "повторный вход не повторяет скрип")


func test_threshold_creak_stays_silent_when_the_guard_blocks() -> void:
	var site := _spawn_location()
	await wait_process_frames(2)
	site.reach_temple()
	assert_eq(site.get("_creak_plays"), 0, "без Mark порог не пересечён — скрипа нет")


func test_threshold_creak_is_not_replayed_after_reload() -> void:
	NightmareRunState.set_flag(&"mark_of_divinity")
	var first := _spawn_location()
	await wait_process_frames(2)
	first.reach_temple()
	var reloaded := _spawn_location()
	await wait_process_frames(2)
	reloaded.reach_temple()
	assert_eq(reloaded.get("_creak_plays"), 0, "перезагрузка после прохода не проигрывает скрип заново")


func test_bone_field_is_one_multimesh_without_collision() -> void:
	# Канон: тысячи костей. Поле — один MultiMesh (много экземпляров, один узел), без коллизий.
	var site := _spawn_location()
	await wait_process_frames(2)
	var field := site.get_node("Props/Bones/BoneField") as MultiMeshInstance3D
	assert_not_null(field)
	assert_eq(field.multimesh.instance_count, PilgrimPath.BONE_COUNT, "число экземпляров костей задано константой")
	assert_eq((site.get("_bone_origins") as Array).size(), PilgrimPath.BONE_COUNT, "каждому экземпляру задана позиция")
	assert_eq(_count_collision(site.get_node("Props/Bones")), 0, "кости не блокируют движение")


func test_bone_field_stays_beside_the_stairs_not_inside_them() -> void:
	var site := _spawn_location()
	await wait_process_frames(2)
	var stair := site.get_node("Geometry/TempleStair") as CSGBox3D
	var half := stair.size * 0.5
	var origins: Array = site.get("_bone_origins")
	var inside_core := 0
	for index in origins.size():
		var origin: Vector3 = origins[index]
		var local := origin - stair.position
		# Кости — по бокам ступеней: x вне центральной части, z в пределах ступеней.
		assert_true(absf(local.z) <= half.z + 0.5,
			"кость %d лежит в пределах ступеней по z: origin.z=%.2f, stair.z=%.2f, half.z=%.2f" % [index, origin.z, stair.position.z, half.z])
		if absf(local.x) < half.x - 1.0:
			inside_core += 1
	assert_eq(inside_core, 0, "центр ступеней свободен от костей: проход не загроможден")


func test_found_you_plays_once_after_the_temple_appears() -> void:
	NightmareRunState.set_flag(&"hero_confrontation_seen")
	var wrapper := _spawn_wrapper()
	await wait_process_frames(2)
	var site := wrapper.get_node("PilgrimPath") as PilgrimPath
	var runner := wrapper.get_node("DialogueRunner") as DialogueRunner
	var texts: Array[String] = []
	runner.line_started.connect(func(line: DialogueLine, _index: int, _count: int) -> void: texts.append(line.text))

	assert_false(texts.has("Found you."), "до звонка реплики нет")
	site.call(&"_ring_bell")
	assert_true(await _wait_until(func() -> bool: return texts.has("Found you.")), "реплика звучит после захвата")
	var found_index := texts.find("Found you.")
	assert_eq(texts.count("Found you."), 1)
	assert_eq(found_index, texts.size() - 1, "реплика — последняя после линий звонка")
	assert_false(wrapper.has_started_transition(), "реплика сама не переводит в храм")

	site.call(&"_ring_bell")
	await wait_process_frames(30)
	assert_eq(texts.count("Found you."), 1, "повторный звонок не повторяет реплику")
