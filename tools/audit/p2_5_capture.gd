extends SceneTree
## P2.5: рендерит Spell Void transition (L04/B13) в трёх фазах.

var _out := ""


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(_out)
	root.size = Vector2i(1280, 720)
	var scene := (load("res://scenes/slice/locations/spell_void.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(scene)
	for i in 10:
		await process_frame
	scene.call("play_cutscene", &"spell", false)
	await _save("p25_spell_void_start.png", 2)
	await create_timer(2.4).timeout
	await _save("p25_spell_void_mid.png", 1)
	await create_timer(5.0).timeout
	await _save("p25_spell_void_end.png", 2)
	print("p2.5 capture done out=", _out)
	quit(0)


func _save(file_name: String, frames: int) -> void:
	for i in frames:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(_out.path_join(file_name))
