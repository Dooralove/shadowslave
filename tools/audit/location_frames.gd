extends SceneTree
## Кадры локации для арт-аудита. Сцена не изменяется: создаётся временная
## Camera3D, кадры складываются в scratchpad, после замера сцена освобождается.
##
## Запуск (нужен рендер, без --headless):
##   godot --path . -s tools/audit/location_frames.gd -- \
##     --scene=res://scenes/slice/locations/caravan_road_art.tscn \
##     --name=caravan_road \
##     --out=C:/Users/user/AppData/Local/Temp/opencode/shadowslave_art/frames/before
##
## Опции:
##   --scene=res://...       сцена; обязательна
##   --out=...               папка scratchpad; обязательна
##   --name=...              префикс файлов; по умолчанию имя сцены
##   --focus=x1,y1,z1,x2,y2,z2  явный box игровой зоны
##   --width=1600 --height=900
##   --fps-frames=180        число кадров замера FPS; 0 — не мерить
##   --keep-ui               не скрывать CanvasLayer
##   --keep-labels           не скрывать Label3D
##   --list                  только вывести bounds/ключевые точки, без рендера

const DEFAULT_WIDTH := 1600
const DEFAULT_HEIGHT := 900
const DEFAULT_FPS_FRAMES := 180

## Игровая зона, а не вся декоративная геометрия: дальние хребты и облака
## остаются в кадре, но не растягивают облёт на километры.
const FOCUS_RECTS := {
	"caravan_road_art": AABB(Vector3(-34, -12, -62), Vector3(68, 42, 86)),
	"caravan_site_art": AABB(Vector3(-24, -6, -18), Vector3(48, 30, 36)),
	"pilgrim_path_art": AABB(Vector3(-24, -10, -94), Vector3(48, 40, 112)),
	"shadow_sanctuary_art": AABB(Vector3(-16, -3, -17), Vector3(32, 26, 34)),
}

## Точки, с которых игрок читает локацию. Координаты — по земле/полу.
const KEY_POINTS := {
	"caravan_road_art": [
		["start", Vector3(0, 0.0, 14), Vector3(0, 2.0, -12)],
		["chain", Vector3(0, 0.0, -4), Vector3(0, 2.0, -24)],
		["valley", Vector3(0, 0.0, -20), Vector3(0, 3.0, -45)],
		["far_road", Vector3(0, 0.0, -34), Vector3(0, 3.0, -58)],
		["backdrop", Vector3(0, 0.0, -20), Vector3(0, 20.0, -100)],
	],
	"caravan_site_art": [
		["south", Vector3(0, 0.0, 7), Vector3(0, 1.4, 0)],
		["fire", Vector3(0, 0.0, 2.5), Vector3(0, 1.3, -2)],
		["east", Vector3(7, 0.0, 3), Vector3(0, 1.4, -1)],
		["west", Vector3(-7, 0.0, -1), Vector3(1, 1.4, 1)],
		["south_exit", Vector3(0, 0.0, -5), Vector3(0, 4.0, 40)],
		["backdrop", Vector3(0, 0.0, -3), Vector3(0, 20.0, 75)],
	],
	"pilgrim_path_art": [
		["start", Vector3(0, 4.15, 8.5), Vector3(0, 4.5, -5)],
		["ledge", Vector3(2.4, 4.15, -34.7), Vector3(0, 4.8, -45)],
		["cave", Vector3(1.2, 4.15, -40), Vector3(1.0, 5.0, -45.5)],
		["approach", Vector3(1.0, 4.15, -67), Vector3(0, 7.0, -80)],
		["backdrop", Vector3(1.0, 4.15, -67), Vector3(0, 20.0, -130)],
	],
	"shadow_sanctuary_art": [
		["entrance", Vector3(0, 0.05, 12), Vector3(0, 1.7, -4)],
		["hall", Vector3(0, 0.05, 4), Vector3(0, 1.8, -6)],
		["altar", Vector3(0, 0.05, -1), Vector3(0, 1.7, -5)],
		["side", Vector3(-4.5, 0.05, 4), Vector3(0, 1.8, -4)],
		["backdrop", Vector3(0, 0.05, 16), Vector3(0, 20.0, -62)],
	],
}

