extends SceneTree
## Visual capture with current_scene set, so SceneAudioDirector/SceneVfxDirector
## actually apply the M1 profile. This is an audit tool, not gameplay code.
##
##   godot --path . -s tools/audio/capture_m1_vfx.gd -- \
##     --scene=res://scenes/locations/post_nightmare/police_precinct.tscn \
##     --out=<dir> [--flag=shroud_summoned]

var _scene_path := "res://scenes/locations/post_nightmare/police_precinct.tscn"
var _out_dir := ""
var _flag := &""
var _camera_position := Vector3.INF
var _camera_look := Vector3.INF


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--scene="):
			_scene_path = arg.trim_prefix("--scene=")
		elif arg.begins_with("--out="):
			_out_dir = arg.trim_prefix("--out=")
		elif arg.begins_with("--flag="):
			_flag = StringName(arg.trim_prefix("--flag="))
		elif arg.begins_with("--pos="):
			_camera_position = _vec3(arg.trim_prefix("--pos="))
		elif arg.begins_with("--look="):
			_camera_look = _vec3(arg.trim_prefix("--look="))
	if _out_dir.is_empty():
		printerr("capture_m1_vfx: missing --out")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(_out_dir)
	var packed := load(_scene_path) as PackedScene
	var scene := packed.instantiate() as Node3D
	root.add_child(scene)
	current_scene = scene
	await create_timer(1.0).timeout
	if not _flag.is_empty():
		var state := root.get_node_or_null(^"NightmareRunState")
		if state != null:
			state.set_flag(_flag, true)
			await create_timer(0.6).timeout
	var player := get_first_node_in_group(&"player") as Node
	var camera := _find_camera(player if player != null else scene)
	if _camera_position.is_finite() and _camera_look.is_finite():
		var audit_camera := Camera3D.new()
		audit_camera.fov = 70.0
		audit_camera.far = 300.0
		scene.add_child(audit_camera)
		audit_camera.global_position = _camera_position
		audit_camera.look_at(_camera_look, Vector3.UP)
		camera = audit_camera
	if camera == null:
		printerr("capture_m1_vfx: no camera")
		quit(1)
		return
	camera.make_current()
	await _save("vfx_player_view.png")
	print("capture_m1_vfx: ", _scene_path, " flag=", _flag, " vfx=", scene.find_children("M1Vfx*", "", true, false).size())
	quit(0)


func _find_camera(node: Node) -> Camera3D:
	var stack: Array[Node] = [node]
	while not stack.is_empty():
		var current: Node = stack.pop_back()
		if current is Camera3D:
			return current as Camera3D
		for child in current.get_children():
			stack.append(child)
	return null


func _vec3(text: String) -> Vector3:
	var parts := text.split(",")
	if parts.size() != 3:
		return Vector3.INF
	return Vector3(float(parts[0]), float(parts[1]), float(parts[2]))


func _save(file_name: String) -> void:
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(_out_dir.path_join(file_name))
