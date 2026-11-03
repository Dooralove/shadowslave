class_name ParkBatch
extends Node3D
## P5: batch repeated static park props into MultiMesh instances.
## The originals stay in the scene (hidden) so authored node paths and
## collision/debug inspection remain available; only rendering is batched.

@export var batch_roots: Array[NodePath] = []


func _ready() -> void:
	for path in batch_roots:
		var root := get_node_or_null(path) as Node3D
		if root != null:
			_batch_root(root)


func _batch_root(root: Node3D) -> void:
	var groups := {}
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance == null or not mesh_instance.is_visible_in_tree() or mesh_instance.mesh == null:
			continue
		var key := _key(mesh_instance)
		if not groups.has(key):
			groups[key] = []
		groups[key].append(mesh_instance)

	var serial := 0
	for key in groups:
		var meshes: Array = groups[key]
		if meshes.size() < 3:
			continue
		var source: MeshInstance3D = meshes[0]
		var batch := MultiMesh.new()
		batch.transform_format = MultiMesh.TRANSFORM_3D
		batch.mesh = source.mesh
		batch.instance_count = meshes.size()
		var inverse := root.global_transform.affine_inverse()
		var bounds := AABB()
		for i in meshes.size():
			var mesh_instance: MeshInstance3D = meshes[i]
			batch.set_instance_transform(i, inverse * mesh_instance.global_transform)
			var local_bounds := _local_aabb(mesh_instance, inverse)
			bounds = local_bounds if i == 0 else bounds.merge(local_bounds)
			mesh_instance.visible = false
		bounds = bounds.grow(0.25)
		batch.custom_aabb = bounds
		var instance := MultiMeshInstance3D.new()
		instance.name = "P5Batch_%d" % serial
		serial += 1
		instance.multimesh = batch
		instance.material_override = source.material_override
		instance.material_overlay = source.material_overlay
		instance.cast_shadow = source.cast_shadow
		instance.layers = source.layers
		instance.gi_mode = source.gi_mode
		instance.custom_aabb = bounds
		root.add_child(instance)
		instance.global_transform = root.global_transform


func _key(mesh_instance: MeshInstance3D) -> String:
	var material := mesh_instance.material_override
	var material_key := material.resource_path if material != null else "<mesh>"
	var overlay := mesh_instance.material_overlay
	var overlay_key := overlay.resource_path if overlay != null else "<none>"
	return "%s|%s|%s" % [mesh_instance.mesh.get_instance_id(), material_key, overlay_key]


func _local_aabb(mesh_instance: MeshInstance3D, inverse: Transform3D) -> AABB:
	var mesh_aabb := mesh_instance.get_aabb()
	var local_transform := inverse * mesh_instance.global_transform
	var points := [
		mesh_aabb.position,
		mesh_aabb.position + Vector3(mesh_aabb.size.x, 0, 0),
		mesh_aabb.position + Vector3(0, mesh_aabb.size.y, 0),
		mesh_aabb.position + Vector3(0, 0, mesh_aabb.size.z),
		mesh_aabb.position + Vector3(mesh_aabb.size.x, mesh_aabb.size.y, 0),
		mesh_aabb.position + Vector3(mesh_aabb.size.x, 0, mesh_aabb.size.z),
		mesh_aabb.position + Vector3(0, mesh_aabb.size.y, mesh_aabb.size.z),
		mesh_aabb.position + mesh_aabb.size,
	]
	var min_point := Vector3.INF
	var max_point := -Vector3.INF
	for point in points:
		var transformed: Vector3 = local_transform * point
		min_point = min_point.min(transformed)
		max_point = max_point.max(transformed)
	return AABB(min_point, max_point - min_point)
