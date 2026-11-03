extends SceneTree
## Read-only capture of the Soul Sea asset preview scene.

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := "C:/Users/user/AppData/Local/Temp/opencode/soul_sea_preview.png"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
	root.size = Vector2i(1280, 720)
	var scene: Node = (load("res://scenes/dev/soul_sea_asset_preview.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	for i in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out)
	print("soul_sea_preview_capture: ", out)
	quit(0)
