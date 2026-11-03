extends SceneTree
## P3: снимает ключевые локации Первого Кошмара с проверенных ракурсов.
## Запуск без --headless (нужен реальный рендер):
##   godot --path . -s tools/audit/p3_capture.gd -- --out=C:/.../p3

var _out_dir := ""


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out_dir = arg.trim_prefix("--out=")
	if _out_dir.is_empty():
		push_error("p3_capture: нужен --out=<папка>")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(_out_dir)
	root.size = Vector2i(1280, 720)

	await _capture_road()
	await _capture_site()
	await _capture_trail()
	await _capture_vision()
	await _capture_sanctuary()
	print("p3_capture: done out=", _out_dir)
	quit(0)


func _capture_road() -> void:
	var scene := await _instantiate("res://scenes/campaign/first_nightmare_pass.tscn")
	var player := _find_player(scene)
	var player_camera := _find_camera(player) if player != null else null
	if player_camera != null:
		player_camera.make_current()
		await _save("road_player.png")
	await _shot(scene, "road_eye", Vector3(0, 1.7, 4.0), Vector3(0, 1.45, -10.0))
	await _shot(scene, "road_rim", Vector3(4.0, 3.0, 7.0), Vector3(-0.5, 1.4, -8.0))
	await _shot(scene, "road_chain", Vector3(-2.8, 2.1, 2.5), Vector3(0, 1.4, -5.0))
	await _free(scene)


func _capture_site() -> void:
	var scene := await _instantiate("res://scenes/campaign/caravan_site_arrival.tscn")
	if scene.has_method("_stage_night_camera"):
		scene.call("_stage_night_camera")
		await _save("site_night_script.png")
	if scene.has_method("_stage_wagon_camera"):
		scene.call("_stage_wagon_camera")
		await _save("site_wagon_script.png")
	await _shot(scene, "site_night_montage", Vector3(4.6, 3.4, 4.6), Vector3(0.6, 1.35, 0.5))
	await _shot(scene, "site_wagon", Vector3(4.5, 3.0, 1.2), Vector3(-4.5, 0.9, -2.6))
	await _shot(scene, "site_wide", Vector3(4.6, 3.4, 4.6), Vector3(-0.8, 1.0, -1.8))
	await _shot(scene, "site_fire", Vector3(2.0, 2.0, 3.4), Vector3(0.6, 0.8, 0.5))
	await _free(scene)


func _capture_trail() -> void:
	var scene := await _instantiate("res://scenes/campaign/pilgrim_path_arrival.tscn")
	var player := _find_player(scene)
	var player_camera := _find_camera(player) if player != null else null
	if player_camera != null:
		player_camera.make_current()
		await _save("trail_player.png")
	await _shot(scene, "trail_start", Vector3(0, 1.8, 8.5), Vector3(0, 2.2, -20.0))
	await _shot(scene, "trail_alcove", Vector3(1.5, 4.8, -20.0), Vector3(1.4, 4.3, -32.0))
	await _shot(scene, "trail_cave", Vector3(1.0, 5.4, -47.0), Vector3(1.0, 4.4, -53.0))
	await _shot(scene, "trail_temple", Vector3(1.0, 6.0, -53.0), Vector3(1.0, 5.2, -78.4))
	await _free(scene)


func _capture_vision() -> void:
	var scene := await _instantiate("res://scenes/slice/locations/mountain_vision_art.tscn")
	var caravan := scene.get_node_or_null(^"Road/Caravan") as Node3D
	if caravan != null:
		caravan.visible = true
	var bones := scene.get_node_or_null(^"Road/Bones") as Node3D
	if bones != null:
		bones.visible = true
	var snow_cover := scene.get_node_or_null(^"Road/SnowCover") as Node3D
	if snow_cover != null:
		snow_cover.visible = true
	var road_shot := scene.call("shot", &"RoadShot") as Camera3D
	if road_shot != null:
		road_shot.make_current()
		await _save("vision_road.png")
	var orbit := scene.call("shot", &"Orbit") as Camera3D
	if orbit != null:
		orbit.make_current()
		await _save("vision_orbit.png")
	await _shot(scene, "vision_ridge", Vector3(0, 35, 30), Vector3(10, -10, -80))
	await _shot(scene, "vision_road_path", Vector3(11.2, 2.6, 6.0), Vector3(11.5, 6.5, -40.0))
	await _shot(scene, "vision_caravan", Vector3(11.2, 9.5, -30.0), Vector3(12.0, 8.5, -48.0))
	await _free(scene)


func _capture_sanctuary() -> void:
	var scene := await _instantiate("res://scenes/locations/shadow_sanctuary/shadow_sanctuary_art.tscn")
	await _shot(scene, "sanctuary_nave", Vector3(0, 2.2, 4.8), Vector3(0, 2.2, -5.0))
	await _shot(scene, "sanctuary_altar", Vector3(0, 2.0, -0.5), Vector3(0, 1.4, -5.0))
	await _shot(scene, "sanctuary_columns", Vector3(4.8, 2.2, 4.0), Vector3(-2.0, 3.5, -5.0))
	await _shot(scene, "sanctuary_breach", Vector3(0, 2.1, 21.5), Vector3(0, 2.0, -2.0))
	await _free(scene)


func _instantiate(path: String) -> Node3D:
	var packed := load(path) as PackedScene
	if packed == null:
		push_error("p3_capture: cannot load " + path)
		return null
	var scene := packed.instantiate() as Node3D
	root.add_child(scene)
	for i in 8:
		await process_frame
	for canvas in scene.find_children("*", "CanvasLayer", true, false):
		(canvas as CanvasLayer).visible = false
	await process_frame
	return scene


func _shot(scene: Node3D, file_name: String, position: Vector3, target: Vector3) -> void:
	if scene == null:
		return
	var camera := Camera3D.new()
	camera.name = "P3Camera_" + file_name
	camera.fov = 60.0
	camera.near = 0.05
	camera.far = 1600.0
	scene.add_child(camera)
	camera.global_position = position
	camera.look_at(target, Vector3.UP)
	camera.make_current()
	await _save(file_name + ".png")
	camera.queue_free()
	await process_frame


func _save(file_name: String) -> void:
	for i in 10:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.save_png(_out_dir.path_join(file_name))


func _find_player(scene: Node) -> Node3D:
	var players := get_nodes_in_group(&"player")
	if not players.is_empty():
		return players[0] as Node3D
	for node in scene.find_children("*", "Node3D", true, false):
		if node is Node3D and node.name == "Sunny":
			return node as Node3D
	return null


func _find_camera(scene: Node) -> Camera3D:
	if scene == null:
		return null
	var stack: Array[Node] = [scene]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is Camera3D:
			return node as Camera3D
		for child in node.get_children():
			stack.append(child)
	return null


func _free(scene: Node) -> void:
	if scene != null:
		scene.queue_free()
	for i in 3:
		await process_frame
