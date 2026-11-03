extends SceneTree
## Read-only capture of the upgraded P1 cast in UAL poses.
## godot --path . -s tools/audit/cast_gear_capture.gd -- --out=<folder>

const MANNEQUIN := preload("res://scenes/slice/props/mannequin.tscn")

var _out := ""


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
	if _out.is_empty():
		push_error("cast_gear_capture: need --out=<folder>")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	root.size = Vector2i(1600, 900)

	var specs := [
		["hero", "walk", -2.4],
		["veteran", "idle", -1.2],
		["shifty", "walk", 0.0],
		["mass_slave", "idle", 1.2],
		["mass_soldier", "walk", 2.4],
	]
	for spec in specs:
		var model := MANNEQUIN.instantiate()
		model.archetype = spec[0]
		model.pose = spec[1]
		model.position = Vector3(spec[2], 0, 0)
		# Mannequin rotates the model 180° to face -Z; rotate the root back so the
		# audit camera sees the front instead of the back.
		model.rotation.y = PI
		root.add_child(model)
	await process_frame
	await process_frame

	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.22, 0.25, 0.30)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.70, 0.74, 0.80)
	env.ambient_light_energy = 1.8
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.glow_enabled = true
	env.glow_intensity = 0.3
	env_node.environment = env
	root.add_child(env_node)

	var key := DirectionalLight3D.new()
	key.light_color = Color(1.0, 0.88, 0.74)
	key.light_energy = 2.2
	key.rotation_degrees = Vector3(-48, 28, 0)
	key.shadow_enabled = true
	root.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.light_color = Color(0.55, 0.72, 1.0)
	rim.light_energy = 1.4
	rim.rotation_degrees = Vector3(-18, 205, 0)
	root.add_child(rim)
	var backfill := DirectionalLight3D.new()
	backfill.light_color = Color(0.95, 0.93, 0.90)
	backfill.light_energy = 1.8
	backfill.rotation_degrees = Vector3(-25, 180, 0)
	root.add_child(backfill)

	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(14, 8)
	var floor := MeshInstance3D.new()
	floor.mesh = floor_mesh
	floor.position = Vector3(0, -0.01, 0)
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.035, 0.04, 0.045)
	fm.roughness = 0.9
	floor.material_override = fm
	root.add_child(floor)

	var camera := Camera3D.new()
	camera.fov = 34.0
	camera.position = Vector3(0.0, 1.55, 6.2)
	root.add_child(camera)
	camera.look_at(Vector3(0, 0.9, 0))
	camera.make_current()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(_out.path_join("cast_gear.png"))
	print("cast_gear_capture: done ", _out)
	quit(0)
