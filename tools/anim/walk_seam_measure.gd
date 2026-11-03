extends SceneTree
## Measure WalkClean loop seam and try alternative trim ranges on Sunny v3.
## godot --headless --path . -s tools/anim/walk_seam_measure.gd

const SCENE := "res://assets/characters/generated/sunny_real_v3/sunny_real_v3.tscn"
const SOURCE := &"HumanRelaxedWalkLoopF"
const RANGES := [
	Vector2(0.7, 1.7),
	Vector2(0.8, 1.8),
	Vector2(0.9, 1.9),
	Vector2(1.0, 2.0),
	Vector2(0.75, 1.75),
]

var _failed := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var node := (load(SCENE) as PackedScene).instantiate() as Node3D
	root.add_child(node)
	await process_frame
	await process_frame
	var player := node.get_node(^"Model/AnimationPlayer") as AnimationPlayer
	var skeleton := node.find_child("Skeleton3D", true, false) as Skeleton3D
	if player == null or skeleton == null:
		push_error("missing player/skeleton")
		quit(1)
		return
	var source := player.get_animation(SOURCE)
	if source == null:
		push_error("missing source")
		quit(1)
		return
	var lib := AnimationLibrary.new()
	for range in RANGES:
		var anim := _trim(source, range.x, range.y)
		anim.loop_mode = Animation.LOOP_LINEAR
		var name := StringName("range_%d_%d" % [int(range.x * 100), int(range.y * 100)])
		lib.add_animation(name, anim)
	player.add_animation_library(&"seamtest", lib)
	for range in RANGES:
		var name := StringName("seamtest/range_%d_%d" % [int(range.x * 100), int(range.y * 100)])
		player.play(name)
		player.seek(0.0, true)
		await process_frame
		var start_l := skeleton.get_bone_global_pose(skeleton.find_bone(&"LeftFoot")).origin
		var start_r := skeleton.get_bone_global_pose(skeleton.find_bone(&"RightFoot")).origin
		var length := player.get_animation(name).length
		player.seek(length, true)
		await process_frame
		var end_l := skeleton.get_bone_global_pose(skeleton.find_bone(&"LeftFoot")).origin
		var end_r := skeleton.get_bone_global_pose(skeleton.find_bone(&"RightFoot")).origin
		print("SEAM ", range, " L=", start_l.distance_to(end_l), " R=", start_r.distance_to(end_r))
	node.queue_free()
	quit(0)


func _trim(source: Animation, start: float, end: float) -> Animation:
	var anim := source.duplicate() as Animation
	var span := end - start
	for i in range(anim.get_track_count() - 1, -1, -1):
		for k in range(anim.track_get_key_count(i) - 1, -1, -1):
			var t := anim.track_get_key_time(i, k)
			if t < start - 0.0001 or t > end + 0.0001:
				anim.track_remove_key(i, k)
		for k in anim.track_get_key_count(i):
			anim.track_set_key_time(i, k, anim.track_get_key_time(i, k) - start)
	_flatten_hips(anim, span)
	anim.length = span
	return anim


func _flatten_hips(anim: Animation, span: float) -> void:
	for i in anim.get_track_count():
		if anim.track_get_type(i) != Animation.TYPE_POSITION_3D:
			continue
		if StringName(anim.track_get_path(i).get_concatenated_subnames()) != &"Hips":
			continue
		var n := anim.track_get_key_count(i)
		if n < 2:
			return
		var first: Vector3 = anim.track_get_key_value(i, 0)
		var last: Vector3 = anim.track_get_key_value(i, n - 1)
		for k in n:
			var t := anim.track_get_key_time(i, k) / maxf(span, 0.001)
			var v: Vector3 = anim.track_get_key_value(i, k)
			v.y -= (last.y - first.y) * t
			v.z -= (last.z - first.z) * t
			anim.track_set_key_value(i, k, v)
		return
