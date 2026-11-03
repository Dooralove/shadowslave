extends SceneTree
## Печатает фактические габариты сцены и координаты игровых точек.
## Только читает: сцена инстанцируется, узлы не изменяются.
##
## godot --headless --path . -s tools/audit/scene_bounds.gd -- \
##   --scene=res://scenes/locations/forgotten_shore_labyrinth/labyrinth_first_fragment.tscn

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene_path := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--scene="):
			scene_path = arg.trim_prefix("--scene=")
	if scene_path.is_empty():
		push_error("scene_bounds: нужен --scene=res://...tscn")
		quit(2)
		return
	var packed := load(scene_path) as PackedScene
	if packed == null:
		push_error("scene_bounds: сцена не загружается: " + scene_path)
		quit(2)
		return
	var scene := packed.instantiate()
	root.add_child(scene)
	for i in 8:
		await process_frame

	print("SCENE ", scene_path)
	print("root=", scene.name)
	print("world_aabb=", _merged_aabb(scene))
	print("collision_aabb=", _collision_aabb(scene))
	print("--- top-level groups ---")
	for child in scene.get_children():
		if child is Node3D:
			var box := _merged_aabb(child)
			if box.has_volume():
				print("%-24s aabb=%s size=%s" % [child.name, str(box), str(box.size)])
	print("--- markers ---")
	_print_markers(scene, scene)
	print("--- portals ---")
	var portals := scene.get_node_or_null(^"Portals")
	if portals:
		for portal in portals.get_children():
			if portal is Node3D:
				print("%-24s pos=%s rot_y=%.1f" % [portal.name, str((portal as Node3D).global_position),
					rad_to_deg((portal as Node3D).global_rotation.y)])
	print("--- landmarks ---")
	var landmarks := scene.get_node_or_null(^"Landmarks")
	if landmarks:
		for landmark in landmarks.get_children():
			if landmark is Node3D:
				print("%-24s pos=%s" % [landmark.name, str((landmark as Node3D).global_position)])
	scene.queue_free()
	await process_frame
	quit(0)


func _print_markers(scene: Node, node: Node) -> void:
	for child in node.get_children():
		if child is Marker3D:
			var marker := child as Marker3D
			print("%-52s pos=%s rot_y=%.1f" % [str(scene.get_path_to(marker)), str(marker.global_position),
				rad_to_deg(marker.global_rotation.y)])
		_print_markers(scene, child)


func _merged_aabb(root_node: Node) -> AABB:
	var box := AABB()
	var first := true
	var stack: Array[Node] = [root_node]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child in node.get_children():
			stack.append(child)
		if node is MeshInstance3D and (node as MeshInstance3D).is_visible_in_tree():
			var mesh := node as MeshInstance3D
			if mesh.mesh == null:
				continue
			var world: AABB = mesh.global_transform * mesh.get_aabb()
			box = world if first else box.merge(world)
			first = false
	return box


## Габарит игровой коллизии: формы крупнее 500 м — фоновые
## плоскости/скалы и в игровые границы не входят.
func _collision_aabb(root_node: Node) -> AABB:
	var box := AABB()
	var first := true
	var stack: Array[Node] = [root_node]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child in node.get_children():
			stack.append(child)
		if node is CollisionShape3D and (node as CollisionShape3D).shape != null:
			var shape_node := node as CollisionShape3D
			var shape: Shape3D = shape_node.shape
			var local := AABB()
			if shape is BoxShape3D:
				var box_shape := shape as BoxShape3D
				local = AABB(-box_shape.size * 0.5, box_shape.size)
			elif shape is CylinderShape3D:
				var cylinder := shape as CylinderShape3D
				var r: float = cylinder.radius * 2.0
				local = AABB(Vector3(-cylinder.radius, -cylinder.height * 0.5, -cylinder.radius), Vector3(r, cylinder.height, r))
			elif shape is SphereShape3D:
				var sphere := shape as SphereShape3D
				var d: float = sphere.radius * 2.0
				local = AABB(Vector3.ONE * -sphere.radius, Vector3.ONE * d)
			else:
				var debug := shape.get_debug_mesh()
				if debug == null:
					continue
				local = debug.get_aabb()
			if local.size.length() > 900.0:
				continue
			var world: AABB = shape_node.global_transform * local
			box = world if first else box.merge(world)
			first = false
	return box
