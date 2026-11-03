extends SceneTree
## Сбор фактических характеристик сцены для графического аудита. Только чтение.
## godot --path . -s tools/audit/scene_stats.gd -- --scene=res://...

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene_path := "res://scenes/locations/post_nightmare/coral_labyrinth.tscn"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--scene="):
			scene_path = arg.trim_prefix("--scene=")
	root.size = Vector2i(1280, 720)
	var scene: Node = (load(scene_path) as PackedScene).instantiate()
	root.add_child(scene)
	for i in 20:
		await process_frame

	var mesh_count := 0
	var collider_count := 0
	var collision_shape_count := 0
	var collision_body_count := 0
	var light_count := 0
	var label_count := 0
	var camera_count := 0
	var triangles := 0
	var material_keys := {}
	var light_types := {}
	var env: Environment = null
	var env_node: WorldEnvironment = null
	var stack: Array[Node] = [scene]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child in node.get_children():
			stack.append(child)
		if node is MeshInstance3D:
			mesh_count += 1
			var mi := node as MeshInstance3D
			if mi.mesh != null:
				for s in mi.mesh.get_surface_count():
					var arrays := mi.mesh.surface_get_arrays(s)
					var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
					if indices.size() > 0:
						triangles += indices.size() / 3
					else:
						var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
						triangles += verts.size() / 3
			var mat := mi.material_override
			if mat == null and mi.mesh != null and mi.mesh.get_surface_count() > 0:
				mat = mi.mesh.surface_get_material(0)
			if mat != null:
				var key := mat.resource_path if not mat.resource_path.is_empty() else mat.get_class()
				material_keys[key] = int(material_keys.get(key, 0)) + 1
		elif node is Light3D:
			light_count += 1
			var key := node.get_class()
			light_types[key] = int(light_types.get(key, 0)) + 1
		elif node is Label3D:
			label_count += 1
		elif node is Camera3D:
			camera_count += 1
		elif node is CollisionShape3D:
			collision_shape_count += 1
		elif node is CollisionObject3D:
			collision_body_count += 1
		if node is CollisionShape3D or node is CollisionObject3D:
			collider_count += 1
		if node is WorldEnvironment:
			env_node = node as WorldEnvironment
			env = env_node.environment

	print("SCENE ", scene_path)
	print("nodes=", _count_nodes(scene), " meshes=", mesh_count, " triangles~=", triangles)
	var generated := scene.get_node_or_null(^"Generated")
	if generated != null:
		var gen := _mesh_stats(generated)
		print("generated meshes=", gen.meshes, " triangles~=", gen.triangles)
	var player_node := scene.get_node_or_null(^"Player")
	if player_node != null:
		var pl := _mesh_stats(player_node)
		print("player meshes=", pl.meshes, " triangles~=", pl.triangles)
	print("colliders=", collider_count, " shapes=", collision_shape_count, " bodies=", collision_body_count, " lights=", light_count, " ", light_types)
	print("labels=", label_count, " cameras=", camera_count)
	print("materials=", material_keys)
	if env != null:
		print("environment=", env.resource_path, " sky=", env.sky, " background=", env.background_mode,
			" tonemap=", env.tonemap_mode, " ambient=", env.ambient_light_source,
			" ssao=", env.ssao_enabled, " ssil=", env.ssil_enabled, " sdfgi=", env.sdfgi_enabled,
			" glow=", env.glow_enabled, " fog=", env.fog_enabled, " volumetric=", env.volumetric_fog_enabled)
	print("render: draw_calls=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		" primitives=", Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		" objects=", Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		" fps=", Performance.get_monitor(Performance.TIME_FPS),
		" frame_ms=", Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
	var player := scene.get_tree().get_first_node_in_group(&"player")
	if player != null:
		print("player=", player.get_path())
	quit(0)


func _count_nodes(root_node: Node) -> int:
	var count := 0
	var stack: Array[Node] = [root_node]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		count += 1
		for child in node.get_children():
			stack.append(child)
	return count


func _mesh_stats(root_node: Node) -> Dictionary:
	var meshes := 0
	var triangles := 0
	var stack: Array[Node] = [root_node]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child in node.get_children():
			stack.append(child)
		if node is MeshInstance3D:
			meshes += 1
			var mi := node as MeshInstance3D
			if mi.mesh != null:
				for s in mi.mesh.get_surface_count():
					var arrays := mi.mesh.surface_get_arrays(s)
					var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
					if indices.size() > 0:
						triangles += indices.size() / 3
					else:
						var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
						triangles += verts.size() / 3
	return {"meshes": meshes, "triangles": triangles}
