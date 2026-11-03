extends SceneTree
## Try GuardPose offsets and report the right-hand position.

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
	var guard := sunny.find_child("GuardPose", true, false)
	animator.set_guard(true)
	player.pause()
	await process_frame
	var hand := skeleton.find_bone("RightHand")
	var base := skeleton.get_bone_global_pose(hand).origin
	print("BASE ", base)
	var tests := [
		[Vector3(30, 0, 0), Vector3(-60, 0, 0)],
		[Vector3(-30, 0, 0), Vector3(-60, 0, 0)],
		[Vector3(60, 0, 0), Vector3(-70, 0, 0)],
		[Vector3(0, 0, 30), Vector3(0, 0, -60)],
		[Vector3(0, 0, -30), Vector3(0, 0, -60)],
		[Vector3(30, 30, 0), Vector3(-60, 0, 0)],
	]
	for t in tests:
		guard.set("offsets_deg", {&"RightUpperArm": t[0], &"RightLowerArm": t[1], &"RightHand": Vector3.ZERO})
		guard.call("_process", 0.016)
		var p := skeleton.get_bone_global_pose(hand).origin
		print("TEST upper=", t[0], " lower=", t[1], " hand=", p, " delta=", (p - base).length())
	quit(0)
