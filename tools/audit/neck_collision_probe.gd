extends SceneTree
## Дополнительная проверка площадки: где реально есть физическая опора.
## Запуск: godot --headless --path . --script tools/audit/neck_collision_probe.gd

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var packed := load("res://scenes/locations/post_nightmare/black_sea_platform.tscn") as PackedScene
	var scene := packed.instantiate()
	root.add_child(scene)
	await process_frame
	await physics_frame
	var space: PhysicsDirectSpaceState3D = scene.get_world_3d().direct_space_state
	for point in [Vector3(0, 5, 0), Vector3(5.5, 5, 3.0), Vector3(6.2, 5, 3.0), Vector3(7.0, 5, 3.0), Vector3(7.5, 5, 3.0), Vector3(8.0, 5, 3.0)]:
		var query := PhysicsRayQueryParameters3D.create(point, Vector3(point.x, -8, point.z))
		var hit: Dictionary = space.intersect_ray(query)
		print("PROBE ", point, " hit=", not hit.is_empty(), " collider=", hit.get("collider", null), " at=", hit.get("position", null))
	quit(0)
