extends SceneTree
## Read-only pose capture for armour deformation:
## ATTACK, DODGE, DEATH and a head turn.
## godot --path . -s tools/audit/armor_pose_capture.gd -- --out=<dir>

const DEMO := "res://scenes/dev/equipment_loot_demo.tscn"
const SETS := [
	["none", ""],
	["scout", "res://resources/equipment/armor/scout_leather.tres"],
	["mercenary", "res://resources/equipment/armor/mercenary_medium.tres"],
	["heavy", "res://resources/equipment/armor/heavy_plate.tres"],
]
const POSES := [
	["attack", &"HumanSpBoxing", 0.40],
	["dodge", &"HumanRoll", 0.50],
	["death", &"HumanDeath", 0.90],
]

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
	var sunny := scene.get_node("Sunny") as CharacterBody3D
	sunny.set_physics_process(false)
	var tree := scene.get_node("Sunny/AnimationTree") as AnimationTree
	tree.active = false
	var animator := scene.get_node("Sunny/Animator")
	animator.set_process(false)
	animator.set_physics_process(false)
	var player := scene.get_node("Sunny/Visual/ModelPoc/Model/AnimationPlayer") as AnimationPlayer
	var skeleton := scene.get_node("Sunny/Visual/ModelPoc/Model/Armature/Skeleton3D") as Skeleton3D

	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.current = true

	for set_info in SETS:
		if set_info[1] == "":
			equipment.call("unequip", EquipmentItemData.Slot.BODY)
		else:
			equipment.call("equip", load(set_info[1]))
		for i in 8:
			await process_frame
		for pose in POSES:
			camera.fov = 50.0
			camera.position = Vector3(0.0, 1.05, 0.05)
			camera.look_at(Vector3(0.0, 0.95, 2.0), Vector3.UP)
			if pose[0] == "death":
				camera.fov = 58.0
				camera.position = Vector3(0.0, 1.7, 0.8)
				camera.look_at(Vector3(0.0, 0.45, 2.0), Vector3.UP)
			player.play(pose[1])
			player.seek(float(pose[2]), true)
			player.pause()
			for i in 4:
				await process_frame
			await RenderingServer.frame_post_draw
			var path := _out.path_join("pose_%s_%s.png" % [set_info[0], pose[0]])
			root.get_texture().get_image().save_png(path)
			print("CAPTURE ", path)

		# Head turn: idle pose then rotate the head bone locally.
		camera.fov = 50.0
		camera.position = Vector3(0.0, 1.05, 0.05)
		camera.look_at(Vector3(0.0, 0.95, 2.0), Vector3.UP)
		player.play(&"HumanStandingIdle")
		player.seek(0.0, true)
		player.pause()
		var head := skeleton.find_bone(&"Head")
		if head >= 0:
			var current := skeleton.get_bone_pose_rotation(head)
			skeleton.set_bone_pose_rotation(head, current * Quaternion(Vector3.UP, deg_to_rad(35.0)))
		for i in 4:
			await process_frame
		await RenderingServer.frame_post_draw
		var head_path := _out.path_join("pose_%s_head_turn.png" % set_info[0])
		root.get_texture().get_image().save_png(head_path)
		print("CAPTURE ", head_path)
	quit(0)
