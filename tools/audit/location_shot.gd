extends SceneTree
## Read-only single-shot capture for a location scene.
##
## Run with a rendering window (do NOT pass --headless):
##   godot --path . -s tools/audit/location_shot.gd -- \
##     --scene=res://scenes/locations/pilgrim_path/pilgrim_path_art.tscn \
##     --out=%TEMP%/opencode/stealth_before.png \
##     --pos=0,6.2,-50 --look=1,4.8,-56

var _scene_path := ""
var _out_path := ""
var _pos := Vector3.ZERO
var _look := Vector3.ZERO
var _fov := 70.0
var _far := 400.0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--scene="):
			_scene_path = arg.trim_prefix("--scene=")
		elif arg.begins_with("--out="):
			_out_path = arg.trim_prefix("--out=")
		elif arg.begins_with("--pos="):
			_pos = _vec(arg.trim_prefix("--pos="))
		elif arg.begins_with("--look="):
			_look = _vec(arg.trim_prefix("--look="))
		elif arg.begins_with("--fov="):
			_fov = float(arg.trim_prefix("--fov="))
		elif arg.begins_with("--far="):
			_far = float(arg.trim_prefix("--far="))
	if _scene_path.is_empty() or _out_path.is_empty():
		push_error("location_shot: --scene and --out are required")
		quit(2)
		return

	root.size = Vector2i(1280, 720)
	var packed := load(_scene_path) as PackedScene
	if packed == null:
		push_error("location_shot: cannot load " + _scene_path)
		quit(2)
		return
	var scene := packed.instantiate()
	root.add_child(scene)
	for i in 6:
		await process_frame

	var camera := Camera3D.new()
	camera.name = "AuditShot"
	camera.fov = _fov
	camera.far = _far
	scene.add_child(camera)
	camera.global_position = _pos
	camera.look_at(_look, Vector3.UP)
	camera.make_current()
	for i in 4:
		await process_frame

	var image := root.get_texture().get_image()
	var err := image.save_png(_out_path)
	if err != OK:
		push_error("location_shot: save failed " + str(err))
	else:
		print("saved: " + _out_path)
	quit(0)


func _vec(text: String) -> Vector3:
	var parts := text.split(",")
	if parts.size() != 3:
		return Vector3.ZERO
	return Vector3(float(parts[0]), float(parts[1]), float(parts[2]))
