extends GutTest
## Механика «чутья»: Inspectable подсвечивает объект только в своём событии,
## снимает подсветку после выполнения и приглушает GuideBeacon, чтобы не
## дублировать ведение игрока.

const CARAVAN_SCENE := "res://scenes/locations/caravan_site/caravan_site.tscn"
const PILGRIM_SCENE := "res://scenes/locations/pilgrim_path/pilgrim_path.tscn"
const LARVA_SCENE := "res://scenes/enemies/larva_enemy.tscn"
const BEACON_SCENE := "res://scenes/guide/guide_beacon.tscn"


func before_each() -> void:
	NightmareRunState.reset()
	CampaignGuide.reset_campaign()


func after_each() -> void:
	NightmareRunState.reset()
	CampaignGuide.reset_campaign()


func _beat(id: String) -> BeatData:
	return load("res://resources/campaign/beats/%s.tres" % id) as BeatData


func _make_target() -> Node3D:
	var root := Node3D.new()
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	root.add_child(mesh)
	add_child_autofree(root)
	return root


func test_inspectable_applies_and_restores_outline() -> void:
	var root := _make_target()
	var data := InspectableData.new()
	data.id = &"test_outline"
	data.highlight_color = Color(0.7, 0.9, 1.0, 1.0)
	data.highlight_strength = 0.8
	data.auto_inspect = false
	var inspect := Inspectable.new()
	inspect.data = data
	root.add_child(inspect)
	await wait_process_frames(1)
	var mesh := root.get_child(0) as MeshInstance3D
	assert_null(mesh.material_overlay, "до чутья контур не наложен")

	inspect.set_active(true, true)
	assert_true(inspect.is_active())
	assert_not_null(mesh.material_overlay, "контур наложен")
	assert_eq(mesh.material_overlay, inspect.get_overlay_material())

	inspect.set_active(false, true)
	assert_false(inspect.is_active())
	assert_null(mesh.material_overlay, "после выключения исходный материал восстановлен")


func test_inspectable_only_active_in_its_beat_and_until_completed() -> void:
	var root := _make_target()
	var data := InspectableData.new()
	data.id = &"test_event"
	data.beat_id = &"N10"
	data.required_flags = [&"ready_for_sense"]
	data.completed_flag = &"sense_done"
	data.auto_inspect = false
	var inspect := Inspectable.new()
	inspect.data = data
	root.add_child(inspect)
	await wait_process_frames(1)

	CampaignGuide.apply_beat(_beat("n10"))
	assert_false(inspect.is_event_active(), "нужен обязательный флаг")
	NightmareRunState.set_flag(&"ready_for_sense")
	assert_true(inspect.is_event_active(), "в событии N10 подсветка доступна")

	CampaignGuide.apply_beat(_beat("n11"))
	assert_false(inspect.is_event_active(), "вне события подсветка выключена")

	CampaignGuide.apply_beat(_beat("n10"))
	NightmareRunState.set_flag(&"sense_done")
	assert_false(inspect.is_event_active(), "после выполнения подсветка снимается")


func test_completed_item_disables_highlight() -> void:
	var root := _make_target()
	var data := InspectableData.new()
	data.id = &"test_item"
	data.completed_item = &"key"
	data.auto_inspect = false
	var inspect := Inspectable.new()
	inspect.data = data
	root.add_child(inspect)
	await wait_process_frames(1)
	assert_true(inspect.is_event_active(), "пока ключ не взят, подсветка доступна")
	NightmareRunState.add_item(&"key", 1)
	assert_false(inspect.is_event_active(), "после подбора ключа подсветка снимается")


func test_inspectable_auto_activates_near_player_and_turns_off_after_leaving() -> void:
	var root := _make_target()
	var data := InspectableData.new()
	data.id = &"test_proximity"
	data.auto_inspect = true
	data.detection_radius = 3.0
	var inspect := Inspectable.new()
	inspect.data = data
	root.add_child(inspect)
	var player := Node3D.new()
	player.add_to_group(&"player")
	add_child_autofree(player)
	player.global_position = Vector3(0, 0, 1)
	await wait_physics_frames(2)
	assert_true(inspect.is_active(), "рядом с игроком подсветка включается")

	player.global_position = Vector3(0, 0, 20)
	await wait_physics_frames(2)
	assert_false(inspect.is_active(), "при уходе подсветка выключается")


