extends SceneTree
## Одноразовый кадр арт-сцены лагеря: проверить, что арт-оверлей, огонь и
## силуэты читаются без QA-обвязки.


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var scene := (load("res://scenes/locations/caravan_site/caravan_site_art.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var camera := Camera3D.new()
	camera.position = Vector3(8.5, 4.5, 8.5)
	camera.look_at(Vector3(0.0, 1.0, 0.0), Vector3.UP)
	camera.fov = 55.0
	root.add_child(camera)
	camera.current = true
	for i in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var path := OS.get_environment("TEMP").path_join("opencode/camp_art_final.png")
	image.save_png(path)
	print("CAMP_CAPTURE ", path)
	quit()
