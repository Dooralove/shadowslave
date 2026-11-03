extends SceneTree
## Probe the integrated v3 AnimationTree through SunnyAnimator.

const SCENE := "res://assets/characters/sunny_realistic_poc/sunny_waking_poc.tscn"

var _out := ""
var _sunny: Node3D
var _animator: SunnyAnimator
var _tree: AnimationTree
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
	_animator = _sunny.get_node("Animator") as SunnyAnimator
	_animator.set_physics_process(false)
	_tree = _sunny.get_node("AnimationTree") as AnimationTree
	_player = _animator.animation_player
	await process_frame
	await process_frame
	await process_frame
	print("TREE ", _tree, " active=", _tree.active if _tree else "?")
	print("ANIMS ", _player.get_animation_list())
	print("HAS WalkClean ", _player.has_animation(&"WalkClean"))
	_camera_setup(stage)
	var cases := [
		["idle", 0.0],
		["walk", 1.7],
		["run", 4.5],
	]
	for entry in cases:
		var label: String = entry[0]
		var speed: float = entry[1]
		_animator.update(0.05, true, Vector3(0, 0, -speed))
		for i in 20:
			await process_frame
		_dump(label)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(_out.path_join("v3tree_%s.png" % label))
		print("SHOT ", label)
	_animator.play_dodge()
	for i in 12:
		await process_frame
	_dump("dodge")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(_out.path_join("v3tree_dodge.png"))
	_animator.play_action(&"HumanSit", &"Interact")
	for i in 12:
		await process_frame
	_dump("sit")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(_out.path_join("v3tree_sit.png"))
	quit(0)


func _dump(label: String) -> void:
	var playback := _tree.get("parameters/playback") as AnimationNodeStateMachinePlayback if _tree else null
	print("STATE ", label, " animator=", _animator.state, " tree=", playback.get_current_node() if playback else "?",
		" player=", _player.current_animation if _player else "?")


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
