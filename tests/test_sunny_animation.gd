extends GutTest
## Анимационный слой Санни: модель и клипы на месте, переходы по состоянию тела,
## боевые события не влияют на урон, смерть необратима. Аниматор двигается вручную через update().

const SUNNY_SCENE := "res://scenes/characters/sunny.tscn"
const MODEL := "res://assets/characters/sunny_placeholder/Rogue_Hooded.glb"
const DT := 1.0 / 60.0

var sunny: SunnyController
var animator: SunnyAnimator
var player: AnimationPlayer


func before_each() -> void:
	sunny = (load(SUNNY_SCENE) as PackedScene).instantiate() as SunnyController
	add_child_autofree(sunny)
	animator = sunny.get_node("Animator") as SunnyAnimator
	animator.set_physics_process(false)
	sunny.attack.set_physics_process(false)
	player = animator.animation_player


func _clips() -> Array[StringName]:
	return [animator.idle_clip, animator.walk_clip, animator.run_clip, animator.jump_clip, animator.fall_clip,
		animator.land_clip, animator.attack_clip, animator.hit_clip, animator.death_clip]


func _make_target() -> Hurtbox:
	var hurtbox := Hurtbox.new()
	var health := HealthComponent.new()
	hurtbox.add_child(health)
	hurtbox.health = health
	add_child_autofree(hurtbox)
	return hurtbox


func test_model_loads_with_skeleton_and_player() -> void:
	assert_not_null(load(MODEL), "модель импортирована")
	assert_not_null(sunny.get_node_or_null("Visual/Model/Rig/Skeleton3D"), "скелет на месте")
	assert_not_null(player, "AnimationPlayer модели подключён к аниматору")
	assert_eq(player.root_motion_track, NodePath(""), "root motion не используется")


func test_all_used_clips_exist() -> void:
	for clip in _clips():
		assert_true(player.has_animation(clip), "нет клипа %s" % clip)


func test_loop_modes() -> void:
	for clip in [animator.idle_clip, animator.walk_clip, animator.run_clip, animator.fall_clip]:
		assert_ne(player.get_animation(clip).loop_mode, Animation.LOOP_NONE, "%s должен зацикливаться" % clip)
	for clip in [animator.jump_clip, animator.land_clip, animator.attack_clip, animator.hit_clip, animator.death_clip]:
		assert_eq(player.get_animation(clip).loop_mode, Animation.LOOP_NONE, "%s играет один раз" % clip)


func test_model_faces_visual_forward() -> void:
	sunny.visual.rotation.y = 0.7
	var model := sunny.get_node("Visual/Model") as Node3D
	# Импортированная модель смотрит вдоль своей +Z; после разворота это должно совпасть с -Z узла Visual.
	var model_forward := (model.global_basis * Vector3.BACK).normalized()
	var visual_forward := (sunny.visual.global_basis * Vector3.FORWARD).normalized()
	assert_almost_eq(model_forward.x, visual_forward.x, 0.001)
	assert_almost_eq(model_forward.z, visual_forward.z, 0.001)


func test_locomotion_follows_speed() -> void:
	animator.update(DT, true, Vector3.ZERO)
	assert_eq(animator.state, SunnyAnimator.State.IDLE)
	animator.update(DT, true, Vector3(3.0, 0.0, 0.0))
	assert_eq(animator.state, SunnyAnimator.State.WALK)
	assert_eq(player.assigned_animation, String(animator.walk_clip))
	assert_almost_eq(player.speed_scale, 3.0 / sunny.walk_speed, 0.001, "шаг подстраивается под скорость")
	animator.update(DT, true, Vector3(0.0, 0.0, -sunny.sprint_speed))
	assert_eq(animator.state, SunnyAnimator.State.RUN)
	assert_eq(player.assigned_animation, String(animator.run_clip))
	animator.update(DT, true, Vector3.ZERO)
	assert_eq(animator.state, SunnyAnimator.State.IDLE)
	assert_eq(player.speed_scale, 1.0)


func test_jump_fall_land_cycle() -> void:
	animator.update(DT, false, Vector3(0.0, sunny.jump_velocity, 0.0))
	assert_eq(animator.state, SunnyAnimator.State.JUMP)
	animator.update(DT, false, Vector3(0.0, -1.0, 0.0))
	assert_eq(animator.state, SunnyAnimator.State.FALL, "на спуске — падение")
	animator.update(DT, true, Vector3.ZERO)
	assert_eq(animator.state, SunnyAnimator.State.LAND)
	animator.update(DT, true, Vector3.ZERO)
	assert_eq(animator.state, SunnyAnimator.State.LAND, "приземление доигрывается, пока персонаж стоит")
	animator.update(DT, true, Vector3(3.0, 0.0, 0.0))
	assert_eq(animator.state, SunnyAnimator.State.WALK, "движение прерывает приземление")


func test_land_finishes_into_idle() -> void:
	animator.update(DT, false, Vector3(0.0, -3.0, 0.0))
	animator.update(animator.fall_delay, false, Vector3(0.0, -3.0, 0.0))
	assert_eq(animator.state, SunnyAnimator.State.FALL)
	animator.update(DT, true, Vector3.ZERO)
	assert_eq(animator.state, SunnyAnimator.State.LAND)
	animator.update(player.get_animation(animator.land_clip).length, true, Vector3.ZERO)
	assert_eq(animator.state, SunnyAnimator.State.IDLE)


