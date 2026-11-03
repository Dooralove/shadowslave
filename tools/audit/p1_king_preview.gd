extends SceneTree
## Read-only Mountain King preview: GLB + LOD + animation.
## godot --path . -s tools/audit/p1_king_preview.gd -- --model=... --out=...

var _model_path := ""
var _out := ""
var _model: Node3D


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--model="):
			_model_path = arg.trim_prefix("--model=")
		elif arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
	if _model_path.is_empty() or _out.is_empty():
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	root.size = Vector2i(1100, 900)

	var stage := Node3D.new()
	root.add_child(stage)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.012, 0.015, 0.025)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.25, 0.32, 0.44)
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.25
	env.ssao_enabled = true
	env.ssao_intensity = 1.3
	env.glow_enabled = true
	env.glow_intensity = 0.2
	env.fog_enabled = true
	env.fog_light_color = Color(0.03, 0.04, 0.07)
	env.fog_density = 0.008
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.01
	env.volumetric_fog_albedo = Color(0.28, 0.34, 0.44)
	env.volumetric_fog_length = 60.0
	var we := WorldEnvironment.new()
	we.environment = env
	stage.add_child(we)

	var floor := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(30, 30)
	floor.mesh = plane
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.16, 0.18, 0.21)
	fm.roughness = 0.88
	floor.material_override = fm
	stage.add_child(floor)

	var back := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(14, 10, 0.3)
	back.mesh = box
	back.position = Vector3(0, 5, -5)
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color(0.03, 0.035, 0.045)
	bm.roughness = 0.9
	back.material_override = bm
	stage.add_child(back)

	_model = (load(_model_path) as PackedScene).instantiate() as Node3D
	_model.rotation.y = PI
	stage.add_child(_model)
	var lod := CharacterLodVisibility.new()
	lod.name = "CharacterLodVisibility"
	lod.lod1_distance = 20.0
	lod.lod2_distance = 45.0
	_model.add_child(lod)

	var player := _model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if player != null:
		print("KING_ANIMS=", player.get_animation_list())
		if player.has_animation(&"Idle"):
			player.play(&"Idle")
		elif not player.get_animation_list().is_empty():
			player.play(player.get_animation_list()[0])
		player.seek(0.6, true)

	# 1.75 m scale reference.
	var ref := MeshInstance3D.new()
	var ref_mesh := BoxMesh.new()
	ref_mesh.size = Vector3(0.5, 1.75, 0.35)
	ref.mesh = ref_mesh
	ref.position = Vector3(3.6, 0.875, 1.5)
	var rm := StandardMaterial3D.new()
	rm.albedo_color = Color(0.45, 0.48, 0.52)
	rm.roughness = 0.8
	ref.material_override = rm
	stage.add_child(ref)

	_add_spot(stage, Vector3(-5.0, 7.0, 7.0), Vector3(0, 2.2, 0), Color(1.0, 0.86, 0.70), 18.0, 18.0, 42.0, true)
	_add_spot(stage, Vector3(6.0, 4.0, 5.0), Vector3(0, 2.0, 0), Color(0.42, 0.62, 1.0), 6.0, 14.0, 48.0, false)
	_add_spot(stage, Vector3(0.0, 5.0, -5.0), Vector3(0, 2.5, 0), Color(0.55, 0.70, 1.0), 10.0, 18.0, 45.0, true)

	var cam := Camera3D.new()
	cam.fov = 42.0
	cam.near = 0.1
	cam.far = 100.0
	stage.add_child(cam)
	cam.position = Vector3(7.5, 3.4, 13.5)
	cam.look_at(Vector3(0, 2.2, 0), Vector3.UP)
	cam.current = true

	for i in 30:
		await process_frame
	await RenderingServer.frame_post_draw
	var path := _out.path_join("mountain_king_p1.png")
	root.get_texture().get_image().save_png(path)
	print("KING_PREVIEW saved ", path)
	quit(0)


func _add_spot(parent: Node3D, pos: Vector3, target: Vector3, color: Color, energy: float,
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
