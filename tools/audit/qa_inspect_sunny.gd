extends SceneTree
## Read-only: print player visual children visibility for duplicate-model audit.

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var scene := (load("res://scenes/campaign/campaign_entry.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	for i in 5:
		await process_frame
	var player := get_first_node_in_group(&"player") as Node3D
	if player == null:
		print("NO_PLAYER")
		quit(1)
		return
	var visual := player.get_node_or_null(^"Visual") as Node3D
	print("PLAYER=", player.name, " scene=", player.scene_file_path)
	if visual != null:
		for child in visual.get_children():
			print("VISUAL_CHILD ", child.name, " class=", child.get_class(), " visible=", child.visible,
				" owner=", child.owner.name if child.owner != null else "<none>")
	quit(0)
