extends GutTest
## Боевые правила Санни: компоненты подключены, атака работает, после смерти атак и управления нет.

const SUNNY_SCENE := "res://scenes/characters/sunny.tscn"

var sunny: SunnyController


func before_each() -> void:
	sunny = (load(SUNNY_SCENE) as PackedScene).instantiate() as SunnyController
	add_child_autofree(sunny)
	sunny.attack.set_physics_process(false)


func test_combat_nodes_are_wired() -> void:
	assert_not_null(sunny.health)
	assert_not_null(sunny.attack)
	var hurtbox := sunny.get_node("Hurtbox") as Hurtbox
	assert_eq(hurtbox.health, sunny.health, "хёртбокс передаёт урон в здоровье Санни")
	assert_eq(sunny.attack.collision_mask, 16, "атака Санни видит только хёртбоксы противников")
	assert_eq(hurtbox.collision_layer, 8, "хёртбокс Санни на слое player_hurtbox")


func test_attack_respects_cooldown() -> void:
	assert_true(sunny.try_attack())
	assert_false(sunny.try_attack(), "вторая атака сразу — нельзя")


func test_attack_faces_camera_direction() -> void:
	sunny.camera_rig.yaw = 1.0
	sunny.try_attack()
	assert_almost_eq(sunny.visual.rotation.y, 1.0, 0.0001)


func test_no_attack_and_no_controls_after_death() -> void:
	sunny.health.take_damage(sunny.health.max_health)
	assert_true(sunny.is_dead())
	assert_false(sunny.controls_enabled)
	assert_false(sunny.attack.enabled)
	assert_false(sunny.try_attack())
	sunny.attack.tick(10.0)
	assert_false(sunny.try_attack(), "и после любой паузы тоже")
