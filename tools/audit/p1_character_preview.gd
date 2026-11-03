extends SceneTree
## P1 character preview: read-only studio render of a GLB with idle animation.
## godot --path . -s tools/audit/p1_character_preview.gd -- --model=res://assets/characters/p1/models/police_desk.glb --out=...

var _out := ""
var _model_path := ""
var _back := false
var _model: Node3D
var _cam: Camera3D
var _player: AnimationPlayer
var _env: WorldEnvironment


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--model="):
			_model_path = arg.trim_prefix("--model=")
		elif arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg == "--back":
			_back = true
	if _model_path.is_empty() or _out.is_empty():
		push_error("usage: --model=res://... --out=<dir>")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	root.size = Vector2i(900, 900)

	var stage := Node3D.new()
	root.add_child(stage)
	_env = WorldEnvironment.new()
	_env.environment = _make_environment()
	stage.add_child(_env)

	var floor := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(10, 10)
	floor.mesh = plane
	floor.material_override = _plain(Color(0.12, 0.13, 0.15), 0.82)
	stage.add_child(floor)

	var back := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(8, 6, 0.2)
	back.mesh = box
	back.position = Vector3(0, 3, -2.2)
	back.material_override = _plain(Color(0.055, 0.06, 0.07), 0.9)
	back.visible = not _back
	stage.add_child(back)

	_model = (load(_model_path) as PackedScene).instantiate() as Node3D
	if _model == null:
		push_error("cannot load " + _model_path)
		quit(3)
		return
	stage.add_child(_model)
	_model.rotation.y = 0.0
	var skeleton := _model.find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton != null:
		skeleton.name = "GeneralSkeleton"
		skeleton.unique_name_in_owner = true
		skeleton.owner = _model
	var lod := CharacterLodVisibility.new()
	lod.name = "CharacterLodVisibility"
	_model.add_child(lod)

	_player = AnimationPlayer.new()
	_player.name = "PreviewAnimationPlayer"
	_model.add_child(_player)
	_player.root_node = _player.get_path_to(_model)
	var idle_lib := load("res://assets/characters/sunny_realistic_poc/animations/sunny_idle_relaxed.glb") as AnimationLibrary
	var ual_lib := load("res://assets/characters/sunny_realistic_poc/animations/ual_standard.glb") as AnimationLibrary
	if idle_lib:
		_player.add_animation_library(&"", idle_lib)
	if ual_lib:
		_player.add_animation_library(&"ual", ual_lib)
	var clip := &"Idle_Relaxed"
	if not _player.has_animation(clip):
		var names := _player.get_animation_list()
		print("PREVIEW anims=", names)
		if not names.is_empty():
			clip = names[0]
	_player.play(clip)
	_player.seek(0.35, true)

	_cam = Camera3D.new()
	_cam.fov = 34.0
	_cam.near = 0.05
	_cam.far = 50.0
	stage.add_child(_cam)
	_cam.current = true
	_cam.position = Vector3(1.4, 1.45, 5.6)
	_cam.look_at(Vector3(0, 1.0, 0), Vector3.UP)
	if _back:
		_cam.position = Vector3(1.4, 1.45, -5.6)
		_cam.look_at(Vector3(0, 1.0, 0), Vector3.UP)

	_add_light(stage, Vector3(-2.7, 3.5, 3.0), Vector3(0, 1.2, 0), Color(1.0, 0.92, 0.82), 10.0, 10.0, 45.0, true)
	_add_light(stage, Vector3(2.8, 2.2, 2.7), Vector3(0, 1.2, 0), Color(0.48, 0.64, 1.0), 4.0, 8.0, 45.0, false)
	_add_light(stage, Vector3(0.4, 3.1, -2.0), Vector3(0, 1.4, 0), Color(0.62, 0.72, 1.0), 6.0, 8.0, 40.0, false)
	if _back:
		_add_light(stage, Vector3(-2.7, 3.5, -3.0), Vector3(0, 1.2, 0), Color(1.0, 0.92, 0.82), 10.0, 10.0, 45.0, true)

	for i in 20:
		await process_frame
	await RenderingServer.frame_post_draw
	var suffix := "_back" if _back else ""
	var path := _out.path_join(_model_path.get_file().get_basename() + suffix + ".png")
	root.get_texture().get_image().save_png(path)
	print("PREVIEW saved ", path, " anim=", clip)
	quit(0)


func _make_environment() -> Environment:
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
	env.glow_enabled = true
	env.glow_intensity = 0.18
	return env


func _plain(color: Color, roughness: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	return mat


func _add_light(parent: Node3D, pos: Vector3, target: Vector3, color: Color, energy: float,
		range_m: float, angle: float, shadows: bool) -> void:
	var light := SpotLight3D.new()
	light.position = pos
	light.light_color = color
	light.light_energy = energy
	light.spot_range = range_m
	light.spot_angle = angle
	light.shadow_enabled = shadows
	parent.add_child(light)
	light.look_at(target, Vector3.UP)
