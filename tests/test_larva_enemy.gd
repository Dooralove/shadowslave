extends GutTest
## Личинка на базе TestEnemy: данные из EnemyData, цикл подойти → замах →
## удар → пауза, урон только в окне попадания.

const LARVA_SCENE := "res://scenes/enemies/larva_enemy.tscn"
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
	enemy = (load(LARVA_SCENE) as PackedScene).instantiate() as TestEnemy
	add_child_autofree(enemy)
	enemy.set_physics_process(false)
	enemy.attack.set_physics_process(false)
	enemy.target = target
	target.global_position = enemy.global_position + Vector3(0.0, 0.0, -100.0)


func _place_target(distance: float) -> void:
	target.global_position = enemy.global_position + Vector3(0.0, 0.0, -distance)


func _step(seconds: float) -> void:
	var elapsed := 0.0
	while elapsed < seconds - 0.0001:
		enemy.update_ai(STEP)
		enemy.attack.tick(STEP)
		elapsed += STEP


func _make_hurtbox() -> Hurtbox:
	var hurtbox := Hurtbox.new()
	var health := HealthComponent.new()
	hurtbox.add_child(health)
	hurtbox.health = health
	add_child_autofree(hurtbox)
	return hurtbox


func test_larva_uses_enemy_data_and_attack_data() -> void:
	assert_not_null(enemy.data)
	assert_eq(enemy.data.id, &"larva")
	assert_eq(enemy.health.max_health, 55.0)
	assert_true(enemy.attack.stats is AttackData)
	assert_eq((enemy.attack.stats as AttackData).damage, 14.0)
	assert_true(enemy.is_in_group(&"enemy"))
	assert_not_null(enemy.get_node_or_null("Animator") as LarvaAnimator)


func test_larva_cycle_chase_telegraph_attack_recovery() -> void:
	_place_target(enemy.detection_range - 1.0)
	_step(STEP)
	assert_eq(enemy.state, TestEnemy.State.CHASE)

	_place_target(enemy.attack_distance - 0.2)
	_step(STEP)
	assert_eq(enemy.state, TestEnemy.State.TELEGRAPH)
	assert_true(enemy.telegraph_visual.visible, "замах виден")

	_step(enemy.telegraph_time + STEP)
	assert_eq(enemy.state, TestEnemy.State.ATTACK)
	assert_true(enemy.attack.is_active(), "удар открывает окно попадания")

	_step(enemy.attack.stats.active_time + STEP)
	assert_eq(enemy.state, TestEnemy.State.RECOVERY)
	assert_false(enemy.attack.is_active())


func test_larva_damages_only_in_active_window() -> void:
	var victim := _make_hurtbox()
	_place_target(enemy.attack_distance - 0.2)
	_step(2.0 * STEP)
	assert_false(enemy.attack.apply_hit(victim), "замах не наносит урон")
	_step(enemy.telegraph_time + STEP)
	assert_eq(enemy.state, TestEnemy.State.ATTACK)
	assert_true(enemy.attack.apply_hit(victim))
	assert_false(enemy.attack.apply_hit(victim), "один удар — одно попадание")
	assert_eq(victim.health.current_health, victim.health.max_health - 14.0)


func test_larva_arena_loads_with_hud() -> void:
	var arena := (load("res://scenes/levels/larva_arena.tscn") as PackedScene).instantiate()
	add_child_autofree(arena)
	await wait_process_frames(1)
	var enemy_node := arena.get_node("TestEnemy") as TestEnemy
	assert_not_null(enemy_node)
	assert_eq(enemy_node.data.id, &"larva")
	assert_not_null(arena.get_node("HUD") as CombatHud)


func test_larva_death_is_final_and_does_not_block() -> void:
	_place_target(enemy.attack_distance - 0.2)
	_step(2.0 * STEP)
	enemy.health.take_damage(1000.0)
	assert_eq(enemy.state, TestEnemy.State.DEAD)
	assert_eq(enemy.collision_layer, 0)
	_step(4.0)
	assert_eq(enemy.state, TestEnemy.State.DEAD)
