extends SceneTree
## Read-only probe: validate the Sunny AnimationTree resource on the P1 model.
## godot --path . -s tools/audit/sunny_tree_probe.gd -- --out=<dir>

const MODEL := "res://assets/characters/p1/sunny_p1_model.tscn"
const TREE := "res://resources/characters/sunny_animation_tree.tres"

var _out := ""
var _model: Node3D
var _player: AnimationPlayer
var _tree: AnimationTree
var _skeleton: Skeleton3D


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

	_model = (load(MODEL) as PackedScene).instantiate() as Node3D
	stage.add_child(_model)
	await process_frame
	await process_frame
	var skeletons := _model.find_children("*", "Skeleton3D", true, false)
	_skeleton = skeletons[0] as Skeleton3D if not skeletons.is_empty() else null
	_player = _model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _skeleton == null or _player == null:
		push_error("missing skeleton/player")
		quit(3)
		return
	# One-shots must not loop.
	for clip in [&"Jump_Start", &"Jump_Land", &"Sword_Attack", &"Hit_Chest", &"Hit_Head", &"Roll", &"Death01", &"Interact", &"Spell_Simple_Shoot"]:
		if _player.has_animation(clip):
			_player.get_animation(clip).loop_mode = Animation.LOOP_NONE
	for clip in [&"Idle", &"Walk", &"Sprint", &"Jump", &"Sword_Idle", &"sunny/Idle_Relaxed"]:
		if _player.has_animation(clip):
			_player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR

	_tree = AnimationTree.new()
	_tree.name = "AnimationTree"
	_model.add_child(_tree)
	_tree.anim_player = _tree.get_path_to(_player)
	_tree.tree_root = load(TREE)
	_tree.active = true
	await process_frame
	var playback := _tree.get("parameters/playback") as AnimationNodeStateMachinePlayback
	if playback == null:
		push_error("no playback")
		quit(4)
		return
	print("TREE OK states=", (_tree.tree_root as AnimationNodeStateMachine).get_node_list())

	_camera_setup(stage)
	var poses := [
		["Locomotion", 0.0, "loco_idle"],
		["Locomotion", 0.35, "loco_walk"],
		["Locomotion", 1.0, "loco_sprint"],
		["Attack", 0.0, "attack"],
		["Hit", 0.0, "hit"],
		["Guard", 0.0, "guard"],
		["Dodge", 0.0, "dodge"],
		["Death", 0.0, "death"],
		["Interact", 0.0, "interact"],
		["Special", 0.0, "special"],
	]
	for entry in poses:
		var state: String = entry[0]
		var blend: float = entry[1]
		var label: String = entry[2]
		if state == "Locomotion":
			_tree.set("parameters/Locomotion/blend_position", blend)
		playback.travel(StringName(state))
		# Let the transition settle and the clip reach a readable pose.
		for i in 8:
			await process_frame
		await RenderingServer.frame_post_draw
		_dump(label)
		root.get_texture().get_image().save_png(_out.path_join("tree_%s.png" % label))
		print("SHOT ", label, " anim=", _player.current_animation, " pos=", _player.current_animation_position)
	# Auto-return check: Attack -> Locomotion when the clip finishes.
	playback.travel(&"Locomotion")
	_tree.set("parameters/Locomotion/blend_position", 0.0)
	for i in 5:
		await process_frame
	playback.travel(&"Attack")
	var attack_len := _player.get_animation(&"Sword_Attack").length
	var waited := 0.0
	while waited < attack_len + 0.4:
		await process_frame
		waited += 1.0 / 60.0
	print("AUTO_RETURN current=", _player.current_animation, " state=", playback.get_current_node())
	quit(0)


func _dump(label: String) -> void:
	var hips := _skeleton.find_bone("Hips")
	var lf := _skeleton.find_bone("LeftFoot")
	var rf := _skeleton.find_bone("RightFoot")
	print("POSE ", label,
		" hips=", _skeleton.get_bone_global_pose(hips).origin if hips >= 0 else "?",
		" lf=", _skeleton.get_bone_global_pose(lf).origin if lf >= 0 else "?",
		" rf=", _skeleton.get_bone_global_pose(rf).origin if rf >= 0 else "?")


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
