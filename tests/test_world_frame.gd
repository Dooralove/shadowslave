extends GutTest
## Structural checks for the WorldFrame distant-geometry kit.
##
## The kit is visual-only. These tests protect the two invariants that matter
## for gameplay and performance: it never creates collision/lights, and its
## generators return non-empty, tagged geometry.

const WorldFrameScript := preload("res://scripts/world/world_frame.gd")


func test_ridge_ring_is_mesh_and_tagged() -> void:
	var root := Node3D.new()
	add_child_autofree(root)
	var ring := WorldFrameScript.ridge_ring(
		Vector3.ZERO,
		500.0,
		32,
		-5.0,
		10.0,
		40.0,
		Color(0.7, 0.7, 0.7),
		Color(0.4, 0.4, 0.4),
		Color(0.4, 0.4, 0.4),
		Color(0.2, 0.2, 0.2),
		7
	)
	root.add_child(ring)
	assert_true(ring.has_meta(&"world_frame"), "ridge ring is tagged")
	assert_not_null(ring.mesh, "ridge ring has a mesh")
	assert_eq(ring.mesh.get_surface_count(), 1, "ridge ring is one surface")
	assert_gt(ring.get_aabb().size.x, 0.0, "ridge ring has a non-empty AABB")
	assert_eq(ring.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "ridge ring casts no shadows")


func test_far_sea_uses_shader_material() -> void:
	var root := Node3D.new()
	add_child_autofree(root)
	var sea := WorldFrameScript.far_sea(Vector3.ZERO, 1000.0, Color.BLACK, Color.GRAY)
	root.add_child(sea)
	assert_true(sea.has_meta(&"world_frame"), "far sea is tagged")
	assert_true(sea.material_override is ShaderMaterial, "far sea uses a shader material")
	assert_eq(sea.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "far sea casts no shadows")


func test_city_skyline_is_multimesh() -> void:
	var root := Node3D.new()
	add_child_autofree(root)
	var skyline := WorldFrameScript.city_skyline(
		root,
		Vector3.ZERO,
		0.0,
		60.0,
		160.0,
		12,
		8.0,
		30.0,
		[Color(0.1, 0.1, 0.1), Color(0.15, 0.15, 0.15)],
		11,
		0.0,
		0.0,
		"TestSkyline"
	)
	assert_true(skyline.has_meta(&"world_frame"), "skyline is tagged")
	assert_not_null(skyline.multimesh, "skyline has a multimesh")
	assert_eq(skyline.multimesh.instance_count, 12, "all requested blocks are placed without a gap")
	assert_eq(skyline.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "skyline casts no shadows")


func test_spire_and_reef_bands_are_non_empty() -> void:
	var root := Node3D.new()
	add_child_autofree(root)
	var spires := WorldFrameScript.spire_cluster(
		root, Vector3.ZERO, 0.0, 40.0, 4,
		Color(0.1, 0.1, 0.1), Color(0.3, 0.3, 0.3), 0.4, 3, "TestSpires", 12.0
	)
	assert_true(spires.has_meta(&"world_frame"), "spire cluster is tagged")
	assert_eq(spires.get_child_count(), 1, "spire cluster is one MultiMesh child")
	var spires_mesh := spires.get_child(0) as MultiMeshInstance3D
	assert_not_null(spires_mesh, "spire cluster child is a MultiMeshInstance3D")
	if spires_mesh != null:
		assert_eq(spires_mesh.multimesh.instance_count, 4, "spire cluster has the requested spikes")
	var band := WorldFrameScript.reef_band(
		root, Vector3.ZERO, 0.0, 100.0, 200.0, 24, 4.0, 16.0,
		Color(0.1, 0.1, 0.1), Color(0.3, 0.3, 0.3), 0.4, 5, "TestBand"
	)
	assert_true(band.has_meta(&"world_frame"), "reef band is tagged")
	assert_not_null(band.multimesh, "reef band has a multimesh")
	assert_gt(band.multimesh.instance_count, 0, "reef band places at least one instance")


func test_blocks_and_fins_have_meshes() -> void:
	var root := Node3D.new()
	add_child_autofree(root)
	var block := WorldFrameScript.mass_block(
		root, Vector3.ZERO, Vector3(10, 20, 10),
		Color(0.1, 0.1, 0.1), Color(0.3, 0.3, 0.3), 0.3, "TestBlock"
	)
	assert_not_null(block.mesh, "mass block has a mesh")
	var fin := WorldFrameScript.water_fin(
		root, Vector3.ZERO, 20.0, 10.0, 4.0,
		Color(0.1, 0.1, 0.1), Color(0.3, 0.3, 0.3), 0.3, "TestFin"
	)
	assert_not_null(fin.mesh, "water fin has a mesh")


func test_kit_adds_no_collision_or_lights() -> void:
	var root := Node3D.new()
	add_child_autofree(root)
	var ring := WorldFrameScript.ridge_ring(Vector3.ZERO, 300.0, 24, -5.0, 8.0, 30.0,
		Color(0.7, 0.7, 0.7), Color(0.4, 0.4, 0.4),
		Color(0.4, 0.4, 0.4), Color(0.2, 0.2, 0.2), 9)
	root.add_child(ring)
	var sea := WorldFrameScript.far_sea(Vector3.ZERO, 800.0, Color.BLACK, Color.GRAY)
	root.add_child(sea)
	WorldFrameScript.city_skyline(root, Vector3.ZERO, 0.0, 40.0, 90.0, 6, 5.0, 20.0,
		[Color(0.1, 0.1, 0.1)], 2, 0.0, 0.0, "NoCollisionCity")
	WorldFrameScript.spire_cluster(root, Vector3.ZERO, 0.0, 30.0, 3,
		Color(0.1, 0.1, 0.1), Color(0.3, 0.3, 0.3), 0.3, 4, "NoCollisionSpires", 8.0)
	WorldFrameScript.reef_band(root, Vector3.ZERO, 0.0, 80.0, 120.0, 12, 3.0, 12.0,
		Color(0.1, 0.1, 0.1), Color(0.3, 0.3, 0.3), 0.3, 6, "NoCollisionBand")
	WorldFrameScript.mass_block(root, Vector3.ZERO, Vector3(5, 5, 5),
		Color(0.1, 0.1, 0.1), Color(0.3, 0.3, 0.3), 0.3, "NoCollisionBlock")
	WorldFrameScript.water_fin(root, Vector3.ZERO, 10.0, 5.0, 2.0,
		Color(0.1, 0.1, 0.1), Color(0.3, 0.3, 0.3), 0.3, "NoCollisionFin")

	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		assert_false(node is CollisionObject3D or node is CollisionShape3D,
			"WorldFrame must not create collision: %s" % node.get_path())
		assert_false(node is Light3D, "WorldFrame must not create lights: %s" % node.get_path())
		for child in node.get_children():
			stack.append(child)
