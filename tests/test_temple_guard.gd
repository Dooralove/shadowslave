extends GutTest
## B3: невидимый страж пропускает к храму только с Mark of Divinity.
##
## Канон: S12 (docs/design/first_nightmare_restoration_spec.md), критерий
## «страж пропускает только с Mark of Divinity»; E6.3 (03_ascent_and_climax_canon.md):
## страж чувствует Mark, отступает, боя нет. Реакция без Mark в каноне не описана:
## вход просто закрыт, текст — заглушка проекта.

const LOCATION_SCENE := "res://scenes/locations/pilgrim_path/pilgrim_path.tscn"
const WRAPPER_SCENE := "res://scenes/campaign/pilgrim_path_arrival.tscn"


func before_each() -> void:
	NightmareRunState.reset()


func after_each() -> void:
	NightmareRunState.reset()


func _spawn_location() -> PilgrimPath:
	var site := (load(LOCATION_SCENE) as PackedScene).instantiate() as PilgrimPath
	add_child_autofree(site)
	return site


## Открывает подход к храму штатным образом (после захвата Героя) и возвращает триггер.
func _open_temple_approach(site: PilgrimPath) -> TriggerZone:
	site.set_trigger_enabled(&"temple", true)
	return site.get_trigger(&"temple") as TriggerZone


func _spawn_wrapper() -> Node3D:
	var wrapper := (load(WRAPPER_SCENE) as PackedScene).instantiate() as Node3D
	wrapper.transition_enabled = false
	wrapper.fade_in = false
	add_child_autofree(wrapper)
	return wrapper


func test_guard_blocks_entry_without_mark() -> void:
	var site := _spawn_location()
	await wait_process_frames(2)
	var hints: Array[String] = []
	site.hint_requested.connect(func(text: String) -> void: hints.append(text))
	var temple := _open_temple_approach(site)

	temple.fire()
	assert_false(NightmareRunState.has_flag(&"temple_reached"), "без Mark страж не пропускает")
	assert_ne(site.phase, PilgrimPath.PHASE_COMPLETE, "фаза храма не наступает без прохода")
	assert_eq(hints.back(), PilgrimPath.GUARD_BLOCKED_HINT, "закрытый вход объясняется подсказкой")
	assert_true(temple.enabled, "триггер не сгорает, пока вход закрыт")


func test_guard_passes_with_mark_once() -> void:
	NightmareRunState.set_flag(&"mark_of_divinity")
	var site := _spawn_location()
	await wait_process_frames(2)
	var temple := _open_temple_approach(site)
	var emitted := [0]
	site.temple_reached.connect(func() -> void: emitted[0] += 1)

	temple.fire()
	assert_true(NightmareRunState.has_flag(&"temple_reached"), "с Mark страж пропускает")
	assert_eq(site.phase, PilgrimPath.PHASE_COMPLETE)
	assert_eq(emitted[0], 1, "переход к храму срабатывает один раз")
	assert_false(NightmareRunState.has_flag(&"first_nightmare_completed"),
		"вход в храм не подтверждает финал")
	temple.fire()
	assert_eq(emitted[0], 1, "повторный вход не запускает переход снова")


func test_reach_temple_is_guarded_the_same_way() -> void:
	var site := _spawn_location()
	await wait_process_frames(2)
	site.reach_temple()
	assert_false(NightmareRunState.has_flag(&"temple_reached"), "reach_temple тоже уважает стража")
	NightmareRunState.set_flag(&"mark_of_divinity")
	site.reach_temple()
	assert_true(NightmareRunState.has_flag(&"temple_reached"))


func test_wrapper_transition_waits_for_the_guard() -> void:
	var wrapper := _spawn_wrapper()
	await wait_process_frames(2)
	var site := wrapper.get_node("PilgrimPath") as PilgrimPath
	var temple := _open_temple_approach(site)
	temple.fire()
	assert_false(wrapper.has_started_transition(), "без Mark переход в святилище не начинается")

	NightmareRunState.set_flag(&"mark_of_divinity")
	temple.fire()
	assert_true(wrapper.has_started_transition(), "с Mark переход в святилище начинается")
	assert_true(NightmareRunState.has_flag(&"pilgrim_path_completed"))
	assert_false(NightmareRunState.has_flag(&"first_nightmare_completed"))


func test_mark_and_temple_state_survive_snapshot_restore() -> void:
	NightmareRunState.set_flag(&"mark_of_divinity")
	var site := _spawn_location()
	await wait_process_frames(2)
	_open_temple_approach(site).fire()
	var snapshot := NightmareRunState.snapshot()
	NightmareRunState.reset()
	NightmareRunState.restore(snapshot)

	assert_true(NightmareRunState.has_flag(&"mark_of_divinity"), "Mark переживает перенос состояния")
	assert_false(NightmareRunState.has_item(&"mark_of_divinity"), "Mark остаётся атрибутом, не предметом")
	var reloaded := _spawn_location()
	await wait_process_frames(2)
	assert_eq(reloaded.phase, PilgrimPath.PHASE_COMPLETE, "повторный вход не откатывает проход храма")
	assert_false((reloaded.get_trigger(&"temple") as TriggerZone).enabled,
		"повторный вход не открывает переход заново")


## Захват Героя оставляет hero_dead (штатное состояние после B3-захвата); предусловие для видимости стража.
func _capture_done(site: PilgrimPath) -> void:
	NightmareRunState.set_flag(&"hero_dead")
	site.call(&"prepare_route")


