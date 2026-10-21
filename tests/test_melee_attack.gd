extends GutTest
## Правила MeleeAttack: перезарядка, окно попадания, одно попадание по цели за удар.
## Таймеры двигаются вручную через tick(), физика не участвует.

const DAMAGE := 10.0
const COOLDOWN := 0.5
const ACTIVE_TIME := 0.2


func _make_attack() -> MeleeAttack:
	var attack := MeleeAttack.new()
	var shape := CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	attack.add_child(shape)
	var stats := AttackStats.new()
	stats.damage = DAMAGE
	stats.cooldown = COOLDOWN
	stats.active_time = ACTIVE_TIME
	attack.stats = stats
	add_child_autofree(attack)
	attack.set_physics_process(false)
	return attack


func _make_target(max_health := 100.0) -> Hurtbox:
	var hurtbox := Hurtbox.new()
	var health := HealthComponent.new()
	health.max_health = max_health
	hurtbox.add_child(health)
	hurtbox.health = health
	add_child_autofree(hurtbox)
	return hurtbox


func test_attack_opens_hit_window() -> void:
	var attack := _make_attack()
	assert_true(attack.try_attack())
	assert_true(attack.is_active())


func test_cannot_attack_during_cooldown() -> void:
	var attack := _make_attack()
	attack.try_attack()
	attack.tick(ACTIVE_TIME + 0.01)
	assert_false(attack.is_active(), "окно закрылось")
	assert_false(attack.try_attack(), "перезарядка ещё идёт")
	attack.tick(COOLDOWN)
	assert_true(attack.try_attack(), "после перезарядки можно атаковать")


func test_same_target_hit_once_per_swing() -> void:
	var attack := _make_attack()
	var target := _make_target()
	attack.try_attack()
	assert_true(attack.apply_hit(target))
	assert_false(attack.apply_hit(target), "повторное попадание тем же ударом")
	attack.tick(0.05)
	assert_false(attack.apply_hit(target), "и на следующем кадре окна тоже")
	assert_eq(target.health.current_health, 100.0 - DAMAGE)


func test_each_target_hit_once_in_same_swing() -> void:
	var attack := _make_attack()
	var first := _make_target()
	var second := _make_target()
	attack.try_attack()
	assert_true(attack.apply_hit(first))
	assert_true(attack.apply_hit(second))
	assert_eq(first.health.current_health, 100.0 - DAMAGE)
	assert_eq(second.health.current_health, 100.0 - DAMAGE)


func test_new_swing_can_hit_same_target_again() -> void:
	var attack := _make_attack()
	var target := _make_target()
	attack.try_attack()
	attack.apply_hit(target)
	attack.tick(COOLDOWN + 0.01)
	attack.try_attack()
	assert_true(attack.apply_hit(target))
	assert_eq(target.health.current_health, 100.0 - 2.0 * DAMAGE)


func test_no_damage_outside_hit_window() -> void:
	var attack := _make_attack()
	var target := _make_target()
	assert_false(attack.apply_hit(target), "до удара")
	attack.try_attack()
	attack.tick(ACTIVE_TIME + 0.01)
	assert_false(attack.apply_hit(target), "после окна")
	assert_eq(target.health.current_health, 100.0)


func test_disabled_attack_cannot_attack_or_hit() -> void:
	var attack := _make_attack()
	var target := _make_target()
	attack.try_attack()
	attack.disable()
	assert_false(attack.is_active(), "отключение закрывает окно")
	assert_false(attack.apply_hit(target))
	attack.tick(COOLDOWN + 0.01)
	assert_false(attack.try_attack())
	assert_eq(target.health.current_health, 100.0)


func test_dead_target_takes_no_hit() -> void:
	var attack := _make_attack()
	var target := _make_target(5.0)
	target.health.take_damage(5.0)
	attack.try_attack()
	assert_false(attack.apply_hit(target))
