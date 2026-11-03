extends GutTest
## Smoke tests for the Labyrinth placeholder audio map.

const LABYRINTH_AUDIO := "res://scripts/locations/forgotten_shore_labyrinth/labyrinth_audio.gd"


func test_all_eighteen_zones_have_audio_definitions() -> void:
	var zones := AudioLibrary.ambience_zones()
	var audio := LabyrinthAudio.new()
	add_child_autofree(audio)
	for zone in audio.get_zone_definitions():
		assert_true(zones.has(zone["id"]), "ambience exists for %s" % zone["id"])
		assert_ne(zone["reverb_profile"], &"", "reverb profile exists for %s" % zone["id"])
	assert_eq(audio.get_zone_definitions().size(), 18)
	var reverb_count := 0
	for child in audio.get_children():
		if child is ReverbZone:
			reverb_count += 1
	assert_eq(reverb_count, 18, "all zones have a reverb area")


func test_zone_lookup_uses_xz_rectangles() -> void:
	var audio := LabyrinthAudio.new()
	add_child_autofree(audio)
	assert_eq(audio._zone_at(Vector3(28, 0, 0)), &"labyrinth_z01")
	assert_eq(audio._zone_at(Vector3(19, -1.5, 26)), &"labyrinth_z02")
	assert_eq(audio._zone_at(Vector3(-105, 18, -5)), &"labyrinth_z10")
	assert_eq(audio._zone_at(Vector3(-700, 18, -20)), &"labyrinth_z15")
	assert_eq(audio._zone_at(Vector3(-1400, 35, 0)), &"labyrinth_z18")
	assert_eq(audio._zone_at(Vector3(1000, 0, 1000)), &"labyrinth")


func test_labyrinth_and_pilgrim_music_cues_exist() -> void:
	var cues := AudioLibrary.music_cues()
	assert_true(cues.has(&"labyrinth"))
	assert_true(cues.has(&"pilgrim"))
	assert_gt((cues[&"labyrinth"] as MusicCue).layers.size(), 0)
	assert_gt((cues[&"pilgrim"] as MusicCue).layers.size(), 0)


func test_labyrinth_detail_sfx_exist() -> void:
	var cues := AudioLibrary.sfx_cues()
	for id in [&"world_tide_surge", &"world_storm_rumble", &"world_bone_creak", &"world_coral_groan", &"world_silver_bell", &"world_whip"]:
		assert_true(cues.has(id), "SFX exists for %s" % id)


func test_labyrinth_material_maps_to_footstep_surface() -> void:
	var greybox := LabyrinthGreybox.new()
	assert_eq(greybox._surface_for_material(&"mud"), &"mud")
	assert_eq(greybox._surface_for_material(&"bone"), &"bone")
	assert_eq(greybox._surface_for_material(&"coral_pale"), &"coral")
	assert_eq(greybox._surface_for_material(&"wood_dark"), &"wood")
	assert_eq(greybox._surface_for_material(&"statue"), &"stone")
	greybox.free()


func test_reverb_presets_switch_on_reverb_bus() -> void:
	var director := get_node_or_null(^"/root/AudioDirector")
	assert_not_null(director)
	director.call(&"set_reverb_profile", &"tunnel")
	assert_eq(director.call(&"get_reverb_profile"), &"tunnel")
	var index := AudioServer.get_bus_index(&"Reverb")
	var effect := AudioServer.get_bus_effect(index, 0) as AudioEffectReverb
	assert_not_null(effect)
	assert_almost_eq(effect.room_size, 0.8, 0.001)
	director.call(&"push_reverb_profile", &"tunnel")
	assert_eq(director.call(&"get_reverb_profile"), &"tunnel")
	director.call(&"pop_reverb_profile", &"tunnel")
	assert_eq(director.call(&"get_reverb_profile"), &"outdoor")
	director.call(&"set_reverb_profile", &"coral_cave")
