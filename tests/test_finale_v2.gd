extends GutTest
## Финал v2: храм без врагов, E-поступок у алтаря, коллизия плато и
## переход к пробуждению с первыми способностями Аспекта/Памяти.

const SANCTUARY_WRAPPER := "res://scenes/campaign/sanctuary_arrival.tscn"
const PILGRIM_ART := "res://scenes/locations/pilgrim_path/pilgrim_path_art.tscn"
const N24_PATH := "res://resources/campaign/beats/n24.tres"
const APPRAISAL_SCENE := "res://scenes/campaign/appraisal_arrival.tscn"
const FINALE_SCENE := "res://scenes/campaign/finale_arrival.tscn"


func before_each() -> void:
	NightmareRunState.reset()


func after_each() -> void:
	NightmareRunState.reset()


func _spawn_wrapper() -> Node3D:
	var wrapper := (load(SANCTUARY_WRAPPER) as PackedScene).instantiate() as Node3D
	for property in [&"fade_in", &"transition_enabled"]:
		for entry in wrapper.get_property_list():
			if StringName(entry.get("name", "")) == property:
				wrapper.set(property, false)
				break
	add_child_autofree(wrapper)
	await wait_physics_frames(1)
	return wrapper


func test_temple_is_single_objective_with_e_altar_action_and_no_enemies() -> void:
	var beat := load(N24_PATH) as BeatData
	assert_not_null(beat)
	if beat == null:
		return
	assert_eq(beat.objective, "Дойти до алтаря", "цель храма — одна строка")
	assert_false(beat.objective.contains("→"))
	assert_true(beat.idle_objectives.is_empty(), "в храме нет чек-листа целей")

	var wrapper := await _spawn_wrapper()
	var sanctuary := wrapper.get_node("Sanctuary") as Node3D
	var sunny := wrapper.get_node("Sanctuary/Sunny") as SunnyController
	var altar := wrapper.get_node("Sanctuary/Interactables/AltarOffering") as Interactable
	assert_not_null(sanctuary)
	assert_not_null(sunny)
	assert_not_null(altar)
	if sanctuary == null or sunny == null or altar == null:
		return
	assert_eq(altar.prompt, "Лечь на алтарь", "лечь на алтарь остаётся поступком E")
	assert_false(sunny.allow_jump, "прыжок в храме выключен")
	assert_false(sunny.combat_enabled, "в храме нет боя")
	assert_eq(sanctuary.find_children("*", "TestEnemy", true, false).size(), 0)
	assert_eq(sanctuary.find_children("*", "MountainKing", true, false).size(), 0)
	assert_eq(sanctuary.find_children("*", "StealthSection", true, false).size(), 0,
		"в храме нет стелс-участка")


func test_plateau_has_real_collision_and_hidden_temple_floor_is_disabled() -> void:
	var art := (load(PILGRIM_ART) as PackedScene).instantiate() as Node3D
	add_child_autofree(art)
	await wait_physics_frames(2)
	var glow := art.get_node_or_null("Props/TempleGlow") as Node3D
	var plateau := art.get_node_or_null("Art/PlateauCollision") as Node3D
	assert_not_null(glow)
	assert_not_null(plateau, "под видимым плато есть отдельная коллизия")
	if glow == null or plateau == null:
		return
	assert_false(glow.visible)
	for shape in glow.find_children("*", "CollisionShape3D", true, false):
		assert_true((shape as CollisionShape3D).disabled,
			"скрытые ступени храма не оставляют призрачную коллизию")

	var space := art.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		Vector3(1.0, 12.0, -76.0), Vector3(1.0, -2.0, -76.0), 1 | 32
	)
	var hit := space.intersect_ray(query)
	assert_false(hit.is_empty(), "под плато есть реальная опора")
	if not hit.is_empty():
		var floor_y: float = (hit.position as Vector3).y
		assert_gt(floor_y, 3.8, "опора не ниже видимой снежной поверхности")
		assert_lt(floor_y, 4.4, "это не скрытый этаж храма")


func test_appraisal_completion_opens_awakening_gate() -> void:
	NightmareRunState.set_flag(&"temple_reached")
	NightmareRunState.set_flag(&"trial_completed")
	NightmareRunState.set_flag(&"veteran_dead")
	NightmareRunState.set_flag(&"flasks_poisoned")
	NightmareRunState.set_flag(&"shifty_dead")
	NightmareRunState.set_flag(&"scholar_abandoned")

	var appraisal := (load(APPRAISAL_SCENE) as PackedScene).instantiate() as Control
	appraisal.fade_in = false
	appraisal.fast_mode = true
	appraisal.transition_enabled = false
	appraisal.start_delay = 0.0
	appraisal.end_delay = 0.0
	add_child_autofree(appraisal)
	await wait_seconds(0.4)
	assert_true(appraisal.is_completed())
	assert_true(NightmareRunState.has_flag(&"appraisal_completed"))
	assert_false(NightmareRunState.has_flag(&"aspect_abilities_unlocked"))

	var finale := (load(FINALE_SCENE) as PackedScene).instantiate() as Control
	finale.transition_enabled = false
	assert_true(finale.can_complete(), "оценка открывает переход к пробуждению")
	finale.free()


func test_awakening_unlocks_aspect_and_memory_only_after_finale() -> void:
	NightmareRunState.set_flag(&"temple_reached")
	NightmareRunState.set_flag(&"trial_completed")
	NightmareRunState.set_flag(&"appraisal_completed")
	assert_false(NightmareRunState.has_flag(&"aspect_abilities_unlocked"))
	assert_false(NightmareRunState.has_flag(&"memory_abilities_unlocked"))

	var finale := (load(FINALE_SCENE) as PackedScene).instantiate() as Control
	finale.fade_in = false
	finale.fast_mode = true
	finale.transition_enabled = false
	add_child_autofree(finale)
	await wait_seconds(0.4)
	assert_true(finale.is_completed())
	assert_true(NightmareRunState.has_flag(&"aspect_abilities_unlocked"))
	assert_true(NightmareRunState.has_flag(&"memory_abilities_unlocked"))
	assert_true(NightmareRunState.has_flag(&"shadow_core_awakened"))
	assert_true(NightmareRunState.has_flag(&"shadow_control_unlocked"))
	assert_true(NightmareRunState.has_flag(&"first_nightmare_completed"))
