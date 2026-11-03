extends SceneTree
## Диагностика: где находятся ноги модели Mountain King относительно origin.


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var scene := (load("res://scenes/characters/mountain_king.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var min_y := INF
	var max_y := -INF
	for node in scene.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.mesh == null:
			continue
		var aabb := mesh.global_transform * mesh.get_aabb()
		min_y = minf(min_y, aabb.position.y)
		max_y = maxf(max_y, aabb.position.y + aabb.size.y)
	print("TYRANT_BOUNDS min_y=", min_y, " max_y=", max_y)
	scene.queue_free()
	quit()
