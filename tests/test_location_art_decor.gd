extends GutTest
## Проверка переиспользуемого декора и того, что арт-проход не добавил
## игровых коллизий в фоновые силуэты.

const SETS := [
	"res://scenes/environment/nightmare/decor/mountain_silhouette_a.tscn",
	"res://scenes/environment/nightmare/decor/mountain_silhouette_b.tscn",
	"res://scenes/environment/nightmare/decor/ruin_watchtower_a.tscn",
	"res://scenes/environment/nightmare/decor/dead_tree_grove_a.tscn",
	"res://scenes/environment/nightmare/decor/camp_perimeter_a.tscn",
]
const LOCATIONS := {
	"caravan_road": "res://scenes/slice/locations/caravan_road_art.tscn",
	"caravan_site": "res://scenes/locations/caravan_site/caravan_site_art.tscn",
	"pilgrim_path": "res://scenes/locations/pilgrim_path/pilgrim_path_art.tscn",
	"shadow_sanctuary": "res://scenes/locations/shadow_sanctuary/shadow_sanctuary_art.tscn",
}


func test_decor_sets_are_reusable_and_have_no_collision() -> void:
	for path in SETS:
		var packed := load(path) as PackedScene
		assert_not_null(packed, "сцена должна загружаться: %s" % path)
		if packed == null:
			continue
		var instance := packed.instantiate() as Node3D
		add_child_autofree(instance)
		await wait_physics_frames(1)
		assert_true(instance.is_in_group(&"background_decor"), "набор помечен как фоновый декор")
		for body in instance.find_children("*", "StaticBody3D", true, false):
			assert_eq((body as StaticBody3D).collision_layer, 0, "декор не участвует в коллизиях")
		for shape in instance.find_children("*", "CollisionShape3D", true, false):
			assert_true((shape as CollisionShape3D).disabled, "формы декора отключены")


func test_dead_trees_have_ground_under_roots() -> void:
	for name in LOCATIONS:
		var packed := load(LOCATIONS[name]) as PackedScene
		if packed == null:
			continue
		var instance := packed.instantiate() as Node3D
		add_child_autofree(instance)
		await wait_physics_frames(2)
		var tree := instance.get_node_or_null("SeamsMidground/DeadTree") as Node3D
		assert_not_null(tree, "%s: один наземный силуэт дерева" % name)
		if tree == null:
			continue
		var box := AABB()
		var first := true
		for node in tree.find_children("*", "MeshInstance3D", true, false):
			var mesh := node as MeshInstance3D
			if mesh.mesh == null:
				continue
			var mesh_box := mesh.global_transform * mesh.get_aabb()
			box = mesh_box if first else box.merge(mesh_box)
			first = false
		assert_false(first, "%s: у дерева есть меш" % name)
		var root_xz := tree.global_position
		var from := Vector3(root_xz.x, box.position.y + 2.0, root_xz.z)
		var to := Vector3(root_xz.x, box.position.y - 8.0, root_xz.z)
		var query := PhysicsRayQueryParameters3D.create(from, to, 1 | 32)
		var hit := instance.get_world_3d().direct_space_state.intersect_ray(query)
		assert_false(hit.is_empty(), "%s: под корнем дерева есть пол" % name)
		if not hit.is_empty():
			assert_lt(absf(box.position.y - (hit.position as Vector3).y), 0.8,
				"%s: дерево не висит над полом" % name)


func test_locations_have_midground_clouds_and_fill_light() -> void:
	for name in LOCATIONS:
		var packed := load(LOCATIONS[name]) as PackedScene
		assert_not_null(packed, "сцена должна загружаться: %s" % name)
		if packed == null:
			continue
		var instance := packed.instantiate() as Node3D
		add_child_autofree(instance)
		await wait_physics_frames(1)
		assert_not_null(instance.get_node_or_null("SeamsMidground"), "%s: средний план" % name)
		var low_clouds := instance.get_node_or_null("Backdrop/LowClouds")
		if low_clouds == null:
			low_clouds = instance.get_node_or_null("Outside/LowClouds")
		assert_not_null(low_clouds, "%s: низкие облака" % name)
		assert_not_null(instance.get_node_or_null("RimLight"), "%s: заполняющий свет" % name)
