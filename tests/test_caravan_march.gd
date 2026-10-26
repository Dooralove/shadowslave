extends GutTest
## S01: обязательные знакомства, продольный поводок, прибытие и передача в лагерь.

const PASS_SCENE := "res://scenes/campaign/first_nightmare_pass.tscn"
const CAMP_ARRIVAL := "res://scenes/campaign/caravan_site_arrival.tscn"
const PASS_SCRIPT := preload("res://scripts/campaign/first_nightmare_pass.gd")


func before_each() -> void:
	NightmareRunState.reset()


func after_each() -> void:
	NightmareRunState.reset()


func _spawn_pass(start := false) -> Node3D:
	var scene := (load(PASS_SCENE) as PackedScene).instantiate() as Node3D
	scene.autostart = false
	scene.transition_enabled = false
	scene.fast_mode = true
	add_child_autofree(scene)
	if start:
		scene.start()
	return scene


func test_route_targets_camp_arrival_and_not_old_sandbox() -> void:
	assert_eq(PASS_SCRIPT.NEXT_SCENE, CAMP_ARRIVAL)
	assert_true(FileAccess.file_exists(PASS_SCRIPT.NEXT_SCENE))


func test_start_marks_debug_entry_and_keeps_player_in_chain() -> void:
	var pass_scene := _spawn_pass(true)
	var sunny := pass_scene.get_node("Sunny") as SunnyController
	assert_true(NightmareRunState.has_flag(&"prologue_completed"), "прямой запуск помечается как отладочный")
	assert_true(sunny.chain_restrained, "на марше включена цепь")
	assert_true(sunny.input_enabled)
	assert_false(sunny.allow_sprint)
	assert_false(sunny.allow_jump)
	assert_false(sunny.combat_enabled)
	assert_true(pass_scene.is_march_intro_seen() == false, "знакомства ещё не проиграны")


func test_beats_fire_once_and_complete_intro() -> void:
	var pass_scene := _spawn_pass(true)
	var dialogue := pass_scene.get_node("DialogueRunner") as DialogueRunner
	var line_count := [0]
	dialogue.line_started.connect(
		func(_line: DialogueLine, _index: int, _count: int) -> void:
			line_count[0] += 1
	)
	assert_eq(pass_scene.march_beats.size(), 4)
	pass_scene._trigger_beats(-99.0)
	assert_true(NightmareRunState.has_flag(&"march_threat_seen"))
	assert_true(NightmareRunState.has_flag(&"march_scholar_seen"))
	assert_true(NightmareRunState.has_flag(&"march_water_seen"))
	assert_true(NightmareRunState.has_flag(&"march_camp_seen"))
	assert_true(NightmareRunState.has_flag(&"march_intro_seen"))
	var first_count: int = line_count[0]
	assert_gt(first_count, 0, "реплики знакомства действительно проиграны")
	pass_scene._trigger_beats(-99.0)
	assert_eq(line_count[0], first_count, "повторный проход не дублирует знакомства")


func test_convoy_clamps_ahead_and_behind() -> void:
	var pass_scene := _spawn_pass(true)
	var sunny := pass_scene.get_node("Sunny") as SunnyController
	var road := pass_scene.get_node("CaravanRoad/Road") as Node3D
	var ahead := road.to_global(Vector3(0.0, 0.2, -8.0))
	sunny.global_position = ahead
	pass_scene._physics_process(0.016)
	var local := road.to_local(sunny.global_position)
	assert_almost_eq(local.z, -pass_scene.march_lead_limit, 0.05, "вперёд цепь не отпускает дальше лимита")

	var behind := road.to_global(Vector3(0.0, 0.2, 8.0))
	sunny.global_position = behind
	pass_scene._physics_process(0.016)
	local = road.to_local(sunny.global_position)
	assert_almost_eq(local.z, pass_scene.march_trail_limit, 0.05, "назад цепь подтягивает к колонне")


func test_convoy_stop_is_reachable_inside_chain_corridor() -> void:
	var pass_scene := _spawn_pass(true)
	for i in 500:
		pass_scene._physics_process(0.1)
		if pass_scene.has_started_transition():
			break
	assert_true(pass_scene.has_started_transition(), "колонна доходит до CampArrival, а не застревает перед z=-36")
	assert_true(NightmareRunState.has_flag(&"camp_reached"))


func test_camp_arrival_starts_transition_once_and_sets_flags() -> void:
	var pass_scene := _spawn_pass(true)
	var sunny := pass_scene.get_node("Sunny") as SunnyController
	pass_scene._on_exit_body_entered(sunny)
	pass_scene._on_exit_body_entered(sunny)
	assert_true(pass_scene.has_started_transition())
	assert_true(NightmareRunState.has_flag(&"camp_reached"))
	assert_true(NightmareRunState.has_flag(&"march_intro_seen"))
	assert_false(sunny.input_enabled)
	assert_false(sunny.chain_restrained)
	assert_true(pass_scene.get_node("PrototypeNote/Root/Note").visible == false)
