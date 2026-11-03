extends GutTest
## AnimationTree-лаборатория: P1-скелет, UAL + Rokoko, shared library,
## state machine и weapon socket. Игровые сцены не затрагиваются.

const LAB := "res://scenes/dev/animation_lab.tscn"


func _make_lab() -> AnimationLab:
	var lab := (load(LAB) as PackedScene).instantiate() as AnimationLab
	add_child_autofree(lab)
	return lab


func test_lab_has_player_tree_and_shared_library() -> void:
	var lab := _make_lab()
	await wait_process_frames(2)
	var player := lab.get_node("Model/AnimationPlayer") as AnimationPlayer
	var tree := lab.get_node_or_null("AnimationTree") as AnimationTree
	assert_not_null(tree, "AnimationTree создан")
	assert_true(tree.active, "tree активен")
	assert_not_null(tree.tree_root, "у tree есть state machine")
	assert_true(player.has_animation_library(&"rokoko"), "Rokoko library подключена")
	assert_eq(player.get_animation_library(&"rokoko").get_animation_list().size(), 7, "7 Rokoko-клипов")
	for clip in ["Walk_Forward", "Run_Treadmill", "Run_Injured_Treadmill", "Knife_Stab_01", "Knife_Stab_02", "Grenade_Throw_01", "Grenade_Throw_02"]:
		assert_true(player.has_animation("rokoko/" + clip), "нет Rokoko-клипа " + clip)
	assert_true(player.has_animation(&"sunny/Idle_Relaxed"), "Idle на месте")
	assert_true(player.has_animation(&"Sword_Attack"), "UAL attack на месте")


func test_weapon_socket_is_attached_to_hand() -> void:
	var lab := _make_lab()
	await wait_process_frames(2)
	var skeleton := lab.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var socket := skeleton.get_node_or_null("WeaponSocket") as BoneAttachment3D
	assert_not_null(socket, "weapon socket создан")
	assert_eq(socket.bone_name, &"RightHand", "socket на правой кисти P1")
	assert_not_null(socket.get_node_or_null("DebugWeapon"), "debug weapon создан")
	var start := socket.global_transform.origin
	lab.travel(&"Combat")
	await wait_process_frames(6)
	assert_gt(start.distance_to(socket.global_transform.origin), 0.02, "socket следует за анимацией кисти")


func test_state_machine_changes_pose_and_returns() -> void:
	var lab := _make_lab()
	await wait_process_frames(2)
	var tree := lab.get_node("AnimationTree") as AnimationTree
	var pb := tree.get("parameters/playback") as AnimationNodeStateMachinePlayback
	var skeleton := lab.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var hand := skeleton.find_bone(&"RightHand")
	var idle := skeleton.get_bone_global_pose(hand).origin
	lab.travel(&"Combat")
	await wait_process_frames(6)
	var combat := skeleton.get_bone_global_pose(hand).origin
	assert_eq(pb.get_current_node(), &"Combat", "state machine перешёл в Combat")
	assert_gt(idle.distance_to(combat), 0.05, "поза руки изменилась")
	lab.travel(&"Locomotion")
	await wait_process_frames(6)
	assert_eq(pb.get_current_node(), &"Locomotion", "state machine вернулся в Locomotion")


func test_rokoko_knife_state_is_reachable() -> void:
	var lab := _make_lab()
	await wait_process_frames(2)
	lab.travel(&"Knife02")
	await wait_process_frames(4)
	var tree := lab.get_node("AnimationTree") as AnimationTree
	var pb := tree.get("parameters/playback") as AnimationNodeStateMachinePlayback
	assert_eq(pb.get_current_node(), &"Knife02", "state machine перешёл в Knife02")


func test_rokoko_root_motion_clip_is_playable() -> void:
	var lab := _make_lab()
	await wait_process_frames(2)
	var player := lab.get_node("Model/AnimationPlayer") as AnimationPlayer
	assert_true(player.has_animation(&"rokoko/Walk_Forward"), "Rokoko walk доступен")
	assert_gt(player.get_animation(&"rokoko/Walk_Forward").length, 10.0, "длинный root-motion тейк")
	lab.travel(&"RokokoWalk")
	await wait_process_frames(4)
	var tree := lab.get_node("AnimationTree") as AnimationTree
	var pb := tree.get("parameters/playback") as AnimationNodeStateMachinePlayback
	assert_eq(pb.get_current_node(), &"RokokoWalk", "переход в RokokoWalk")
