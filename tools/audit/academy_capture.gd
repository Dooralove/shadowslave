extends SceneTree
## Read-only capture and material audit for the standalone Academy locations.
## Run with a rendering window (no --headless):
##   godot --path . -s tools/audit/academy_capture.gd -- \
##     --scene=res://scenes/locations/academy/academy_grounds.tscn \
##     --out=C:/Users/user/AppData/Local/Temp/opencode/academy_shots

var _out_dir := ""
var _scene_path := "res://scenes/locations/academy/academy_grounds.tscn"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out_dir = arg.trim_prefix("--out=")
		elif arg.begins_with("--scene="):
			_scene_path = arg.trim_prefix("--scene=")
	if _out_dir.is_empty():
		push_error("academy_capture: need --out=<folder>")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(_out_dir)
	root.size = Vector2i(1440, 810)
	var packed := load(_scene_path) as PackedScene
	if packed == null:
		push_error("academy_capture: cannot load %s" % _scene_path)
		quit(2)
		return
	var location := packed.instantiate() as Node3D
	root.add_child(location)
	await process_frame
	await process_frame
	await process_frame
	_audit(location)
	var shots := location.get_node_or_null(^"Shots")
	if shots == null:
		push_error("academy_capture: no Shots node")
		quit(2)
		return
	for child in shots.get_children():
		var camera := child as Camera3D
		if camera == null:
			continue
		camera.current = true
		await _save("%s.png" % camera.name.to_snake_case())
	print("academy_capture: done scene=", _scene_path, " out=", _out_dir)
	quit(0)


func _audit(location: Node) -> void:
	var mesh_count := 0
	var triangle_count := 0
	var materials := {}
	var stack: Array[Node] = [location]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is MeshInstance3D:
			var mesh_instance := node as MeshInstance3D
			mesh_count += 1
			if mesh_instance.mesh != null:
				triangle_count += int(mesh_instance.mesh.get_faces().size() / 3)
				for surface in mesh_instance.mesh.get_surface_count():
					var material := mesh_instance.get_surface_override_material(surface)
					if material == null:
						material = mesh_instance.mesh.surface_get_material(surface)
					var key := "<none>"
					if material != null:
						key = material.resource_name if not material.resource_name.is_empty() else material.resource_path
					materials[key] = int(materials.get(key, 0)) + 1
		for child in node.get_children():
			stack.append(child)
	print("ACADEMY_AUDIT meshes=", mesh_count, " triangles=", triangle_count)
	var keys := materials.keys()
	keys.sort()
	for key in keys:
		print("  material ", key, " x", materials[key])


func _save(file_name: String) -> void:
	for i in 5:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(_out_dir.path_join(file_name))
	print("CAPTURE ", _out_dir.path_join(file_name))