var _scene_path := ""
var _out_dir := ""
var _name := ""
var _focus_override := AABB()
var _has_focus_override := false
var _width := DEFAULT_WIDTH
var _height := DEFAULT_HEIGHT
var _fps_frames := DEFAULT_FPS_FRAMES
var _keep_ui := false
var _keep_labels := false
var _keep_characters := false
var _list_only := false
var _hide_added_decor := false
var _skip_frames := false

## Свободные камеры у краёв игровой зоны. Для каждой локации выбраны
## открытые стороны, а не слепые задворки скал.
const EDGE_SHOTS := {
	"caravan_road_art": [
		["edge_west_open", Vector3(-18, 8, 12), Vector3(0, 2, -16)],
		["edge_valley_drop", Vector3(-24, 2, -20), Vector3(0, 2, -30)],
		["edge_far_north", Vector3(-12, 11, -52), Vector3(0, 2, -20)],
		["edge_south_gate", Vector3(0, 7, 28), Vector3(0, 2, -6)],
	],
	"caravan_site_art": [
		["edge_south", Vector3(0, 5, 17), Vector3(0, 1, 0)],
		["edge_southwest", Vector3(-12, 6, 13), Vector3(0, 1, 0)],
		["edge_west", Vector3(-15, 3, 2), Vector3(0, 1, 0)],
		["edge_high", Vector3(-9, 15, 17), Vector3(0, 1, -1)],
	],
	"pilgrim_path_art": [
		["edge_start", Vector3(-17, 8, 18), Vector3(0, 4, -12)],
		["edge_west_ledge", Vector3(-18, 6, -20), Vector3(0, 4, -32)],
		["edge_east_cave", Vector3(14, 8, -38), Vector3(0, 4, -50)],
		["edge_approach", Vector3(12, 8, -60), Vector3(0, 6, -78)],
	],
	"shadow_sanctuary_art": [
		["edge_south_front", Vector3(0, 3, 16), Vector3(0, 1, 0)],
		["edge_southwest", Vector3(-18, 10, 18), Vector3(0, 1, 0)],
		["edge_southeast", Vector3(18, 10, 18), Vector3(0, 1, 0)],
		["edge_high_south", Vector3(0, 24, 26), Vector3(0, 1, 0)],
	],
}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_parse_args()
	if _scene_path.is_empty() or (_out_dir.is_empty() and not _list_only):
		push_error("location_frames: нужны --scene=res://... и --out=<папка>")
		quit(2)
		return
	if _name.is_empty():
		_name = _scene_path.get_file().get_basename()
	var packed := load(_scene_path) as PackedScene
	if packed == null:
		push_error("location_frames: не загрузилась сцена %s" % _scene_path)
		quit(3)
		return
	if not _out_dir.is_empty():
		DirAccess.make_dir_recursive_absolute(_out_dir)
	root.size = Vector2i(_width, _height)
	var location := packed.instantiate() as Node3D
	if location == null:
		push_error("location_frames: сцена не Node3D")
		quit(4)
		return
	root.add_child(location)
	for i in 8:
		await process_frame
	await physics_frame
	await physics_frame
	_prepare_visuals(location)
	if _hide_added_decor:
		_hide_added_decor_nodes(location)

	var focus := _focus_for(location)
	var key_points: Array = KEY_POINTS.get(_scene_path.get_file().get_basename(), [])
	if _list_only:
		print("location_frames: scene=", _scene_path)
		print("  focus=", focus)
		print("  focus_center=", focus.get_center(), " size=", focus.size)
		for point in key_points:
			print("  key=", point[0], " eye=", point[1], " target=", point[2])
		quit(0)
		return

	var camera := Camera3D.new()
	camera.name = "AuditCamera"
	camera.fov = 62.0
	camera.near = 0.08
	camera.far = 1200.0
	camera.cull_mask = 0xFFFFF
	location.add_child(camera)
	var manifest: Array[String] = [
		"# Frames: %s" % _name,
		"scene: %s" % _scene_path,
		"focus: %s" % focus,
	]

	if not _skip_frames:
		await _capture_top(camera, focus, manifest)
		await _capture_edges(camera, focus, manifest)
		await _capture_keys(camera, focus, key_points, manifest)
	var perf := await _measure_performance()
	manifest.append("")
	manifest.append("## Performance")
	for line in perf:
		manifest.append(line)
	var file := FileAccess.open(_out_dir.path_join("%s_frames.md" % _name), FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(manifest))
		file.close()
	print("location_frames: done scene=", _scene_path, " out=", _out_dir)
	for line in perf:
		print(line)
	quit(0)


