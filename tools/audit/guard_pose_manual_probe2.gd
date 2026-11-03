extends SceneTree
## Manual GuardPoseModifier check on the P1 skeleton.

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
	var player := model_root.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var guard := sunny.find_child("GuardPose", true, false) as SkeletonModifier3D
	animator.set_guard(true)
	player.pause()
	await process_frame
	var hand := skeleton.find_bone("RightHand")
	var before := skeleton.get_bone_global_pose(hand).origin
	guard.call("_process_modification_with_delta", 0.016)
	var after := skeleton.get_bone_global_pose(hand).origin
	print("GUARD active=", guard.active, " influence=", guard.influence, " before=", before, " after=", after, " delta=", (after - before).length())
	print("OFFSETS ", guard.get("offsets_deg"))
	quit(0)
