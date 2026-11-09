extends SceneTree
## Read-only width probe for the pilgrim ascent.
## Casts a Sunny-sized capsule across the trail at each z and prints the
## longest collision-free interval. Used to keep the passable strip >= 2.2 m.
##
## godot --headless --path . -s tools/audit/pilgrim_width_probe.gd -- \
##   --scene=res://scenes/locations/pilgrim_path/pilgrim_path_art.tscn \
##   --from-z=-14 --to-z=-62 --step=1

const WORLD_MASK := 1 | 32

var _scene_path := "res://scenes/locations/pilgrim_path/pilgrim_path_art.tscn"
var _from_z := -14.0
var _to_z := -62.0
var _step := 1.0
var _min_width := 2.2


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--scene="):
			_scene_path = arg.trim_prefix("--scene=")
		elif arg.begins_with("--from-z="):
			_from_z = float(arg.trim_prefix("--from-z="))
		elif arg.begins_with("--to-z="):
			_to_z = float(arg.trim_prefix("--to-z="))
		elif arg.begins_with("--step="):
			_step = maxf(float(arg.trim_prefix("--step=")), 0.25)
	var packed := load(_scene_path) as PackedScene
	if packed == null:
		push_error("pilgrim_width_probe: cannot load " + _scene_path)
		quit(2)
		return
	var scene := packed.instantiate() as Node3D
	root.add_child(scene)
	for i in 6:
		await physics_frame
	var space := scene.get_world_3d().direct_space_state
	var narrow: Array[String] = []
	print("WIDTH_PROBE scene=", _scene_path, " step=%.2f" % _step)
	for z in range(int(_from_z), int(_to_z) - 1, -int(_step)):
		var floor_hit := _floor(space, Vector3(-0.4, 5.5, z))
		if floor_hit.is_empty():
			continue
		var floor_y: float = floor_hit.position.y
		if floor_y < 3.0:
			continue
		var free_runs: Array[Vector2] = []
		var run_start := INF
		var x := -2.0
		while x <= 7.0:
			var free := not _blocked_at(space, Vector3(x, floor_y, z))
			if free and run_start == INF:
				run_start = x
			elif not free and run_start != INF:
				free_runs.append(Vector2(run_start, x - 0.1))
				run_start = INF
			x += 0.1
		if run_start != INF:
			free_runs.append(Vector2(run_start, 6.9))
		var best := Vector2.ZERO
		var best_distance := INF
		for run in free_runs:
			# The route runs near x = 0.95; report the free interval that
			# actually contains it, not a random open pocket behind a wall.
			var distance := 0.0 if run.x <= 0.95 and run.y >= 0.95 else minf(absf(run.x - 0.95), absf(run.y - 0.95))
			if distance < best_distance:
				best = run
				best_distance = distance
		var width := best.y - best.x
		var flag := "OK"
		if width < _min_width:
			flag = "NARROW"
			narrow.append("z=%d width=%.2f x=[%.2f..%.2f] y=%.2f" % [z, width, best.x, best.y, floor_y])
		print("z=%4d y=%.2f  best=[%6.2f..%6.2f] width=%.2f  %s" % [
			z, floor_y, best.x, best.y, width, flag
		])
	if narrow.is_empty():
		print("WIDTH_RESULT PASS all slices >= %.2f m" % _min_width)
	else:
		print("WIDTH_RESULT FAIL narrow slices=", narrow.size())
		for line in narrow:
			print("  ", line)
	scene.queue_free()
	await process_frame
	quit(0)


func _floor(space: PhysicsDirectSpaceState3D, from: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 20.0, WORLD_MASK)
	return space.intersect_ray(query)


func _blocked_at(space: PhysicsDirectSpaceState3D, point: Vector3) -> bool:
	for height_value in [0.5, 1.5]:
		var height := float(height_value)
		var from := point + Vector3.UP * height
		var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.RIGHT * 0.1, WORLD_MASK)
		var hit := space.intersect_ray(query)
		if not hit.is_empty() and hit.normal.y < 0.7:
			return true
	return false
