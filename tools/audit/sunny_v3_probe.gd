extends SceneTree
## Read-only probe: current real-world Sunny v3 scene, native clips and grounding.

const SCENE := "res://assets/characters/sunny_realistic_poc/sunny_waking_poc.tscn"

var _out := ""
var _sunny: Node3D
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
	_sunny = (load(SCENE) as PackedScene).instantiate() as Node3D
	stage.add_child(_sunny)
	_sunny.set_physics_process(false)
	var animator := _sunny.get_node_or_null("Animator")
	if animator:
		animator.set_physics_process(false)
	await process_frame
	await process_frame
	_sunny.print_tree_pretty()
	var model_root := _sunny.get_node_or_null("Visual/ModelPoc") as Node3D
	var skeletons := model_root.find_children("*", "Skeleton3D", true, false) if model_root else _sunny.find_children("*", "Skeleton3D", true, false)
	_skeleton = skeletons[0] as Skeleton3D if not skeletons.is_empty() else null
	var players := model_root.find_children("*", "AnimationPlayer", true, false) if model_root else _sunny.find_children("*", "AnimationPlayer", true, false)
	_player = players[0] as AnimationPlayer if not players.is_empty() else null
	if _skeleton == null or _player == null:
		push_error("missing skeleton/player")
		quit(3)
		return
	print("ANIMS ", _player.get_animation_list())
	_camera_setup(stage)
	var poses := [
		[&"HumanStandingIdle", 1.2, "idle"],
		[&"HumanRelaxedWalkLoopF", 1.0, "walk"],
		[&"HumanSprintLoop", 0.3, "sprint"],
		[&"HumanSpBoxing", 0.7, "attack"],
		[&"HumanSpHeadHit", 0.2, "hit"],
		[&"HumanDeath", 0.9, "death"],
		[&"HumanRoll", 0.5, "roll"],
		[&"HumanInplaceJumpL", 0.6, "jump"],
		[&"HumanLandrollR", 0.8, "land"],
		[&"HumanSit", 0.5, "sit"],
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
		for i in 6:
			await process_frame
		await RenderingServer.frame_post_draw
		_dump(label)
		root.get_texture().get_image().save_png(_out.path_join("v3_%s.png" % label))
		print("SHOT ", label)
	quit(0)


func _dump(label: String) -> void:
	var hips := _skeleton.find_bone("Hips")
	var lf := _skeleton.find_bone("LeftFoot")
	var rf := _skeleton.find_bone("RightFoot")
	var head := _skeleton.find_bone("Head")
	var base := _skeleton.global_transform
	print("POSE ", label,
		" hips=", base * _skeleton.get_bone_global_pose(hips).origin,
		" lf=", base * _skeleton.get_bone_global_pose(lf).origin,
		" rf=", base * _skeleton.get_bone_global_pose(rf).origin,
		" head=", base * _skeleton.get_bone_global_pose(head).origin)


func _camera_setup(stage: Node3D) -> void:
	var cam := Camera3D.new()
	cam.fov = 34.0
	cam.near = 0.05
	cam.far = 50.0
	stage.add_child(cam)
	cam.current = true
	cam.position = Vector3(1.6, 1.55, 5.4)
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
