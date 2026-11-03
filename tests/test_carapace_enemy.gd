extends GutTest
## Canon carapace scavenger: data, scuttle direction, independent AI cycle,
## attack/health contract and final death.

const ENEMY_SCENE := "res://scenes/enemies/carapace_enemy.tscn"

var enemy: CarapaceEnemy
var target: Node3D


func before_each() -> void:
	enemy = (load(ENEMY_SCENE) as PackedScene).instantiate() as CarapaceEnemy
	add_child_autofree(enemy)
	target = Node3D.new()
	add_child_autofree(target)
	enemy.target = target
	enemy.global_position = Vector3.ZERO


func test_uses_canonical_data_and_attack() -> void:
	assert_eq(enemy.data.id, &"carapace_scavenger")
	assert_eq(enemy.get_display_name(), "Карапакс-падальщик")
	assert_eq(enemy.health.max_health, 95.0)
	assert_eq(enemy.attack.stats.attack_name, "Удар клешнёй")
	assert_eq(enemy.state, CarapaceEnemy.State.IDLE)


func test_has_carapace_rig_and_five_clips() -> void:
	var skeleton := enemy.find_child("Skeleton3D", true, false) as Skeleton3D
	assert_not_null(skeleton)
	assert_eq(skeleton.get_bone_count(), 38)
	var player := enemy.find_child("AnimationPlayer", true, false) as AnimationPlayer
	assert_not_null(player)
	for clip in [&"Attack", &"Death", &"Idle", &"Telegraph", &"Walk"]:
		assert_true(player.has_animation(clip), "missing clip " + String(clip))


func test_scuttle_is_not_a_straight_line() -> void:
	enemy.state = CarapaceEnemy.State.CHASE
	target.global_position = Vector3(0, 0, -10)
	enemy._state_time = 0.22
	var v := enemy._desired_velocity()
	assert_almost_eq(v.length(), enemy.move_speed, 0.01)
	assert_gt(absf(v.x), 0.05, "crab moves sideways as well as forward")


func test_separate_ai_cycle_chase_telegraph_attack_recovery() -> void:
	target.global_position = Vector3(0, 0, -5)
	enemy.update_ai(0.01)
	assert_eq(enemy.state, CarapaceEnemy.State.CHASE)

	target.global_position = Vector3(0, 0, -1.5)
	enemy.update_ai(0.01)
	assert_eq(enemy.state, CarapaceEnemy.State.TELEGRAPH)

	enemy.update_ai(enemy.telegraph_time + 0.01)
	assert_eq(enemy.state, CarapaceEnemy.State.ATTACK)
	assert_true(enemy.attack.is_active(), "атака открыла окно")

	enemy.attack.tick(enemy.attack.stats.active_time + 0.01)
	enemy.update_ai(0.01)
	assert_eq(enemy.state, CarapaceEnemy.State.RECOVERY)

	enemy.update_ai(enemy.recovery_time + 0.01)
	assert_eq(enemy.state, CarapaceEnemy.State.CHASE)


func test_death_is_final_and_does_not_block() -> void:
	target.global_position = Vector3(0, 0, -5)
	enemy.update_ai(0.01)
	enemy.health.take_damage(1000.0)
	assert_eq(enemy.state, CarapaceEnemy.State.DEAD)
	assert_eq(enemy.collision_layer, 0)
	assert_eq(enemy.collision_mask, 0)
	assert_false(enemy.attack.enabled)
	enemy.update_ai(10.0)
	assert_eq(enemy.state, CarapaceEnemy.State.DEAD)


func test_attack_contact_time_matches_measured_claw_clip() -> void:
	var animator := enemy.get_node("Animator") as CarapaceAnimator
	assert_not_null(animator)
	assert_almost_eq(animator.attack_contact_time, 0.40, 0.001, "LeftPincer peak in Attack clip")
	assert_almost_eq(enemy.attack.stats.contact_time, 0.40, 0.001, "data and animator agree")


func test_dormant_encounter_does_not_block_until_activated() -> void:
	enemy.set_dormant(true)
	assert_true(enemy.is_dormant())
	assert_eq(enemy.collision_layer, 0, "спящий не блокирует маршрут")
	enemy.set_dormant(false)
	assert_false(enemy.is_dormant())
	assert_eq(enemy.collision_layer, 4, "после активации тело снова на слое enemy")


func test_blocked_cooldown_returns_to_idle_without_oscillating() -> void:
	target.global_position = Vector3(0, 0, -5)
	enemy.update_ai(0.01)
	assert_eq(enemy.state, CarapaceEnemy.State.CHASE)
	enemy.notify_blocked()
	assert_eq(enemy.state, CarapaceEnemy.State.IDLE)
	enemy.update_ai(0.1)
	assert_eq(enemy.state, CarapaceEnemy.State.IDLE, "пауза после блокировки не даёт мгновенно снова aggro")
	enemy.update_ai(enemy.blocked_cooldown + 0.1)
	assert_eq(enemy.state, CarapaceEnemy.State.CHASE)


func test_stuck_detection_releases_target_after_three_attempts() -> void:
	enemy.state = CarapaceEnemy.State.CHASE
	enemy._stuck_attempts = 0
	for i in 4:
		enemy._update_stuck(0.8, enemy.global_position, enemy.move_speed)
	assert_eq(enemy.state, CarapaceEnemy.State.IDLE, "три неудачных обхода отпускают цель")
	assert_gt(enemy._blocked_left, 0.0, "после застревания есть пауза перед новым aggro")


func test_death_during_attack_closes_hit_window() -> void:
	var victim := Hurtbox.new()
	var victim_health := HealthComponent.new()
	victim_health.max_health = 100.0
	victim.add_child(victim_health)
	victim.health = victim_health
	add_child_autofree(victim)
	target.global_position = Vector3(0, 0, -1.5)
	enemy.update_ai(0.01)
	assert_eq(enemy.state, CarapaceEnemy.State.CHASE)
	enemy.update_ai(0.01)
	assert_eq(enemy.state, CarapaceEnemy.State.TELEGRAPH)
	enemy.update_ai(enemy.telegraph_time + 0.01)
	assert_eq(enemy.state, CarapaceEnemy.State.ATTACK)
	assert_true(enemy.attack.is_active())
	enemy.health.take_damage(1000.0)
	assert_false(enemy.attack.apply_hit(victim))
	assert_eq(victim_health.current_health, 100.0)
