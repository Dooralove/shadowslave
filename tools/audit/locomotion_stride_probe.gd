extends SceneTree
## Measure in-place locomotion stride from the P1 UAL clips.

const MODEL := "res://assets/characters/p1/sunny_p1_model.tscn"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var model := (load(MODEL) as PackedScene).instantiate() as Node3D
	root.add_child(model)
	await process_frame
	var skeleton := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var player := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	for clip in [&"Walk", &"Sprint", &"Jog_Fwd"]:
		if not player.has_animation(clip):
			continue
		var anim := player.get_animation(clip)
		var length := anim.length
		player.play(clip)
		var lf := skeleton.find_bone("LeftFoot")
		var rf := skeleton.find_bone("RightFoot")
		var lmin := INF
		var lmax := -INF
		var rmin := INF
		var rmax := -INF
		var samples := 60
		for i in samples:
			var t := length * float(i) / float(samples)
			player.seek(t, true)
			await process_frame
			var lp := skeleton.get_bone_global_pose(lf).origin
			var rp := skeleton.get_bone_global_pose(rf).origin
			lmin = minf(lmin, lp.z)
			lmax = maxf(lmax, lp.z)
			rmin = minf(rmin, rp.z)
			rmax = maxf(rmax, rp.z)
		var stride := maxf(lmax - lmin, rmax - rmin)
		# Two steps per cycle: body advances one stride per half cycle.
		var speed := stride / maxf(length * 0.5, 0.001)
		print("CLIP ", clip, " len=", length, " stride=", stride, " authored_speed=", speed,
			" lrange=", [lmin, lmax], " rrange=", [rmin, rmax])
	quit(0)
