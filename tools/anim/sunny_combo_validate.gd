extends SceneTree
## Verify the arena Sunny visual combo chain.
## godot --headless --path . -s tools/anim/sunny_combo_validate.gd

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
	var attack := sunny.get_node(^"Visual/MeleeAttack") as MeleeAttack
	var player := animator.animation_player
	if animator.combo_clips.size() < 3:
		_fail("combo_clips expected >=3, got %d" % animator.combo_clips.size())
	for clip in animator.combo_clips:
		if not player.has_animation(clip):
			_fail("missing combo clip %s" % clip)
	attack.attack_started.emit()
	if player.assigned_animation != animator.attack_clip:
		_fail("first attack clip=%s expected=%s" % [player.assigned_animation, animator.attack_clip])
	attack.attack_started.emit()
	var second := animator.combo_clips[1] if animator.combo_clips.size() > 1 else &""
	if player.assigned_animation != second:
		_fail("second attack clip=%s expected=%s" % [player.assigned_animation, second])
	attack.attack_started.emit()
	var third := animator.combo_clips[2] if animator.combo_clips.size() > 2 else &""
	if player.assigned_animation != third:
		_fail("third attack clip=%s expected=%s" % [player.assigned_animation, third])
	animator.update(1.3, true, Vector3.ZERO)
	attack.attack_started.emit()
	if player.assigned_animation != animator.attack_clip:
		_fail("combo did not reset: clip=%s expected=%s" % [player.assigned_animation, animator.attack_clip])
	print("SUNNY_COMBO_VALIDATE failed=", _failed, " clips=", animator.combo_clips)
	quit(1 if _failed > 0 else 0)


func _fail(message: String) -> void:
	_failed += 1
	push_error(message)
