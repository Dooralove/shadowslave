extends SceneTree
## Headless-проверка интеграции статуи в black_sea_platform.
## Запуск: godot --headless --path . --script tools/audit/statue_integration_check.gd

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var packed := load("res://scenes/locations/post_nightmare/black_sea_platform.tscn") as PackedScene
	if packed == null:
		push_error("cannot load black_sea_platform.tscn")
		quit(2)
		return
	var scene := packed.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var structure := scene.find_child("Structure", true, false) as Node3D
	var statue := structure.find_child("StatueKnightColossus", true, false) if structure else null
	var collision := structure.find_child("NeckPlatformCollision", true, false) if structure else null
	print("STATUE=", statue != null, " COLLISION=", collision != null)
	if statue != null:
		print("STATUE_CHILDREN=", statue.get_child_count())
		for c in statue.get_children():
			var lod_tris := 0
			for mi_node in c.find_children("*", "MeshInstance3D", true, false):
				var mi := mi_node as MeshInstance3D
				if mi.mesh == null:
					continue
				for si in mi.mesh.get_surface_count():
					var arrays := mi.mesh.surface_get_arrays(si)
					var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
					lod_tris += indices.size() / 3
			print("  LOD=", c.name, " type=", c.get_class(), " tris=", lod_tris)
			for g in c.get_children():
				if g is GeometryInstance3D:
					print("    GEO ", g.name, " begin=", g.visibility_range_begin, " end=", g.visibility_range_end)
	if collision != null:
		for c in collision.get_children():
			if c is CollisionShape3D:
				print("COLLISION_SHAPE=", c.shape.get_class())
	var prim := structure.find_child("Chest", true, false) if structure else null
	print("OLD_PRIMITIVE_CHEST=", prim != null)
	if collision != null:
		var query := PhysicsRayQueryParameters3D.create(Vector3(0, 5, 0), Vector3(0, -5, 0))
		var hit: Dictionary = scene.get_world_3d().direct_space_state.intersect_ray(query)
		print("PLATFORM_RAY_HIT=", not hit.is_empty(), " ", hit.get("collider", null))
	quit(0)
