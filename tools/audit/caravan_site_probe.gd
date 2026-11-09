extends Node3D
## Поток D: проверка лагеря каравана в реальном контексте проекта (автозагрузки
## NightmareRunState/CampaignGuide доступны). Только читает и ставит временные
## состояния: сцена на диске не меняется.
##
## Запуск:
##   godot --path . res://tools/audit/caravan_site_probe.tscn -- \
##     --out=$env:TEMP\opencode\caravan_probe --threshold=0.15 [--shots]
##
## Печатает зазоры до пола для дерева, следов, камней, повозки и Тирана.
## Итог: CARAVAN_PROBE RESULT PASS/FAIL.

const DEFAULT_SCENE := "res://scenes/locations/caravan_site/caravan_site_art.tscn"

var _scene_path := DEFAULT_SCENE
var _out_dir := ""
var _threshold := 0.15
var _take_shots := false
var _failures: Array[String] = []
var _shot_camera: Camera3D
var _site: CaravanSite


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--scene="):
			_scene_path = arg.trim_prefix("--scene=")
		elif arg.begins_with("--out="):
			_out_dir = arg.trim_prefix("--out=")
		elif arg.begins_with("--threshold="):
			_threshold = float(arg.trim_prefix("--threshold="))
		elif arg == "--shots":
			_take_shots = true
	if not _out_dir.is_empty():
		DirAccess.make_dir_recursive_absolute(_out_dir)
	await _run()
	print("CARAVAN_PROBE RESULT %s%s" % [
		"PASS" if _failures.is_empty() else "FAIL",
		"" if _failures.is_empty() else " " + ", ".join(_failures),
	])
	get_tree().quit(0 if _failures.is_empty() else 1)


func _run() -> void:
	var packed := load(_scene_path) as PackedScene
	if packed == null:
		push_error("caravan_site_probe: сцена не загрузилась: %s" % _scene_path)
		get_tree().quit(2)
		return
	_site = packed.instantiate() as CaravanSite
	add_child(_site)
	for i in 4:
		await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().physics_frame

	print("CARAVAN_PROBE scene=%s threshold=%.2f" % [_scene_path, _threshold])
	_report_tree()
	_report_trails()
	_report_wagon()
	_site.drop_rocks(true)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_report_rocks()
	_report_initial_npcs()
	await _report_tyrant()
	await _report_aftermath()
	_report_barriers()
	_report_markers()
	_report_camera()
	_report_dawn_exit()
	if _take_shots and not _out_dir.is_empty():
		await _capture_frames()


func _visual_ground(point: Vector3, ignore: Node = null) -> Dictionary:
	## Самый высокий видимый меш, который накрывает x/z и находится не выше point.y.
	var best_y := -INF
	var best_path := ""
	for node in _site.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh == null or mesh.mesh == null or not mesh.is_visible_in_tree():
			continue
		if ignore != null and (mesh == ignore or ignore.is_ancestor_of(mesh)):
			continue
		var box := mesh.global_transform * mesh.get_aabb()
		if maxf(box.size.x, maxf(box.size.y, box.size.z)) > 60.0:
			continue
		if point.x < box.position.x or point.x > box.end.x:
			continue
		if point.z < box.position.z or point.z > box.end.z:
			continue
		var top := box.end.y
		# Допускаем опору чуть выше нижней грани: объект может быть слегка
		# утоплен в снег/камень. Для «висит» важен только зазор сверху.
		if top <= point.y + 0.6 and top > best_y:
			best_y = top
			best_path = String(_site.get_path_to(mesh))
	return {"y": best_y, "path": best_path}


func _ray_down(point: Vector3, depth := 12.0) -> Dictionary:
	var space := _site.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		point + Vector3.UP * 0.4, point + Vector3.DOWN * depth, 1 | 32
	)
	return space.intersect_ray(query)


