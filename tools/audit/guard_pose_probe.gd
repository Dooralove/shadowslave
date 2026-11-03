extends SceneTree
## Check GuardPoseModifier activation and hand displacement.

const SCENE := "res://assets/characters/p1/sunny_waking_nightmare.tscn"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var sunny := (load(SCENE) as PackedScene).instantiate() as Node3D
	root.add_child(sunny)
	sunny.set_physics_process(false)
	var animator := sunny.get_node("Animator") as SunnyAnimator
	animator.set_physics_process(false)
	await process_frame
	await process_frame
	await process_frame
	var model_root := sunny.get_node("Visual/ModelPoc") as Node3D
	var skeleton := model_root.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var guard := sunny.find_child("GuardPose", true, false) as SkeletonModifier3D
	print("GUARD_NODE ", guard, " active=", guard.active if guard else "?")
	var hand := skeleton.find_bone("RightHand")
	animator.set_guard(true)
	for i in 20:
		await process_frame
	print("GUARD_ON hand=", skeleton.get_bone_global_pose(hand).origin, " active=", guard.active if guard else "?")
	animator.set_guard(false)
	for i in 20:
		await process_frame
	print("GUARD_OFF hand=", skeleton.get_bone_global_pose(hand).origin, " active=", guard.active if guard else "?")
	quit(0)
