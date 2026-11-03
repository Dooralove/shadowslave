extends SceneTree
## Read-only in-context captures of the placed loot caches.
##
## Usage:
##   godot --path . -s tools/audit/loot_secret_capture.gd -- \
##     --out=C:/Users/user/AppData/Local/Temp/opencode/loot_secrets

const SCENE_PATH := "res://scenes/locations/forgotten_shore_labyrinth/labyrinth_first_fragment.tscn"

var _out_dir := ""


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out_dir = arg.trim_prefix("--out=")
	if _out_dir.is_empty():
		_out_dir = OS.get_temp_dir().path_join("loot_secrets")
	DirAccess.make_dir_recursive_absolute(_out_dir)

	var packed := load(SCENE_PATH) as PackedScene
	if packed == null:
		push_error("loot_secret_capture: cannot load scene")
		quit(2)
		return
	var scene := packed.instantiate() as Node3D
	root.add_child(scene)
	for _i in 8:
		await process_frame

	var secrets := scene.get_node_or_null(^"Gameplay/Interactables/Secrets")
	if secrets == null:
		push_error("loot_secret_capture: Secrets node missing")
		quit(2)
		return

	var camera := Camera3D.new()
	camera.name = "LootSecretCaptureCamera"
	camera.fov = 55.0
	camera.near = 0.05
	camera.far = 80.0
	root.add_child(camera)
	camera.make_current()
	root.size = Vector2i(640, 640)

	var count := 0
	for child in secrets.get_children():
		if not (child is LootCache):
			continue
		var cache := child as LootCache
		var forward := -cache.global_transform.basis.z
		var is_ossuary := String(cache.name).contains("Ossuary")
		var distance := 3.8 if is_ossuary else 2.6
		var target_height := 0.85 if is_ossuary else 0.55
		var camera_pos := cache.global_position + forward * distance + Vector3.UP * 1.55
		var target := cache.global_position + Vector3.UP * target_height
		camera.global_position = camera_pos
		camera.look_at(target, Vector3.UP)
		await process_frame
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		var path := _out_dir.path_join("%s.png" % cache.name)
		image.save_png(path)
		count += 1
		print("CAPTURE %s -> %s" % [cache.name, path])
	print("LOOT_SECRET_CAPTURE count=%d out=%s" % [count, _out_dir])
	quit(0)
