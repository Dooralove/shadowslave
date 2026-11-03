extends SceneTree
## Read-only: list interactables, triggers, portals and NPCs in one scene.
##   godot --headless --path . -s tools/audit/qa_scene_interactables.gd -- --scene=res://...

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var scene_path := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--scene="):
			scene_path = arg.trim_prefix("--scene=")
	if scene_path.is_empty():
		print("NO_SCENE")
		quit(2)
		return
	var packed := load(scene_path) as PackedScene
	if packed == null:
		print("NO_PACKED")
		quit(3)
		return
	var scene := packed.instantiate()
	root.add_child(scene)
	for i in 8:
		await process_frame
	var stack: Array[Node] = [scene]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child in node.get_children():
			stack.append(child)
		var script: Script = node.get_script() as Script
		if script != null:
			var script_path: String = script.resource_path
			if script_path.ends_with("interactable.gd"):
				print("INTERACT ", node.get_path(), " id=", node.get(&"interaction_id"), " enabled=", node.get(&"enabled"))
			elif script_path.ends_with("trigger_zone.gd"):
				print("TRIGGER ", node.get_path(), " id=", node.get(&"trigger_id"), " enabled=", node.get(&"enabled"))
			elif script_path.ends_with("level_portal.gd"):
				print("PORTAL ", node.get_path(), " dest=", node.get(&"destination_scene"), " enabled=", node.get(&"enabled"))
			elif node.has_method(&"get_npc_id"):
				print("NPC ", node.get_path(), " id=", node.call(&"get_npc_id"))
	quit(0)
