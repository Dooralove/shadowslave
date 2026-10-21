extends GutTest
## Визуальное подтверждение попадания: вспышка в точке контакта и подсветка урона.

const SUNNY_SCENE := "res://scenes/characters/sunny.tscn"

var sunny: SunnyController


func before_each() -> void:
	sunny = (load(SUNNY_SCENE) as PackedScene).instantiate() as SunnyController
	add_child_autofree(sunny)
	sunny.attack.set_physics_process(false)


func after_each() -> void:
	for spark in get_tree().get_nodes_in_group("hit_spark"):
		spark.free()


func _make_target_in_front() -> Hurtbox:
	var hurtbox := Hurtbox.new()
	var shape := CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	shape.position = Vector3(0.0, 1.0, 0.0)
	hurtbox.add_child(shape)
	var health := HealthComponent.new()
	hurtbox.add_child(health)
	hurtbox.health = health
	add_child_autofree(hurtbox)
	hurtbox.global_position = sunny.global_position + Vector3(0.0, 0.0, -1.5)
	return hurtbox


func test_spark_appears_only_on_real_hit() -> void:
	var target := _make_target_in_front()
	sunny.try_attack()
	assert_eq(get_tree().get_nodes_in_group("hit_spark").size(), 0, "подготовка без вспышки")
	sunny.attack.tick(sunny.attack.stats.windup_time)
	sunny.attack.apply_hit(target)
	assert_eq(get_tree().get_nodes_in_group("hit_spark").size(), 1, "вспышка по факту попадания")
	sunny.attack.apply_hit(target)
	assert_eq(get_tree().get_nodes_in_group("hit_spark").size(), 1, "повторного попадания нет — нет и вспышки")


func test_spark_is_between_attacker_and_target() -> void:
	var target := _make_target_in_front()
	var spark_component := sunny.get_node("HitSpark") as HitSpark
	var point := spark_component.contact_point(target)
	assert_between(point.z, target.global_position.z, sunny.global_position.z, "точка контакта со стороны атакующего")
	assert_almost_eq(point.x, 0.0, 0.001)


func test_flash_survives_rapid_repeated_hits() -> void:
	var flash := sunny.get_node("HitFlash") as HitFlash
	# Длинная вспышка, чтобы шаг ожидания GUT (целые кадры) не влиял на результат.
	flash.duration = 0.5
	sunny.health.take_damage(1.0)
	await wait_seconds(flash.duration * 0.6)
	sunny.health.take_damage(1.0)
	await wait_seconds(flash.duration * 0.6)
	assert_true(flash.is_flashing(), "первый таймер не гасит подсветку второго попадания")
	await wait_seconds(flash.duration)
	assert_false(flash.is_flashing(), "подсветка гаснет после последнего попадания")
