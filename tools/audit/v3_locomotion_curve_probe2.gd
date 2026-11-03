extends SceneTree
## Sample native v3 locomotion curves (Hips / feet) to find clean loop ranges.

const GLB := "res://assets/characters/generated/sunny_real_v3/sunny_real_v3_clean.glb"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	if doc.append_from_file(GLB, state) != OK:
		quit(2)
		return
	var model := doc.generate_scene(state) as Node3D
	root.add_child(model)
	var skeleton := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var player := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var hips := skeleton.find_bone("Hips")
	var lf := skeleton.find_bone("LeftFoot")
	var rf := skeleton.find_bone("RightFoot")
	for clip in [&"HumanRelaxedWalkLoopF", &"HumanSprintLoop", &"HumanStandingIdle"]:
		player.play(clip)
		var length := player.get_animation(clip).length
		print("CLIP ", clip, " len=", length)
		var t := 0.0
		while t <= length + 0.001:
			player.seek(t, true)
			await process_frame
			var h := skeleton.get_bone_global_pose(hips).origin
			var l := skeleton.get_bone_global_pose(lf).origin
			var r := skeleton.get_bone_global_pose(rf).origin
			print("  t=%.2f hips=(%.3f,%.3f,%.3f) lf=(%.3f,%.3f) rf=(%.3f,%.3f)" % [t, h.x, h.y, h.z, l.y, l.z, r.y, r.z])
			t += 0.2
	quit(0)
