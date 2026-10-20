extends GutTest
## Структура сцены Санни и базовая логика камеры. Качество физики здесь не проверяется.

const SUNNY_SCENE := "res://scenes/characters/sunny.tscn"


func _spawn_sunny() -> SunnyController:
	var sunny := (load(SUNNY_SCENE) as PackedScene).instantiate() as SunnyController
	add_child_autofree(sunny)
	return sunny


func test_scene_loads() -> void:
	assert_not_null(load(SUNNY_SCENE), "sunny.tscn должна загружаться")


func test_root_is_character_body_with_controller() -> void:
	var sunny := _spawn_sunny()
	assert_true(sunny is CharacterBody3D)
	assert_true(sunny is SunnyController)


func test_required_nodes_exist() -> void:
	var sunny := _spawn_sunny()
	for path in ["CollisionShape3D", "Visual", "CameraRig", "CameraRig/SpringArm3D", "CameraRig/SpringArm3D/Camera3D"]:
		assert_not_null(sunny.get_node_or_null(path), "нет узла %s" % path)
	assert_true(sunny.get_node("CollisionShape3D").shape is CapsuleShape3D, "коллизия — капсула")
	assert_true(sunny.get_node("CameraRig") is ThirdPersonCamera)


func test_camera_pitch_is_clamped() -> void:
	var rig := _spawn_sunny().get_node("CameraRig") as ThirdPersonCamera
	rig.set_pitch(deg_to_rad(-120.0))
	assert_almost_eq(rig.pitch, deg_to_rad(rig.min_pitch_deg), 0.0001, "нижний предел")
	rig.set_pitch(deg_to_rad(120.0))
	assert_almost_eq(rig.pitch, deg_to_rad(rig.max_pitch_deg), 0.0001, "верхний предел")
	assert_almost_eq(rig.spring_arm.rotation.x, rig.pitch, 0.0001, "тангаж применён к SpringArm3D")


func test_planar_basis_follows_camera_yaw() -> void:
	var rig := _spawn_sunny().get_node("CameraRig") as ThirdPersonCamera
	rig.yaw = PI / 2.0
	var forward := rig.get_planar_basis() * Vector3.FORWARD
	assert_almost_eq(forward.x, -1.0, 0.0001, "при yaw=90° «вперёд» указывает в -X")
	assert_almost_eq(forward.y, 0.0, 0.0001, "движение остаётся горизонтальным")