func _aabb_of(node: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var mesh := child as MeshInstance3D
		if mesh == null or mesh.mesh == null or not mesh.is_visible_in_tree():
			continue
		var mesh_box := mesh.global_transform * mesh.get_aabb()
		box = mesh_box if first else box.merge(mesh_box)
		first = false
	return box


func _report_tree() -> void:
	var tree := _site.get_node_or_null(^"SeamsMidground/DeadTree") as Node3D
	if tree == null:
		_record("TREE missing", false)
		return
	var box := _aabb_of(tree)
	var ground := _visual_ground(Vector3(box.get_center().x, box.position.y, box.get_center().z), tree)
	var gap := maxf(0.0, box.position.y - float(ground["y"])) if ground["y"] > -INF else 999.0
	_line("TREE bottom=%.3f ground=%.3f gap=%.3f support=%s" % [
		box.position.y, ground["y"], gap, ground["path"]
	])
	_record("TREE", gap <= _threshold)


func _report_trails() -> void:
	for trail_name in [^"P3SiteDressing/BootprintsApproach", ^"P3SiteDressing/ChainScuffs", ^"P3SiteDressing/BloodSpots"]:
		var trail := _site.get_node_or_null(trail_name) as Node3D
		if trail == null:
			_record("TRAIL %s missing" % trail_name, false)
			continue
		var worst_gap := 0.0
		var worst_name := ""
		var total := 0
		for child in trail.get_children():
			var mesh := child as MeshInstance3D
			if mesh == null or mesh.mesh == null:
				continue
			total += 1
			var box := mesh.global_transform * mesh.get_aabb()
			var ground := _visual_ground(Vector3(box.get_center().x, box.position.y, box.get_center().z), trail)
			var gap := maxf(0.0, box.position.y - float(ground["y"])) if ground["y"] > -INF else 999.0
			if gap > worst_gap:
				worst_gap = gap
				worst_name = String(mesh.name)
		_line("TRAIL %s steps=%d worst_gap=%.3f step=%s" % [trail.name, total, worst_gap, worst_name])
		_record("TRAIL %s" % trail.name, worst_gap <= _threshold)


func _report_wagon() -> void:
	var wagon := _site.get_node_or_null(^"Props/Wagon") as Node3D
	if wagon == null:
		return
	var box := _aabb_of(wagon)
	var ground := _visual_ground(Vector3(box.get_center().x, box.position.y, box.get_center().z), wagon)
	var gap := maxf(0.0, box.position.y - float(ground["y"])) if ground["y"] > -INF else 999.0
	_line("WAGON bottom=%.3f ground=%.3f gap=%.3f" % [box.position.y, ground["y"], gap])


func _report_rocks() -> void:
	var rocks := _site.get_node_or_null(^"Props/Rocks") as Node3D
	if rocks == null:
		return
	var worst_gap := 0.0
	var worst_name := ""
	var visible := 0
	for child in rocks.get_children():
		if child is RockfallHazard:
			continue
		var rock := child as Node3D
		if rock == null or not rock.visible:
			continue
		visible += 1
		var box := _aabb_of(rock)
		var ground := _visual_ground(Vector3(box.get_center().x, box.position.y, box.get_center().z), rock)
		var gap := maxf(0.0, box.position.y - float(ground["y"])) if ground["y"] > -INF else 999.0
		if gap > worst_gap:
			worst_gap = gap
			worst_name = String(rock.name)
		_line("ROCK %s bottom=%.3f ground=%.3f gap=%.3f" % [
			rock.name, box.position.y, ground["y"], gap
		])
	_line("ROCK_SUMMARY visible=%d worst_gap=%.3f rock=%s" % [visible, worst_gap, worst_name])
	_record("ROCKS", worst_gap <= _threshold)


func _report_tyrant() -> void:
	_site.show_tyrant()
	_site.grow_tyrant(0.0, true)
	await get_tree().process_frame
	var tyrant := _site.get_node_or_null("Tyrant") as Node3D
	if tyrant == null:
		_record("TYRANT missing", false)
		return
	var box := _aabb_of(tyrant)
	var ledge := _site.get_node_or_null(^"Art/TyrantLedge") as Node3D
	var ledge_box := _aabb_of(ledge) if ledge != null else AABB()
	var center := Vector3(tyrant.global_position.x, box.position.y, tyrant.global_position.z)
	var center_hit := _ray_down(center, 5.0)
	var ray_y := (center_hit.position as Vector3).y if not center_hit.is_empty() else -999.0
	var ray_gap := box.position.y - ray_y
	var ray_collider := ""
	if not center_hit.is_empty():
		var collider := center_hit.collider as Node
		ray_collider = String(_site.get_path_to(collider)) if collider != null else ""
	var aabb_gap := box.position.y - ledge_box.end.y if ledge != null else 999.0
	_line("TYRANT origin_y=%.3f foot_bottom=%.3f ledge_aabb_top=%.3f aabb_gap=%.3f ray_top=%.3f ray_gap=%.3f collider=%s" % [
		tyrant.global_position.y, box.position.y, ledge_box.end.y, aabb_gap, ray_y, ray_gap, ray_collider
	])
	for x_offset in [-0.45, 0.45]:
		var foot_hit := _ray_down(tyrant.global_position + Vector3(x_offset, box.position.y - tyrant.global_position.y, 0.0), 5.0)
		if not foot_hit.is_empty():
			var foot_collider := foot_hit.collider as Node
			_line("TYRANT_FOOT x=%.2f hit=%.3f collider=%s" % [
				x_offset, (foot_hit.position as Vector3).y,
				String(_site.get_path_to(foot_collider)) if foot_collider != null else ""
			])
	_record("TYRANT_LEDGE", absf(ray_gap) <= _threshold)


func _report_initial_npcs() -> void:
	for actor_name in ["BroadSlave", "ShiftySlave", "Scholar", "SlaveA", "SlaveB", "SlaveC"]:
		var actor := _site.get_node_or_null("NPCs/" + actor_name) as Node3D
		if actor == null or not actor.visible:
			continue
		var box := _aabb_of(actor)
		var ground := _visual_ground(Vector3(actor.global_position.x, actor.global_position.y + 1.0, actor.global_position.z), actor)
		var gap := maxf(0.0, box.position.y - float(ground["y"])) if ground["y"] > -INF else 999.0
		_line("NPC_INITIAL %s pose=%s bottom=%.3f ground=%.3f gap=%.3f" % [
			actor_name, (actor as Mannequin).pose, box.position.y, ground["y"], gap
		])


func _report_aftermath() -> void:
	_site.show_aftermath()
	_site.broad_slave.visible = false
	await get_tree().process_frame
	var player_point := Vector3(0.6, 0.0, 2.1)
	for actor_name in ["Hero", "ShiftySlave", "Scholar", "Veteran"]:
		var actor := _site.get_node_or_null("NPCs/" + actor_name) as Node3D
		if actor == null:
			continue
		var box := _aabb_of(actor)
		var ground := _visual_ground(Vector3(actor.global_position.x, actor.global_position.y + 1.0, actor.global_position.z), actor)
		var gap := maxf(0.0, box.position.y - float(ground["y"])) if ground["y"] > -INF else 999.0
		var forward := -actor.global_transform.basis.z
		var head_dir := actor.global_transform.basis.z
		var to_player := (player_point - actor.global_position).normalized()
		var facing := forward.dot(to_player)
		var head_facing := head_dir.dot(to_player)
		_line("NPC %s pose=%s bottom=%.3f ground=%.3f gap=%.3f facing_player=%.2f head_to_player=%.2f" % [
			actor_name, (actor as Mannequin).pose, box.position.y, ground["y"], gap, facing, head_facing
		])
		_record("NPC_GROUND %s" % actor_name, gap <= _threshold)
	_record("NPC_HEAD Veteran", _head_facing(_site.get_node("NPCs/Veteran") as Node3D, player_point))
	_record("NPC_FACING Hero", _facing_ok(_site.get_node("NPCs/Hero") as Node3D, player_point))


func _head_facing(actor: Node3D, point: Vector3) -> bool:
	if actor == null:
		return false
	var head_dir := actor.global_transform.basis.z
	var to_point := (point - actor.global_position).normalized()
	return head_dir.dot(to_point) > 0.15



func _facing_ok(actor: Node3D, point: Vector3) -> bool:
	if actor == null:
		return false
	var forward := -actor.global_transform.basis.z
	var to_point := (point - actor.global_position).normalized()
	return forward.dot(to_point) > 0.15


func _report_barriers() -> void:
	for barrier_name in [
		"NorthEndWall", "NorthEndSnow",
		"SouthBarrierRock", "SouthBarrierScree", "SouthBarrierSnow",
		"SouthBarrierWall", "SouthBarrierCliff",
	]:
		var barrier := _site.get_node_or_null("Art/" + barrier_name) as Node3D
		if barrier == null:
			_line("BARRIER %s missing" % barrier_name)
			continue
		var box := _aabb_of(barrier)
		_line("BARRIER %s pos=%s aabb_min=%s max=%s" % [
			barrier_name, str(barrier.global_position), str(box.position), str(box.end)
		])


func _report_markers() -> void:
	## Видимые маркеры HUD — экранные; здесь проверяем мировые точки спавнов,
	## к которым они привязаны: ни одна не должна висеть над полом.
	for child in _site.get_node(^"Spawns").get_children():
		var marker := child as Node3D
		if marker == null:
			continue
		var hit := _ray_down(marker.global_position, 4.0)
		var ground_y := (hit.position as Vector3).y if not hit.is_empty() else -INF
		var gap := marker.global_position.y - ground_y
		_line("SPAWN %s y=%.3f ground=%.3f gap=%.3f" % [marker.name, marker.global_position.y, ground_y, gap])


func _report_dawn_exit() -> void:
	var exit_node := _site.get_node_or_null(^"Interactables/DawnExit") as Node3D
	if exit_node == null:
		_record("DAWN_EXIT missing", false)
		return
	var hit := _ray_down(exit_node.global_position, 4.0)
	var ground_y := (hit.position as Vector3).y if not hit.is_empty() else -INF
	_line("DAWN_EXIT pos=%s ground=%.3f" % [str(exit_node.global_position), ground_y])
	_record("DAWN_EXIT_FLOOR", ground_y > -INF)
	# Между лагерем и выходом не должно быть новой стены: проверяем пол по линии.
	var blocked := false
	for z in [-4.6, -5.6, -6.6, -7.4, -8.4]:
		var floor_hit := _ray_down(Vector3(0.2, 0.8, z), 3.0)
		if floor_hit.is_empty():
			blocked = true
	_line("DAWN_EXIT_PATH blocked=%s" % str(blocked))
	_record("DAWN_EXIT_PATH", not blocked)


func _report_camera() -> void:
	var target := Vector3(-4.0, 1.4, -2.4)
	var point := Vector3(4.2, 4.2, 4.6)
	var space := _site.get_world_3d().direct_space_state
	var sight := space.intersect_ray(PhysicsRayQueryParameters3D.create(point, target, 1 | 32))
	var blocked := ""
	if not sight.is_empty():
		var collider := sight.collider as Node
		var path := String(_site.get_path_to(collider)) if collider != null else ""
		var is_subject := path.contains("Wagon") or path.contains("Tyrant")
		if not is_subject and (sight.position as Vector3).distance_to(point) < point.distance_to(target) - 2.0:
			blocked = path
	_line("CAMERA %s target=%s blocker=%s" % [str(point), str(target), blocked if not blocked.is_empty() else "none"])
	_record("CAMERA", blocked.is_empty())


func _capture_frames() -> void:
	_shot_camera = Camera3D.new()
	_shot_camera.fov = 58.0
	_shot_camera.near = 0.05
	_shot_camera.far = 600.0
	add_child(_shot_camera)
	_shot_camera.current = true
	await _shot("01_camp_overview", Vector3(4.2, 4.2, 4.6), Vector3(-1.5, 1.2, -1.2), 62.0)
	_site.show_aftermath()
	_site.broad_slave.visible = false
	await get_tree().process_frame
	await _shot("02_aftermath", Vector3(4.2, 2.6, 5.0), Vector3(1.6, 0.6, -2.4), 65.0)
	await _shot("05_veteran_close", Vector3(2.2, 2.2, 1.4), Vector3(2.2, 0.35, -3.3), 55.0)
	await _shot("06_north_barrier", Vector3(0.2, 2.0, -1.8), Vector3(0.8, 0.8, -6.2), 65.0)
	await _shot("07_south_barrier", Vector3(0.2, 2.0, 5.8), Vector3(0.2, 0.8, 11.0), 65.0)
	_site.show_aftermath()
	_site.broad_slave.visible = false
	_site.begin_wagon_phase()
	await get_tree().process_frame
	_site.wagon.visible = true
	_site.wagon.position = Vector3(-4.0, 0.0, -2.4)
	_site.wagon.rotation = Vector3.ZERO
	var wagon_box := _aabb_of(_site.wagon)
	var camera_box := AABB(Vector3(4.2, 4.2, 4.6) - Vector3(0.25, 0.25, 0.25), Vector3(0.5, 0.5, 0.5))
	_record("CAMERA_WAGON_CLEAR", not camera_box.intersects(wagon_box))
	await _shot("03_wagon_camera", Vector3(4.2, 4.2, 4.6), Vector3(-4.0, 1.4, -2.4), 58.0)
	_site.wagon.visible = false
	_site.hide_tyrant()
	_site.show_tyrant()
	_site.grow_tyrant(0.0, true)
	await get_tree().process_frame
	await _shot("04_tyrant_ledge", Vector3(3.2, 8.0, 2.2), Vector3(0.8, 6.6, -4.5), 55.0)
	await _capture_wrapper_camera()


func _capture_wrapper_camera() -> void:
	var packed := load("res://scenes/campaign/caravan_site_arrival.tscn") as PackedScene
	if packed == null:
		_record("WRAPPER_CAMERA load", false)
		return
	var wrapper := packed.instantiate()
	wrapper.set(&"fast_mode", true)
	wrapper.set(&"fade_in", false)
	wrapper.set(&"transition_enabled", false)
	wrapper.set(&"debug_direct_scene", true)
	add_child(wrapper)
	for i in 4:
		await get_tree().process_frame
	var site := wrapper.get_node("CaravanSite") as CaravanSite
	site.stage_tyrant_for_wagon()
	site.begin_wagon_phase()
	site.wagon.visible = true
	wrapper.call(&"_stage_wagon_camera")
	await get_tree().process_frame
	await get_tree().process_frame
	var camera := wrapper.get_node_or_null("WagonCamera") as Camera3D
	if camera == null:
		_record("WRAPPER_CAMERA node", false)
		wrapper.queue_free()
		return
	var up_dot := camera.global_transform.basis.y.dot(Vector3.UP)
	_line("WRAPPER_CAMERA pos=%s current=%s up_dot=%.3f" % [
		str(camera.global_position), str(camera.current), up_dot
	])
	_record("WRAPPER_CAMERA_UP", up_dot > 0.9)
	var wagon_box := _aabb_of(site.wagon)
	var cam_box := AABB(camera.global_position - Vector3(0.25, 0.25, 0.25), Vector3(0.5, 0.5, 0.5))
	_record("WRAPPER_CAMERA_INSIDE_WAGON", not cam_box.intersects(wagon_box))
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := _out_dir.path_join("08_wagon_camera_real.png")
	image.save_png(path)
	print("CARAVAN_PROBE SHOT %s %s" % [path, str(image.get_size())])
	wrapper.queue_free()
	await get_tree().process_frame


func _shot(name: String, position: Vector3, look: Vector3, fov: float, keep_transform := false) -> void:
	if not keep_transform:
		_shot_camera.global_position = position
		_shot_camera.look_at(look, Vector3.UP)
		_shot_camera.fov = fov
	for i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := _out_dir.path_join(name + ".png")
	image.save_png(path)
	print("CARAVAN_PROBE SHOT %s %s" % [path, str(image.get_size())])


func _record(label: String, ok: bool) -> void:
	if not ok:
		_failures.append(label)


func _line(text: String) -> void:
	print("  " + text)
