extends SceneTree
## Close-up capture of the generated NPCs integrated into the caravan scene.
## godot --path . -s tools/audit/npc_capture.gd -- --out=<dir>

var _out := ""

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
	if _out.is_empty():
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	root.size = Vector2i(900, 900)
	var scene := (load("res://scenes/locations/caravan_site/caravan_site.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	for i in 4:
		await process_frame
	var cam := Camera3D.new()
	cam.fov = 32.0
	cam.near = 0.05
	cam.far = 80.0
	scene.add_child(cam)
	cam.current = true
	var entries := [
		["shifty", ^"NPCs/ShiftySlave"],
		["scholar", ^"NPCs/Scholar"],
		["veteran", ^"NPCs/Veteran"],
		["broad", ^"NPCs/BroadSlave"],
		["white_horse", ^"NPCs/Hero/WhiteHorse"],
		["dark_horse", ^"NPCs/Veteran/DarkHorse"],
	]
	for entry in entries:
		var npc := scene.get_node_or_null(entry[1]) as Node3D
		if npc == null:
			print("MISSING ", entry[0])
			continue
		var target := npc.global_position + Vector3(0, 1.0, 0)
		var is_horse := String(entry[0]).contains("horse")
		cam.global_position = target + (Vector3(4.0, 0.4, 0.0) if is_horse else Vector3(0.7, 0.35, -2.8))
		cam.look_at(target, Vector3.UP)
		for i in 2:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(_out.path_join("%s.png" % entry[0]))
		print("SHOT ", entry[0], " pos=", npc.global_position)
	quit(0)
