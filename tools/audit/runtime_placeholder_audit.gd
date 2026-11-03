extends SceneTree
## Runtime placeholder audit for scenes whose greybox is built by script
## (currently the Forgotten Shore labyrinth).
##
## Read-only. Instantiates the scene, waits for CSG/geometry updates, then
## reports visible primitive meshes and CSG shapes with world AABBs.
##
## Run:
##   godot --headless --path . -s tools/audit/runtime_placeholder_audit.gd -- \
##     --scene=res://scenes/locations/forgotten_shore_labyrinth/labyrinth_first_fragment.tscn \
##     --out=%TEMP%/opencode/labyrinth_placeholders.txt

var _scene_path := "res://scenes/locations/forgotten_shore_labyrinth/labyrinth_first_fragment.tscn"
var _out_path := ""


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--scene="):
			_scene_path = arg.trim_prefix("--scene=")
		elif arg.begins_with("--out="):
			_out_path = arg.trim_prefix("--out=")

	var packed := load(_scene_path) as PackedScene
	if packed == null:
		push_error("runtime_placeholder_audit: cannot load " + _scene_path)
		quit(2)
		return
	var scene := packed.instantiate()
	root.add_child(scene)
	for i in 8:
		await process_frame

	var records: Array[Dictionary] = []
	_collect(scene, records)

	var lines: Array[String] = []
	lines.append("# Runtime placeholder audit")
	lines.append("scene: " + _scene_path)
	lines.append("visible primitives: %d" % records.size())
	lines.append("")
	lines.append("| Node path | Class | Mesh | World position | World AABB size |")
	lines.append("|---|---|---|---|---|")
	for r in records:
		lines.append("| `%s` | %s | %s | %.2f, %.2f, %.2f | %.2f x %.2f x %.2f |" % [
			r.path, r.class, r.mesh, r.pos.x, r.pos.y, r.pos.z, r.size.x, r.size.y, r.size.z,
		])
	var text := "\n".join(lines)
	if _out_path.is_empty():
		print(text)
	else:
		var f := FileAccess.open(_out_path, FileAccess.WRITE)
		if f == null:
			push_error("runtime_placeholder_audit: cannot write " + _out_path)
		else:
			f.store_string(text)
			f.close()
		print("written: " + _out_path)
		print("visible primitives: %d" % records.size())
	quit(0)


func _collect(node: Node, records: Array[Dictionary]) -> void:
	# ArtFinal contains intentional procedural art (horizon, sea stacks, rain),
	# not greybox placeholders. Do not count it as a replacement target.
	if String(node.get_path()).contains("/ArtFinal/"):
		return
	for child in node.get_children():
		_collect(child, records)
	if not (node is MeshInstance3D or node is CSGShape3D):
		return
	if not node.is_visible_in_tree():
		return
	var mi := node as MeshInstance3D
	if mi != null:
		var mesh := mi.mesh
		if mesh == null:
			return
		var cls := mesh.get_class()
		if cls not in ["BoxMesh", "CylinderMesh", "SphereMesh", "PrismMesh", "PlaneMesh", "QuadMesh", "TorusMesh", "CapsuleMesh"]:
			return
		var aabb := mi.global_transform * mesh.get_aabb()
		records.append({
			"path": String(mi.get_path()).replace("/root/" + str(root.get_child(0).name) + "/", ""),
			"class": "MeshInstance3D",
			"mesh": cls,
			"pos": aabb.get_center(),
			"size": aabb.size,
		})
		return
	var csg := node as CSGShape3D
	if csg != null:
		var meshes := csg.get_meshes()
		if meshes.is_empty():
			return
		var combined := AABB()
		var first := true
		var i := 0
		while i + 1 < meshes.size():
			var xform: Transform3D = meshes[i]
			var mesh: Mesh = meshes[i + 1]
			i += 2
			if mesh == null:
				continue
			var box := csg.global_transform * xform * mesh.get_aabb()
			if first:
				combined = box
				first = false
			else:
				combined = combined.merge(box)
		if first:
			return
		records.append({
			"path": String(csg.get_path()).replace("/root/" + str(root.get_child(0).name) + "/", ""),
			"class": csg.get_class(),
			"mesh": "CSG",
			"pos": combined.get_center(),
			"size": combined.size,
		})
