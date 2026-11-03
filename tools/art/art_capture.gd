extends Node
## A07 capture harness. Run with a real renderer (not --headless):
##   godot --path . res://tools/art/art_capture.tscn -- \
##     --scene=res://scenes/environment/post_nightmare/preview/p05_police_precinct_preview.tscn \
##     --camera=Shots/Overview \
##     --out=docs/art/previews/post_nightmare/p05_overview.png
##
## The scene is a preview wrapper: it instantiates the A03 greybox location and
## the A07 art overlay. No A03 scene is edited.

var _scene_path := ""
var _camera_path := "Shots/Overview"
var _out_path := ""
var _frames := 45
var _no_art := false
var _base_env_path := ""


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		var text := String(arg)
		if text.begins_with("--scene="):
			_scene_path = text.trim_prefix("--scene=")
		elif text.begins_with("--camera="):
			_camera_path = text.trim_prefix("--camera=")
		elif text.begins_with("--out="):
			_out_path = text.trim_prefix("--out=")
		elif text.begins_with("--frames="):
			_frames = maxi(2, int(text.trim_prefix("--frames=")))
		elif text == "--no-art":
			_no_art = true
		elif text.begins_with("--base-env="):
			_base_env_path = text.trim_prefix("--base-env=")
	if _scene_path.is_empty() or _out_path.is_empty():
		push_error("A07 capture: --scene and --out are required")
		get_tree().quit(2)
		return
	_capture.call_deferred()


func _capture() -> void:
	var packed := load(_scene_path) as PackedScene
	if packed == null:
		push_error("A07 capture: cannot load " + _scene_path)
		get_tree().quit(3)
		return
	var root := packed.instantiate() as Node3D
	add_child(root)
	await get_tree().process_frame
	await get_tree().process_frame
	if _no_art:
		var art := _find_node(root, "ArtOverlay")
		if art != null:
			art.queue_free()
			await get_tree().process_frame
	if not _base_env_path.is_empty():
		var world_env := _find_node(root, "WorldEnvironment") as WorldEnvironment
		var base_env := load(_base_env_path) as Environment
		if world_env != null and base_env != null:
			world_env.environment = base_env
			print("A07_CAPTURE_ENV " + _base_env_path)
	var camera := _find_node(root, _camera_path) as Camera3D
	if camera == null:
		# Fallback: first camera in the scene, then any Camera3D.
		camera = _find_first_camera(root)
	if camera == null:
		push_error("A07 capture: no camera in " + _scene_path)
		get_tree().quit(4)
		return
	print("A07_CAPTURE_CAMERA %s global=%s current=%s" % [camera.get_path(), str(camera.global_position), str(get_viewport().get_camera_3d())])
	# Stop the player controller from owning the camera while we capture.
	var player := _find_node(root, "Player")
	if player != null:
		player.set_process(false)
		player.set_physics_process(false)
	camera.make_current()
	camera.current = true
	for i in _frames:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var absolute := ProjectSettings.globalize_path(_out_path)
	DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	var err := image.save_png(absolute)
	if err == OK:
		print("A07_CAPTURE_OK " + _out_path)
	else:
		push_error("A07 capture: save failed (%s) %s" % [err, _out_path])
	get_tree().quit(0 if err == OK else 5)


func _find_node(root: Node, path: String) -> Node:
	var direct := root.get_node_or_null(NodePath(path))
	if direct != null:
		return direct
	var wanted := path
	for node in root.find_children("*", "", true, false):
		if String(node.name) == wanted or String(node.get_path()).ends_with("/" + wanted):
			return node
	return null


func _find_first_camera(root: Node) -> Camera3D:
	for node in root.find_children("*", "Camera3D", true, false):
		return node as Camera3D
	return null
