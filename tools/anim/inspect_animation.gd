extends SceneTree
## Inspect animation tracks of a GLB/scene for A06 clip authoring.
## godot --headless --path . -s tools/anim/inspect_animation.gd -- <resource> <clip>

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error("usage: inspect_animation.gd <resource> <clip>")
		quit(2)
		return
	var packed := load(args[0]) as PackedScene
	var node := packed.instantiate()
	root.add_child(node)
	await process_frame
	var player := node.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if player == null:
		push_error("no AnimationPlayer")
		quit(1)
		return
	print("PLAYER ", player.get_path(), " clips=", player.get_animation_list())
	var clip := StringName(args[1])
	var anim := player.get_animation(clip)
	if anim == null:
		push_error("no clip " + args[1])
		quit(1)
		return
	print("ANIM ", clip, " length=", anim.length, " tracks=", anim.get_track_count())
	for i in anim.get_track_count():
		print("TRACK ", i, " type=", anim.track_get_type(i), " path=", anim.track_get_path(i), " keys=", anim.track_get_key_count(i))
		for k in mini(anim.track_get_key_count(i), 4):
			print("  KEY ", k, " t=", anim.track_get_key_time(i, k), " v=", anim.track_get_key_value(i, k))
	quit(0)
