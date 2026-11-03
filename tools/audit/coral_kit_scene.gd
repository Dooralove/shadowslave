extends SceneTree
## Пилотная сцена кораллового кита в Godot: проверка масштаба, материалов и силуэтов.
## godot --path . -s tools/audit/coral_kit_scene.gd -- --out=C:/Users/user/AppData/Local/Temp/opencode

const ROOT := "res://assets/environments/nightmare/coral/"
const LAYOUT := [
	["ground_patch_large_a.glb", Vector3(0, 0, 0), 0.0, 1.5],
	["ground_patch_b.glb", Vector3(8, 0, 5), 0.3, 1.0],
	["coral_wall_tall_a.glb", Vector3(-7, 0, -4), 0.0, 1.0],
	["coral_wall_tall_b.glb", Vector3(7, 0, -13), 3.14, 1.0],
	["coral_wall_low_a.glb", Vector3(0, 0, -19), 0.0, 1.15],
	["coral_mass_a.glb", Vector3(0, 0, -15), 0.4, 1.2],
	["coral_blade_hero.glb", Vector3(5, 0, -25), 0.7, 1.0],
	["coral_ledge_a.glb", Vector3(-3.5, 2.5, -8), 0.2, 1.0],
	["coral_ramp_a.glb", Vector3(-4.5, 0, 3), 0.0, 1.0],
	["coral_arch_a.glb", Vector3(0, 0, -22), 0.0, 1.2],
	["bone_rib_a.glb", Vector3(3.5, 0, -3), 0.4, 1.0],
	["campfire_a.glb", Vector3(-3.5, 0, -1), 0.0, 1.0],
	["coral_tunnel_shell_a.glb", Vector3(12, 0, 8), 1.2, 1.0],
	["coral_pillar_camp.glb", Vector3(-14, 0, -32), 0.0, 1.0],
]

var _out := ""


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
	if _out.is_empty():
		_out = OS.get_user_data_dir()
	DirAccess.make_dir_recursive_absolute(_out)
	root.size = Vector2i(1280, 720)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.30, 0.33, 0.38)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.66, 0.72)
	env.ambient_light_energy = 0.85
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.ssao_enabled = true
	env.ssao_intensity = 1.2
	env.glow_enabled = true
	env.glow_intensity = 0.25
	env.fog_enabled = true
	env.fog_light_color = Color(0.22, 0.21, 0.24)
	env.fog_density = 0.0035
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -38, 0)
	sun.light_color = Color(0.80, 0.85, 0.96)
	sun.light_energy = 3.0
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 80.0
	root.add_child(sun)

	var floor := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(80, 80)
	floor.mesh = plane
	var fmat := StandardMaterial3D.new()
	fmat.albedo_color = Color(0.10, 0.09, 0.11)
	fmat.roughness = 0.75
	floor.material_override = fmat
	floor.position = Vector3(0, -0.05, 0)
	root.add_child(floor)

	for entry in LAYOUT:
		var packed := load(ROOT + entry[0]) as PackedScene
		if packed == null:
			push_warning("missing " + str(entry[0]))
			continue
		var n := packed.instantiate() as Node3D
		n.position = entry[1]
		n.rotation.y = entry[2]
		n.scale = Vector3.ONE * entry[3]
		root.add_child(n)

	# Обзор.
	var cam := Camera3D.new()
	cam.fov = 55.0
	cam.far = 300.0
	root.add_child(cam)
	cam.position = Vector3(20, 18, 26)
	cam.look_at(Vector3(0, 4, -12), Vector3.UP)
	cam.make_current()
	for i in 10:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(_out.path_join("coral_kit_overview.png"))

	# Глаза игрока.
	cam.position = Vector3(0, 1.75, 12)
	cam.look_at(Vector3(0, 3.5, -12), Vector3.UP)
	for i in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(_out.path_join("coral_kit_eye.png"))

	print("coral_kit_scene: saved ", _out)
	quit(0)
