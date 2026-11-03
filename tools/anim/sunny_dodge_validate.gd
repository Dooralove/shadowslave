extends SceneTree
## Verify arena dodge state is held for combat_settings.dodge_duration (0.8 s),
## not only for the 0.4 s Dodge_Backward clip.
## godot --headless --path . -s tools/anim/sunny_dodge_validate.gd

const SCENE := "res://scenes/characters/sunny.tscn"

var _failed := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var sunny := (load(SCENE) as PackedScene).instantiate() as Node3D
	root.add_child(sunny)
	await process_frame
	await process_frame
	var animator := sunny.get_node(^"Animator") as SunnyAnimator
	var player := animator.animation_player
	animator.play_dodge()
	await process_frame
	if player.assigned_animation != animator.dodge_clip:
		_fail("dodge clip=%s expected=%s" % [player.assigned_animation, animator.dodge_clip])
	await create_timer(0.5).timeout
	print("DODGE_AFTER_0.5 pos=", player.current_animation_position, " playing=", player.is_playing(), " state=", animator.state, " state_time=", animator._state_time, " hold=", animator.dodge_hold_time)
	if animator.state != SunnyAnimator.State.DODGE:
		_fail("dodge released too early at 0.5 s: state=%d" % animator.state)
	animator.update(0.4, true, Vector3.ZERO)
	if animator.state == SunnyAnimator.State.DODGE:
		_fail("dodge still active after 0.9 s")
	print("SUNNY_DODGE_VALIDATE failed=", _failed, " clip_len=", player.get_animation(animator.dodge_clip).length, " hold=", animator.dodge_hold_time)
	quit(1 if _failed > 0 else 0)


func _fail(message: String) -> void:
	_failed += 1
	push_error(message)
