extends SceneTree
## Capture the A03-spawned NPCs after A06 context profiles are applied.
## godot --path . -s tools/anim/location_npc_capture.gd -- --out=<dir>

const CASES := [
	["p06", "res://scenes/locations/post_nightmare/academy_approach.tscn", ["Jet", "CheckpointGuard"]],
	["p09", "res://scenes/locations/post_nightmare/academy_sleeper_center.tscn", ["InductionMedic", "Julius"]],
	["z08", "res://scenes/locations/forgotten_shore_labyrinth/labyrinth_first_fragment.tscn", ["NPC_Nephis", "NPC_Cassia"]],
]

var _out := ""


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
	if _out.is_empty():
		push_error("location_npc_capture: missing --out")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	root.size = Vector2i(960, 720)
	for entry in CASES:
		await _capture(entry[0], entry[1], entry[2])
	quit(0)


func _capture(label: String, path: String, node_names: Array) -> void:
	var scene := (load(path) as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	for node_name in node_names:
		var node := scene.find_child(node_name, true, false) as Node3D
		if node == null:
			push_error("%s: %s missing" % [label, node_name])
			continue
		var cam := Camera3D.new()
		cam.fov = 36.0
		cam.near = 0.05
		cam.far = 40.0
		scene.add_child(cam)
		cam.current = true
		var target := node.global_position + Vector3(0, 1.0, 0)
		var camera_side := 3.0 if node_name == "Jet" else -3.0
		cam.global_position = node.global_position + Vector3(0.7, 1.45, camera_side)
		cam.look_at(target, Vector3.UP)
		for f in 12:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(_out.path_join("%s_%s.png" % [label, node_name]))
		print("LOCATION_SHOT ", label, " ", node_name)
		cam.queue_free()
	scene.queue_free()
	await process_frame
