extends Node
## A07 validation harness for the post-nightmare art overlay.
## Loads each preview wrapper, waits for layout_built + deferred overlay work,
## and checks that the profile applied, art props/lights exist, and the art
## scene itself contributes no collision.

const PREVIEWS := [
	["P05", "res://scenes/environment/post_nightmare/preview/p05_police_precinct_preview.tscn", "PolicePrecinct"],
	["P06", "res://scenes/environment/post_nightmare/preview/p06_academy_approach_preview.tscn", "AcademyApproach"],
	["P07", "res://scenes/environment/post_nightmare/preview/p07_academy_gate_preview.tscn", "AcademyGate"],
	["P08", "res://scenes/environment/post_nightmare/preview/p08_academy_campus_preview.tscn", "AcademyCampus"],
	["P09", "res://scenes/environment/post_nightmare/preview/p09_sleeper_center_preview.tscn", "AcademySleeperCenter"],
	["B01", "res://scenes/environment/post_nightmare/preview/b01_black_sea_platform_preview.tscn", "BlackSeaPlatform"],
	["B02", "res://scenes/environment/post_nightmare/preview/b02_tide_descent_preview.tscn", "TideDescent"],
]


func _ready() -> void:
	var failures: Array[String] = []
	for entry in PREVIEWS:
		var tag: String = entry[0]
		var preview := load(String(entry[1])) as PackedScene
		if preview == null:
			failures.append("%s preview failed to load" % tag)
			continue
		var instance := preview.instantiate() as Node3D
		add_child(instance)
		await get_tree().process_frame
		await get_tree().process_frame
		var location := instance.get_node_or_null(String(entry[2])) as Node3D
		var overlay := instance.get_node_or_null(^"ArtOverlay") as Node3D
		var applied := overlay != null and bool(overlay.get_meta(&"art_profile_applied", false))
		var props := 0
		var lights := 0
		var decals := 0
		var art_collision := 0
		if overlay != null:
			props = _count_children(overlay.get_node_or_null(^"Props"))
			lights = _count_children(overlay.get_node_or_null(^"Lights"))
			decals = _count_children(overlay.get_node_or_null(^"Decals"))
			art_collision = _count_collision(overlay)
		var swapped := _count_swapped(location)
		var generated := location.get_node_or_null(^"Generated") as Node3D if location != null else null
		var has_generated := generated != null
		print("A07_VALIDATE %s applied=%s generated=%s props=%d lights=%d decals=%d swapped=%d art_collision=%d" % [
			tag, str(applied), str(has_generated), props, lights, decals, swapped, art_collision,
		])
		if not applied:
			failures.append("%s overlay not applied" % tag)
		if not has_generated:
			failures.append("%s generated layout missing" % tag)
		if props + lights + decals <= 0:
			failures.append("%s art overlay is empty" % tag)
		if art_collision != 0:
			failures.append("%s art scene adds collision (%d)" % [tag, art_collision])
		instance.queue_free()
		await get_tree().process_frame
	print("A07_VALIDATE_DONE failures=%d" % failures.size())
	for failure in failures:
		print("A07_VALIDATE_FAIL " + failure)
	get_tree().quit(0 if failures.is_empty() else 1)


func _count_children(node: Node) -> int:
	if node == null:
		return 0
	var count := 0
	for child in node.get_children():
		if child is Node3D:
			count += 1
	return count


func _count_collision(node: Node) -> int:
	var count := 0
	var stack: Array[Node] = [node]
	while not stack.is_empty():
		var current: Node = stack.pop_back()
		if current is CollisionObject3D or current is CollisionShape3D:
			count += 1
		for child in current.get_children():
			stack.append(child)
	return count


func _count_swapped(location: Node3D) -> int:
	if location == null:
		return 0
	var count := 0
	var stack: Array[Node] = [location]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is MeshInstance3D:
			var mi := node as MeshInstance3D
			if mi.material_override != null:
				var name := mi.material_override.resource_name
				if name.begins_with("art_") or name.begins_with("lab_"):
					count += 1
		for child in node.get_children():
			stack.append(child)
	return count
