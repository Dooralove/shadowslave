extends SceneTree
## Read-only close-up preview for a model or prop scene.
## Usage:
##   godot --path . -s tools/audit/asset_preview.gd -- \
##     --scene=res://scenes/locations/caravan_site/larva.tscn \
##     --out=C:/Users/user/AppData/Local/Temp/opencode/shots/larva
## The scene is instantiated, framed by its mesh AABB and rendered from three yaw angles.

var _scene_path := ""
var _out_dir := ""


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--scene="):
			_scene_path = arg.trim_prefix("--scene=")
		elif arg.begins_with("--out="):
			_out_dir = arg.trim_prefix("--out=")
	if _scene_path.is_empty() or _out_dir.is_empty():
		push_error("asset_preview: need --scene=res://... and --out=<folder>")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(_out_dir)
	root.size = Vector2i(900, 900)

	var packed := load(_scene_path) as PackedScene
	if packed == null:
		push_error("asset_preview: cannot load " + _scene_path)
		quit(2)
		return
	var model := packed.instantiate()
	root.add_child(model)
	await process_frame
	await process_frame

	var bounds := _mesh_bounds(model)
	if bounds.size == Vector3.ZERO:
		push_error("asset_preview: no meshes in " + _scene_path)
		quit(2)
		return
	var center := bounds.get_center()
	var radius: float = maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))

	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.015, 0.02, 0.028)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.30, 0.36, 0.44)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.glow_enabled = true
	env.glow_intensity = 0.35
	world.environment = env
	root.add_child(world)

	var key := DirectionalLight3D.new()
	key.light_color = Color(1.0, 0.88, 0.75)
	key.light_energy = 2.2
	key.rotation_degrees = Vector3(-48, 32, 0)
	key.shadow_enabled = true
	root.add_child(key)

	var rim := DirectionalLight3D.new()
	rim.light_color = Color(0.55, 0.72, 1.0)
	rim.light_energy = 1.4
	rim.rotation_degrees = Vector3(-20, 205, 0)
	root.add_child(rim)

	var camera := Camera3D.new()
	camera.fov = 42.0
	camera.near = 0.02
	camera.far = radius * 50.0
	root.add_child(camera)
	camera.make_current()

	var yaws := [35.0, 145.0, 235.0]
	for i in yaws.size():
		var yaw: float = deg_to_rad(yaws[i])
		var distance := radius * 2.8
		camera.global_position = center + Vector3(sin(yaw) * distance, radius * 0.16, cos(yaw) * distance)
		camera.look_at(center + Vector3(0, radius * 0.06, 0), Vector3.UP)
		await process_frame
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		image.save_png(_out_dir.path_join("view_%d.png" % i))
	print("asset_preview: done scene=", _scene_path, " out=", _out_dir, " bounds=", bounds)
	quit(0)


func _mesh_bounds(node: Node) -> AABB:
	var result := AABB()
	var has := false
	var stack: Array[Node] = [node]
	while not stack.is_empty():
		var current: Node = stack.pop_back()
		var mesh_instance := current as MeshInstance3D
		if mesh_instance != null and mesh_instance.mesh != null:
			var box := mesh_instance.global_transform * mesh_instance.mesh.get_aabb()
			if not has:
				result = box
				has = true
			else:
				result = result.merge(box)
		for child in current.get_children():
			stack.append(child)
	return result
