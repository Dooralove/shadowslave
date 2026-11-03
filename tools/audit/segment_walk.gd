extends SceneTree
## Один сегмент реального движения по коллизии. Read-only.
## godot --headless --path . -s tools/audit/segment_walk.gd -- \
##   --scene=res://...tscn --from=-52,0.2,-15 --to=-30,-2.8,-42 --speed=6

var _scene_path := ""
var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _speed := 6.0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--scene="):
			_scene_path = arg.trim_prefix("--scene=")
		elif arg.begins_with("--from="):
			_from = _vec(arg.trim_prefix("--from="))
		elif arg.begins_with("--to="):
			_to = _vec(arg.trim_prefix("--to="))
		elif arg.begins_with("--speed="):
			_speed = float(arg.trim_prefix("--speed="))
	var packed := load(_scene_path) as PackedScene
	if packed == null:
		push_error("segment_walk: нет сцены")
		quit(2)
		return
	var scene := packed.instantiate()
	root.add_child(scene)
	for i in 6:
		await physics_frame
	var player := get_first_node_in_group(&"player") as SunnyController
	if player == null:
		push_error("segment_walk: нет игрока")
		quit(2)
		return
	player.global_position = _from
	player.velocity = Vector3.ZERO
	for i in 3:
		await physics_frame
	var max_frames := int(_from.distance_to(_to) / maxf(_speed, 1.0) * 60.0) + 400
	for frame in max_frames:
		var delta := _to - player.global_position
		var flat := Vector2(delta.x, delta.z)
		if flat.length() < 1.0 and absf(delta.y) < 1.4:
			player.forced_velocity = Vector3.ZERO
			print("PASS frames=", frame, " pos=", player.global_position)
			scene.queue_free()
			await process_frame
			quit(0)
			return
		if player.global_position.y < -20.0:
			player.forced_velocity = Vector3.ZERO
			print("FAIL fell pos=", player.global_position, " frame=", frame)
			scene.queue_free()
			await process_frame
			quit(1)
			return
		if flat.length() > 0.01:
			player.forced_velocity = Vector3(flat.x, 0.0, flat.y).normalized() * _speed
		await physics_frame
	player.forced_velocity = Vector3.ZERO
	print("FAIL timeout pos=", player.global_position)
	scene.queue_free()
	await process_frame
	quit(1)


func _vec(text: String) -> Vector3:
	var parts := text.split(",")
	if parts.size() != 3:
		return Vector3.ZERO
	return Vector3(float(parts[0]), float(parts[1]), float(parts[2]))
