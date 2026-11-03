extends Node
## P5 campaign probe: real prologue/park, player + unified UI, 1080p metrics.
## Run as a normal scene (autoloads available), not with `-s`.

func _ready() -> void:
	get_tree().root.size = Vector2i(1920, 1080)
	var hide_ui := false
	var hide_player := false
	for arg in OS.get_cmdline_user_args():
		if arg == "--hide-ui":
			hide_ui = true
		elif arg == "--hide-player":
			hide_player = true
	var prologue := (load("res://scenes/slice/prologue.tscn") as PackedScene).instantiate()
	prologue.autostart = false
	add_child(prologue)
	for i in 10:
		await get_tree().process_frame
	prologue.call("_load", &"park", &"BenchSit")
	for i in 20:
		await get_tree().process_frame
	var player := prologue.get_node("Sunny")
	player.camera_rig.camera.make_current()
	prologue.get_node("UI").fade.color.a = 0.0
	if hide_ui:
		prologue.get_node("UI").visible = false
	if hide_player:
		player.visible = false
	print("P5_CAMPAIGN camera=", player.camera_rig.camera.global_position, " forward=", -player.camera_rig.camera.global_basis.z)
	var batches := prologue.find_children("*", "MultiMeshInstance3D", true, false)
	print("P5_CAMPAIGN batches=", batches.size(), " player=", player.get_path())
	for i in 90:
		await get_tree().process_frame
	var start_usec := Time.get_ticks_usec()
	var draw_calls := 0.0
	var primitives := 0.0
	var objects := 0.0
	for i in 120:
		await get_tree().process_frame
		draw_calls += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		primitives += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
		objects += Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
	var elapsed := float(Time.get_ticks_usec() - start_usec) / 1_000_000.0
	print("P5_CAMPAIGN resolution=1920x1080 elapsed_s=", snappedf(elapsed,0.001),
		" avg_fps=", snappedf(120.0/maxf(elapsed,0.0001),0.01))
	print("P5_CAMPAIGN draw_calls_avg=", snappedf(draw_calls/120.0,0.1),
		" primitives_avg=", snappedf(primitives/120.0,0.1),
		" objects_avg=", snappedf(objects/120.0,0.1))
	print("P5_CAMPAIGN video_mem_mb=", snappedf(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)/1048576.0,0.1))
	get_tree().quit(0)
