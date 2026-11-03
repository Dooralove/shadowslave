extends SceneTree
## Build and preview an in-place loop from the native v3 walk take.

const GLB := "res://assets/characters/generated/sunny_real_v3/sunny_real_v3_clean.glb"
const START := 0.8
const END := 1.8

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
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	if doc.append_from_file(GLB, state) != OK:
		quit(3)
		return
	var model := doc.generate_scene(state) as Node3D
	model.position.y = 0.95
	stage.add_child(model)
	var skeleton := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var player := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var source := player.get_animation(&"HumanRelaxedWalkLoopF")
	var walk := _trim_and_flatten(source, START, END)
	var library := player.get_animation_library(&"")
	library.add_animation(&"WalkClean", walk)
	player.play(&"WalkClean")
	var cam := Camera3D.new()
	cam.fov = 34.0
	cam.near = 0.05
	cam.far = 50.0
	stage.add_child(cam)
	cam.current = true
	cam.position = Vector3(1.6, 1.55, -5.4)
	cam.look_at(Vector3(0, 1.0, 0), Vector3.UP)
	var hips := skeleton.find_bone("Hips")
	var lf := skeleton.find_bone("LeftFoot")
	for t in [0.0, 0.2, 0.4, 0.6, 0.8, 1.0]:
		player.seek(t, true)
		for i in 3:
			await process_frame
		print("POSE t=", t, " hips=", skeleton.get_bone_global_pose(hips).origin, " lf=", skeleton.get_bone_global_pose(lf).origin)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(_out.path_join("walkclean_%.1f.png" % t))
	quit(0)


func _trim_and_flatten(source: Animation, start: float, end: float) -> Animation:
	var anim := source.duplicate() as Animation
	anim.loop_mode = Animation.LOOP_LINEAR
	var span := end - start
	for i in range(anim.get_track_count() - 1, -1, -1):
		var keys := anim.track_get_key_count(i)
		var times: Array[float] = []
		for k in keys:
			times.append(anim.track_get_key_time(i, k))
		# Remove keys outside the window, then shift.
		for k in range(keys - 1, -1, -1):
			var t := anim.track_get_key_time(i, k)
			if t < start - 0.0001 or t > end + 0.0001:
				anim.track_remove_key(i, k)
		for k in anim.track_get_key_count(i):
			anim.track_set_key_time(i, k, anim.track_get_key_time(i, k) - start)
	# Flatten Hips position drift on Y (vertical) and Z (forward).
	var hips_track := -1
	for i in anim.get_track_count():
		if anim.track_get_type(i) == Animation.TYPE_POSITION_3D:
			var bone := StringName(anim.track_get_path(i).get_concatenated_subnames())
			if bone == &"Hips":
				hips_track = i
				break
	if hips_track >= 0:
		var n := anim.track_get_key_count(hips_track)
		if n >= 2:
			var first: Vector3 = anim.track_get_key_value(hips_track, 0)
			var last: Vector3 = anim.track_get_key_value(hips_track, n - 1)
			var dy := last.y - first.y
			var dz := last.z - first.z
			for k in n:
				var t := anim.track_get_key_time(hips_track, k) / maxf(span, 0.001)
				var v: Vector3 = anim.track_get_key_value(hips_track, k)
				v.y -= dy * t
				v.z -= dz * t
				anim.track_set_key_value(hips_track, k, v)
	anim.length = span
	return anim


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
