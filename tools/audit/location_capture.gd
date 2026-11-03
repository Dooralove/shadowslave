extends SceneTree
## Снимки локации для графического аудита. Только чтение: сцена не меняется.
## Запуск (нужен рендер, без --headless):
##   godot --path . -s tools/audit/location_capture.gd -- \
##     --scene=res://scenes/locations/post_nightmare/coral_labyrinth.tscn \
##     --out=C:/Users/user/AppData/Local/Temp/opencode/shots [--hide-labels]

var _out_dir := ""
var _scene_path := "res://scenes/locations/post_nightmare/coral_labyrinth.tscn"
var _hide_labels := false
var _tide_mode := "low"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out_dir = arg.trim_prefix("--out=")
		elif arg.begins_with("--scene="):
			_scene_path = arg.trim_prefix("--scene=")
		elif arg == "--hide-labels":
			_hide_labels = true
		elif arg.begins_with("--tide="):
			_tide_mode = arg.trim_prefix("--tide=")
	if _out_dir.is_empty():
		push_error("location_capture: нужен --out=<папка>")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(_out_dir)
	root.size = Vector2i(1280, 720)
	var location: Node3D = (load(_scene_path) as PackedScene).instantiate()
	root.add_child(location)
	var tide := location.get_node_or_null(^"Tide/TideController")
	if tide != null and tide.has_method(&"set_phase"):
		var phase := 0.02
		if _tide_mode == "high":
			phase = 0.5
		elif _tide_mode == "mid":
			phase = 0.25
		tide.set_phase(phase)
		print("CAPTURE tide_mode=", _tide_mode, " phase=", phase, " water_y=", (location.get_node_or_null(^"Tide/WaterPlane") as Node3D).position.y)
	await process_frame
	await process_frame

	if _hide_labels:
		var labels := location.get_node_or_null(^"Generated/Labels")
		if labels != null:
			(labels as Node3D).visible = false

	# Кадр от третьего лица: так локация выглядит в игре по умолчанию.
	var player := get_first_node_in_group(&"player") as Node3D
	if player != null:
		var player_camera := _find_camera(player)
		if player_camera != null:
			player_camera.make_current()
			await _save("player_view.png")

	# Обзорные и сюжетные ракурсы, заданные в самой сцене.
	var shots := location.get_node_or_null(^"Shots")
	if shots != null:
		for child in shots.get_children():
			var camera := child as Camera3D
			if camera == null:
				continue
			camera.make_current()
			await _save("%s.png" % camera.name.to_snake_case())

	# Глаза игрока: несколько точек внутри маршрута.
	var eye_points := [
		["eye_entrance", Vector3(0, 1.7, 15.5), Vector3(0, 1.5, 0)],
		["eye_corridor", Vector3(0, 1.7, 4.0), Vector3(0, 1.6, -6.0)],
		["eye_hub_east", Vector3(1.5, 1.7, -5.0), Vector3(14, 1.6, -5.0)],
		["eye_hub_west", Vector3(-1.5, 1.7, -5.0), Vector3(-14, 1.6, -5.0)],
		["eye_shrine", Vector3(0, 1.7, -17.0), Vector3(0, 2.2, -23.0)],
		["eye_landing", Vector3(0, -4.3, 27.5), Vector3(0, -1.0, 22.0)],
	]
	var eye_camera := Camera3D.new()
	eye_camera.name = "AuditEye"
	eye_camera.fov = 70.0
	eye_camera.far = 260.0
	location.add_child(eye_camera)
	for point in eye_points:
		eye_camera.global_position = point[1]
		eye_camera.look_at(point[2], Vector3.UP)
		eye_camera.make_current()
		await _save("%s.png" % point[0])

	print("location_capture: done scene=", _scene_path, " out=", _out_dir)
	quit(0)


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
	for i in 5:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(_out_dir.path_join(file_name))
