extends SceneTree
## Read-only asset inspection: node tree, mesh AABBs, skeleton and animation clips.

var _path := ""


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--scene="):
			_path = arg.trim_prefix("--scene=")
	if _path.is_empty():
		push_error("inspect_asset: need --scene=res://...")
		quit(2)
		return
	var packed := load(_path) as PackedScene
	if packed == null:
		push_error("inspect_asset: cannot load " + _path)
		quit(2)
		return
	var root := packed.instantiate()
	get_root().add_child(root)
	await process_frame

	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is MeshInstance3D:
			var mesh := node as MeshInstance3D
			var lines := PackedStringArray()
			if mesh.mesh != null:
				lines.append("AABB=%s" % str(mesh.mesh.get_aabb()))
				for i in mesh.mesh.get_surface_count():
					var mat := mesh.mesh.surface_get_material(i)
					if mat is BaseMaterial3D:
						var bm := mat as BaseMaterial3D
						lines.append("mat%d albedo=%s normal=%s rough=%s" % [
							i,
							bm.albedo_texture.resource_path if bm.albedo_texture else "none",
							bm.normal_texture.resource_path if bm.normal_texture else "none",
							bm.roughness_texture.resource_path if bm.roughness_texture else "none",
						])
			print("MESH ", root.get_path_to(node), " ", " ".join(lines))
		elif node is Skeleton3D:
			print("SKELETON ", root.get_path_to(node), " bones=", (node as Skeleton3D).get_bone_count())
		elif node is AnimationPlayer:
			var ap := node as AnimationPlayer
			print("ANIM ", root.get_path_to(node), " clips=", ap.get_animation_list(), " autoplay=", ap.autoplay)
		for child in node.get_children():
			stack.append(child)
	quit(0)