func test_short_ground_loss_does_not_trigger_fall() -> void:
	animator.update(DT, true, Vector3(3.0, 0.0, 0.0))
	animator.update(animator.fall_delay * 0.5, false, Vector3(3.0, -0.5, 0.0))
	assert_eq(animator.state, SunnyAnimator.State.WALK, "ступенька не включает падение")
	animator.update(animator.fall_delay, false, Vector3(3.0, -2.0, 0.0))
	assert_eq(animator.state, SunnyAnimator.State.FALL)


func test_attack_plays_from_start_with_contact_in_hit_window() -> void:
	var stats := sunny.attack.stats
	assert_true(sunny.try_attack())
	assert_eq(animator.state, SunnyAnimator.State.ATTACK)
	assert_eq(player.assigned_animation, String(animator.attack_clip))
	assert_almost_eq(player.current_animation_position, 0.0, 0.001, "клип играет с начала")
	assert_almost_eq(player.speed_scale, animator.attack_clip_speed(), 0.0001)
	# Когда в реальном времени наступает контакт клипа.
	var contact_real := animator.attack_contact_time / player.speed_scale
	assert_between(contact_real, stats.windup_time, stats.windup_time + stats.active_time, "контакт внутри окна попадания")
	assert_between(player.speed_scale, 0.8, 1.2, "клип почти не растянут: подготовка взята из самого клипа")


func test_attack_state_follows_attack_phases() -> void:
	var stats := sunny.attack.stats
	sunny.try_attack()
	animator.update(stats.windup_time * 0.5, true, Vector3(3.0, 0.0, 0.0))
	assert_eq(animator.state, SunnyAnimator.State.ATTACK, "подготовка не прерывается движением")
	sunny.attack.tick(stats.windup_time)
	assert_true(sunny.attack.is_active())
	animator.update(DT, true, Vector3(3.0, 0.0, 0.0))
	assert_eq(animator.state, SunnyAnimator.State.ATTACK, "окно попадания")
	sunny.attack.tick(stats.active_time)
	assert_eq(sunny.attack.phase, MeleeAttack.Phase.RECOVERY)
	animator.update(DT, true, Vector3(3.0, 0.0, 0.0))
	assert_eq(animator.state, SunnyAnimator.State.ATTACK, "восстановление")
	sunny.attack.tick(stats.cooldown)
	assert_false(sunny.attack.is_attacking())
	animator.update(DT, true, Vector3(3.0, 0.0, 0.0))
	assert_eq(animator.state, SunnyAnimator.State.WALK, "после атаки — снова передвижение")


func test_reentering_attack_state_does_not_repeat_damage() -> void:
	var target := _make_target()
	sunny.try_attack()
	sunny.attack.tick(sunny.attack.stats.windup_time)
	assert_true(sunny.attack.apply_hit(target))
	var after_hit := target.health.current_health
	# Повторный вход в состояние атаки — только визуальное событие.
	for i in 3:
		sunny.attack.attack_started.emit()
	assert_eq(animator.state, SunnyAnimator.State.ATTACK)
	assert_false(sunny.attack.apply_hit(target), "та же атака не бьёт повторно")
	sunny.attack.tick(sunny.attack.stats.active_time)
	assert_eq(target.health.current_health, after_hit)


func test_hit_reaction_does_not_touch_health() -> void:
	sunny.health.take_damage(10.0)
	assert_eq(animator.state, SunnyAnimator.State.HIT)
	assert_eq(player.assigned_animation, String(animator.hit_clip))
	for i in 60:
		animator.update(DT, true, Vector3.ZERO)
	assert_eq(sunny.health.current_health, sunny.health.max_health - 10.0, "реакция не меняет здоровье")


func test_hit_does_not_interrupt_attack() -> void:
	sunny.try_attack()
	sunny.health.take_damage(10.0)
	assert_eq(animator.state, SunnyAnimator.State.ATTACK)


func test_hit_can_be_interrupted_by_movement() -> void:
	sunny.health.take_damage(10.0)
	animator.update(animator.hit_interrupt_time * 0.5, true, Vector3(3.0, 0.0, 0.0))
	assert_eq(animator.state, SunnyAnimator.State.HIT, "в начале реакция держится")
	animator.update(animator.hit_interrupt_time, true, Vector3(3.0, 0.0, 0.0))
	assert_eq(animator.state, SunnyAnimator.State.WALK)


func test_death_is_final() -> void:
	sunny.health.take_damage(sunny.health.max_health)
	assert_eq(animator.state, SunnyAnimator.State.DEAD)
	assert_eq(player.assigned_animation, String(animator.death_clip))
	assert_false(animator.is_physics_processing(), "аниматор перестаёт обновляться")
	# Ничто не должно отменить смерть.
	sunny.attack.attack_started.emit()
	sunny.health.damaged.emit(5.0)
	for i in 30:
		animator.update(DT, true, Vector3(5.0, 0.0, 0.0))
	animator.update(DT, false, Vector3(0.0, 5.0, 0.0))
	assert_eq(animator.state, SunnyAnimator.State.DEAD)
	assert_eq(player.assigned_animation, String(animator.death_clip))
	assert_false(sunny.try_attack(), "атака после смерти невозможна")
