extends GutTest
## FallRecovery: смертельное падение возвращает Санни на безопасный пол или чекпоинт;
## телепорт скриптом и падение во время постановки возвратом не считаются.

const SUNNY_SCENE := "res://scenes/characters/sunny.tscn"

var sunny: SunnyController
var recovery: FallRecovery
var floor_body: StaticBody3D


func before_each() -> void:
	floor_body = _platform(Vector3.ZERO, Vector3(6, 1, 6))
	sunny = (load(SUNNY_SCENE) as PackedScene).instantiate() as SunnyController
	add_child_autofree(sunny)
	sunny.global_position = Vector3(0, 0.05, 0)
	sunny.attack.set_physics_process(false)
	recovery = sunny.get_node("FallRecovery") as FallRecovery
	# Постоять на полу, чтобы узел запомнил безопасную точку.
	await wait_physics_frames(30)


func test_sunny_has_fall_recovery() -> void:
	assert_not_null(recovery)
	assert_eq(sunny.collision_mask & 32, 32, "тело Санни упирается в стены границы (слой 6)")
	assert_eq(sunny.camera_rig.spring_arm.collision_mask & 32, 0, "пружина камеры проходит сквозь стены границы и не дёргается")


func test_fall_returns_to_safe_ground() -> void:
	var safe: Vector3 = recovery.recovery_point()
	assert_almost_eq(safe.y, 0.0, 0.2, "безопасная точка — на полу")
	watch_signals(recovery)
	await _walk_off_edge()
	await wait_physics_frames(150)
	assert_signal_emitted(recovery, "recovered")
	var target: Vector3 = get_signal_parameters(recovery, "recovered")[0]
	assert_almost_eq(target.y, safe.y, 0.2, "возврат — на пол платформы")
	# Платформа до x = 3: безопасная точка идёт за Санни, но не ближе safe_radius к краю.
	assert_lte(target.x, 3.0 - recovery.safe_radius + 0.01, "безопасная точка не на самом краю платформы")


func test_checkpoint_wins_over_safe_ground() -> void:
	var checkpoint := Vector3(1, 0.05, -1)
	recovery.set_checkpoint(checkpoint)
	assert_eq(recovery.recovery_point(), checkpoint)
	watch_signals(recovery)
	await _walk_off_edge()
	await wait_physics_frames(150)
	assert_signal_emitted_with_parameters(recovery, "recovered", [checkpoint])


func test_teleport_is_not_a_fall() -> void:
	_platform(Vector3(0, -40, 0), Vector3(6, 1, 6))
	watch_signals(recovery)
	sunny.global_position = Vector3(0, -39.95, 0)
	await wait_physics_frames(30)
	assert_signal_not_emitted(recovery, "recovered", "перенос скриптом на 40 м вниз — не падение")
	assert_almost_eq(recovery.recovery_point().y, -40.0, 0.2, "после телепорта отсчёт с нового пола")


func test_scripted_fall_is_ignored() -> void:
	sunny.input_enabled = false
	floor_body.queue_free()
	watch_signals(recovery)
	await wait_physics_frames(150)
	assert_signal_not_emitted(recovery, "recovered", "во время постановки возврата нет")


func test_death_with_active_checkpoint_recovers_immediately() -> void:
	var n08 := load("res://resources/campaign/beats/n08.tres") as BeatData
	assert_not_null(n08)
	assert_true(recovery.apply_beat_checkpoint(n08))
	assert_eq(recovery.get_checkpoint_id(), &"CP-N08")
	var expected_pos := n08.get_checkpoint_position(&"CP-N08")
	sunny.global_position = Vector3(2.2, 0.05, -1.5)
	watch_signals(recovery)
	sunny.health.take_damage(sunny.health.max_health)
	assert_signal_emitted_with_parameters(recovery, "recovered", [expected_pos])
	assert_false(sunny.is_dead(), "смерть при активном чекпоинте возвращает Санни к жизни")
	assert_true(sunny.controls_enabled)
	assert_eq(sunny.global_position, expected_pos)


func test_death_recovery_restores_idle_animation_pose() -> void:
	var animator := sunny.get_node("Animator") as SunnyAnimator
	var player := animator.animation_player
	sunny.health.take_damage(sunny.health.max_health)
	assert_eq(animator.state, SunnyAnimator.State.DEAD)
	assert_eq(player.assigned_animation, String(animator.death_clip))
	recovery.recover()
	assert_eq(animator.state, SunnyAnimator.State.IDLE, "после возврата аниматор снова в IDLE")
	assert_eq(player.assigned_animation, String(animator.idle_clip), "death-клип заменён на idle")
	assert_true(animator.is_physics_processing(), "аниматор снова обновляется")


func test_checkpoint_survives_cutscene_and_scripted_teleport_without_false_recovery() -> void:
	var checkpoint := Vector3(-1.5, 0.05, 1.0)
	recovery.set_named_checkpoint(&"CP-N15a", checkpoint)
	watch_signals(recovery)

	sunny.input_enabled = false
	sunny.global_position = Vector3(0.0, -25.0, 0.0)
	await wait_physics_frames(15)
	assert_signal_not_emitted(recovery, "recovered", "катсцена не вызывает ложного возврата")
	assert_true(recovery.has_checkpoint(), "явный чекпоинт не стирается катсценой")
	assert_eq(recovery.get_checkpoint_id(), &"CP-N15a")

	sunny.input_enabled = true
	sunny.global_position = Vector3(0.0, 0.05, 0.0)
	await wait_physics_frames(10)
	assert_signal_not_emitted(recovery, "recovered", "телепорт скриптом не вызывает ложного возврата")
	assert_eq(recovery.recovery_point(), checkpoint, "после катсцены и телепорта активен тот же чекпоинт")



func _platform(center: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	add_child_autofree(body)
	body.global_position = center - Vector3(0, size.y * 0.5, 0)
	return body


## Шагами меньше порога телепорта, как при ходьбе, — за край платформы.
func _walk_off_edge() -> void:
	for i in 80:
		sunny.global_position.x += 0.06
		await wait_physics_frames(1)
		if not sunny.is_on_floor() and sunny.global_position.x > 3.5:
			return
