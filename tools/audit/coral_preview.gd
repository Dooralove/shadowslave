extends SceneTree
## Быстрый превью одного GLB-ассета в Godot: материалы, масштаб, силуэт.
## godot --path . -s tools/audit/coral_preview.gd -- \
##   --glb=res://assets/environments/nightmare/coral/coral_wall_tall_a.glb \
##   --out=C:/Users/user/AppData/Local/Temp/opencode/coral_wall_host.png

var _glb := ""
var _out := ""


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--glb="):
			_glb = arg.trim_prefix("--glb=")
		elif arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
	if _glb.is_empty() or _out.is_empty():
		push_error("coral_preview: нужны --glb= и --out=")
		quit(2)
		return
	root.size = Vector2i(1280, 720)
	var packed := load(_glb) as PackedScene
	if packed == null:
		push_error("coral_preview: не загрузился " + _glb)
		quit(3)
		return
	var model := packed.instantiate() as Node3D
	root.add_child(model)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.19, 0.21, 0.24)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.58, 0.64)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.ssao_enabled = true
	env.ssao_intensity = 1.0
	env.glow_enabled = true
	env.glow_intensity = 0.2
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -38, 0)
	sun.light_color = Color(0.82, 0.86, 0.95)
	sun.light_energy = 2.2
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 40.0
	root.add_child(sun)

	var cam := Camera3D.new()
	cam.fov = 55.0
	cam.far = 200.0
	root.add_child(cam)
	cam.position = Vector3(2.4, 6.8, 9.5)
	cam.look_at(Vector3(0, 4.8, 0), Vector3.UP)
	cam.make_current()

	for i in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(_out.get_base_dir())
	root.get_texture().get_image().save_png(_out)
	print("coral_preview: saved ", _out)
	quit(0)
