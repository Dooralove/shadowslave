extends GutTest
## Проверки автомата Горного Короля без запуска физики сцены:
## смена состояний, перезарядка атак, укрытие, BLOCKED, отступление и смерть.

const KING_SCENE := "res://scenes/characters/mountain_king.tscn"
const STEP := 0.05


class FakeTarget extends Node3D:
	var dead := false

	func is_dead() -> bool:
		return dead


var king: MountainKing
var target: FakeTarget


func before_each() -> void:
	target = FakeTarget.new()
	add_child_autofree(target)
	king = (load(KING_SCENE) as PackedScene).instantiate() as MountainKing
	add_child_autofree(king)
	king.set_physics_process(false)
	king.attack.set_physics_process(false)
	king.target = target
	_place_target(100.0)


func _place_target(distance: float) -> void:
	target.global_position = king.global_position + Vector3(0.0, 0.0, -distance)


func _step(seconds: float) -> void:
	var elapsed := 0.0
	while elapsed < seconds - 0.0001:
		king.update_ai(STEP)
		king.attack.tick(STEP)
		elapsed += STEP


func _time_until(state: MountainKing.State, limit := 8.0) -> float:
	var elapsed := 0.0
	while king.state != state and elapsed < limit:
		king.update_ai(STEP)
		king.attack.tick(STEP)
		elapsed += STEP
	return elapsed


func _make_hurtbox() -> Hurtbox:
	var hurtbox := Hurtbox.new()
	var health := HealthComponent.new()
	hurtbox.add_child(health)
	hurtbox.health = health
	add_child_autofree(hurtbox)
	return hurtbox


func test_starts_dormant_and_does_not_chase_automatically() -> void:
	_place_target(5.0)
	_step(1.0)
	assert_eq(king.state, MountainKing.State.DORMANT, "до триггера засады монстр спит")
	assert_false(king.is_awake())


func test_activation_starts_chase_even_beyond_detection_range() -> void:
	_place_target(king.config.detection_range + 4.0)
	assert_true(king.activate(), "цель уже существует")
	assert_eq(king.state, MountainKing.State.CHASE)
	_step(STEP)
	assert_eq(king.state, MountainKing.State.CHASE)


func test_activation_can_wait_for_target_that_appears_later() -> void:
	king.target = null
	assert_false(king.activate())
	assert_eq(king.state, MountainKing.State.DORMANT)

	var late_target := FakeTarget.new()
	late_target.add_to_group(&"player")
	add_child_autofree(late_target)
	late_target.global_position = king.global_position + Vector3(0.0, 0.0, -6.0)

	king.update_ai(STEP)
	assert_eq(king.state, MountainKing.State.CHASE, "после активации цель находится, когда появляется")


func test_full_attack_cycle_and_cooldown_between_attacks() -> void:
	_place_target(king.config.attack_distance - 0.2)
	king.activate()
	_step(STEP)
	assert_eq(king.state, MountainKing.State.TELEGRAPH)
	assert_true(king.telegraph_visual.visible, "подготовка видна")
	assert_false(king.attack.is_active(), "во время подготовки урона нет")

	var elapsed := _time_until(MountainKing.State.ATTACK)
	assert_almost_eq(elapsed, king.config.telegraph_time, STEP * 1.01)
	assert_true(king.attack.is_active(), "окно попадания открыто")

	elapsed = _time_until(MountainKing.State.RECOVERY)
	assert_almost_eq(elapsed, king.attack.stats.active_time, STEP * 1.01)

	elapsed = _time_until(MountainKing.State.CHASE)
	assert_almost_eq(elapsed, king.config.recovery_time, STEP * 1.01)
	assert_gt(king.get_attack_cooldown_left(), 0.0, "после атаки ещё действует пауза")

	var remaining := king.get_attack_cooldown_left()
	var wait_to_next := _time_until(MountainKing.State.TELEGRAPH)
	assert_almost_eq(wait_to_next, remaining, STEP * 1.01, "вторая атака ждёт перезарядку")


func test_damage_only_during_attack_window_and_once_per_swing() -> void:
	var victim := _make_hurtbox()
	_place_target(king.config.attack_distance - 0.2)
	king.activate()
	_step(2.0 * STEP)
	assert_eq(king.state, MountainKing.State.TELEGRAPH)
	assert_false(king.attack.apply_hit(victim), "подготовка не наносит урон")

	_step(king.config.telegraph_time + STEP)
	assert_eq(king.state, MountainKing.State.ATTACK)
	assert_true(king.attack.apply_hit(victim), "удар наносит урон")
	assert_false(king.attack.apply_hit(victim), "повторно в том же ударе — нет")
	assert_eq(victim.health.current_health, victim.health.max_health - king.attack.stats.damage)


