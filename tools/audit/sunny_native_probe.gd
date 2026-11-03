extends SceneTree
## Read-only probe: render the native Mixamo-style clips of the generated Sunny v2.
## godot --path . -s tools/audit/sunny_native_probe.gd -- --out=<dir>

const GLB := "res://incoming_models/P0_characters/sunny_real_v2_rigged_core10.glb"

var _out := ""
var _model: Node3D
var _skeleton: Skeleton3D
var _player: AnimationPlayer


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

	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	if doc.append_from_file(GLB, state) != OK:
		quit(3)
		return
	_model = doc.generate_scene(state) as Node3D
	# The generated GLB has its origin at the character's centre; feet are at -0.95 m.
	_model.position.y = 0.95
	stage.add_child(_model)
	_skeleton = _model.find_child("Skeleton3D", true, false) as Skeleton3D
	_player = _model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _skeleton == null or _player == null:
		push_error("missing skeleton/player")
		quit(4)
		return
	print("PLAYER ", _player.get_animation_list())
	_camera_setup(stage)
	var poses := [
		[&"HumanStandingIdle", 1.2, "native_idle"],
		[&"HumanRelaxedWalkLoopF", 1.0, "native_walk"],
		[&"HumanSprintLoop", 0.3, "native_sprint"],
		[&"HumanSpBoxing", 0.7, "native_boxing"],
		[&"HumanSpHeadHit", 0.2, "native_hit"],
		[&"HumanDeath", 0.9, "native_death"],
		[&"HumanRoll", 0.5, "native_roll"],
		[&"HumanInplaceJumpL", 0.6, "native_jump"],
		[&"HumanLandrollR", 0.8, "native_landroll"],
	]
	for entry in poses:
		var clip: StringName = entry[0]
		var at: float = entry[1]
		var label: String = entry[2]
		if not _player.has_animation(clip):
			print("MISSING ", clip)
			continue
		_player.play(clip)
		_player.seek(at, true)
		_player.pause()
		for i in 3:
			await process_frame
		await RenderingServer.frame_post_draw
		_dump_pose(label)
		root.get_texture().get_image().save_png(_out.path_join("sunny_v2_%s.png" % label))
		print("SHOT ", label)
	quit(0)


func _dump_pose(label: String) -> void:
	var hips := _skeleton.find_bone("Hips")
	var lf := _skeleton.find_bone("LeftFoot")
	var rf := _skeleton.find_bone("RightFoot")
	var head := _skeleton.find_bone("Head")
	print("POSE ", label,
		" hips=", _skeleton.get_bone_global_pose(hips).origin if hips >= 0 else "?",
		" lf=", _skeleton.get_bone_global_pose(lf).origin if lf >= 0 else "?",
		" rf=", _skeleton.get_bone_global_pose(rf).origin if rf >= 0 else "?",
		" head=", _skeleton.get_bone_global_pose(head).origin if head >= 0 else "?")


func _camera_setup(stage: Node3D) -> void:
	var cam := Camera3D.new()
	cam.fov = 34.0
	cam.near = 0.05
	cam.far = 50.0
	stage.add_child(cam)
	cam.current = true
	cam.position = Vector3(1.4, 1.45, 5.6)
	cam.look_at(Vector3(0, 1.0, 0), Vector3.UP)


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
	env.glow_enabled = true
	env.glow_intensity = 0.18
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
