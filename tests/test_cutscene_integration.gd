extends GutTest
## Контракты cutscene-фреймворка и его реальных M1-вставок.

const PROBE_DEFINITION := "res://tests/support/cutscene_probe_definition.tres"
const HOLD_DEFINITION := "res://tests/support/cutscene_hold_definition.tres"

const SCENE_CASES := [
	{
		"scene": "res://scenes/locations/post_nightmare/police_precinct.tscn",
		"stage": "Cutscene/P05Wake",
		"id": &"m1/p05_wake",
	},
	{
		"scene": "res://scenes/locations/post_nightmare/police_precinct.tscn",
		"stage": "Cutscene/P05Mirror",
		"id": &"m1/p05_mirror",
	},
	{
		"scene": "res://scenes/locations/post_nightmare/academy_sleeper_center.tscn",
		"stage": "Cutscene/P09Induction",
		"id": &"m1/p09_induction",
	},
	{
		"scene": "res://scenes/locations/post_nightmare/academy_sleeper_center.tscn",
		"stage": "Cutscene/P09Capsule",
		"id": &"m1/p09_capsule",
	},
	{
		"scene": "res://scenes/locations/post_nightmare/black_sea_platform.tscn",
		"stage": "Cutscene/B01Shroud",
		"id": &"m1/b01_shroud",
	},
]

const BEAT_SCENE_CASES := [
	{
		"scene": "res://scenes/campaign/caravan_site_arrival.tscn",
		"shots": [&"Attack", &"Veteran", &"VeteranDeath"],
	},
	{
		"scene": "res://scenes/campaign/pilgrim_path_arrival.tscn",
		"shots": [&"ShiftyFall", &"CaveWound", &"HeroConfront", &"HeroCapture"],
	},
]


func before_each() -> void:
	NightmareRunState.reset()
	CutsceneDirector.reset_for_tests()


func after_each() -> void:
	CutsceneDirector.reset_for_tests()
	NightmareRunState.reset()


func test_definition_resources_are_valid() -> void:
	for entry in SCENE_CASES:
		var path := String(entry["scene"]).replace(".tscn", ".tscn")
		assert_true(ResourceLoader.exists(path), "сцена существует: %s" % path)
	for path in [
		"res://resources/cutscene/m1/p05_wake.tres",
		"res://resources/cutscene/m1/p05_mirror.tres",
		"res://resources/cutscene/m1/p09_induction.tres",
		"res://resources/cutscene/m1/p09_capsule.tres",
		"res://resources/cutscene/m1/b01_shroud.tres",
	]:
		var definition := load(path) as CutsceneDefinition
		assert_not_null(definition, "манифест загружается: %s" % path)
		if definition != null:
			assert_not_null(definition.cutscene_script, "у манифеста есть сценарий: %s" % path)
			assert_true(definition.cutscene_script.can_instantiate(), "сценарий инстанцируется: %s" % path)
			assert_true(definition.max_duration > 0.0, "задан таймаут: %s" % path)


func test_director_runs_definition_and_applies_flags() -> void:
	var stage := CutsceneStage.new()
	stage.name = "ProbeStage"
	stage.definition = load(PROBE_DEFINITION) as CutsceneDefinition
	add_child_autofree(stage)
	await get_tree().process_frame

	CutsceneDirector.fast_mode = true
	var result: int = await CutsceneDirector.play_stage(stage)
	assert_eq(result, CutsceneTypes.Result.COMPLETED, "кат-сцена завершилась")
	assert_true(NightmareRunState.has_flag(&"test_cutscene_ran"), "сценарий выполнился")
	assert_true(NightmareRunState.has_flag(&"test_cutscene_done"), "completion_flags применены")
	assert_false(CutsceneDirector.is_playing(), "директор вернулся в idle")


func test_cutscene_blocks_pause_and_player_menu() -> void:
	var player := Node3D.new()
	player.name = "ProbePlayer"
	player.add_to_group(&"player")
	add_child_autofree(player)
	var stage := CutsceneStage.new()
	stage.name = "HoldStage"
	stage.definition = load(HOLD_DEFINITION) as CutsceneDefinition
	add_child_autofree(stage)
	await get_tree().process_frame
	var run := CutsceneDirector.start_stage(stage)
	assert_not_null(run, "hold-катсцена стартовала")
	assert_true(CutsceneDirector.is_locked(), "директор удерживает ввод")
	assert_false(PauseMenuSystem.open_menu(), "пауза не открывается во время катсцены")
	assert_false(PlayerMenuSystem.open_menu(&"character"), "меню персонажа не открывается")
	CutsceneDirector.abort("test")


func test_m1_scenes_expose_cutscene_stages() -> void:
	for entry in SCENE_CASES:
		var packed := load(String(entry["scene"])) as PackedScene
		assert_not_null(packed, "сцена загружается: %s" % entry["scene"])
		if packed == null:
			continue
		var scene := packed.instantiate()
		add_child_autofree(scene)
		await get_tree().process_frame
		var stage := scene.get_node_or_null(NodePath(String(entry["stage"]))) as CutsceneStage
		assert_not_null(stage, "stage существует: %s" % entry["stage"])
		if stage != null:
			assert_not_null(stage.definition, "у stage есть манифест: %s" % entry["stage"])
			if stage.definition != null:
				assert_eq(stage.definition.id, entry["id"], "id манифеста совпадает")
		scene.queue_free()
		await get_tree().process_frame


func test_campaign_beat_stages_expose_camera_shots() -> void:
	for entry in BEAT_SCENE_CASES:
		var packed := load(String(entry["scene"])) as PackedScene
		assert_not_null(packed, "сцена загружается: %s" % entry["scene"])
		if packed == null:
			continue
		var scene := packed.instantiate()
		scene.set(&"fade_in", false)
		scene.set(&"transition_enabled", false)
		scene.set(&"fast_mode", true)
		add_child_autofree(scene)
		await get_tree().process_frame
		var stage := scene.get_node_or_null(^"BeatStage") as BeatShotStage
		assert_not_null(stage, "BeatStage существует: %s" % entry["scene"])
		if stage != null:
			for shot_id in entry["shots"]:
				var shot := stage.get_node_or_null(NodePath("Shots/%s" % shot_id)) as Camera3D
				assert_not_null(shot, "кадр %s существует" % shot_id)
		scene.queue_free()
		await get_tree().process_frame
