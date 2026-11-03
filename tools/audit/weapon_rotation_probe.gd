extends SceneTree
## Compare weapon socket rotations in Sword_Idle / Sword_Attack.

const MODEL := "res://assets/characters/p1/sunny_p1_model.tscn"

var _out := ""


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
	if _out.is_empty():
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	root.size = Vector2i(900, 900)
	var stage := Node3D.new()
	root.add_child(stage)
	_add_environment(stage)
	_add_floor(stage)
	_add_lights(stage)
	var model := (load(MODEL) as PackedScene).instantiate() as Node3D
	stage.add_child(model)
	await process_frame
	await process_frame
	var player := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var socket := model.find_child("WeaponSocket", true, false) as BoneAttachment3D
	var sword := socket.get_node("Weapon") as Node3D
	socket.visible = true
	var cam := Camera3D.new()
	cam.fov = 34.0
	cam.near = 0.05
	cam.far = 50.0
	stage.add_child(cam)
	cam.current = true
	cam.position = Vector3(1.6, 1.55, 5.4)
	cam.look_at(Vector3(0, 1.0, 0), Vector3.UP)
	for rot in [Vector3(90, 0, 0), Vector3(90, 0, 45), Vector3(90, 30, 0), Vector3(90, -30, 0), Vector3(70, 0, 0), Vector3(110, 0, 0)]:
		sword.rotation_degrees = rot
		for entry in [[&"Sword_Idle", 0.4, "idle"], [&"Sword_Attack", 0.55, "attack"]]:
			player.play(entry[0])
			player.seek(entry[1], true)
			player.pause()
			for i in 3:
				await process_frame
			await RenderingServer.frame_post_draw
			var tag := "%d_%d_%d_%s" % [int(rot.x), int(rot.y), int(rot.z), entry[2]]
			root.get_texture().get_image().save_png(_out.path_join("rot_%s.png" % tag))
			print("SHOT ", tag)
	quit(0)


func _add_environment(stage: Node3D) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.025, 0.03, 0.04)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.34, 0.4, 0.5)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.4
	env.ssao_enabled = true
	env.ssao_radius = 1.5
	env.ssao_intensity = 1.3
	var node := WorldEnvironment.new()
	node.environment = env
	stage.add_child(node)


func _add_floor(stage: Node3D) -> void:
	var floor := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(10, 10)
	floor.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.12, 0.13, 0.15)
	mat.roughness = 0.82
	floor.material_override = mat
	stage.add_child(floor)


func _add_lights(stage: Node3D) -> void:
	_add_spot(stage, Vector3(-2.7, 3.5, 3.0), Vector3(0, 1.2, 0), Color(1.0, 0.92, 0.82), 10.0, 10.0, 45.0, true)
	_add_spot(stage, Vector3(2.8, 2.2, 2.7), Vector3(0, 1.2, 0), Color(0.48, 0.64, 1.0), 4.0, 8.0, 45.0, false)
	_add_spot(stage, Vector3(0.4, 3.1, -2.0), Vector3(0, 1.4, 0), Color(0.62, 0.72, 1.0), 6.0, 8.0, 40.0, false)


func _add_spot(stage: Node3D, pos: Vector3, target: Vector3, color: Color, energy: float, range_m: float, angle: float, shadows: bool) -> void:
	var light := SpotLight3D.new()
	light.position = pos
	light.light_color = color
	light.light_energy = energy
	light.spot_range = range_m
	light.spot_angle = angle
	light.shadow_enabled = shadows
	stage.add_child(light)
	light.look_at(target, Vector3.UP)
