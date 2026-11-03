extends SceneTree
## QA capture: loads one scene, waits for it to settle and saves the rendered frame.
## Read-only: it does not save or mutate the scene. Run with a visible window:
##   godot --path . -s tools/audit/qa_capture.gd -- \
##     --scene=res://scenes/ui/main_menu/main_menu.tscn \
##     --out=C:/Users/user/AppData/Local/Temp/opencode/qa_shots

var _out_dir := ""
var _scene_path := ""
var _camera_name := ""
var _frames := 45
var _hide_ui := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out_dir = arg.trim_prefix("--out=")
		elif arg.begins_with("--scene="):
			_scene_path = arg.trim_prefix("--scene=")
		elif arg.begins_with("--camera="):
			_camera_name = arg.trim_prefix("--camera=")
		elif arg.begins_with("--frames="):
			_frames = int(arg.trim_prefix("--frames="))
		elif arg == "--hide-ui":
			_hide_ui = true
	if _out_dir.is_empty() or _scene_path.is_empty():
		push_error("qa_capture: need --scene=<res://...> and --out=<dir>")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(_out_dir)
	root.size = Vector2i(1920, 1080)
	var packed := load(_scene_path) as PackedScene
	if packed == null:
		push_error("qa_capture: cannot load " + _scene_path)
		quit(3)
		return
	var scene := packed.instantiate()
	root.add_child(scene)
	for i in _frames:
		await process_frame

	if _hide_ui:
		for node in scene.find_children("*", "CanvasLayer", true, false):
			(node as CanvasLayer).visible = false
	if not _camera_name.is_empty():
		var camera := scene.get_node_or_null(_camera_name) as Camera3D
		if camera != null:
			camera.make_current()
	for i in 5:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var file_name := _scene_path.get_file().get_basename() + ".png"
	if not _camera_name.is_empty():
		file_name = _scene_path.get_file().get_basename() + "_" + _camera_name.replace("/", "_") + ".png"
	var path := _out_dir.path_join(file_name)
	var error := image.save_png(path)
	print("QA_CAPTURE scene=", _scene_path, " image=", image.get_width(), "x", image.get_height(),
		" error=", error, " out=", path)
	quit(0 if error == OK else 4)