func _parse_args() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--scene="):
			_scene_path = arg.trim_prefix("--scene=")
		elif arg.begins_with("--out="):
			_out_dir = arg.trim_prefix("--out=")
		elif arg.begins_with("--name="):
			_name = arg.trim_prefix("--name=")
		elif arg.begins_with("--focus="):
			var values := arg.trim_prefix("--focus=").split_floats(",")
			if values.size() == 6:
				_focus_override = AABB(
					Vector3(values[0], values[1], values[2]),
					Vector3(values[3] - values[0], values[4] - values[1], values[5] - values[2])
				)
				_has_focus_override = true
		elif arg.begins_with("--width="):
			_width = maxi(320, int(arg.trim_prefix("--width=")))
		elif arg.begins_with("--height="):
			_height = maxi(180, int(arg.trim_prefix("--height=")))
		elif arg.begins_with("--fps-frames="):
			_fps_frames = maxi(0, int(arg.trim_prefix("--fps-frames=")))
		elif arg == "--keep-ui":
			_keep_ui = true
		elif arg == "--keep-labels":
			_keep_labels = true
		elif arg == "--keep-characters":
			_keep_characters = true
		elif arg == "--hide-added-decor":
			_hide_added_decor = true
		elif arg == "--no-frames":
			_skip_frames = true
		elif arg == "--list":
			_list_only = true


func _prepare_visuals(location: Node) -> void:
	if not _keep_ui:
		for node in location.find_children("*", "CanvasLayer", true, false):
			(node as CanvasLayer).visible = false
	if not _keep_labels:
		for node in location.find_children("*", "Label3D", true, false):
			(node as Label3D).visible = false
	if not _keep_characters:
		_hide_characters(location)


func _hide_added_decor_nodes(location: Node) -> void:
	for node in location.find_children("*", "Node3D", true, false):
		if String(node.name) in ["SeamsMidground", "LowClouds", "RimLight"]:
			if node is Node3D:
				(node as Node3D).visible = false
			if node is Light3D:
				(node as Light3D).visible = false


func _hide_characters(location: Node) -> void:
	var npcs := location.get_node_or_null(^"NPCs") as Node3D
	if npcs != null:
		npcs.visible = false
	var groups := [&"player", &"npc", &"enemy"]
	var names := [
		"sunny", "shifty", "hero", "veteran", "scholar", "tyrant", "larva",
		"mannequin", "slave", "rider", "soldier", "guard", "merchant",
	]
	for node in location.find_children("*", "Node3D", true, false):
		var node_3d := node as Node3D
		var hide := false
		for group in groups:
			if node_3d.is_in_group(group):
				hide = true
				break
		if not hide:
			var name := String(node.name).to_lower()
			for part in names:
				if name.contains(part):
					hide = true
					break
		if hide:
			# NPC-визуалы часто вложены в контейнеры; скрываем сам контейнер,
			# чтобы не оставить в кадре висящую деталь.
			node_3d.visible = false