func test_guard_visual_shows_at_gate_after_capture_and_retreats_on_pass() -> void:
	var site := _spawn_location()
	await wait_process_frames(2)
	var guard := site.get_node("Props/TempleGuard") as Node3D
	assert_false(guard.visible, "до захвата страж у входа не виден")

	_capture_done(site)
	assert_true(guard.visible, "после захвата страж виден у входа, пока не пропущен")

	NightmareRunState.set_flag(&"mark_of_divinity")
	_open_temple_approach(site).fire()
	assert_false(guard.visible, "страж отступает после пропуска с Mark")


func test_guard_stays_visible_when_entry_is_blocked() -> void:
	var site := _spawn_location()
	await wait_process_frames(2)
	_capture_done(site)
	_open_temple_approach(site).fire()
	assert_false(NightmareRunState.has_flag(&"temple_reached"))
	assert_true((site.get_node("Props/TempleGuard") as Node3D).visible, "без Mark страж остаётся у входа")


func test_guard_visual_has_no_collision_and_does_not_block_movement() -> void:
	var site := _spawn_location()
	await wait_process_frames(2)
	var distortion := site.get_node("Props/TempleGuard/Distortion") as CSGSphere3D
	assert_not_null(distortion)
	assert_false(distortion.use_collision, "визуальное искажение не имеет коллизии")
	assert_eq(_count_collision_objects(site.get_node("Props/TempleGuard")), 0)


func _count_collision_objects(root: Node) -> int:
	var count := 0
	for child in root.get_children():
		if child is CollisionObject3D or (child is CSGShape3D and (child as CSGShape3D).use_collision):
			count += 1
		count += _count_collision_objects(child)
	return count


func test_guard_visibility_restores_from_state_on_reload() -> void:
	NightmareRunState.set_flag(&"hero_dead")
	var before := _spawn_location()
	await wait_process_frames(2)
	assert_true((before.get_node("Props/TempleGuard") as Node3D).visible, "перезагрузка до прохода показывает стража")

	NightmareRunState.set_flag(&"mark_of_divinity")
	before.call(&"reach_temple")
	var after := _spawn_location()
	await wait_process_frames(2)
	assert_false((after.get_node("Props/TempleGuard") as Node3D).visible, "перезагрузка после прохода не возвращает стража")


func test_temple_approach_geometry_contains_gate_and_guard() -> void:
	var site := _spawn_location()
	await wait_process_frames(2)
	var stair := site.get_node("Geometry/TempleStair") as CSGBox3D
	var half := stair.size * 0.5
	var inside := func(point: Vector3) -> bool:
		var local := point - stair.position
		return absf(local.x) <= half.x and absf(local.z) <= half.z
	var approach := (site.get_node("Spawns/TempleApproach") as Node3D).global_position
	var gate := (site.get_node("Interactables/Temple") as Node3D).position
	var guard := (site.get_node("Props/TempleGuard") as Node3D).position
	assert_true(inside.call(approach), "маркер подхода лежит на ступенях храма")
	assert_true(inside.call(gate), "зона перехода лежит на ступенях храма")
	assert_true(inside.call(guard), "страж стоит на ступенях у входа")
	assert_lt(absf(approach.y - (stair.position.y + half.y)), 0.5, "маркер подхода на высоте ступеней")


func test_guard_is_a_faint_ground_level_distortion_not_a_body() -> void:
	# A02 (beats_shrine_climax.md): стражей не показывать целиком — только едва заметное искажение.
	var site := _spawn_location()
	await wait_process_frames(2)
	var guard := site.get_node("Props/TempleGuard") as Node3D
	var distortion := guard.get_node("Distortion") as CSGSphere3D
	var height := distortion.radius * 2.0 * guard.scale.y
	assert_lt(height, 0.5, "визуал стража ниже человеческого роста: не силуэт тела")
	assert_lt(distortion.material.albedo_color.a, 0.12, "искажение полупрозрачно")


func test_bone_clusters_line_the_stairs_inside_the_footprint() -> void:
	# Канон: тысячи костей у ступеней (canon_shadow_shrine.md, гл. 14); скопления, не одиночки.
	var site := _spawn_location()
	await wait_process_frames(2)
	var stair := site.get_node("Geometry/TempleStair") as CSGBox3D
	var half := stair.size * 0.5
	# Новые скопления: ClusterWest, ClusterEast, ClusterFront. Исходные Bone01–04 — декорация, не проверяются.
	var bones: Array = []
	for cluster in ["ClusterWest", "ClusterEast", "ClusterFront"]:
		bones.append_array(site.get_node("Props/Bones/%s" % cluster).find_children("B*", "CSGCylinder3D", false, false))
	# Канон: «тысячи костей»; 11 новых примитивов — частичное покрытие, пробел остаётся открытым.
	assert_eq(bones.size(), 11, "число новых костей у ступеней")
	for bone in bones:
		var local := (bone as Node3D).global_position - stair.global_position
		var on_steps := absf(local.x) <= half.x + 0.5 and absf(local.z) <= half.z + 4.5
		assert_true(on_steps, "кость %s лежит у ступеней" % (bone as Node3D).name)


func test_broken_gate_fragments_frame_the_temple_entrance() -> void:
	# Канон: высокие ворота храма сломаны (canon_shadow_shrine.md, гл. 14).
	var site := _spawn_location()
	await wait_process_frames(2)
	var gate := site.get_node("Props/TempleGlow/BrokenGate")
	assert_eq(gate.get_child_count(), 3, "два фрагмента створок и обломок перемычки")
	for fragment in gate.get_children():
		assert_false((fragment as CSGShape3D).use_collision, "декор проёма не блокирует проход")
