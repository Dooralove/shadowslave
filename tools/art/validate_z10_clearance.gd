extends Node
## A07 Stage 4 clearance audit for the A03 DemoEndZone.
## A03 places DemoEndZone at (-100, 18.2, -5) with radius 4.0. Only the
## campfire may sit inside that volume; all other A07 camp props must stay out.

const SCENE := "res://scenes/locations/forgotten_shore_labyrinth/labyrinth_first_fragment.tscn"
const CENTER := Vector3(-100.0, 18.2, -5.0)
const RADIUS := 4.0


func _ready() -> void:
	var packed := load(SCENE) as PackedScene
	if packed == null:
		push_error("A07 clearance: scene missing")
		get_tree().quit(2)
		return
	var location := packed.instantiate() as Node3D
	add_child(location)
	await get_tree().process_frame
	await get_tree().process_frame
	var camp := location.get_node_or_null(^"ArtFinal/Zones/Z10_CoralHill") as Node3D
	if camp == null:
		push_error("A07 clearance: ArtFinal/Zones/Z10_CoralHill missing")
		get_tree().quit(3)
		return
	var offenders: Array[String] = []
	var checked := 0
	var stack: Array[Node] = [camp]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child in node.get_children():
			stack.append(child)
		if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
			checked += 1
			if _is_campfire(node) or _is_scenery(node):
				continue
			var mi := node as MeshInstance3D
			var box := mi.global_transform * mi.mesh.get_aabb()
			var closest := Vector3(
				clampf(CENTER.x, box.position.x, box.position.x + box.size.x),
				clampf(CENTER.y, box.position.y, box.position.y + box.size.y),
				clampf(CENTER.z, box.position.z, box.position.z + box.size.z)
			)
			if closest.distance_to(CENTER) < RADIUS:
				offenders.append("%s at %s (d=%.2f)" % [str(mi.get_path()), str(box.get_center()), closest.distance_to(CENTER)])
	print("A07_Z10_CLEARANCE checked=%d offenders=%d" % [checked, offenders.size()])
	for offender in offenders:
		print("A07_Z10_OFFENDER " + offender)
	print("A07_Z10_CLEARANCE_DONE")
	location.queue_free()
	get_tree().quit(0 if offenders.is_empty() else 1)


func _is_campfire(node: Node) -> bool:
	var current := node
	while current != null:
		if String(current.name).to_lower().contains("campfire"):
			return true
		current = current.get_parent()
	return false


func _is_scenery(node: Node) -> bool:
	# The camp sits on a coral hill. Large coral masses, ground patches and
	# mud banks intentionally intersect the trigger's bounding sphere; they
	# are visual-only and must not be counted as camp props blocking entry.
	var current := node
	while current != null:
		var name := String(current.name)
		if name.begins_with("coral_") or name.begins_with("mud_") or name.begins_with("ground_patch"):
			return true
		current = current.get_parent()
	return false
