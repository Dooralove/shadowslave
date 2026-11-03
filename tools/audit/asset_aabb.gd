extends SceneTree
## Печатает AABB GLB-ассета, чтобы ставить его по земле без догадок.
## `godot --headless --path . -s tools/audit/asset_aabb.gd -- res://path/a.glb`


func _init() -> void:
	var paths: Array[String] = []
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("res://"):
			paths.append(arg)
	call_deferred(&"_run", paths)


func _run(paths: Array[String]) -> void:
	for path in paths:
		var packed := load(path) as PackedScene
		if packed == null:
			print(path, " MISSING")
			continue
		var node := packed.instantiate() as Node3D
		root.add_child(node)
		var box := AABB()
		var first := true
		for child in node.find_children("*", "MeshInstance3D", true, false):
			var mesh := child as MeshInstance3D
			if mesh.mesh == null:
				continue
			var mesh_box: AABB = mesh.global_transform * mesh.get_aabb()
			box = mesh_box if first else box.merge(mesh_box)
			first = false
		print(
			"%s  pos=%s size=%s" % [path.get_file(), str(box.position.snapped(Vector3.ONE * 0.01)), str(box.size.snapped(Vector3.ONE * 0.01))]
		)
		node.queue_free()
	quit()
