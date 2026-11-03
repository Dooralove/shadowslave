extends SceneTree
## Read-only check: P1 Sunny in the containment chair, Sitting_Idle pose.
## godot --path . -s tools/audit/p2_containment_pose.gd -- --out=<dir>

var _out := ""


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
	if _out.is_empty():
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	root.size = Vector2i(1100, 720)

	var packed := load("res://scenes/slice/locations/containment_room_art.tscn") as PackedScene
	var scene := packed.instantiate()
	root.add_child(scene)
	await process_frame

	var chair := scene.get_node_or_null("Spawns/Chair") as Node3D
	var sunny := (load("res://assets/characters/p1/sunny_p1_model.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(sunny)
	if chair:
		sunny.global_position = chair.global_position
		sunny.global_rotation.y = chair.global_rotation.y
	var ap := sunny.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap:
		var clip := &"Sitting_Idle"
		if ap.has_animation(clip):
			ap.play(clip)
			ap.seek(0.7, true)
			ap.pause()

	var cam := Camera3D.new()
	cam.fov = 48.0
	cam.near = 0.05
	cam.far = 40.0
	scene.add_child(cam)
	cam.position = Vector3(1.45, 1.85, 2.3)
	cam.look_at(Vector3(0, 1.0, 0.3), Vector3.UP)
	cam.current = true
	for i in 30:
		await process_frame
	await RenderingServer.frame_post_draw
	var path := _out.path_join("containment_sunny_pose.png")
	root.get_texture().get_image().save_png(path)
	print("POSE_PREVIEW ", path)

	cam.position = Vector3(0.0, 1.70, -0.90)
	cam.fov = 60.0
	cam.look_at(Vector3(0, 1.15, 2.4), Vector3.UP)
	for i in 20:
		await process_frame
	await RenderingServer.frame_post_draw
	var wide := _out.path_join("containment_sunny_wide.png")
	root.get_texture().get_image().save_png(wide)
	print("POSE_PREVIEW ", wide)
	quit(0)
