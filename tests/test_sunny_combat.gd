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


## Горизонтальное направление от атаки к её дочернему узлу в мировых координатах.
func _direction_to(child_name: String) -> Vector3:
	var child := sunny.attack.get_node(child_name) as Node3D
	var offset := child.global_position - sunny.attack.global_position
	offset.y = 0.0
	return offset.normalized()


## Куда смотрит модель при заданном рыскании: Visual смотрит вдоль -Z.
func _forward_for_yaw(yaw: float) -> Vector3:
	return Basis(Vector3.UP, yaw) * Vector3.FORWARD


func _assert_direction(actual: Vector3, expected: Vector3, text: String) -> void:
	assert_almost_eq(actual.x, expected.x, 0.001, text + " (x)")
	assert_almost_eq(actual.z, expected.z, 0.001, text + " (z)")


func test_camera_rotation_does_not_change_attack_direction() -> void:
	sunny.visual.rotation.y = 0.5
	sunny.camera_rig.yaw = 2.5
	sunny.camera_rig.set_pitch(sunny.camera_rig.pitch)
	assert_true(sunny.try_attack())
	assert_almost_eq(sunny.visual.rotation.y, 0.5, 0.0001, "атака не разворачивает модель к камере")
	_assert_direction(_direction_to("CollisionShape3D"), _forward_for_yaw(0.5), "зона удара — по взгляду модели")
	_assert_direction(_direction_to("SwingVisual"), _forward_for_yaw(0.5), "визуализация удара — туда же")


func test_attack_direction_locked_during_hit_window() -> void:
	sunny.visual.rotation.y = 0.5
	sunny.try_attack()
	# Модель поворачивается во время окна попадания (например, Санни начал двигаться), камера тоже.
	sunny.visual.rotation.y = -1.2
	sunny.camera_rig.yaw = 1.0
	sunny.attack.tick(0.05)
	assert_true(sunny.attack.is_active())
	_assert_direction(_direction_to("CollisionShape3D"), _forward_for_yaw(0.5), "зона удара зафиксирована")
	_assert_direction(_direction_to("SwingVisual"), _forward_for_yaw(0.5), "визуализация зафиксирована")

	sunny.attack.tick(sunny.attack.stats.active_time)
	assert_false(sunny.attack.is_active())
	_assert_direction(_direction_to("CollisionShape3D"), _forward_for_yaw(-1.2), "после удара зона снова следует за моделью")


func test_no_attack_and_no_controls_after_death() -> void:
	sunny.health.take_damage(sunny.health.max_health)
	assert_true(sunny.is_dead())
	assert_false(sunny.controls_enabled)
	assert_false(sunny.attack.enabled)
	assert_false(sunny.try_attack())
	sunny.attack.tick(10.0)
	assert_false(sunny.try_attack(), "и после любой паузы тоже")
