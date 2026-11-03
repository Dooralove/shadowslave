extends SceneTree
## Find the contact frame of native attack clips by peak hand speed.

const V3 := "res://assets/characters/generated/sunny_real_v3/sunny_real_v3_clean.glb"
const P1 := "res://assets/characters/p1/sunny_p1_model.tscn"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await _scan_glb(V3, &"HumanSpBoxing", &"RightHand", "v3_boxing")
	await _scan_model(P1, &"Sword_Attack", &"RightHand", "p1_sword")
	quit(0)


func _scan_glb(path: String, clip: StringName, bone_name: StringName, label: String) -> void:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	if doc.append_from_file(path, state) != OK:
		return
	var model := doc.generate_scene(state) as Node3D
	root.add_child(model)
	var skeleton := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var player := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	await _scan(player, skeleton, clip, bone_name, label)
	model.queue_free()
	await process_frame


func _scan_model(path: String, clip: StringName, bone_name: StringName, label: String) -> void:
	var model := (load(path) as PackedScene).instantiate() as Node3D
	root.add_child(model)
	var skeleton := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var player := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	await _scan(player, skeleton, clip, bone_name, label)
	model.queue_free()
	await process_frame


func _scan(player: AnimationPlayer, skeleton: Skeleton3D, clip: StringName, bone_name: StringName, label: String) -> void:
	if not player.has_animation(clip):
		print("MISSING ", label, " ", clip)
		return
	var anim := player.get_animation(clip)
	var bone := skeleton.find_bone(bone_name)
	player.play(clip)
	var prev := Vector3.ZERO
	var prev_t := -1.0
	var speeds := []
	var t := 0.0
	while t <= anim.length + 0.0001:
		player.seek(t, true)
		await process_frame
		var pos := skeleton.get_bone_global_pose(bone).origin
		if prev_t >= 0.0:
			speeds.append([(pos - prev).length() / maxf(t - prev_t, 0.0001), t])
		prev = pos
		prev_t = t
		t += 1.0 / 30.0
	speeds.sort_custom(func(a, b): return a[0] > b[0])
	print("CLIP ", label, " len=", anim.length, " top:")
	for i in mini(8, speeds.size()):
		print("  speed=%.3f at t=%.3f" % [speeds[i][0], speeds[i][1]])
