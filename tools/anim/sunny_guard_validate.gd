extends SceneTree
## Verify v3/Nightmare guard pose wiring through SunnyV3Model.get_guard_pose().
## godot --headless --path . -s tools/anim/sunny_guard_validate.gd

const SCENES := [
	"res://assets/characters/sunny_realistic_poc/sunny_waking_poc.tscn",
	"res://assets/characters/p1/sunny_waking_nightmare.tscn",
]

var _failed := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for path in SCENES:
		var sunny := (load(path) as PackedScene).instantiate() as Node3D
		root.add_child(sunny)
		await process_frame
		await process_frame
		var animator := sunny.get_node(^"Animator") as SunnyAnimator
		if animator.guard_pose == null:
			_fail("%s: guard_pose not discovered" % path)
		else:
			animator.set_guard(true)
			await process_frame
			if not animator.guard_pose.get(&"active"):
				_fail("%s: guard pose not active" % path)
			animator.set_guard(false)
			await process_frame
			if animator.guard_pose.get(&"active"):
				_fail("%s: guard pose still active" % path)
			print("SUNNY_GUARD ", path.get_file(), " ok")
		sunny.queue_free()
		await process_frame
	print("SUNNY_GUARD_VALIDATE failed=", _failed)
	quit(1 if _failed > 0 else 0)


func _fail(message: String) -> void:
	_failed += 1
	push_error(message)
