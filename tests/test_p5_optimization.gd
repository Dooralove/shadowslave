extends GutTest
## P5: park optimization guards. These test the authored optimization hooks,
## not GPU FPS (FPS is measured by tools/audit/p5_benchmark.gd in a real run).

const PARK := "res://scenes/slice/locations/park/park_street_art.tscn"
const TREE := "res://scenes/environment/park/island_tree.tscn"


func _spawn(path: String) -> Node3D:
	var scene := (load(path) as PackedScene).instantiate() as Node3D
	add_child_autofree(scene)
	return scene


func test_park_uses_joined_facade_assets() -> void:
	for name in ["facade_p2_stone", "facade_p2_balcony", "facade_p2_glass", "station_entrance_p2", "bus_shelter_p2"]:
		var path := "res://assets/environments/park/p2/p5/%s.glb" % name
		assert_true(FileAccess.file_exists(path), "%s: glTF-Transform join output exists" % name)
	var source := FileAccess.get_file_as_string("res://scenes/slice/locations/park/p2_park_set.tscn")
	assert_string_contains(source, "p2/p5/facade_p2_stone.glb", "P2 set uses joined stone facade")
	assert_string_contains(source, "p2/p5/station_entrance_p2.glb", "P2 set uses joined entrance")


func test_park_batches_repeated_props() -> void:
	var scene := _spawn(PARK)
	await wait_process_frames(2)
	assert_not_null(scene.get_node_or_null(^"P2/P5Batch"), "P5 batch controller")
	var batches := scene.find_children("*", "MultiMeshInstance3D", true, false)
	assert_gte(batches.size(), 3, "DistantCity and Upgrade groups are batched")
	assert_lte(batches.size(), 4, "hidden legacy groups are not batched")
	var tower := scene.get_node_or_null(^"P2/DistantCity/Tower00") as Node3D
	assert_not_null(tower, "authored distant tower remains available")
	if tower != null:
		assert_false(tower.visible, "original tower is hidden after batching")


func test_park_has_occluder_and_culling_enabled() -> void:
	var scene := _spawn(PARK)
	await wait_process_frames(1)
	var occluder := scene.get_node_or_null(^"P2/Occlusion/StationBack")
	assert_not_null(occluder, "station occluder")
	assert_true(occluder is OccluderInstance3D, "station occluder type")
	assert_true(bool(ProjectSettings.get_setting("rendering/occlusion_culling/use_occlusion_culling")),
		"occlusion culling project setting enabled")
	assert_true(bool(ProjectSettings.get_setting("rendering/textures/vram_compression/import_s3tc_bptc")),
		"VRAM texture compression enabled")


func test_park_tree_has_three_authored_lods() -> void:
	var tree := _spawn(TREE)
	for name in ["LOD0", "LOD1", "LOD2"]:
		assert_not_null(tree.get_node_or_null(NodePath(name)), "%s: tree LOD exists" % name)
	assert_not_null(tree.get_script(), "TreeLod controller attached")


func test_park_texture_import_is_vram_compressed() -> void:
	var import_path := "res://assets/environments/park/materials/textures/clean_asphalt_diff_1k.jpg.import"
	var file := FileAccess.open(import_path, FileAccess.READ)
	assert_not_null(file, import_path)
	if file == null:
		return
	var text := file.get_as_text()
	file.close()
	assert_string_contains(text, "vram_texture", "park texture imports as VRAM compressed")
	assert_string_contains(text, "s3tc_bptc", "park texture has S3TC/BPTC output")
