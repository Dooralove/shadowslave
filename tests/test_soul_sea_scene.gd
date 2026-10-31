extends GutTest
## Контракт визуальной сцены Моря Души: отдельная камера с собственным
## окружением, слой 2 и отсутствие физики/второго тела внутри сцены.

const SOUL_SEA_SCENE := preload("res://scenes/soul_sea/soul_sea.tscn")

var _soul: SoulSeaScene


func before_each() -> void:
	_soul = SOUL_SEA_SCENE.instantiate() as SoulSeaScene
	add_child_autofree(_soul)


func test_scene_has_camera_beacon_and_no_duplicate_body() -> void:
	assert_not_null(_soul, "сцена Моря Души инстанцируется")
	assert_not_null(_soul.get_node_or_null("CameraRig/Camera3D"), "у сцены своя камера")
	assert_not_null(_soul.get_node_or_null("MemoryBeacon/Core"), "у сцены есть тестовая Память")
	assert_true(_soul.find_children("*", "CollisionObject3D", true, false).is_empty(), "в сцене нет физики")
	assert_true(_soul.find_children("*", "CharacterBody3D", true, false).is_empty(), "в сцене нет второго тела")
	assert_true(_soul.find_children("Health", "", true, false).is_empty(), "в сцене нет второго HealthComponent")
	assert_true(_soul.beacon.is_in_group(&"soul_sea_beacon"), "Память зарегистрирована для взаимодействия")


func test_camera_uses_local_environment_and_layer_two() -> void:
	var camera := _soul.get_camera()
	assert_not_null(camera, "камера доступна через API сцены")
	assert_eq(camera.cull_mask, 2, "камера видит только слой Моря Души")
	assert_not_null(camera.environment, "у камеры есть environment override")
	assert_not_null(camera.environment.sky, "у override есть собственное небо")
	assert_true(camera.environment.sky.sky_material is ShaderMaterial, "небо — авторский шейдер")
	assert_null(_soul.find_child("WorldEnvironment", true, false), "в сцене нет второго WorldEnvironment")


func test_all_visual_nodes_are_isolated_on_layer_two() -> void:
	var visuals := _soul.find_children("*", "VisualInstance3D", true, false)
	assert_gt(visuals.size(), 0, "в сцене есть визуальные узлы")
	for node in visuals:
		if node is Light3D:
			assert_eq((node as Light3D).light_cull_mask, 2, "свет %s не освещает обычный мир" % node.name)
		else:
			assert_eq((node as VisualInstance3D).layers, 2, "узел %s не попадает в обычную камеру" % node.name)
