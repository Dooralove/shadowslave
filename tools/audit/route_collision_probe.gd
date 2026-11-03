extends SceneTree
## Read-only probe: list colliders near route failure points.
##   godot --headless --path . -s tools/audit/route_collision_probe.gd -- \
##     --scene=res://scenes/locations/forgotten_shore_labyrinth/labyrinth_first_fragment.tscn

var _scene_path := "res://scenes/locations/forgotten_shore_labyrinth/labyrinth_first_fragment.tscn"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--scene="):
			_scene_path = arg.trim_prefix("--scene=")
	var scene := (load(_scene_path) as PackedScene).instantiate()
	root.add_child(scene)
	for i in 6:
		await physics_frame
	var runtime := scene.get_node_or_null(^"Gameplay/Runtime")
	if runtime != null:
		for child in runtime.get_children():
			if child is CollisionObject3D or child is CharacterBody3D:
				child.queue_free()
		await physics_frame
	var space := root.world_3d.direct_space_state
	for entry in [
		["z08_z09", Vector3(-68.0, 0.2, 20.0)],
		["z08_z09_target", Vector3(-70.0, 0.2, 20.0)],
		["z14_low_west", Vector3(-597.5, 2.0, 18.0)],
		["z14_stuck", Vector3(-588.8, 2.0, 18.0)],
		["z14_low_west_ahead", Vector3(-600.0, 2.0, 18.0)],
		["z14_low_west_far", Vector3(-640.0, 2.0, 18.0)],
	]:
		var shape := CapsuleShape3D.new()
		shape.radius = 0.36
		shape.height = 1.8
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = shape
		query.transform = Transform3D(Basis(), entry[1])
		query.collision_mask = 1 | 32
		query.collide_with_areas = false
		var hits := space.intersect_shape(query, 24)
		print("PROBE ", entry[0], " at ", entry[1], " hits=", hits.size())
		for hit in hits:
			var collider := hit.get("collider") as Node
			if collider == null:
				continue
			print("  HIT ", collider.get_path(), " class=", collider.get_class(), " pos=", (collider as Node3D).global_position if collider is Node3D else "?")
			for child in collider.get_children():
				if child is CollisionShape3D:
					var shape_node := child as CollisionShape3D
					if shape_node.shape is BoxShape3D:
						print("    BOX size=", (shape_node.shape as BoxShape3D).size, " shape_pos=", shape_node.position, " shape_rot=", shape_node.rotation)
					else:
						print("    SHAPE ", shape_node.shape.get_class(), " pos=", shape_node.position)
	quit(0)
