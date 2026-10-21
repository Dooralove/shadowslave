extends GutTest
## Санни пролога (sunny_waking.tscn): ограничения управления, постановочный режим, скрытое оружие.
## Заодно проверяется, что Санни арены сохранил прежнее поведение.

const WAKING := "res://scenes/characters/sunny_waking.tscn"
const ARENA_SUNNY := "res://scenes/characters/sunny.tscn"
const KNIFE := "Visual/Model/Rig/Skeleton3D/handslot_r/Knife"


func _spawn(path: String) -> SunnyController:
	var sunny := (load(path) as PackedScene).instantiate() as SunnyController
	add_child_autofree(sunny)
	return sunny


func after_each() -> void:
	Input.action_release(&"move_forward")


func test_prologue_disables_combat_sprint_and_jump() -> void:
	var sunny := _spawn(WAKING)
	assert_false(sunny.combat_enabled)
	assert_false(sunny.allow_sprint)
	assert_false(sunny.allow_jump)
	assert_false(sunny.try_attack())
	assert_false(sunny.attack.is_attacking())


func test_arena_sunny_keeps_defaults() -> void:
	var sunny := _spawn(ARENA_SUNNY)
	assert_true(sunny.combat_enabled)
	assert_true(sunny.allow_sprint)
	assert_true(sunny.allow_jump)
	assert_true(sunny.input_enabled)
	assert_eq(sunny.forced_velocity, Vector3.ZERO)
	assert_true(sunny.try_attack(), "в арене удар по-прежнему работает")


func test_prologue_idle_is_unarmed() -> void:
	var animator := _spawn(WAKING).get_node("Animator") as SunnyAnimator
	assert_eq(animator.idle_clip, &"Unarmed_Idle", "без оружия — без боевой стойки")
	assert_true(animator.animation_player.has_animation(animator.idle_clip))
	var arena_animator := _spawn(ARENA_SUNNY).get_node("Animator") as SunnyAnimator
	assert_ne(arena_animator.idle_clip, &"Unarmed_Idle", "в арене стойка прежняя")


func test_knives_hidden_only_in_prologue() -> void:
	assert_false((_spawn(WAKING).get_node(KNIFE) as Node3D).visible, "в прологе Санни без оружия")
	assert_true((_spawn(ARENA_SUNNY).get_node(KNIFE) as Node3D).visible, "в арене нож на месте")


func test_every_mapped_action_has_a_clip() -> void:
	var actor := _spawn(WAKING).get_node("CinematicActor") as CinematicActor
	for action in actor.clip_map.clips:
		assert_true(actor.has_action(action), "клип для действия %s" % action)
	assert_gt(actor.play(&"stand_up"), 0.0)
	assert_eq(actor.play(&"no_such_action"), 0.0, "неизвестное действие не ломает сценарий")


func test_cinematic_mode_pauses_locomotion_animator() -> void:
	var sunny := _spawn(WAKING)
	var actor := sunny.get_node("CinematicActor") as CinematicActor
	var animator := sunny.get_node("Animator") as SunnyAnimator
	actor.begin()
	assert_true(animator.cinematic)
	animator.update(0.1, true, Vector3(3, 0, 0))
	assert_eq(animator.state, SunnyAnimator.State.IDLE, "постановка не перебивается ходьбой")
	actor.end()
	assert_false(animator.cinematic)
	animator.update(0.1, true, Vector3(3, 0, 0))
	assert_eq(animator.state, SunnyAnimator.State.WALK, "после постановки аниматор снова работает")


func test_body_without_physics_does_not_fall() -> void:
	var sunny := _spawn(WAKING)
	var animator := sunny.get_node("Animator") as SunnyAnimator
	sunny.set_physics_process(false)
	sunny.velocity = Vector3.ZERO
	for i in 10:
		animator._physics_process(0.05)
	assert_eq(animator.state, SunnyAnimator.State.IDLE, "в диалоге Санни стоит, а не падает")


func test_input_disabled_ignores_movement() -> void:
	var sunny := _spawn(WAKING)
	sunny.input_enabled = false
	Input.action_press(&"move_forward")
	for i in 10:
		sunny._physics_process(0.1)
	assert_almost_eq(Vector2(sunny.velocity.x, sunny.velocity.z).length(), 0.0, 0.001)
	sunny.input_enabled = true
	for i in 10:
		sunny._physics_process(0.1)
	assert_gt(Vector2(sunny.velocity.x, sunny.velocity.z).length(), 0.5, "с вводом идёт")


func test_forced_velocity_walks_without_input() -> void:
	var sunny := _spawn(WAKING)
	sunny.input_enabled = false
	sunny.forced_velocity = Vector3(0, 0, -1.1)
	for i in 30:
		sunny._physics_process(0.1)
	assert_almost_eq(sunny.velocity.z, -1.1, 0.05, "идёт в темпе цепи")
	assert_almost_eq(sunny.velocity.x, 0.0, 0.01)
	assert_almost_eq(wrapf(sunny.visual.rotation.y, -PI, PI), 0.0, 0.05, "смотрит по ходу движения")


func test_camera_look_can_be_locked() -> void:
	var rig := _spawn(WAKING).camera_rig
	rig.look_enabled = false
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(200, 0)
	var yaw := rig.yaw
	rig._unhandled_input(motion)
	assert_eq(rig.yaw, yaw, "в жёсткой постановке мышь не вращает камеру")
