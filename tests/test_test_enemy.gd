extends GutTest
## Переходы конечного автомата TestEnemy. AI и таймер атаки продвигаются вручную, без физики.

const ENEMY_SCENE := "res://scenes/characters/test_enemy.tscn"
const STEP := 0.05


class FakeTarget extends Node3D:
	var dead := false

	func is_dead() -> bool:
		return dead


var enemy: TestEnemy
var target: FakeTarget


func before_each() -> void:
	target = FakeTarget.new()
	add_child_autofree(target)
	enemy = (load(ENEMY_SCENE) as PackedScene).instantiate() as TestEnemy
	add_child_autofree(enemy)
	enemy.set_physics_process(false)
	enemy.attack.set_physics_process(false)
	enemy.target = target
	_place_target(100.0)


func _place_target(distance: float) -> void:
	target.global_position = enemy.global_position + Vector3(0.0, 0.0, -distance)


func _step(seconds: float) -> void:
	var elapsed := 0.0
	while elapsed < seconds - 0.0001:
		enemy.update_ai(STEP)
		enemy.attack.tick(STEP)
		elapsed += STEP


## Шагает, пока противник не перейдёт в состояние; возвращает затраченное время.
func _time_until(state: TestEnemy.State, limit := 5.0) -> float:
	var elapsed := 0.0
	while enemy.state != state and elapsed < limit:
		enemy.update_ai(STEP)
		enemy.attack.tick(STEP)
		elapsed += STEP
	return elapsed


func _make_hurtbox() -> Hurtbox:
	var hurtbox := Hurtbox.new()
	var health := HealthComponent.new()
	hurtbox.add_child(health)
	hurtbox.health = health
	add_child_autofree(hurtbox)
	return hurtbox


func test_idle_while_target_out_of_range() -> void:
	_step(1.0)
	assert_eq(enemy.state, TestEnemy.State.IDLE)


func test_chases_detected_target() -> void:
	_place_target(enemy.detection_range - 1.0)
	_step(STEP)
	assert_eq(enemy.state, TestEnemy.State.CHASE)


func test_full_attack_cycle() -> void:
	_place_target(enemy.detection_range - 1.0)
	_step(STEP)
	_place_target(enemy.attack_distance - 0.2)
	_step(STEP)
	assert_eq(enemy.state, TestEnemy.State.TELEGRAPH, "в зоне атаки — подготовка")
	assert_true(enemy.telegraph_visual.visible, "подготовка видна")
	assert_false(enemy.attack.is_active(), "во время подготовки урона нет")

	var elapsed := _time_until(TestEnemy.State.ATTACK)
	assert_eq(enemy.state, TestEnemy.State.ATTACK)
	assert_almost_eq(elapsed, enemy.telegraph_time, STEP * 1.01, "подготовка длится telegraph_time")
	assert_true(enemy.attack.is_active(), "в момент атаки окно попадания открыто")

	elapsed = _time_until(TestEnemy.State.RECOVERY)
	assert_eq(enemy.state, TestEnemy.State.RECOVERY)
	assert_almost_eq(elapsed, enemy.attack.stats.active_time, STEP * 1.01, "удар длится active_time")

	# Цель отошла за дистанцию удара, но осталась в зоне обнаружения — после восстановления погоня.
	_place_target(enemy.detection_range - 1.0)
	elapsed = _time_until(TestEnemy.State.CHASE)
	assert_eq(enemy.state, TestEnemy.State.CHASE)
	assert_almost_eq(elapsed, enemy.recovery_time, STEP * 1.01, "восстановление длится recovery_time")


func test_damage_only_during_attack_window() -> void:
	var victim := _make_hurtbox()
	_place_target(enemy.attack_distance - 0.2)
	_step(2.0 * STEP)
	assert_eq(enemy.state, TestEnemy.State.TELEGRAPH)
	assert_false(enemy.attack.apply_hit(victim), "подготовка не наносит урон")
	_step(enemy.telegraph_time + STEP)
	assert_eq(enemy.state, TestEnemy.State.ATTACK)
	assert_true(enemy.attack.apply_hit(victim), "удар наносит урон")
	assert_false(enemy.attack.apply_hit(victim), "но только один раз")
	assert_eq(victim.health.current_health, victim.health.max_health - enemy.attack.stats.damage)


func test_telegraph_faces_target_even_without_chase_turning() -> void:
	# Цель сразу в зоне удара сбоку: погоня длится один шаг, плавный поворот не успевает.
	target.global_position = enemy.global_position + Vector3(enemy.attack_distance - 0.2, 0.0, 0.0)
	_step(2.0 * STEP)
	assert_eq(enemy.state, TestEnemy.State.TELEGRAPH)
	var forward := enemy.visual.global_transform.basis * Vector3.FORWARD
	assert_almost_eq(forward.x, 1.0, 0.001, "удар направлен в сторону цели")


func test_loses_target_out_of_range() -> void:
	_place_target(enemy.detection_range - 1.0)
	_step(STEP)
	_place_target(enemy.lose_range + 1.0)
	_step(STEP)
	assert_eq(enemy.state, TestEnemy.State.IDLE)


func test_ignores_dead_target() -> void:
	_place_target(enemy.detection_range - 1.0)
	_step(STEP)
	target.dead = true
	_step(STEP)
	assert_eq(enemy.state, TestEnemy.State.IDLE)
	_step(1.0)
	assert_eq(enemy.state, TestEnemy.State.IDLE, "мёртвую цель не преследует")


func test_death_stops_everything() -> void:
	_place_target(enemy.attack_distance - 0.2)
	_step(2.0 * STEP)
	assert_eq(enemy.state, TestEnemy.State.TELEGRAPH)
	watch_signals(enemy.health)
	enemy.health.take_damage(1000.0)
	assert_eq(enemy.state, TestEnemy.State.DEAD)
	assert_false(enemy.telegraph_visual.visible)
	_step(3.0)
	assert_eq(enemy.state, TestEnemy.State.DEAD, "мёртвый не меняет состояние")
	assert_false(enemy.attack.try_attack(), "мёртвый не атакует")
	assert_false(enemy.attack.is_active())
	assert_signal_emit_count(enemy.health, "died", 1)
	assert_eq(enemy.collision_layer, 0, "труп не загораживает проход")


func test_death_during_attack_closes_hit_window() -> void:
	var victim := _make_hurtbox()
	_place_target(enemy.attack_distance - 0.2)
	_step(3.0 * STEP + enemy.telegraph_time)
	assert_eq(enemy.state, TestEnemy.State.ATTACK)
	enemy.health.take_damage(1000.0)
	assert_false(enemy.attack.apply_hit(victim), "удар обрывается смертью")
	assert_eq(victim.health.current_health, victim.health.max_health)
