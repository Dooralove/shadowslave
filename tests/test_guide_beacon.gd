extends GutTest
## GuideBeacon: переиспользуемый маяк включается только для текущего события
## и гаснет после смены цели. Эталон — тропа паломников.

const LOCATION_SCENE := "res://scenes/locations/pilgrim_path/pilgrim_path.tscn"
const BEACON_SCENE := "res://scenes/guide/guide_beacon.tscn"


func _beat(id: String) -> BeatData:
	return load("res://resources/campaign/beats/%s.tres" % id) as BeatData


func test_beacon_component_has_light_ring_beam_and_tracks() -> void:
	var beacon := (load(BEACON_SCENE) as PackedScene).instantiate() as GuideBeacon
	add_child_autofree(beacon)
	await wait_process_frames(1)
	assert_not_null(beacon.get_node_or_null("Light") as OmniLight3D, "маяк даёт мягкий свет")
	assert_not_null(beacon.get_node_or_null("Ring") as MeshInstance3D, "у маяка есть кольцо на земле")
	assert_not_null(beacon.get_node_or_null("Beam") as MeshInstance3D, "у маяка есть луч")
	assert_not_null(beacon.get_node_or_null("Track00") as MeshInstance3D, "маяк оставляет следы")

	beacon.set_enabled(true, true)
	assert_true(beacon.is_active())
	assert_eq(beacon.get_opacity(), 1.0)
	assert_true((beacon.get_node("Light") as OmniLight3D).visible)

	beacon.set_enabled(false, true)
	assert_false(beacon.is_active())
	assert_eq(beacon.get_opacity(), 0.0)
	assert_false((beacon.get_node("Light") as OmniLight3D).visible)


func test_art_trail_inherits_the_same_beacon_set() -> void:
	var site := (load("res://scenes/locations/pilgrim_path/pilgrim_path_art.tscn") as PackedScene).instantiate() as PilgrimPath
	add_child_autofree(site)
	await wait_physics_frames(1)
	assert_not_null(site.get_guide_beacon(&"gap"), "арт-вариант наследует маяки базовой тропы")
	site.apply_guide_beat(_beat("n16"))
	assert_true(site.get_guide_beacon(&"alcove").is_active(), "арт-тропа ведёт к алькову на N16")
	assert_false(site.get_guide_beacon(&"gap").is_active())


func test_pilgrim_trail_enables_only_the_current_objective_beacon() -> void:
	var site := (load(LOCATION_SCENE) as PackedScene).instantiate() as PilgrimPath
	add_child_autofree(site)
	await wait_physics_frames(1)
	for id in [&"gap", &"sword", &"alcove", &"dawn", &"cave", &"hero", &"bell", &"temple"]:
		assert_not_null(site.get_guide_beacon(id), "маяк %s стоит на тропе" % id)

	site.apply_guide_beat(_beat("n14"))
	assert_true(site.get_guide_beacon(&"gap").is_active(), "N14 ведёт к провалу")
	assert_false(site.get_guide_beacon(&"sword").is_active(), "старый маяк выключен")

	site.apply_guide_beat(_beat("n15"))
	assert_false(site.get_guide_beacon(&"gap").is_active())
	assert_true(site.get_guide_beacon(&"sword").is_active(), "N15 ведёт к камню с мечом")

	site.apply_guide_beat(_beat("n24"))
	for id in [&"gap", &"sword", &"alcove", &"dawn", &"cave", &"hero", &"bell", &"temple"]:
		assert_false(site.get_guide_beacon(id).is_active(), "без цели маяки не горят")