func test_cover_cancels_telegraph_and_blocks_new_attacks() -> void:
	_place_target(king.config.attack_distance - 0.2)
	king.activate()
	_step(STEP)
	assert_eq(king.state, MountainKing.State.TELEGRAPH)

	king.set_player_hidden(true)
	assert_eq(king.state, MountainKing.State.CHASE, "укрытие отменяет подготовку")
	_step(2.0)
	assert_eq(king.state, MountainKing.State.CHASE, "в укрытии монстр не атакует")
	assert_false(king.attack.is_active())

	king.set_player_hidden(false)
	_step(STEP)
	assert_eq(king.state, MountainKing.State.TELEGRAPH, "после выхода из укрытия атака снова доступна")


func test_leaving_range_returns_to_dormant_and_reacquires() -> void:
	_place_target(5.0)
	king.activate()
	_step(STEP)
	assert_eq(king.state, MountainKing.State.CHASE)

	_place_target(king.config.lose_range + 2.0)
	_step(STEP)
	assert_eq(king.state, MountainKing.State.DORMANT, "вне радиуса потери — сон")

	_place_target(king.config.detection_range - 1.0)
	_step(STEP)
	assert_eq(king.state, MountainKing.State.CHASE, "в радиусе обнаружения — снова погоня")


func test_disable_and_reactivate_ai() -> void:
	_place_target(5.0)
	king.activate()
	_step(STEP)
	assert_eq(king.state, MountainKing.State.CHASE)

	king.set_ai_enabled(false)
	assert_eq(king.state, MountainKing.State.DORMANT)
	assert_false(king.is_ai_enabled())
	_step(2.0)
	assert_eq(king.state, MountainKing.State.DORMANT, "выключенный AI не меняет состояние")

	king.set_ai_enabled(true)
	assert_eq(king.state, MountainKing.State.CHASE, "повторная активация снова запускает погоню")
	assert_true(king.attack.enabled)


func test_blocked_does_not_push_into_wall_forever() -> void:
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(8.0, 5.0, 1.0)
	shape.shape = box
	shape.position.y = 2.5
	wall.add_child(shape)
	wall.collision_layer = 1
	add_child_autofree(wall)
	wall.global_position = Vector3(0.0, 0.0, -3.0)
	_place_target(6.0)
	await wait_physics_frames(2)
	assert_false(king.has_clear_path_to_target(), "стена перекрывает прямую линию")
	king.activate()
	assert_eq(king.state, MountainKing.State.CHASE)

	king.notify_blocked()
	assert_eq(king.state, MountainKing.State.BLOCKED)
	_step(king.config.blocked_wait_time + king.config.blocked_retry_delay + 0.3)
	assert_eq(king.state, MountainKing.State.BLOCKED, "стоя в BLOCKED, монстр не идёт в стену")

	wall.global_position = Vector3(100.0, 0.0, 0.0)
	await wait_physics_frames(2)
	_step(king.config.blocked_retry_delay + 0.3)
	assert_eq(king.state, MountainKing.State.CHASE, "когда путь освободился, погоня продолжается")


func test_retreat_finishes_and_returns_to_dormant() -> void:
	watch_signals(king)
	assert_true(king.start_retreat(king.global_position + Vector3(0.0, 0.0, 8.0), 1.0))
	assert_eq(king.state, MountainKing.State.RETREAT)
	_step(1.1)
	assert_eq(king.state, MountainKing.State.DORMANT)
	assert_signal_emit_count(king, "retreat_finished", 1)
	_step(1.0)
	assert_signal_emit_count(king, "retreat_finished", 1, "сигнал отступления одноразовый")


func test_death_stops_everything() -> void:
	_place_target(king.config.attack_distance - 0.2)
	king.activate()
	_step(2.0 * STEP)
	assert_eq(king.state, MountainKing.State.TELEGRAPH)

	king.health.take_damage(10000.0)
	assert_eq(king.state, MountainKing.State.DEAD)
	assert_false(king.telegraph_visual.visible)
	assert_eq(king.collision_layer, 0)
	_step(2.0)
	assert_eq(king.state, MountainKing.State.DEAD)
	assert_false(king.attack.try_attack(), "мёртвый не атакует")
