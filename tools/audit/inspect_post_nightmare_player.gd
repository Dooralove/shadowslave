extends SceneTree
## Диагностика: почему Player в post-nightmare сцене частично инициализирован.


func _init() -> void:
	var packed := load("res://scenes/locations/post_nightmare/academy_gate.tscn") as PackedScene
	if packed == null:
		print("SCENE_LOAD_FAILED")
		quit(1)
		return
	var scene := packed.instantiate()
	root.add_child(scene)
	await process_frame
	await physics_frame
	var player := scene.get_node_or_null(^"Player")
	print("PLAYER=", player)
	if player != null:
		var script: Script = player.get_script()
		print("PLAYER_CLASS=", player.get_class())
		print("PLAYER_SCRIPT=", script.resource_path if script != null else "NONE")
		print("PLAYER_VISUAL=", player.get(&"visual"))
		print("PLAYER_CAMERA=", player.get(&"camera_rig"))
		print("PLAYER_HEALTH=", player.get(&"health"))
		print("PLAYER_ON_FLOOR=", player.call(&"is_on_floor") if player.has_method(&"is_on_floor") else "NO_METHOD")
		print("CAMERA_NODE=", player.get_node_or_null(^"CameraRig"))
		print("VISUAL_NODE=", player.get_node_or_null(^"Visual"))
	quit(0)