func _focus_for(location: Node3D) -> AABB:
	var key := _scene_path.get_file().get_basename()
	if _has_focus_override:
		return _focus_override
	if FOCUS_RECTS.has(key):
		return FOCUS_RECTS[key]
	var points: Array[Vector3] = []
	for node in location.find_children("*", "Marker3D", true, false):
		if String(location.get_path_to(node)).contains("Spawns"):
			points.append((node as Node3D).global_position)
	for node in location.find_children("*", "Area3D", true, false):
		points.append((node as Area3D).global_position)
	if points.is_empty():
		var box := _visible_mesh_bounds(location)
		if box.size == Vector3.ZERO:
			return AABB(Vector3(-10, -2, -10), Vector3(20, 20, 20))
		box = box.grow(8.0)
		return box
	var focus := AABB(points[0], Vector3.ZERO)
	for point in points:
		focus = focus.expand(point)
	focus = focus.grow(6.0)
	focus.position.y = minf(focus.position.y, 0.0) - 2.0
	focus.size.y = maxf(focus.size.y, 16.0)
	return focus


func _visible_mesh_bounds(root_node: Node) -> AABB:
	var result := AABB()
	var first := true
	var skip_parts := ["player", "npc", "enemy", "ui"]
	var stack: Array[Node] = [root_node]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child in node.get_children():
			stack.append(child)
		if node is MeshInstance3D and node.is_visible_in_tree():
			var mesh := node as MeshInstance3D
			if mesh.mesh == null or _has_skipped_ancestor(mesh, root_node, skip_parts):
				continue
			var box := mesh.global_transform * mesh.get_aabb()
			result = box if first else result.merge(box)
			first = false
	return result


func _has_skipped_ancestor(node: Node, root_node: Node, parts: Array) -> bool:
	var cursor := node
	while cursor != null and cursor != root_node:
		for part in parts:
			if String(cursor.name).to_lower().contains(String(part)):
				return true
		cursor = cursor.get_parent()
	return false


func _capture_top(camera: Camera3D, focus: AABB, manifest: Array[String]) -> void:
	var center := focus.get_center()
	var extent := maxf(focus.size.x, focus.size.z)
	var height := maxf(42.0, extent * 1.4)
	var eye := Vector3(center.x, focus.position.y + height, center.z + 0.01)
	await _shoot(camera, "top", eye, center, 0.0, manifest, "общий вид сверху")


func _capture_edges(camera: Camera3D, focus: AABB, manifest: Array[String]) -> void:
	var key := _scene_path.get_file().get_basename()
	var shots: Array = EDGE_SHOTS.get(key, [])
	if shots.is_empty():
		var center := focus.get_center()
		var sx := maxf(focus.size.x * 0.75, 14.0)
		var sz := maxf(focus.size.z * 0.75, 14.0)
		var altitude := maxf(10.0, minf(focus.size.x, focus.size.z) * 0.32)
		var eye_y := center.y + altitude
		shots = [
			["edge_ne", Vector3(center.x + sx, eye_y, center.z - sz), center + Vector3(0, 2.0, 0)],
			["edge_nw", Vector3(center.x - sx, eye_y, center.z - sz), center + Vector3(0, 2.0, 0)],
			["edge_se", Vector3(center.x + sx, eye_y, center.z + sz), center + Vector3(0, 2.0, 0)],
			["edge_sw", Vector3(center.x - sx, eye_y, center.z + sz), center + Vector3(0, 2.0, 0)],
		]
	for item in shots:
		await _shoot(camera, item[0], item[1], item[2], 0.0, manifest,
			"свободная камера у края игровой зоны")


func _capture_keys(camera: Camera3D, focus: AABB, key_points: Array, manifest: Array[String]) -> void:
	var space := camera.get_world_3d().direct_space_state
	for point in key_points:
		var ground: Vector3 = point[1]
		var ray_from := ground + Vector3(0, 24.0, 0)
		var ray_to := ground - Vector3(0, 24.0, 0)
		var query := PhysicsRayQueryParameters3D.create(ray_from, ray_to, 1 | 32)
		var hit := space.intersect_ray(query)
		if not hit.is_empty():
			ground = hit.position
		var eye: Vector3 = ground + Vector3(0, 1.7, 0)
		var target: Vector3 = point[2]
		await _shoot(camera, "key_%s" % point[0], eye, target, 0.0, manifest,
			"ключевая точка: %s" % point[0])


