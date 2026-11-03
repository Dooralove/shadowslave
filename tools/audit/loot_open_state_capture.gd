extends SceneTree
## Renders the opened chest and sarcophagus in Godot to verify the hinge
## direction and imported materials. Read-only for the project; opens a local
## copy of the scene and writes PNG previews.
##
## Usage:
##   godot --path . -s tools/audit/loot_open_state_capture.gd -- \
##     --out=C:/Users/user/AppData/Local/Temp/opencode/loot_open

const CHEST := "res://scenes/loot/containers/chest_wood_iron.tscn"
const SARC := "res://scenes/loot/containers/ancient_tomb_sarcophagus.tscn"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out_dir := OS.get_temp_dir().path_join("loot_open")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out_dir)

	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.015, 0.02, 0.028)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.30, 0.36, 0.44)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
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

	root.size = Vector2i(900, 900)
	await _capture(CHEST, "chest_wood_iron_open_godot.png", out_dir, 2.8)
	await _capture(SARC, "ancient_tomb_sarcophagus_open_godot.png", out_dir, 4.2)
	print("LOOT_OPEN_CAPTURE out=%s" % out_dir)
	quit(0)


func _capture(scene_path: String, file_name: String, out_dir: String, distance: float) -> void:
	var packed := load(scene_path) as PackedScene
	var cache := packed.instantiate() as LootCache
	root.add_child(cache)
	await process_frame
	await process_frame
	cache.interact()
	await create_timer(0.9).timeout

	var bounds := _mesh_bounds(cache)
	var center := bounds.get_center()
	var radius: float = maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
	var camera := Camera3D.new()
	camera.fov = 42.0
	camera.near = 0.02
	camera.far = 50.0
	root.add_child(camera)
	camera.make_current()
	var yaw := deg_to_rad(35.0)
	camera.global_position = center + Vector3(sin(yaw) * distance, radius * 0.55, cos(yaw) * distance)
	camera.look_at(center + Vector3(0, radius * 0.1, 0), Vector3.UP)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(file_name))
	cache.queue_free()
	await process_frame


func _mesh_bounds(node: Node) -> AABB:
	var result := AABB()
	var has := false
	var stack: Array[Node] = [node]
	while not stack.is_empty():
		var current: Node = stack.pop_back()
		if current is MeshInstance3D:
			var mesh := (current as MeshInstance3D)
			var box := mesh.get_aabb()
			if has:
				result = result.merge(box)
			else:
				result = box
				has = true
		for child in current.get_children():
			stack.append(child)
	return result
