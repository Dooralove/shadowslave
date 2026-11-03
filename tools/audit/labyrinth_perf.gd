extends SceneTree
## Lightweight performance probe for the demo location.
## Run: godot --path . -s tools/audit/labyrinth_perf.gd -- --scene=res://... --w=1920 --h=1080
## This is a focused-window approximation, not a replacement for a manual run.

var _scene_path := "res://scenes/locations/forgotten_shore_labyrinth/labyrinth_first_fragment.tscn"
var _width := 1920
var _height := 1080


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--scene="):
			_scene_path = arg.trim_prefix("--scene=")
		elif arg.begins_with("--w="):
			_width = int(arg.trim_prefix("--w="))
		elif arg.begins_with("--h="):
			_height = int(arg.trim_prefix("--h="))
	root.size = Vector2i(_width, _height)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var scene: Node = (load(_scene_path) as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	var tide := scene.get_node_or_null(^"Tide/TideController")
	if tide != null and tide.has_method(&"set_phase"):
		tide.set_phase(0.02)
	for i in 30:
		await process_frame
	var frames := 180
	var start := Time.get_ticks_usec()
	for i in frames:
		await process_frame
	var elapsed := float(Time.get_ticks_usec() - start) / 1000000.0
	var fps := float(frames) / maxf(elapsed, 0.0001)
	var frame_ms := elapsed * 1000.0 / float(frames)
	print("PERF scene=", _scene_path, " size=", _width, "x", _height)
	print("PERF fps=%.1f frame_ms=%.2f frames=%d" % [fps, frame_ms, frames])
	print("PERF draw_calls=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	print("PERF primitives=", Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	print("PERF objects=", Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
	print("PERF video_mem_mb=%.1f" % (Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0))
	quit(0)
