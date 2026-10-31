extends SceneTree
## Снимки облёта камеры видения (MountainVision._orbit) — только чтение, для проверки кадра.
## Нужен рендер, поэтому без --headless (откроется окно).
##   godot --path . -s tools/audit/orbit_capture.gd -- --out=<папка> [--scene=res://...tscn] [--frames=6]

var _out_dir := ""
var _scene_path := "res://scenes/slice/locations/mountain_vision_art.tscn"
var _frames := 6


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out_dir = arg.trim_prefix("--out=")
		elif arg.begins_with("--scene="):
			_scene_path = arg.trim_prefix("--scene=")
		elif arg.begins_with("--frames="):
			_frames = int(arg.trim_prefix("--frames="))
	if _out_dir.is_empty():
		push_error("orbit_capture: нужен --out=<папка>")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(_out_dir)
	root.size = Vector2i(1280, 720)
	# Без типа SliceLocation: в режиме -s автозагрузки не компилируются вместе со скриптом.
	var location: Node3D = (load(_scene_path) as PackedScene).instantiate()
	root.add_child(location)
	await process_frame
	var camera: Camera3D = location.call(&"shot", &"Orbit")
	camera.make_current()
	if location.has_method(&"set_orbit_mode"):
		location.call(&"set_orbit_mode", true)
	var center := (camera.get_node(^"LookAt") as Node3D).global_position
	var offset := camera.global_position - center
	var start := atan2(offset.x, offset.z)
	var radius := Vector2(offset.x, offset.z).length()
	# Тот же путь, что в MountainVision._orbit: дуга 1,3 рад вокруг LookAt.
	for i in _frames:
		var angle := start + 1.3 * float(i) / float(maxi(_frames - 1, 1))
		camera.global_position = center + Vector3(sin(angle) * radius, offset.y, cos(angle) * radius)
		camera.look_at(center)
		await _save("orbit_%02d.png" % i)
	var road: Camera3D = location.call(&"shot", &"RoadShot")
	if road:
		if location.has_method(&"set_orbit_mode"):
			location.call(&"set_orbit_mode", false)
		road.make_current()
		await _save("road_shot.png")
	print("orbit_capture: center=", center, " radius=", radius, " height=", offset.y)
	quit(0)


func _save(file_name: String) -> void:
	for i in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(_out_dir.path_join(file_name))
