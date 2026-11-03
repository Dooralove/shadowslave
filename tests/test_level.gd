extends GutTest
## Тестовая локация и главная сцена инициализируются, персонаж стоит на полу.

const LEVEL_SCENE := "res://scenes/levels/test_level.tscn"
const MAIN_SCENE := "res://scenes/main/main.tscn"
const MENU_SCENE := "res://scenes/ui/main_menu/main_menu.tscn"


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


func test_project_entry_is_main_menu() -> void:
	assert_eq(ProjectSettings.get_setting("application/run/main_scene"), MENU_SCENE)
	var menu := (load(MENU_SCENE) as PackedScene).instantiate()
	add_child_autofree(menu)
	assert_not_null(menu.find_child("PlayButton", true, false), "меню входа содержит кнопку «Играть»")


func test_main_scene_runs_demo_arena() -> void:
	var main := (load(MAIN_SCENE) as PackedScene).instantiate()
	add_child_autofree(main)
	assert_not_null(main.get_node_or_null("Level/Level/Sunny"), "main.tscn запускает демо-арену с Санни")
	assert_not_null(main.get_node_or_null("Level/SoulSeaController"), "в main.tscn есть переход в Море Души")
	assert_not_null(main.get_node_or_null("Level/InventoryLayer/InventoryPrototype"), "в main.tscn есть прототип инвентаря")
