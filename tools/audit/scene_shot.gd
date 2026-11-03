extends SceneTree
## Универсальный кадр арт-сцены: `godot --path . -s tools/audit/scene_shot.gd --
## --scene=res://... --out=C:/tmp/x.png --pos=x,y,z --look=x,y,z [--fov=55]`.
## Нужен, чтобы смотреть локации без запуска игры и без QA-обвязки.

var _scene_path := ""
var _out := ""
var _pos := Vector3(0, 3, 8)
var _look := Vector3(0, 1, 0)
var _fov := 55.0


func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--scene="):
			_scene_path = arg.trim_prefix("--scene=")
		elif arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg.begins_with("--pos="):
			_pos = _vec(arg.trim_prefix("--pos="))
		elif arg.begins_with("--look="):
			_look = _vec(arg.trim_prefix("--look="))
		elif arg.begins_with("--fov="):
			_fov = float(arg.trim_prefix("--fov="))
	call_deferred(&"_run")


func _vec(text: String) -> Vector3:
	var parts := text.split(",")
	if parts.size() != 3:
		return Vector3.ZERO
	return Vector3(float(parts[0]), float(parts[1]), float(parts[2]))


func _run() -> void:
	if _scene_path.is_empty() or _out.is_empty():
		push_error("scene_shot: нужны --scene и --out")
		quit(1)
		return
	var packed := load(_scene_path) as PackedScene
	if packed == null:
		push_error("scene_shot: не загрузилась сцена " + _scene_path)
		quit(1)
		return
	var scene := packed.instantiate()
	root.add_child(scene)
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.position = _pos
	camera.look_at(_look, Vector3.UP)
	camera.fov = _fov
	camera.current = true
	for i in 10:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.save_png(_out)
	print("SCENE_SHOT ", _out, " ", image.get_size())
	quit()
