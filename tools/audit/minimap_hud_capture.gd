extends SceneTree
## Кадр HUD с миникартой в играбельной сцене.
## godot --path . -s tools/audit/minimap_hud_capture.gd --
##   --scene=res://... --out=C:/tmp/hud.png --pos=x,y,z --look=x,y,z [--fov=60]
##
## Скрипт гасит вступительный fade и прерывает катсцену, чтобы на кадре был
## именно HUD локации, а не чёрный кадр перехода.

var _scene_path := ""
var _out := ""
var _pos := Vector3(8, 5, 12)
var _look := Vector3(0, 1, 0)
var _fov := 60.0
var _frames := 45


func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--scene="):
			_scene_path = arg.trim_prefix("--scene=")
		elif arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg.begins_with("--pos="):
			_pos = _vec(arg.trim_prefix("--pos="))
		elif arg.begins_with("--look="):
			_look = _vec(arg.trim_prefix("--look="))
		elif arg.begins_with("--fov="):
			_fov = float(arg.trim_prefix("--fov="))
		elif arg.begins_with("--frames="):
			_frames = int(arg.trim_prefix("--frames="))
	call_deferred(&"_run")


func _vec(text: String) -> Vector3:
	var parts := text.split(",")
	if parts.size() != 3:
		return Vector3.ZERO
	return Vector3(float(parts[0]), float(parts[1]), float(parts[2]))


func _set_if_present(object: Object, property: StringName, value: Variant) -> void:
	for entry in object.get_property_list():
		if StringName(entry.get("name", "")) == property:
			object.set(property, value)
			return


func _run() -> void:
	if _scene_path.is_empty() or _out.is_empty():
		push_error("minimap_hud_capture: нужны --scene и --out")
		quit(2)
		return
	var packed := load(_scene_path) as PackedScene
	if packed == null:
		push_error("minimap_hud_capture: не загрузилась сцена " + _scene_path)
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(_out.get_base_dir())

	var scene := packed.instantiate()
	# Тестовый кадр не должен ждать переходов и вступления.
	_set_if_present(scene, &"fade_in", false)
	_set_if_present(scene, &"transition_enabled", false)
	root.add_child(scene)
	current_scene = scene
	await process_frame
	await process_frame

	var cutscene := root.get_node_or_null(^"CutsceneDirector")
	if cutscene != null and cutscene.has_method(&"abort") and bool(cutscene.call(&"is_playing")):
		cutscene.call(&"abort", "minimap_hud_capture")

	# Вступительный fade — CanvasItem, а не часть HUD.
	for node in scene.find_children("*", "ColorRect", true, false):
		if String(node.name).to_lower().contains("fade"):
			(node as ColorRect).visible = false

	var camera := Camera3D.new()
	root.add_child(camera)
	camera.position = _pos
	camera.look_at(_look, Vector3.UP)
	camera.fov = _fov
	camera.current = true

	for index in _frames:
		await process_frame

	var minimap := scene.find_child("HUDMinimap", true, false)
	if minimap != null and minimap.has_method(&"_refresh"):
		minimap.call(&"_refresh")
	await process_frame
	if minimap != null:
		print("MINIMAP_HUD scene=", _scene_path, " visible=", minimap.visible)
	else:
		print("MINIMAP_HUD scene=", _scene_path, " node=missing")

	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.save_png(_out)
	print("WROTE ", _out, " ", image.get_size())
	quit(0)
