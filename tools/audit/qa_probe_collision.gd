extends SceneTree
## Read-only probe: list collision shapes near a world point in the labyrinth.
##   godot --headless --path . -s tools/audit/qa_probe_collision.gd -- --at=-565,6,0 --radius=12

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var at := Vector3(-565, 6, 0)
	var radius := 12.0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--at="):
			var p := arg.trim_prefix("--at=").split(",")
			if p.size() >= 3:
				at = Vector3(float(p[0]), float(p[1]), float(p[2]))
		elif arg.begins_with("--radius="):
			radius = float(arg.trim_prefix("--radius="))
	var packed := load("res://scenes/locations/forgotten_shore_labyrinth/labyrinth_first_fragment.tscn") as PackedScene
	var scene := packed.instantiate()
	root.add_child(scene)
	for i in 20:
		await process_frame
	var stack: Array[Node] = [scene]
	var found := 0
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child in node.get_children():
			stack.append(child)
		if node is CollisionShape3D:
			var cs := node as CollisionShape3D
			if cs.global_position.distance_to(at) <= radius:
				var parent := cs.get_parent()
				print("COLLISION ", cs.get_path(), " pos=", cs.global_position,
					" shape=", cs.shape.get_class() if cs.shape != null else "null",
					" parent=", parent.get_class() if parent != null else "null",
					" parent_layer=", (parent as CollisionObject3D).collision_layer if parent is CollisionObject3D else "n/a")
				found += 1
	print("COLLISION_SUMMARY at=", at, " radius=", radius, " found=", found)
	quit(0)
