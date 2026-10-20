extends GutTest
## Smoke test: проверяет, что тестовое окружение работает и основная сцена загружается.


func test_engine_is_godot_4_7() -> void:
	var info := Engine.get_version_info()
	assert_eq(info["major"], 4, "Godot major version")
	assert_eq(info["minor"], 7, "Godot minor version")


func test_main_scene_loads() -> void:
	var scene := load("res://scenes/main/main.tscn")
	assert_not_null(scene, "main.tscn должна загружаться")


func test_main_scene_instantiates() -> void:
	var scene := load("res://scenes/main/main.tscn") as PackedScene
	var instance := scene.instantiate()
	add_child_autofree(instance)
	assert_not_null(instance, "main.tscn должна инстанцироваться")
