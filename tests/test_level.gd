extends GutTest
## Тестовая локация и главная сцена инициализируются, персонаж стоит на полу.

const LEVEL_SCENE := "res://scenes/levels/test_level.tscn"
const MAIN_SCENE := "res://scenes/main/main.tscn"


func test_level_instantiates_with_player_and_light() -> void:
	var level := (load(LEVEL_SCENE) as PackedScene).instantiate()
	add_child_autofree(level)
	assert_true(level.get_node_or_null("Sunny") is SunnyController, "в локации есть Санни")
	assert_not_null(level.get_node_or_null("Moonlight"), "направленный свет")
	assert_not_null(level.get_node_or_null("WorldEnvironment"), "окружение")
	assert_not_null(level.get_node_or_null("Geometry/Ramp"), "рампа")


func test_player_lands_on_floor() -> void:
	var level := (load(LEVEL_SCENE) as PackedScene).instantiate()
	add_child_autofree(level)
	var sunny := level.get_node("Sunny") as SunnyController
	await wait_physics_frames(30)
	assert_true(sunny.is_on_floor(), "после спавна Санни стоит на полу")
	assert_gt(sunny.global_position.y, -0.1, "не провалился сквозь пол")


func test_main_scene_runs_level() -> void:
	assert_eq(ProjectSettings.get_setting("application/run/main_scene"), MAIN_SCENE)
	var main := (load(MAIN_SCENE) as PackedScene).instantiate()
	add_child_autofree(main)
	assert_not_null(main.get_node_or_null("Level/Sunny"), "главная сцена запускает тестовую локацию")
