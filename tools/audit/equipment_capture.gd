extends SceneTree
## Read-only alpha capture for the equipment lab.
## godot --path . -s tools/audit/equipment_capture.gd -- --out=<dir> [--variant=B] [--pose=3]

const DEFAULT_SCENE := "res://scenes/dev/equipment_lab.tscn"

var _out := ""
var _variant := &"A"
var _pose := 0
var _scene := DEFAULT_SCENE
var _weapon := -1
var _time := -1.0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg.begins_with("--variant="):
			_variant = StringName(arg.trim_prefix("--variant=").to_upper())
		elif arg.begins_with("--pose="):
			_pose = int(arg.trim_prefix("--pose="))
		elif arg.begins_with("--scene="):
			_scene = arg.trim_prefix("--scene=")
		elif arg.begins_with("--weapon="):
			_weapon = int(arg.trim_prefix("--weapon="))
		elif arg.begins_with("--time="):
			_time = float(arg.trim_prefix("--time="))
	if _out.is_empty():
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	root.size = Vector2i(900, 900)

	var scene := (load(_scene) as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	var equipment := scene.find_child("Equipment", true, false) as EquipmentComponent
	if equipment != null:
		equipment.set_ab_variant(_variant)
		if _weapon >= 0:
			equipment.set_weapon_drawn(_weapon == 1)
	if scene.has_method("_play_pose"):
		scene.call("_play_pose", _pose)
	if _time >= 0.0:
		var player := scene.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if player != null:
			player.seek(_time, true)
			player.pause()
	for i in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var tag := _scene.get_file().get_basename()
	var path := _out.path_join("equipment_%s_%s_pose%d.png" % [tag, _variant, _pose])
	image.save_png(path)
	print("CAPTURE ", path)
	quit(0)