func _shoot(camera: Camera3D, shot_name: String, eye: Vector3, target: Vector3,
		roll: float, manifest: Array[String], note: String) -> void:
	camera.global_position = eye
	var up := Vector3.UP
	if absf((target - eye).normalized().dot(Vector3.UP)) > 0.98:
		up = Vector3.FORWARD
	camera.look_at(target, up)
	if not is_zero_approx(roll):
		camera.rotate_object_local(Vector3(0, 0, 1), roll)
	camera.make_current()
	await _wait_frames(4)
	await RenderingServer.frame_post_draw
	var path := _out_dir.path_join("%s_%s.png" % [_name, shot_name])
	var image := root.get_texture().get_image()
	if image != null:
		image.save_png(path)
		manifest.append("- `%s`: %s; eye=%s target=%s" % [path.get_file(), note, eye, target])


func _measure_performance() -> Array[String]:
	if _fps_frames <= 0:
		return ["performance: NOT TESTED (--fps-frames=0)"]
	# Godot сильно троттлит окно без фокуса; для сравнения before/after
	# принудительно выводим окно вперёд и отключаем vsync на время замера.
	DisplayServer.window_move_to_foreground()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var viewport_rid := root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(viewport_rid, true)
	for i in 30:
		await process_frame
	var samples: Array[float] = []
	var gpu_samples: Array[float] = []
	var cpu_samples: Array[float] = []
	for i in _fps_frames:
		await process_frame
		var fps := float(Performance.get_monitor(Performance.TIME_FPS))
		if fps > 0.1:
			samples.append(fps)
		var gpu_ms := float(RenderingServer.viewport_get_measured_render_time_gpu(viewport_rid))
		var cpu_ms := float(RenderingServer.viewport_get_measured_render_time_cpu(viewport_rid))
		if gpu_ms > 0.0:
			gpu_samples.append(gpu_ms)
		if cpu_ms > 0.0:
			cpu_samples.append(cpu_ms)
	RenderingServer.viewport_set_measure_render_time(viewport_rid, false)
	if samples.is_empty():
		return ["performance: NOT TESTED (нет валидных samples)"]
	samples.sort()
	gpu_samples.sort()
	cpu_samples.sort()
	var average := _average(samples)
	var p1 := samples[int(samples.size() * 0.01)]
	var p99 := samples[int(samples.size() * 0.99)]
	var gpu_avg := _average(gpu_samples)
	var gpu_p95 := _percentile(gpu_samples, 0.95)
	var cpu_avg := _average(cpu_samples)
	var draw_calls := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var primitives := int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	var objects := int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
	return [
		"- samples: %d, avg_fps: %.1f, p1_fps: %.1f, p99_fps: %.1f" % [samples.size(), average, p1, p99],
		"- gpu_ms_avg: %.2f, gpu_ms_p95: %.2f, cpu_ms_avg: %.2f" % [gpu_avg, gpu_p95, cpu_avg],
		"- draw_calls: %d, primitives: %d, objects: %d" % [draw_calls, primitives, objects],
		"- window: %dx%d, renderer: %s; FPS зависит от фокуса окна, GPU ms — основной показатель" % [
			_width, _height, ProjectSettings.get_setting("rendering/renderer/rendering_method")
		],
	]


func _average(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var total := 0.0
	for value in values:
		total += value
	return total / values.size()


func _percentile(values: Array[float], fraction: float) -> float:
	if values.is_empty():
		return 0.0
	var index := clampi(int(values.size() * fraction), 0, values.size() - 1)
	return values[index]


func _wait_frames(count: int) -> void:
	for i in count:
		await process_frame
