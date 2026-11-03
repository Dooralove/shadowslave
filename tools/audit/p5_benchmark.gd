extends SceneTree
## P5 benchmark: fixed camera, 1920x1080, real renderer metrics.
## Usage:
##   godot --path . -s tools/audit/p5_benchmark.gd -- \
##     --scene=res://scenes/slice/locations/park/park_street_art.tscn \
##     --camera=0,1.65,4.0 --target=0,1.8,-18 --frames=180
##
## This is a real display run, not a headless synthetic FPS estimate. The first
## frames are warmup and are excluded from the average.

var _out := ""


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene_path := "res://scenes/slice/locations/park/park_street_art.tscn"
	var camera_pos := Vector3(0.0, 1.65, 4.0)
	var target := Vector3(0.0, 1.8, -18.0)
	var frames := 180
	var resolution := Vector2i(1920, 1080)
	var hide_paths: Array[String] = []
	var shot_path := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--scene="):
			scene_path = arg.trim_prefix("--scene=")
		elif arg.begins_with("--camera="):
			camera_pos = _vec(arg.trim_prefix("--camera="), camera_pos)
		elif arg.begins_with("--target="):
			target = _vec(arg.trim_prefix("--target="), target)
		elif arg.begins_with("--frames="):
			frames = int(arg.trim_prefix("--frames="))
		elif arg.begins_with("--shot="):
			shot_path = arg.trim_prefix("--shot=")
		elif arg.begins_with("--hide="):
			hide_paths.append(arg.trim_prefix("--hide="))
		elif arg.begins_with("--res="):
			var parts := arg.trim_prefix("--res=").split("x")
			if parts.size() == 2:
				resolution = Vector2i(int(parts[0]), int(parts[1]))

	root.size = resolution
	Engine.max_fps = 0
	var scene := (load(scene_path) as PackedScene).instantiate() as Node3D
	root.add_child(scene)
	for i in 10:
		await process_frame
	for hide_path in hide_paths:
		var hidden := scene.get_node_or_null(NodePath(hide_path)) as Node3D
		if hidden != null:
			hidden.visible = false
	for canvas in scene.find_children("*", "CanvasLayer", true, false):
		(canvas as CanvasLayer).visible = false
	var camera := Camera3D.new()
	camera.name = "P5BenchmarkCamera"
	camera.fov = 60.0
	camera.near = 0.05
	camera.far = 1200.0
	scene.add_child(camera)
	camera.global_position = camera_pos
	camera.look_at(target, Vector3.UP)
	camera.make_current()
	# Warm up shaders/pipeline and let renderer settle.
	for i in 90:
		await process_frame
	var start_usec := Time.get_ticks_usec()
	var draw_calls := 0.0
	var primitives := 0.0
	var objects := 0.0
	var fps_sum := 0.0
	var sample_count := 0
	for i in frames:
		await process_frame
		draw_calls += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		primitives += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
		objects += Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
		fps_sum += Performance.get_monitor(Performance.TIME_FPS)
		sample_count += 1
	var elapsed := float(Time.get_ticks_usec() - start_usec) / 1_000_000.0
	print("P5_BENCH scene=", scene_path)
	print("P5_BENCH resolution=", resolution, " camera=", camera_pos, " target=", target)
	print("P5_BENCH frames=", frames, " elapsed_s=", snappedf(elapsed, 0.001),
		" avg_fps=", snappedf(float(frames) / maxf(elapsed, 0.0001), 0.01),
		" engine_fps_avg=", snappedf(fps_sum / maxf(float(sample_count), 1.0), 0.01))
	print("P5_BENCH draw_calls_avg=", snappedf(draw_calls / maxf(float(sample_count), 1.0), 0.1),
		" primitives_avg=", snappedf(primitives / maxf(float(sample_count), 1.0), 0.1),
		" objects_avg=", snappedf(objects / maxf(float(sample_count), 1.0), 0.1))
	var video_mem := Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)
	var texture_mem := Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)
	if not shot_path.is_empty():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(shot_path)
		print("P5_BENCH shot=", shot_path)
	camera.queue_free()
	scene.queue_free()
	for i in 3:
		await process_frame
	print("P5_BENCH video_mem_mb=", snappedf(video_mem / 1048576.0, 0.1),
		" texture_mem_mb=", snappedf(texture_mem / 1048576.0, 0.1))
	quit(0)


func _vec(text: String, fallback: Vector3) -> Vector3:
	var parts := text.split(",")
	if parts.size() != 3:
		return fallback
	return Vector3(float(parts[0]), float(parts[1]), float(parts[2]))
