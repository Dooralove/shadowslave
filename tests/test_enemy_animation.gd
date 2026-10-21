extends GutTest
## Анимации противника соответствуют состояниям его автомата. AI, таймер атаки и
## проигрыватель анимаций продвигаются вручную одинаковыми шагами.

const ENEMY_SCENE := "res://scenes/characters/test_enemy.tscn"
const STEP := 0.05


class FakeTarget extends Node3D:
	var dead := false

	func is_dead() -> bool:
		return dead


var enemy: TestEnemy
var animator: EnemyAnimator
var player: AnimationPlayer
var target: FakeTarget


func before_each() -> void:
	target = FakeTarget.new()
	add_child_autofree(target)
	enemy = (load(ENEMY_SCENE) as PackedScene).instantiate() as TestEnemy
	add_child_autofree(enemy)
	enemy.set_physics_process(false)
	enemy.attack.set_physics_process(false)
	animator = enemy.get_node("Animator") as EnemyAnimator
	animator.set_process(false)
	player = animator.animation_player
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	enemy.target = target
	_place_target(100.0)


func _place_target(distance: float) -> void:
	target.global_position = enemy.global_position + Vector3(0.0, 0.0, -distance)


func _step(seconds: float) -> void:
	var elapsed := 0.0
	while elapsed < seconds - 0.0001:
		enemy.update_ai(STEP)
		enemy.attack.tick(STEP)
		player.advance(STEP)
		animator._process(STEP)
		elapsed += STEP


func _step_until(state: TestEnemy.State, limit := 5.0) -> void:
	var elapsed := 0.0
	while enemy.state != state and elapsed < limit:
		_step(STEP)
		elapsed += STEP


func test_model_clips_and_loops() -> void:
	assert_not_null(enemy.get_node_or_null("Visual/Model/Rig/Skeleton3D"), "скелет модели на месте")
	for clip in [animator.idle_clip, animator.chase_clip, animator.attack_clip, animator.hit_clip, animator.death_clip]:
		assert_true(player.has_animation(clip), "нет клипа %s" % clip)
	assert_ne(player.get_animation(animator.idle_clip).loop_mode, Animation.LOOP_NONE)
	assert_ne(player.get_animation(animator.chase_clip).loop_mode, Animation.LOOP_NONE)
	assert_eq(player.get_animation(animator.attack_clip).loop_mode, Animation.LOOP_NONE)
	assert_eq(player.get_animation(animator.death_clip).loop_mode, Animation.LOOP_NONE)
	assert_eq(player.root_motion_track, NodePath(""), "root motion не используется")


func test_model_faces_visual_forward() -> void:
	enemy.visual.rotation.y = -0.9
	var model := enemy.get_node("Visual/Model") as Node3D
	var model_forward := (model.global_basis * Vector3.BACK).normalized()
	var visual_forward := (enemy.visual.global_basis * Vector3.FORWARD).normalized()
	assert_almost_eq(model_forward.x, visual_forward.x, 0.001)
	assert_almost_eq(model_forward.z, visual_forward.z, 0.001)


func test_idle_and_chase_clips() -> void:
	assert_eq(player.assigned_animation, String(animator.idle_clip))
	_place_target(enemy.detection_range - 1.0)
	_step(STEP)
	assert_eq(enemy.state, TestEnemy.State.CHASE)
	assert_eq(player.assigned_animation, String(animator.chase_clip))
	assert_almost_eq(player.speed_scale, enemy.move_speed / animator.chase_clip_speed, 0.001)


func test_attack_clip_spans_telegraph_attack_recovery() -> void:
	_place_target(enemy.attack_distance - 0.2)
	_step_until(TestEnemy.State.TELEGRAPH)
	assert_eq(player.assigned_animation, String(animator.attack_clip), "подготовка — замах из клипа атаки")
	# Клип запущен с нуля в шаге входа в Telegraph и с тех пор продвинулся ровно на один шаг.
	assert_almost_eq(player.current_animation_position, STEP * player.speed_scale, 0.001, "клип с начала")
	assert_between(player.speed_scale, 0.8, 1.2, "клип почти не растянут")

	_step_until(TestEnemy.State.ATTACK)
	assert_eq(player.assigned_animation, String(animator.attack_clip), "удар — тот же клип, без перезапуска")
	assert_true(enemy.attack.is_active())
	# Контакт клипа должен прийтись на окно попадания.
	var position := player.current_animation_position
	var window_in_clip := enemy.attack.stats.active_time * player.speed_scale
	assert_between(animator.attack_contact_time, position - STEP, position + window_in_clip + STEP, "контакт внутри окна попадания")

	_step_until(TestEnemy.State.RECOVERY)
	assert_eq(player.assigned_animation, String(animator.attack_clip), "восстановление — доводка того же клипа")
	assert_false(enemy.attack.is_active(), "в восстановлении окно закрыто")


func test_recovery_falls_back_to_idle_when_clip_ends() -> void:
	_place_target(enemy.attack_distance - 0.2)
	_step_until(TestEnemy.State.RECOVERY)
	# Цель ушла — после восстановления противник ждёт; клип атаки к этому времени закончился.
	_place_target(enemy.lose_range + 5.0)
	_step(enemy.recovery_time + STEP)
	assert_eq(enemy.state, TestEnemy.State.IDLE)
	assert_eq(player.assigned_animation, String(animator.idle_clip))


func test_hit_reaction_only_outside_attack() -> void:
	_place_target(enemy.detection_range - 1.0)
	_step(STEP)
	enemy.health.take_damage(5.0)
	assert_eq(player.assigned_animation, String(animator.hit_clip), "реакция на урон при погоне")
	_step(player.get_animation(animator.hit_clip).length + STEP)
	assert_eq(player.assigned_animation, String(animator.chase_clip), "после реакции — снова погоня")

	_place_target(enemy.attack_distance - 0.2)
	_step_until(TestEnemy.State.TELEGRAPH)
	enemy.health.take_damage(5.0)
	assert_eq(player.assigned_animation, String(animator.attack_clip), "урон не сбивает подготовку удара")
	assert_eq(enemy.state, TestEnemy.State.TELEGRAPH, "и не меняет состояние автомата")


func test_death_clip_is_final_and_attack_disabled() -> void:
	_place_target(enemy.attack_distance - 0.2)
	_step_until(TestEnemy.State.ATTACK)
	assert_true(enemy.attack.is_active())
	enemy.health.take_damage(1000.0)
	assert_eq(enemy.state, TestEnemy.State.DEAD)
	assert_false(enemy.attack.is_attacking(), "смерть обрывает удар")
	assert_eq(player.assigned_animation, String(animator.death_clip))
	enemy.health.damaged.emit(5.0)
	_step(3.0)
	assert_eq(enemy.state, TestEnemy.State.DEAD)
	assert_eq(player.assigned_animation, String(animator.death_clip), "ничто не отменяет смерть")
	assert_false(enemy.attack.try_attack())
