extends SceneTree
## Живой кадр события «выжить» в пещере pilgrim_path: спавнит двух угроз
## после ранения и снимает их изнутри. Только для аудита, в релиз не входит.
##
## godot --path . -s tools/audit/pilgrim_cave_capture.gd -- --out=<png>

const SCENE := "res://scenes/locations/pilgrim_path/pilgrim_path_art.tscn"

var _out := "user://pilgrim_cave_enemies.png"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(_out.get_base_dir())
	var state := root.get_node_or_null(^"/root/NightmareRunState")
	if state != null:
		state.call(&"reset")
		state.call(&"set_flag", &"cave_entered")
		state.call(&"set_flag", &"wound_taken")
		state.call(&"set_flag", &"scholar_abandoned")
	var scene := (load(SCENE) as PackedScene).instantiate() as Node3D
	root.add_child(scene)
	root.size = Vector2i(1600, 900)
	for i in 8:
		await physics_frame
	var target := Node3D.new()
	target.position = Vector3(3.4, 4.2, -46.6)
	scene.add_child(target)
	await physics_frame
	scene.call(&"begin_cave_survival", target)
	for i in 12:
		await physics_frame
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.position = Vector3(1.2, 6.2, -45.8)
	camera.look_at(Vector3(5.2, 4.4, -49.8), Vector3.UP)
	camera.fov = 90.0
	camera.current = true
	for i in 5:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.save_png(_out)
	print("PILGRIM_CAVE_CAPTURE ", _out, " ", image.get_size())
	if state != null:
		state.call(&"reset")
	quit()
