extends SceneTree
## Read-only P1 integration capture: load a location scene, add a camera, render.
## godot --path . -s tools/audit/p1_scene_capture.gd -- --scene=res://... --out=<dir>
##
## Does not save or edit the scene; autoload/audio errors from the working tree
## are unrelated to the captured visuals.

var _scene_path := ""
var _out := ""
var _alarm := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--scene="):
			_scene_path = arg.trim_prefix("--scene=")
		elif arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg == "--alarm":
			_alarm = true
	if _scene_path.is_empty() or _out.is_empty():
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	root.size = Vector2i(1280, 720)
	var packed := load(_scene_path) as PackedScene
	if packed == null:
		push_error("cannot load " + _scene_path)
		quit(3)
		return
	var scene := packed.instantiate()
	root.add_child(scene)
	await process_frame

	var cam := Camera3D.new()
	cam.fov = 55.0
	cam.near = 0.05
	cam.far = 400.0
	root.add_child(cam)
	var p := _camera_for(_scene_path)
	cam.position = p[0]
	cam.look_at(p[1], Vector3.UP)
	cam.current = true

	var fill := OmniLight3D.new()
	fill.position = p[0] + Vector3(0, 2.0, 0.5)
	fill.light_color = Color(0.55, 0.62, 0.78)
	fill.light_energy = 1.4
	fill.omni_range = 18.0
	root.add_child(fill)

	if _alarm:
		var alarm_lights := scene.get_node_or_null("AlarmLights")
		if alarm_lights:
			for light in alarm_lights.get_children():
				if light is Light3D:
					(light as Light3D).light_energy = 2.0

	for i in 20:
		await process_frame
	await RenderingServer.frame_post_draw
	var name := _scene_path.get_file().get_basename()
	var suffix := "_alarm" if _alarm else ""
	var path := _out.path_join("p1_scene_" + name + suffix + ".png")
	root.get_texture().get_image().save_png(path)
	print("SCENE_PREVIEW ", path)
	quit(0)


func _camera_for(path: String) -> Array:
	if path.contains("combat_arena"):
		return [Vector3(1.8, 2.0, -2.8), Vector3(-2.0, 0.7, -7.0)]
	if path.contains("caravan_site"):
		return [Vector3(5.0, 2.2, 7.5), Vector3(0.8, 1.2, 0.5)]
	if path.contains("station_lobby"):
		return [Vector3(0.0, 1.65, 2.6), Vector3(0.0, 1.35, -3.0)]
	if path.contains("containment_room"):
		return [Vector3(0.9, 1.9, 2.55), Vector3(0.0, 1.10, 0.25)]
	if path.contains("park_street"):
		return [Vector3(0.0, 1.70, 7.0), Vector3(0.0, 1.30, -2.0)]
	return [Vector3(0.0, 1.7, 6.0), Vector3(0.0, 1.2, 0.0)]
