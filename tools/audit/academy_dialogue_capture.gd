extends SceneTree
## Captures one real NPC dialogue in the Academy grounds for the preview pack.
## Run without --headless:
##   godot --path . -s tools/audit/academy_dialogue_capture.gd -- --out=<folder>


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
	if out.is_empty():
		push_error("dialogue capture: need --out=<folder>")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(1440, 810)
	var packed := load("res://scenes/locations/academy_playable/academy_grounds_playable.tscn") as PackedScene
	var scene := packed.instantiate()
	root.add_child(scene)
	current_scene = scene
	await _frames(8)
	var player := get_first_node_in_group(&"player") as Node3D
	var guard = scene.find_child("gate_guard", true, false)
	if player == null or guard == null:
		push_error("capture: player or gate guard missing")
		quit(2)
		return
	player.global_position = Vector3(4.3, 0.2, 98.2)
	player.rotation.y = 0.0
	var rig := player.get_node_or_null(^"CameraRig")
	if rig != null and rig.has_method(&"set_yaw"):
		rig.call(&"set_yaw", 0.0)
	await _frames(4)
	guard.get("interactable").interact()
	for _i in 30:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join("gate_guard_dialogue.png"))
	print("DIALOGUE_CAPTURE ", out.path_join("gate_guard_dialogue.png"))
	# Close the dialogue, open the gate, then capture the courtyard.
	var runner = get_first_node_in_group(&"dialogue_runner")
	if runner != null:
		for _i in 12:
			if not runner.running:
				break
			runner.advance()
			await _frames(2)
	await _frames(4)
	var state := root.get_node_or_null(^"NightmareRunState")
	if state != null:
		state.set_flag(&"academy_gate_passed")
	await _frames(90)
	player.global_position = Vector3(0, 0.2, 90.0)
	player.rotation.y = 0.0
	if rig != null and rig.has_method(&"set_yaw"):
		rig.call(&"set_yaw", 0.0)
	await _frames(8)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join("gate_open.png"))
	print("DIALOGUE_CAPTURE ", out.path_join("gate_open.png"))
	quit(0)


func _frames(count: int) -> void:
	for _i in count:
		await process_frame
