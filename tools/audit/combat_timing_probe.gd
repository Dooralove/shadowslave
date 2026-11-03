extends SceneTree
## Read-only combat timing probe.
##
## Dumps animation clip lengths and samples the strike hand/claw bone so attack
## contact can be checked against MeleeAttack windup/active windows.
##
## Usage:
##   godot --headless --path . -s tools/audit/combat_timing_probe.gd -- --scene=res://scenes/characters/sunny.tscn --clip=1H_Melee_Attack_Slice_Horizontal --bone=handslot.r
##   godot --headless --path . -s tools/audit/combat_timing_probe.gd -- --scene=res://scenes/enemies/carapace_enemy.tscn --clip=Attack --bone=ClawTipL

var _scene_path := ""
var _clip := ""
var _bone := ""
var _step := 1.0 / 60.0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--scene="):
			_scene_path = arg.trim_prefix("--scene=")
		elif arg.begins_with("--clip="):
			_clip = arg.trim_prefix("--clip=")
		elif arg.begins_with("--bone="):
			_bone = arg.trim_prefix("--bone=")
	if _scene_path.is_empty():
		push_error("combat_timing_probe: need --scene=res://...")
		quit(2)
		return
	var packed := load(_scene_path) as PackedScene
	if packed == null:
		push_error("combat_timing_probe: cannot load " + _scene_path)
		quit(2)
		return
	var root := packed.instantiate()
	get_root().add_child(root)
	await process_frame
	_disable_animator_scripts(root)

	var player := _find_animation_player(root, _clip) as AnimationPlayer
	var skeleton := _find_skeleton_for(player) if player != null else null
	if player == null:
		push_error("combat_timing_probe: no AnimationPlayer")
		quit(2)
		return
	print("SCENE ", _scene_path)
	print("PLAYER ", root.get_path_to(player), " ROOT=", player.root_node)
	if skeleton != null:
		print("SKELETON ", root.get_path_to(skeleton), " BONE_COUNT=", skeleton.get_bone_count())
	if skeleton != null:
		var bones := PackedStringArray()
		for i in skeleton.get_bone_count():
			bones.append(skeleton.get_bone_name(i))
		print("BONES ", ", ".join(bones))
	for clip_name in player.get_animation_list():
		var animation := player.get_animation(clip_name)
		print("CLIP ", clip_name, " length=", snappedf(animation.length, 0.001), " loops=", animation.loop_mode)
	if _clip.is_empty() or not player.has_animation(_clip):
		quit(0)
		return
	if _bone.is_empty() or skeleton == null or skeleton.find_bone(_bone) < 0:
		push_error("combat_timing_probe: need a valid --bone= for sampling; bone not found")
		quit(2)
		return

	player.play(_clip)
	player.seek(0.0, true)
	var animation := player.get_animation(_clip)
	for track in animation.get_track_count():
		if animation.track_get_type(track) == Animation.TYPE_ROTATION_3D or animation.track_get_type(track) == Animation.TYPE_POSITION_3D:
			print("TRACK ", animation.track_get_path(track), " type=", animation.track_get_type(track))
	var bone_index := skeleton.find_bone(_bone)
	var root_index := skeleton.find_bone("Root") if skeleton.find_bone("Root") >= 0 else -1
	var frames := int(ceil(animation.length / _step))
	var previous := Vector3.ZERO
	var samples: Array[Dictionary] = []
	# Let the first seek settle before measuring: the first frame can still show
	# the rest pose, which produces a false "peak" at t=0.
	for settle in 3:
		player.seek(0.0, true)
		await process_frame
	for frame in frames + 1:
		var t := minf(frame * _step, animation.length)
		player.seek(t, true)
		# Seek applies during the next animation update; read one frame later.
		await process_frame
		await process_frame
		skeleton.force_update_all_bone_transforms()
		if frame % 15 == 0:
			print("DBG t=%.3f anim=%s pos=%.3f playing=%s" % [
				t,
				player.current_animation,
				player.current_animation_position,
				str(player.is_playing()),
			])
		var bone_global := skeleton.get_bone_global_pose(bone_index).origin
		if root_index >= 0:
			bone_global -= skeleton.get_bone_global_pose(root_index).origin
		var velocity := Vector3.ZERO
		if frame > 0 and _step > 0.0:
			velocity = (bone_global - previous) / _step
		previous = bone_global
		samples.append({"t": t, "pos": bone_global, "vel": velocity})
	var peak := 0.0
	var peak_t := 0.0
	for sample in samples:
		var speed: float = (sample["vel"] as Vector3).length()
		if speed > peak:
			peak = speed
			peak_t = sample["t"]
	print("SAMPLE bone=%s length=%.3f peak_speed=%.3f at=%.3f" % [_bone, animation.length, peak, peak_t])
	# Print the five fastest samples so a plateau can be inspected.
	var ordered := samples.duplicate()
	ordered.sort_custom(func(a, b): return (a["vel"] as Vector3).length() > (b["vel"] as Vector3).length())
	for i in mini(5, ordered.size()):
		var sample: Dictionary = ordered[i]
		print("  t=%.3f speed=%.3f pos=%s" % [sample["t"], (sample["vel"] as Vector3).length(), str(sample["pos"])])
	quit(0)


func _find_first(node: Node, type_name: String) -> Node:
	if node.is_class(type_name):
		return node
	for child in node.get_children():
		var found := _find_first(child, type_name)
		if found != null:
			return found
	return null


func _find_animation_player(node: Node, clip: String) -> AnimationPlayer:
	if node is AnimationPlayer:
		var player := node as AnimationPlayer
		if clip.is_empty() or player.has_animation(clip):
			return player
	for child in node.get_children():
		var found := _find_animation_player(child, clip)
		if found != null:
			return found
	return null


func _find_skeleton_for(player: AnimationPlayer) -> Skeleton3D:
	if player == null:
		return null
	var root := player.get_node_or_null(player.root_node)
	var search_root := root if root != null else player.get_parent()
	var found := _find_first(search_root, "Skeleton3D") as Skeleton3D
	if found != null:
		return found
	return _find_first(player.get_parent(), "Skeleton3D") as Skeleton3D


## The probe must observe the raw clip, not a gameplay animator that overrides
## it every physical frame (SunnyAnimator, EnemyAnimator, ...).
func _disable_animator_scripts(node: Node) -> void:
	var script := node.get_script() as Script
	if script != null:
		var script_path: String = script.resource_path
		if script_path.ends_with("sunny_animator.gd") or script_path.ends_with("enemy_animator.gd") \
				or script_path.ends_with("carapace_animator.gd") or script_path.ends_with("larva_animator.gd"):
			node.set_process(false)
			node.set_physics_process(false)
	for child in node.get_children():
		_disable_animator_scripts(child)
