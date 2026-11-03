extends SceneTree
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var sunny := (load("res://assets/characters/p1/sunny_waking_nightmare.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(sunny)
	await process_frame
	await process_frame
	var model_root := sunny.get_node("Visual/ModelPoc") as Node3D
	var skeleton := model_root.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	print("MODIFIERS count=", skeleton.get_modifier_count())
	for i in skeleton.get_modifier_count():
		print("  ", i, " ", skeleton.get_modifier(i), " active=", skeleton.get_modifier(i).active)
	quit(0)
