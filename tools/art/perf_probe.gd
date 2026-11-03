extends Node
## A07 perf probe. Run with a real renderer:
##   godot --path . res://tools/art/perf_probe.tscn -- \
##     --scene=res://scenes/locations/forgotten_shore_labyrinth/labyrinth_first_fragment.tscn \
##     --camera=Shots/Entrance --frames=120

var _scene_path := "res://scenes/locations/forgotten_shore_labyrinth/labyrinth_first_fragment.tscn"
var _camera_path := "Shots/Entrance"
var _frames := 120
var _no_art := false


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		var text := String(arg)
		if text.begins_with("--scene="):
			_scene_path = text.trim_prefix("--scene=")
		elif text.begins_with("--camera="):
			_camera_path = text.trim_prefix("--camera=")
		elif text.begins_with("--frames="):
			_frames = maxi(2, int(text.trim_prefix("--frames=")))
		elif text == "--no-art":
			_no_art = true
	_probe.call_deferred()


func _probe() -> void:
	var packed := load(_scene_path) as PackedScene
	if packed == null:
		push_error("A07 perf: cannot load " + _scene_path)
		get_tree().quit(2)
		return
	var root := packed.instantiate() as Node3D
	add_child(root)
	await get_tree().process_frame
	await get_tree().process_frame
	if _no_art:
		var art := _find_by_name(root, "ArtFinal")
		if art != null:
			art.queue_free()
			await get_tree().process_frame
	var camera := _find_node(root, _camera_path) as Camera3D
	if camera != null:
		var player := _find_by_name(root, "Player")
		if player != null:
			player.set_process(false)
			player.set_physics_process(false)
		camera.make_current()
		camera.current = true
	var start_frame := Engine.get_frames_drawn()
	var start_time := Time.get_ticks_msec()
	for i in _frames:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var elapsed_ms := maxf(1.0, float(Time.get_ticks_msec() - start_time))
	var rendered_frames := maxf(1.0, float(Engine.get_frames_drawn() - start_frame))
	var avg_fps := rendered_frames * 1000.0 / elapsed_ms
	var draw_calls := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var primitives := int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	var vram := int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED))
	print("A07_PERF draw_calls=%d primitives=%d vram_mb=%.1f avg_fps=%.1f frames=%d" % [
		draw_calls, primitives, float(vram) / (1024.0 * 1024.0), avg_fps, int(rendered_frames),
	])
	get_tree().quit(0)


func _find_node(root: Node, path: String) -> Node:
	var direct := root.get_node_or_null(NodePath(path))
	if direct != null:
		return direct
	for node in root.find_children("*", "", true, false):
		if String(node.get_path()).ends_with("/" + path):
			return node
	return null


func _find_by_name(root: Node, name: String) -> Node:
	for node in root.find_children("*", "", true, false):
		if String(node.name) == name:
			return node
	return null
