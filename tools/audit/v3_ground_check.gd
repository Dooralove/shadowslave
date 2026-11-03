extends SceneTree
## Check v3 foot grounding after the FootGrounder settles.

const SCENE := "res://assets/characters/sunny_realistic_poc/sunny_waking_poc.tscn"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var sunny := (load(SCENE) as PackedScene).instantiate() as Node3D
	root.add_child(sunny)
	sunny.set_physics_process(false)
	var animator := sunny.get_node("Animator") as SunnyAnimator
	animator.set_physics_process(false)
	var model_root := sunny.get_node("Visual/ModelPoc") as Node3D
	var skeleton := model_root.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var model := model_root.get_node("Model") as Node3D
	var grounder := model_root.find_child("FootGrounder", true, false) as Node
	for i in 120:
		await process_frame
	print("GROUNDER ", grounder, " enabled=", grounder.get("enabled") if grounder else "?")
	print("MODEL_Y ", model.position.y)
	_dump("idle", skeleton)
	for entry in [["walk", 1.7], ["run", 4.5]]:
		animator.update(0.05, true, Vector3(0, 0, -float(entry[1])))
		for i in 90:
			await process_frame
		print("MODEL_Y ", model.position.y)
		_dump(entry[0], skeleton)
	quit(0)


func _dump(label: String, skeleton: Skeleton3D) -> void:
	var hips := skeleton.find_bone("Hips")
	var lf := skeleton.find_bone("LeftFoot")
	var rf := skeleton.find_bone("RightFoot")
	var base := skeleton.global_transform
	print("POSE ", label, " hips_y=", (base * skeleton.get_bone_global_pose(hips).origin).y,
		" lf_y=", (base * skeleton.get_bone_global_pose(lf).origin).y,
		" rf_y=", (base * skeleton.get_bone_global_pose(rf).origin).y)
