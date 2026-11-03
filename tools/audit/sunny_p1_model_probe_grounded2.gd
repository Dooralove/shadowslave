extends SceneTree
## Read-only probe: current campaign Sunny (P1 + UAL), bone heights and clip poses.
## godot --path . -s tools/audit/sunny_p1_probe.gd -- --out=<dir>

const SCENE := "res://assets/characters/p1/sunny_p1_model.tscn"

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
	await process_frame
	await process_frame
	_sunny.print_tree_pretty()
	var skeletons := _sunny.find_children("*", "Skeleton3D", true, false)
	_skeleton = skeletons[0] as Skeleton3D if not skeletons.is_empty() else null
	var players := _sunny.find_children("*", "AnimationPlayer", true, false)
	_player = players[0] as AnimationPlayer if not players.is_empty() else null
	if _skeleton == null or _player == null:
		push_error("missing skeleton/player")
		quit(3)
		return
	print("ANIMS ", _player.get_animation_list())
	print("SKELETON ", _skeleton.name, " bones=", _skeleton.get_bone_count())
	_camera_setup(stage)
	_dump("rest")

	var poses := [
		[&"sunny/Idle_Relaxed", 0.5, "idle"],
		[&"Walk", 0.5, "walk"],
		[&"Sprint", 0.3, "sprint"],
		[&"Sword_Attack", 0.55, "sword_attack"],
		[&"Sword_Idle", 0.4, "guard"],
		[&"Hit_Chest", 0.16, "hit"],
		[&"Roll", 0.55, "roll"],
		[&"Death01", 1.0, "death"],
		[&"Jump_Start", 0.4, "jump"],
		[&"Jump_Land", 0.4, "land"],
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
		for i in 24:
			await process_frame
		await RenderingServer.frame_post_draw
		_dump(label)
		root.get_texture().get_image().save_png(_out.path_join("p1_%s.png" % label))
		print("SHOT ", label)
	quit(0)


func _dump(label: String) -> void:
	var fg := _model.get_node_or_null("FootGrounder")
	if fg != null:
		print("GROUND ", label, " offset=", fg.get("_offset"), " mesh_y=", (_model.get_node("Mesh") as Node3D).position.y)
	var hips := _skeleton.find_bone("Hips")
	var lf := _skeleton.find_bone("LeftFoot")
	var rf := _skeleton.find_bone("RightFoot")
	var head := _skeleton.find_bone("Head")
	var hip_pos := _skeleton.global_transform * _skeleton.get_bone_global_pose(hips).origin if hips >= 0 else Vector3.ZERO
	var lf_pos := _skeleton.global_transform * _skeleton.get_bone_global_pose(lf).origin if lf >= 0 else Vector3.ZERO
	var rf_pos := _skeleton.global_transform * _skeleton.get_bone_global_pose(rf).origin if rf >= 0 else Vector3.ZERO
	var head_pos := _skeleton.global_transform * _skeleton.get_bone_global_pose(head).origin if head >= 0 else Vector3.ZERO
	print("POSE ", label, " hips=", hip_pos, " lf=", lf_pos, " rf=", rf_pos, " head=", head_pos)


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
