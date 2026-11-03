extends SceneTree
## Rendered gameplay captures for the Academy playable scenes.
## Run without --headless:
##   godot --path . -s tools/audit/academy_gameplay_capture.gd -- \
##     --scene=res://scenes/locations/academy_playable/academy_grounds_playable.tscn \
##     --out=C:/Users/user/AppData/Local/Temp/opencode/academy_gameplay

var _out := ""
var _scene_path := "res://scenes/locations/academy_playable/academy_grounds_playable.tscn"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg.begins_with("--scene="):
			_scene_path = arg.trim_prefix("--scene=")
	if _out.is_empty():
		push_error("capture: need --out=<folder>")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	root.size = Vector2i(1440, 810)
	var packed := load(_scene_path) as PackedScene
	if packed == null:
		push_error("capture: cannot load scene")
		quit(2)
		return
	var location := packed.instantiate() as Node3D
	root.add_child(location)
	current_scene = location
	await process_frame
	await process_frame
	await process_frame
	var player := get_first_node_in_group(&"player") as Node3D
	if player == null:
		push_error("capture: no player")
		quit(2)
		return
	var camera := _find_camera(player)
	if camera == null:
		push_error("capture: no player camera")
		quit(2)
		return
	camera.current = true
	var shots := _shots()
	for entry in shots:
		player.global_position = entry[1]
		player.rotation.y = entry[2]
		if player is CharacterBody3D:
			(player as CharacterBody3D).velocity = Vector3.ZERO
		await _save(String(entry[0]) + ".png")
	print("ACADEMY_GAMEPLAY_CAPTURE done ", _out)
	quit(0)


func _shots() -> Array:
	if _scene_path.contains("sleeper_center"):
		return [
			["entry", Vector3(0, 0.2, 10.3), 0.0],
			["dorm", Vector3(0, 0.2, 6.0), 0.0],
			["common", Vector3(-15.0, 0.2, 0.0), PI * 0.5],
			["showers", Vector3(16.0, 0.2, 0.0), -PI * 0.5],
			["observation", Vector3(0, 0.2, -8.0), 0.0],
			["medical", Vector3(0, 0.2, -17.5), 0.0],
			["hollow", Vector3(3.0, 0.2, -17.0), -PI * 0.5],
			["dream", Vector3(0, 0.2, -20.5), 0.0],
			["room07", Vector3(-32.5, 0.2, -8.6), PI * 0.5],
			["laundry", Vector3(-24.5, 0.2, 9.0), -PI * 0.5],
		]
	return [
		["approach", Vector3(0, 0.2, 140.0), 0.0],
		["gate", Vector3(0, 0.2, 98.0), 0.0],
		["gate_guard", Vector3(3.0, 0.2, 100.0), 0.0],
		["gallery", Vector3(0, 0.2, 40.0), 0.0],
		["induction", Vector3(0, 0.2, 33.0), 0.0],
		["dojo_front", Vector3(28.0, 0.2, 12.0), -PI * 0.5],
		["dojo_detail", Vector3(34.0, 0.2, 10.0), -PI * 0.5],
		["academic_front", Vector3(-30.0, 0.2, -28.0), PI * 0.5],
		["dining_front", Vector3(-30.0, 0.2, 10.0), PI * 0.5],
		["sleeper_entrance", Vector3(0, 0.2, -40.0), 0.0],
	]


func _find_camera(root_node: Node) -> Camera3D:
	var stack: Array[Node] = [root_node]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is Camera3D:
			return node as Camera3D
		for child in node.get_children():
			stack.append(child)
	return null


func _save(file_name: String) -> void:
	for i in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(_out.path_join(file_name))
	print("CAPTURE ", _out.path_join(file_name))