func test_inspectable_suppresses_matching_guide_beacon() -> void:
	var beacon := (load(BEACON_SCENE) as PackedScene).instantiate() as GuideBeacon
	beacon.beacon_id = &"cave"
	add_child_autofree(beacon)
	beacon.set_enabled(true, true)
	var root := _make_target()
	var data := InspectableData.new()
	data.id = &"test_suppression"
	data.suppress_beacon_id = &"cave"
	data.auto_inspect = false
	var inspect := Inspectable.new()
	inspect.data = data
	root.add_child(inspect)
	inspect.set_active(true, true)
	assert_true(beacon.is_sense_suppressed(), "чутьё гасит ведущий маяк")
	assert_false((beacon.get_node("Light") as OmniLight3D).visible)

	inspect.set_active(false, true)
	assert_false(beacon.is_sense_suppressed(), "после чутья маяк снова доступен")


func test_inspectable_nodes_are_placed_in_scenes() -> void:
	var caravan := (load(CARAVAN_SCENE) as PackedScene).instantiate()
	add_child_autofree(caravan)
	await wait_physics_frames(1)
	var wedges := caravan.get_node_or_null("Props/Wagon/Inspectable") as Inspectable
	var key := caravan.get_node_or_null("Props/Key/Inspectable") as Inspectable
	var chain := caravan.get_node_or_null("Props/BrokenChain/Inspectable") as Inspectable
	var shackles := caravan.get_node_or_null("Props/BrokenChain/InspectableShackles") as Inspectable
	assert_not_null(wedges)
	assert_not_null(key)
	assert_not_null(chain, "цепь находится через чутьё")
	assert_not_null(shackles, "кандалы находятся через чутьё")
	assert_eq(wedges.data.id, &"inspect_wagon_wedges")
	assert_eq(key.data.id, &"inspect_key")
	assert_eq(chain.data.id, &"inspect_chain")
	assert_eq(shackles.data.id, &"inspect_shackles")
	assert_eq(wedges.get_targets().size(), 2, "подсвечиваются оба клина")
	wedges.set_active(true, true)
	var wedge_mesh := wedges.get_targets()[0] as GeometryInstance3D
	assert_not_null(wedge_mesh.material_overlay, "контур накладывается на CSG-клин")
	wedges.set_active(false, true)
	assert_null(wedge_mesh.material_overlay, "контур снимается с CSG-клина")

	var pilgrim := (load(PILGRIM_SCENE) as PackedScene).instantiate()
	add_child_autofree(pilgrim)
	await wait_physics_frames(1)
	assert_not_null(pilgrim.get_node_or_null("Props/BloodStain/Inspectable") as Inspectable)
	assert_not_null(pilgrim.get_node_or_null("Props/Tracks/Inspectable") as Inspectable)

	var larva := (load(LARVA_SCENE) as PackedScene).instantiate()
	add_child_autofree(larva)
	var weak := larva.get_node_or_null("Visual/Model/WeakSpot/Inspectable") as Inspectable
	assert_not_null(weak)
	assert_eq(weak.data.id, &"inspect_weak_spot")
	assert_true(weak.is_event_active(), "слабое место видно у живого врага")
	(larva as TestEnemy).health.take_damage(9999.0)
	assert_false(weak.is_event_active(), "после смерти врага слабое место больше не подсвечивается")


func test_all_inspectable_resources_are_valid_and_have_thoughts() -> void:
	for path in [
		"res://resources/inspect/inspect_wagon_wedges.tres",
		"res://resources/inspect/inspect_key.tres",
		"res://resources/inspect/inspect_blood.tres",
		"res://resources/inspect/inspect_tracks.tres",
		"res://resources/inspect/inspect_weak_spot.tres",
	]:
		var data := load(path) as InspectableData
		assert_not_null(data, path)
		if data != null:
			assert_true(data.is_valid())
			if data.thought_id != &"":
				assert_not_null(CampaignGuide.get_thought(data.thought_id), "мысль %s существует" % data.thought_id)
