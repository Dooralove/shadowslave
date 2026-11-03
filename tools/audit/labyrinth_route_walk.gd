extends SceneTree
## Проверка реального движения по рампам и связкам Лабиринта.
##
## В отличие от tests/test_labyrinth_first_fragment.gd этот инструмент не
## телепортирует игрока на каждый этаж и не проверяет только «пол есть».
## Он ставит игрока в начало связки и ведёт его через `forced_velocity` до
## конца, поэтому ловит вертикальные разрывы, перевёрнутые рампы и стены,
## которые телепорт-тест мог замаскировать.
##
## Запуск:
##   godot --headless --path . -s tools/audit/labyrinth_route_walk.gd -- \
##     --scene=res://scenes/locations/forgotten_shore_labyrinth/labyrinth_first_fragment.tscn

const DEFAULT_SCENE := "res://scenes/locations/forgotten_shore_labyrinth/labyrinth_first_fragment.tscn"
const DEFAULT_SPEED := 10.0

var _scene_path := DEFAULT_SCENE
var _speed := DEFAULT_SPEED
var _only := PackedStringArray()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--scene="):
			_scene_path = arg.trim_prefix("--scene=")
		elif arg.begins_with("--speed="):
			_speed = maxf(float(arg.trim_prefix("--speed=")), 1.0)
		elif arg.begins_with("--only="):
			_only = arg.trim_prefix("--only=").split(",", false)
	var packed := load(_scene_path) as PackedScene
	if packed == null:
		push_error("route_walk: сцена не загружается: " + _scene_path)
		quit(2)
		return
	var scene := packed.instantiate()
	root.add_child(scene)
	for i in 5:
		await physics_frame
	# Audit isolation: runtime enemies are gameplay, not geometry. They can
	# stand on a route and make a walkable segment look blocked.
	for runtime_path in [^"Gameplay/Runtime", ^"Gameplay/RuntimeNarrative"]:
		var runtime := scene.get_node_or_null(runtime_path)
		if runtime == null:
			continue
		for child in runtime.get_children():
			if child is CollisionObject3D or child is CharacterBody3D:
				child.queue_free()
	await physics_frame
	var player := get_first_node_in_group(&"player") as SunnyController
	if player == null:
		push_error("route_walk: игрок не найден")
		quit(2)
		return
	print("route_walk scene=", _scene_path, " speed=", _speed)
	var failures := 0
	var segments := _segments()
	for index in segments.size():
		var segment: Dictionary = segments[index]
		if not _only.is_empty() and not _only.has(String(segment.name)):
			continue
		var start: Vector3 = segment.start
		var target: Vector3 = segment.target
		var speed: float = segment.get("speed", _speed)
		player.global_position = start
		player.velocity = Vector3.ZERO
		player.forced_velocity = Vector3.ZERO
		for i in 3:
			await physics_frame
		var result: Dictionary = {"ok": true, "pos": player.global_position, "frames": 0}
		var targets: Array = segment.get("path", [target])
		for waypoint in targets:
			result = await _walk(player, waypoint, speed, segment.name)
			if not result.ok:
				break
		if result.ok:
			print("OK   %02d %-22s pos=%s frames=%d" % [index + 1, segment.name, str(result.pos), result.frames])
		else:
			failures += 1
			print("FAIL %02d %-22s pos=%s target=%s frames=%d" % [index + 1, segment.name, str(result.pos), str(target), result.frames])
	player.forced_velocity = Vector3.ZERO
	print("route_walk result: ", segments.size() - failures, "/", segments.size(), " segments passed")
	scene.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)


func _walk(player: SunnyController, target: Vector3, speed: float, label: String) -> Dictionary:
	# Forced velocity is still scaled by the player's combat/equipment
	# multiplier. A demo loadout can be slower than the requested probe speed;
	# budget frames by the effective speed so long corridors do not report a
	# false block.
	var effective_speed := speed
	if player.combat != null and player.combat.has_method(&"get_move_speed_multiplier"):
		effective_speed *= maxf(float(player.combat.call(&"get_move_speed_multiplier")), 0.2)
	var max_frames := int(player.global_position.distance_to(target) / maxf(effective_speed, 1.0) * 60.0) + 600
	for frame in max_frames:
		var delta := target - player.global_position
		var flat := Vector2(delta.x, delta.z)
		if flat.length() < 1.0 and absf(delta.y) < 1.4:
			player.forced_velocity = Vector3.ZERO
			return {"ok": true, "pos": player.global_position, "frames": frame}
		if player.global_position.y < -20.0:
			player.forced_velocity = Vector3.ZERO
			return {"ok": false, "pos": player.global_position, "frames": frame}
		if flat.length() > 0.01:
			player.forced_velocity = Vector3(flat.x, 0.0, flat.y).normalized() * speed
		await physics_frame
	player.forced_velocity = Vector3.ZERO
	return {"ok": false, "pos": player.global_position, "frames": max_frames}


