extends SceneTree
## Print the P1 RightHand bone basis in sword poses to calibrate the weapon socket.

const MODEL := "res://assets/characters/p1/sunny_p1_model.tscn"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var model := (load(MODEL) as PackedScene).instantiate() as Node3D
	root.add_child(model)
	await process_frame
	await process_frame
	var skeleton := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var player := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var hand := skeleton.find_bone("RightHand")
	var socket := model.find_child("WeaponSocket", true, false) as BoneAttachment3D
	for entry in [[&"Sword_Idle", 0.4, "idle"], [&"Sword_Attack", 0.55, "attack"]]:
		player.play(entry[0])
		player.seek(entry[1], true)
		player.pause()
		await process_frame
		var pose := skeleton.get_bone_global_pose(hand)
		var b := pose.basis
		print("HAND ", entry[2], " origin=", pose.origin,
			" x=", b.x, " y=", b.y, " z=", b.z)
		if socket:
			var sb := socket.global_transform.basis
			print("SOCKET ", entry[2], " x=", sb.x, " y=", sb.y, " z=", sb.z)
	quit(0)
