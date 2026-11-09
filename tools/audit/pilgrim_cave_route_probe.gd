extends SceneTree
## Read-only проверка прохода в пещеру pilgrim_path: тело Санни (капсула
## radius 0.35, height 1.8) должно пройти от тропы через устье, камеру,
## восточный проход и южный выход обратно на тропу.
##
## godot --headless --path . -s tools/audit/pilgrim_cave_route_probe.gd

const SCENE := "res://scenes/locations/pilgrim_path/pilgrim_path_art.tscn"
const POINTS := [
	Vector3(1.0, 4.1, -48.0),
	Vector3(2.4, 4.1, -48.2),
	Vector3(3.6, 4.1, -48.5),
	Vector3(4.0, 4.1, -48.5),
	Vector3(5.0, 4.1, -48.5),
	Vector3(6.5, 4.1, -49.5),
	Vector3(6.5, 4.1, -52.0),
	Vector3(4.0, 4.1, -53.4),
	Vector3(2.0, 4.1, -53.4),
	Vector3(1.0, 4.1, -53.4),
]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene := (load(SCENE) as PackedScene).instantiate() as Node3D
	root.add_child(scene)
	for i in 6:
		await physics_frame
	var space := scene.get_world_3d().direct_space_state
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	var blocked := 0
	for point in POINTS:
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = capsule
		query.transform = Transform3D(Basis(), point + Vector3.UP * 0.92)
		query.collision_mask = 1 | 32
		query.collide_with_areas = false
		var hits := space.intersect_shape(query, 8)
		if hits.is_empty():
			print("CAVE_ROUTE ", point, " FREE")
			continue
		blocked += 1
		var names: Array[String] = []
		for hit in hits:
			var collider := hit.get("collider") as Node
			if collider != null:
				names.append(str(scene.get_path_to(collider)))
		print("CAVE_ROUTE ", point, " BLOCKED ", ", ".join(names))
	print("CAVE_ROUTE_RESULT ", "PASS" if blocked == 0 else "FAIL blocked=%d" % blocked)
	scene.queue_free()
	quit()