func _segments() -> Array:
	return [
		{"name": "entry_down", "start": Vector3(38, 6.2, 0), "target": Vector3(30, 0.2, 0), "speed": 6.0},
		{"name": "entry_up", "start": Vector3(28, 0.2, 0), "target": Vector3(37.2, 6.2, 0), "speed": 6.0},
		{"name": "z01_fork", "start": Vector3(30, 0.2, 0), "target": Vector3(12, 0.2, 0), "speed": 8.0},
		{"name": "fork_center", "start": Vector3(12, 0.2, 0), "target": Vector3(6, 0.2, 6), "speed": 6.0},
		{"name": "z03_north", "start": Vector3(6, 0.2, 6), "target": Vector3(0, 0.2, -10), "speed": 6.0},
		{"name": "z07_ramp", "start": Vector3(0, 0.2, -12), "target": Vector3(0, 7.0, -48), "speed": 10.0},
		{"name": "z07_ridge", "start": Vector3(0, 7.0, -48), "target": Vector3(-25, 7.0, -55), "speed": 8.0},
		{"name": "z07_west", "start": Vector3(-25, 7.0, -55), "target": Vector3(-50, 7.0, -48), "speed": 8.0},
		{"name": "z07_spur", "start": Vector3(-50, 7.0, -48), "target": Vector3(-55, 0.2, -20), "speed": 8.0},
		{"name": "z08_west", "start": Vector3(-55, 0.2, -18), "target": Vector3(-80, 0.2, 0), "speed": 8.0},
		{"name": "z10_step", "start": Vector3(-80, 0.2, 0), "target": Vector3(-85, 1.2, 0), "speed": 5.0},
		{"name": "z10_base", "start": Vector3(-85, 1.2, 0), "target": Vector3(-85, 1.2, 20), "speed": 8.0},
		{"name": "z10_climb", "start": Vector3(-85, 1.2, 20), "target": Vector3(-105, 18.2, 20), "speed": 8.0},
		{"name": "z10_top", "start": Vector3(-105, 18.2, 20), "target": Vector3(-105, 18.2, -10), "speed": 8.0},
		{"name": "z10_west", "start": Vector3(-112, 18.2, -10), "target": Vector3(-125, 6.2, -20), "path": [Vector3(-128, 12.2, -5), Vector3(-125, 6.2, -20)], "speed": 8.0},
		{"name": "z11_high", "start": Vector3(-125, 6.2, -20), "target": Vector3(-150, 6.2, -20), "speed": 8.0},
		{"name": "z12_high", "start": Vector3(-153, 5.2, -20), "target": Vector3(-200, 5.2, -20), "speed": 8.0},
		{"name": "z12_high_link", "start": Vector3(-200, 5.2, -20), "target": Vector3(-204, 5.2, -90), "speed": 10.0},
		{"name": "z13_north", "start": Vector3(-204, 5.2, -90), "target": Vector3(-450, 5.2, -90), "speed": 12.0},
		{"name": "z13_north_link", "start": Vector3(-450, 5.2, -90), "target": Vector3(-450, 0.2, -30), "speed": 8.0},
		{"name": "z13_central", "start": Vector3(-450, 0.2, -30), "target": Vector3(-535, 0.2, 0), "speed": 10.0},
		{"name": "z14_bridge_ramp", "start": Vector3(-540, 0.2, 0), "target": Vector3(-550, 6.2, 0), "speed": 6.0},
		{"name": "z14_bridge", "start": Vector3(-550, 6.2, 0), "target": Vector3(-650, 6.2, 0), "speed": 10.0},
		{"name": "z14_bridge_west", "start": Vector3(-650, 6.2, 0), "target": Vector3(-660, 2.2, 0), "speed": 6.0},
		{"name": "z15_base", "start": Vector3(-660, 2.2, 0), "target": Vector3(-650, 2.2, -20), "speed": 6.0},
		{"name": "z15_climb", "start": Vector3(-650, 2.2, -20), "target": Vector3(-680, 18.2, -20), "speed": 8.0},
		{"name": "z15_ledge", "start": Vector3(-680, 18.2, -20), "target": Vector3(-700, 18.2, -20), "speed": 5.0},
		{"name": "z15_down", "start": Vector3(-680, 18.2, -20), "target": Vector3(-650, 2.2, -20), "speed": 8.0},
		{"name": "z15_west", "start": Vector3(-650, 2.2, -30), "target": Vector3(-750, 2.2, -30), "speed": 8.0},
		{"name": "z16_ridge_approach", "start": Vector3(-750, 2.2, -30), "target": Vector3(-800, 0.2, 40), "speed": 10.0},
		{"name": "z16_ridge_link", "start": Vector3(-800, 0.2, 40), "target": Vector3(-800, 6.2, 70), "speed": 8.0},
		{"name": "z16_ridge", "start": Vector3(-800, 6.2, 70), "target": Vector3(-900, 6.2, 90), "speed": 8.0},
		{"name": "z16_ridge_west", "start": Vector3(-900, 6.2, 90), "target": Vector3(-1050, 6.2, 85), "speed": 10.0},
		{"name": "z16_to_z17", "start": Vector3(-1050, 6.2, 85), "target": Vector3(-1050, 8.2, 0), "speed": 10.0},
		{"name": "z17_high", "start": Vector3(-1050, 8.2, 0), "target": Vector3(-1300, 8.2, 0), "speed": 12.0},
		{"name": "z17_cliffs", "start": Vector3(-1300, 8.2, 0), "target": Vector3(-1320, 6.2, 0), "speed": 5.0},
		{"name": "z18_switch1", "start": Vector3(-1320, 6.2, 0), "target": Vector3(-1350, 16.2, 20), "speed": 8.0},
		{"name": "z18_switch2", "start": Vector3(-1350, 16.2, 20), "target": Vector3(-1380, 26.2, -10), "speed": 8.0},
		{"name": "z18_switch3", "start": Vector3(-1380, 26.2, -10), "target": Vector3(-1400, 35.2, 0), "speed": 8.0},
		{"name": "z18_top", "start": Vector3(-1400, 35.2, 0), "target": Vector3(-1410, 35.2, 0), "speed": 4.0},
		# Ответвления и низкие связки.
		{"name": "z03_z04", "start": Vector3(-12, 0.2, -7), "target": Vector3(-20, -2.8, -35), "speed": 8.0},
		{"name": "z04_z08", "start": Vector3(-45, -2.8, -30), "target": Vector3(-50, 0.2, -15), "speed": 8.0},
		{"name": "z03_z05", "start": Vector3(-15, 0.2, 14), "target": Vector3(-30, 0.2, 21), "speed": 8.0},
		{"name": "z05_z06", "start": Vector3(-50, 0.2, 30), "target": Vector3(-47, 6.2, 46), "speed": 8.0},
		{"name": "z05_z08", "start": Vector3(-45, 0.2, 20), "target": Vector3(-50, 0.2, 15), "speed": 5.0},
		{"name": "z08_z09", "start": Vector3(-55, 0.2, 20), "target": Vector3(-70, 0.2, 20), "speed": 6.0},
		{"name": "z11_low", "start": Vector3(-128, -1.0, 0), "target": Vector3(-153, 0.2, 0), "speed": 6.0},
		{"name": "z14_low", "start": Vector3(-540, 0.2, 18), "target": Vector3(-550, 2.2, 18), "speed": 5.0},
		{"name": "z14_low_west", "start": Vector3(-550, 2.2, 18), "target": Vector3(-650, 2.2, 18), "speed": 8.0},
		{"name": "z16_low", "start": Vector3(-750, 2.2, -20), "target": Vector3(-900, 0.2, 0), "speed": 10.0},
		{"name": "z17_low", "start": Vector3(-1050, 0.2, 25), "target": Vector3(-1100, -1.8, 25), "speed": 6.0},
	]
