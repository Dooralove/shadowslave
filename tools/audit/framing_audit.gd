extends SceneTree
## Read-only audit of the WorldFrame distant-geometry kit.
##
## It counts every node tagged with meta `world_frame`, measures the draw-call
## cost of hiding those nodes, and verifies that the kit adds no collision or
## lights. It does not modify the scene on disk.
##
##   godot --path . -s tools/audit/framing_audit.gd -- \
##     --scene=res://scenes/locations/forgotten_shore_labyrinth/labyrinth_first_fragment.tscn

var _scene_path := "res://scenes/locations/forgotten_shore_labyrinth/labyrinth_first_fragment.tscn"
var _rebuild := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--scene="):
			_scene_path = arg.trim_prefix("--scene=")
		elif arg == "--rebuild":
			_rebuild = true
	root.size = Vector2i(1920, 1080)
	var packed := load(_scene_path) as PackedScene
	if packed == null:
		print("FRAMING_AUDIT scene_load_failed=", _scene_path)
		quit(2)
		return
	var scene := packed.instantiate()
	root.add_child(scene)
	if root.get_viewport().get_camera_3d() == null:
		var fallback := Camera3D.new()
		fallback.name = "FramingAuditCamera"
		fallback.fov = 70.0
		fallback.far = 2400.0
		scene.add_child(fallback)
		fallback.global_position = Vector3(0.0, 80.0, -120.0)
		fallback.look_at(Vector3.ZERO, Vector3.UP)
		fallback.make_current()
	for i in 20:
		await process_frame

	var framing_nodes: Array[Node] = []
	var stack: Array[Node] = [scene]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node.has_meta(&"world_frame"):
			framing_nodes.append(node)
		for child in node.get_children():
			stack.append(child)

	var mesh_count := 0
	var multimesh_count := 0
	var multimesh_instances := 0
	var triangles := 0
	var collision_nodes := 0
	var light_nodes := 0
	var root_nodes: Array[Node] = []
	for node in framing_nodes:
		if _has_framing_ancestor(node, scene):
			continue
		root_nodes.append(node)
	for node in framing_nodes:
		if node is MeshInstance3D:
			mesh_count += 1
			var mi := node as MeshInstance3D
			if mi.mesh != null:
				triangles += mi.mesh.get_faces().size() / 3
		elif node is MultiMeshInstance3D:
			multimesh_count += 1
			var mmi := node as MultiMeshInstance3D
			if mmi.multimesh != null:
				multimesh_instances += mmi.multimesh.instance_count
				if mmi.multimesh.mesh != null:
					triangles += (mmi.multimesh.mesh.get_faces().size() / 3) * mmi.multimesh.instance_count
		if node is CollisionObject3D or node is CollisionShape3D:
			collision_nodes += 1
		if node is Light3D:
			light_nodes += 1

	var before := _render_stats()
	for node in root_nodes:
		if node is Node3D:
			(node as Node3D).visible = false
	for i in 12:
		await process_frame
	var after := _render_stats()

	print("FRAMING_AUDIT scene=", _scene_path)
	print("  nodes_tagged=", framing_nodes.size(), " roots=", root_nodes.size())
	print("  meshes=", mesh_count, " multimeshes=", multimesh_count,
		" multimesh_instances=", multimesh_instances, " triangles~=", triangles)
	print("  collision_nodes=", collision_nodes, " lights=", light_nodes)
	print("  draw_calls_before=", before.draw_calls, " after_hide=", after.draw_calls,
		" delta=", before.draw_calls - after.draw_calls)
	print("  primitives_before=", before.primitives, " after_hide=", after.primitives,
		" delta=", before.primitives - after.primitives)
	print("  objects_before=", before.objects, " after_hide=", after.objects,
		" delta=", before.objects - after.objects)

	if _rebuild:
		var art := _find_rebuildable(scene)
		if art != null:
			var before_count := _count_framing(scene)
			art.call(&"rebuild")
			for i in 8:
				await process_frame
			var after_count := _count_framing(scene)
			print("  rebuild_before=", before_count, " rebuild_after=", after_count,
				" duplicate=", after_count - before_count)
		else:
			print("  rebuild_skipped=no_rebuildable_node")
	quit(0)


func _count_framing(scene: Node) -> int:
	var total := 0
	var stack: Array[Node] = [scene]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node.has_meta(&"world_frame"):
			total += 1
		for child in node.get_children():
			stack.append(child)
	return total


func _find_rebuildable(scene: Node) -> Node:
	var stack: Array[Node] = [scene]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node.has_method(&"rebuild") and node.has_method(&"setup"):
			return node
		for child in node.get_children():
			stack.append(child)
	return null


func _has_framing_ancestor(node: Node, scene: Node) -> bool:
	var current := node.get_parent()
	while current != null and current != scene:
		if current.has_meta(&"world_frame"):
			return true
		current = current.get_parent()
	return false


func _render_stats() -> Dictionary:
	return {
		"draw_calls": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		"primitives": int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)),
		"objects": int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)),
	}
