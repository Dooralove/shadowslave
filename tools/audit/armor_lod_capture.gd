extends SceneTree
## Read-only LOD verification: capture the same armour at 2 m, 10 m and 20 m.
## godot --path . -s tools/audit/armor_lod_capture.gd -- --out=<dir>

const DEMO := "res://scenes/dev/equipment_loot_demo.tscn"
const HEAVY := "res://resources/equipment/armor/heavy_plate.tres"
const DISTANCES := [2.0, 10.0, 20.0]

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
	root.size = Vector2i(1600, 900)

	var scene := (load(DEMO) as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	await process_frame
	var equipment := scene.get_node("Equipment")
	var ui := scene.get_node("UI") as CanvasLayer
	ui.visible = false
	equipment.call("equip", load(HEAVY))
	for i in 10:
		await process_frame

	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.current = true
	for distance in DISTANCES:
		# Keep the character roughly the same size while changing true distance.
		var fov := clampf(rad_to_deg(2.0 * atan(1.0 / distance)) * 1.6, 10.0, 55.0)
		camera.fov = fov
		camera.position = Vector3(0.0, 1.0, 2.0 + distance)
		camera.look_at(Vector3(0.0, 0.95, 2.0), Vector3.UP)
		for i in 8:
			await process_frame
		await RenderingServer.frame_post_draw
		var path := _out.path_join("lod_%02dm.png" % int(distance))
		root.get_texture().get_image().save_png(path)
		print("CAPTURE ", path, " fov=", snappedf(fov, 0.1))
	quit(0)
