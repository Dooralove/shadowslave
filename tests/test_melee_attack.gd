extends GutTest
## Правила MeleeAttack: перезарядка, окно попадания, одно попадание по цели за удар.
## Таймеры двигаются вручную через tick(), физика не участвует.

const DAMAGE := 10.0
const COOLDOWN := 0.5
const ACTIVE_TIME := 0.2


func _make_attack(windup := 0.0, with_zone_visual := false) -> MeleeAttack:
	var attack := MeleeAttack.new()
	var shape := CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	attack.add_child(shape)
	if with_zone_visual:
		var zone := MeshInstance3D.new()
		attack.add_child(zone)
		attack.swing_visual = zone
	var stats := AttackStats.new()
	stats.damage = DAMAGE
	stats.cooldown = COOLDOWN
	stats.windup_time = windup
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


func test_phases_windup_active_recovery() -> void:
	var windup := 0.2
	var attack := _make_attack(windup)
	var target := _make_target()
	watch_signals(attack)
	assert_true(attack.try_attack())
	assert_eq(attack.phase, MeleeAttack.Phase.WINDUP)
	assert_true(attack.is_attacking())
	assert_false(attack.is_active(), "на подготовке окно закрыто")
	assert_false(attack.apply_hit(target), "подготовка не наносит урон")

	attack.tick(windup - 0.01)
	assert_eq(attack.phase, MeleeAttack.Phase.WINDUP)
	attack.tick(0.02)
	assert_eq(attack.phase, MeleeAttack.Phase.ACTIVE, "окно открывается по окончании подготовки")
	assert_true(attack.apply_hit(target))
	assert_false(attack.apply_hit(target), "одно попадание по цели за атаку")

	attack.tick(ACTIVE_TIME)
	assert_eq(attack.phase, MeleeAttack.Phase.RECOVERY)
	assert_false(attack.apply_hit(target), "восстановление не наносит урон")
	assert_false(attack.can_attack(), "новая атака только после восстановления")

	attack.tick(COOLDOWN - windup - ACTIVE_TIME)
	assert_eq(attack.phase, MeleeAttack.Phase.READY)
	assert_true(attack.can_attack())
	assert_eq(target.health.current_health, 100.0 - DAMAGE)
	assert_signal_emit_count(attack, "attack_started", 1)
	assert_signal_emit_count(attack, "hit_window_opened", 1)
	assert_signal_emit_count(attack, "hit_window_closed", 1)
	assert_signal_emit_count(attack, "attack_finished", 1)


func test_attack_cycle_length_equals_cooldown() -> void:
	var attack := _make_attack(0.2)
	attack.try_attack()
	attack.tick(COOLDOWN - 0.01)
	assert_true(attack.is_attacking())
	attack.tick(0.02)
	assert_false(attack.is_attacking(), "подготовка не удлиняет цикл атаки")


func test_disable_during_windup_never_opens_window() -> void:
	var attack := _make_attack(0.2)
	var target := _make_target()
	watch_signals(attack)
	attack.try_attack()
	attack.tick(0.1)
	attack.disable()
	assert_eq(attack.phase, MeleeAttack.Phase.READY)
	attack.tick(1.0)
	assert_false(attack.apply_hit(target))
	assert_signal_not_emitted(attack, "hit_window_opened")
	assert_false(attack.try_attack())


func test_hit_zone_visual_is_hidden_unless_debug_enabled() -> void:
	var attack := _make_attack(0.2, true)
	attack.try_attack()
	attack.tick(0.25)
	assert_true(attack.is_active())
	assert_false(attack.swing_visual.visible, "в обычной игре зона удара не показывается")


func test_debug_hit_zone_shows_only_in_hit_window() -> void:
	var attack := _make_attack(0.2, true)
	attack.show_hit_zone = true
	attack.try_attack()
	assert_false(attack.swing_visual.visible, "на подготовке скрыта")
	attack.tick(0.25)
	assert_true(attack.swing_visual.visible, "в окне попадания видна")
	attack.tick(ACTIVE_TIME)
	assert_false(attack.swing_visual.visible, "на восстановлении скрыта")


func test_dead_target_takes_no_hit() -> void:
	var attack := _make_attack()
	var target := _make_target(5.0)
	target.health.take_damage(5.0)
	attack.try_attack()
	assert_false(attack.apply_hit(target))
