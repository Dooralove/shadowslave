extends GutTest
## Smoke tests for the audio foundation: buses, library, settings, surface map.

const EXPECTED_BUSES := [&"Master", &"Music", &"Ambience", &"SFX", &"Voice", &"UI", &"Reverb"]


func after_each() -> void:
	var director := get_node_or_null(^"/root/AudioDirector")
	if director != null:
		if director.has_method(&"apply_pause_policy"):
			director.call(&"apply_pause_policy", false)
		if director.has_method(&"stop_all"):
			director.call(&"stop_all")
	AudioLibrary.force_playback_for_tests = false


func test_audio_buses_exist() -> void:
	for bus_name in EXPECTED_BUSES:
		assert_ne(AudioServer.get_bus_index(bus_name), -1, "bus %s exists" % bus_name)


func test_master_bus_has_compressor_limiter_and_meter_target() -> void:
	var master := AudioServer.get_bus_index(&"Master")
	var has_compressor := false
	var has_limiter := false
	var has_capture := false
	for effect_index in AudioServer.get_bus_effect_count(master):
		var effect := AudioServer.get_bus_effect(master, effect_index)
		has_compressor = has_compressor or effect is AudioEffectCompressor
		has_limiter = has_limiter or effect is AudioEffectLimiter
		has_capture = has_capture or effect is AudioEffectCapture
	assert_true(has_compressor, "Master compressor")
	assert_true(has_limiter, "Master limiter")
	assert_true(has_capture, "Master loudness capture")
	assert_almost_eq(float(AudioDirector.get_target_lufs()), -18.0, 0.001)


func test_bus_routing_uses_reverb_send() -> void:
	assert_eq(AudioServer.get_bus_send(AudioServer.get_bus_index(&"Music")), &"Reverb")
	assert_eq(AudioServer.get_bus_send(AudioServer.get_bus_index(&"Ambience")), &"Reverb")
	assert_eq(AudioServer.get_bus_send(AudioServer.get_bus_index(&"SFX")), &"Master")
	assert_gt(AudioServer.get_bus_effect_count(AudioServer.get_bus_index(&"Reverb")), 0)


func test_audio_director_autoload_exists() -> void:
	var director := get_node_or_null(^"/root/AudioDirector")
	assert_not_null(director, "AudioDirector autoload exists")
	assert_not_null(director.get("music"), "MusicDirector exists")
	assert_not_null(director.get("ambience"), "AmbienceDirector exists")
	assert_not_null(director.get("sfx"), "SfxPool exists")
	assert_not_null(director.get("voice"), "VoiceDirector exists")
	assert_not_null(director.get("_caption_overlay"), "caption overlay exists")


func test_pause_policy_keeps_ui_and_pauses_gameplay() -> void:
	AudioLibrary.force_playback_for_tests = true
	var director := get_node(^"/root/AudioDirector")
	director.call(&"stop_all")
	var sfx := director.get("sfx") as SfxPool
	sfx.get("_last_played").clear()
	director.call(&"play_sfx", &"combat_hit_flesh", Vector3.ZERO)
	director.call(&"play_voice", &"sip_1_000")
	await get_tree().process_frame
	var players_3d := sfx.get("_players_3d") as Array
	var players_ui := sfx.get("_players_ui") as Array
	var active: AudioStreamPlayer3D = null
	for player in players_3d:
		if player.playing:
			active = player
			break
	var voice_player := director.get("voice").get("_player") as AudioStreamPlayer
	director.apply_pause_policy(true)
	assert_not_null(active, "a 3D SFX is active")
	if active == null:
		director.apply_pause_policy(false)
		AudioLibrary.force_playback_for_tests = false
		return
	assert_true(active.stream_paused, "3D SFX pauses")
	assert_false((players_ui[0] as AudioStreamPlayer).stream_paused, "UI keeps playing")
	assert_true(voice_player.stream_paused, "voice pauses")
	director.apply_pause_policy(false)
	assert_false(active.stream_paused, "3D SFX resumes")
	AudioLibrary.force_playback_for_tests = false


func test_captions_emit_only_when_enabled() -> void:
	var director := get_node(^"/root/AudioDirector")
	var received: Array[String] = []
	var receiver := func(text: String) -> void:
		received.append(text)
	director.caption_requested.connect(receiver)
	var cue := SfxCue.new()
	cue.caption = "Test caption"
	director.apply_accessibility(true, false, GameSettings.DYNAMIC_RANGE_FULL)
	director._on_sfx_started(cue)
	director.apply_accessibility(false, false, GameSettings.DYNAMIC_RANGE_FULL)
	director._on_sfx_started(cue)
	director.caption_requested.disconnect(receiver)
	director.apply_accessibility(true, false, GameSettings.DYNAMIC_RANGE_FULL)
	assert_eq(received, ["Test caption"])


func test_accessibility_applies_mono_and_reduced_dynamic_range() -> void:
	var director := get_node(^"/root/AudioDirector")
	director.apply_accessibility(true, true, GameSettings.DYNAMIC_RANGE_REDUCED)
	assert_not_null(director.get("_mono_effect"), "mono effect is installed")
	assert_almost_eq(float(director.get("_compressor").threshold), -26.0, 0.01)
	director.apply_accessibility(true, false, GameSettings.DYNAMIC_RANGE_FULL)
	assert_null(director.get("_mono_effect"), "mono effect is removed")
	assert_almost_eq(float(director.get("_compressor").threshold), -18.0, 0.01)


func test_extended_audio_settings_roundtrip() -> void:
	var path := "user://test_audio_settings.cfg"
	var settings := GameSettings.new(path)
	assert_almost_eq(settings.ambience_volume, GameSettings.DEFAULT_AMBIENCE_VOLUME, 0.001)
	assert_almost_eq(settings.voice_volume, GameSettings.DEFAULT_VOICE_VOLUME, 0.001)
	assert_almost_eq(settings.ui_volume, GameSettings.DEFAULT_UI_VOLUME, 0.001)
	settings.ambience_volume = 0.42
	settings.voice_volume = 0.64
	settings.ui_volume = 0.31
	settings.captions_enabled = false
	settings.mono_downmix = true
	settings.dynamic_range = GameSettings.DYNAMIC_RANGE_REDUCED
	settings.save_settings()
	var loaded := GameSettings.new(path)
	loaded.load_settings()
	assert_almost_eq(loaded.ambience_volume, 0.42, 0.001)
	assert_almost_eq(loaded.voice_volume, 0.64, 0.001)
	assert_almost_eq(loaded.ui_volume, 0.31, 0.001)
	assert_false(loaded.captions_enabled)
	assert_true(loaded.mono_downmix)
	assert_eq(loaded.dynamic_range, GameSettings.DYNAMIC_RANGE_REDUCED)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_legacy_audio_config_gets_new_channel_defaults() -> void:
	var path := "user://test_legacy_audio.cfg"
	var config := ConfigFile.new()
	config.set_value("meta", "version", 1)
	config.set_value("audio", "master", 0.5)
	config.set_value("audio", "music", 0.4)
	config.set_value("audio", "sfx", 0.3)
	config.save(path)
	var settings := GameSettings.new(path)
	assert_true(settings.load_settings())
	assert_almost_eq(settings.master_volume, 0.5, 0.001)
	assert_almost_eq(settings.ambience_volume, GameSettings.DEFAULT_AMBIENCE_VOLUME, 0.001)
	assert_almost_eq(settings.voice_volume, GameSettings.DEFAULT_VOICE_VOLUME, 0.001)
	assert_almost_eq(settings.ui_volume, GameSettings.DEFAULT_UI_VOLUME, 0.001)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_library_has_music_and_sfx() -> void:
	var music := AudioLibrary.music_cues()
	var sfx := AudioLibrary.sfx_cues()
	var zones := AudioLibrary.ambience_zones()
	assert_true(is_same(music, AudioLibrary.music_cues()), "music library is cached")
	assert_true(is_same(sfx, AudioLibrary.sfx_cues()), "SFX library is cached")
	assert_true(is_same(zones, AudioLibrary.ambience_zones()), "ambience library is cached")
	assert_gte(music.size(), 14, "typed music table includes base + demo storm cue")
	assert_gte(sfx.size(), 61, "typed SFX table includes base + demo cues")
	assert_gte(zones.size(), 29, "typed ambience table includes all zones")
	assert_true(music.has(&"menu"), "menu cue exists")
	assert_true(music.has(&"caravan"), "caravan cue exists")
	assert_true(music.has(&"finale"), "finale cue exists")
	assert_true(music.has(&"labyrinth_storm"), "demo storm cue exists")
	for cue_id in [&"menu", &"park", &"caravan", &"camp", &"sanctuary", &"labyrinth", &"pilgrim", &"finale"]:
		var cue := music[cue_id] as MusicCue
		assert_gte(cue.layers.size(), 3, "%s has 3 music layers" % cue_id)
		for layer in cue.layers:
			assert_not_null(layer.stream, "%s layer has a stream" % cue_id)
	assert_true(sfx.has(&"footstep_stone"), "stone footstep cue exists")
	assert_true(sfx.has(&"combat_hit_flesh"), "flesh hit cue exists")
	assert_true(sfx.has(&"world_ritual_offering"), "ritual cue exists")
	assert_eq((sfx[&"world_ritual_offering"] as SfxCue).caption, "Ритуал")
	assert_true(zones.has(&"park"), "park ambience exists")
	assert_true(zones.has(&"caravan"), "caravan ambience exists")


func test_all_sfx_cues_have_streams() -> void:
	for cue_id in AudioLibrary.sfx_cues():
		var cue: SfxCue = AudioLibrary.sfx_cues()[cue_id]
		assert_gt(cue.streams.size(), 0, "%s has at least one stream" % cue_id)


func test_surface_names_map_to_known_cues() -> void:
	var detector := SurfaceDetector.new()
	add_child_autofree(detector)
	assert_eq(detector._surface_from_name("SnowPackedFloor"), &"snow_packed")
	assert_eq(detector._surface_from_name("SoftSnowDrift"), &"snow_soft")
	assert_eq(detector._surface_from_name("IcePatch"), &"ice")
	assert_eq(detector._surface_from_name("FrozenLake"), &"ice")
	assert_eq(detector._surface_from_name("OfficeFloor"), &"")
	assert_eq(detector._surface_from_name("PoliceStation"), &"")
	assert_eq(detector._surface_from_name("BoneBridge"), &"bone")
	assert_eq(detector._surface_from_name("MudPool"), &"mud")
	assert_eq(detector._surface_from_name("WagonWood"), &"wood")
	assert_eq(detector._surface_from_name("MetalGrate"), &"metal")
	assert_eq(detector._surface_from_name("TempleMarble"), &"stone")
	assert_eq(detector._surface_from_name("CoralShelf"), &"coral")


func test_voice_manifest_is_import_table_only() -> void:
	var file := FileAccess.open("res://resources/audio/voice_manifest.json", FileAccess.READ)
	assert_not_null(file)
	var data: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	assert_true(data is Dictionary)
	assert_eq(int(data["counts"]["total"]), int(data["counts"]["lines"]) + int(data["counts"]["barks"]))
	assert_gt(int(data["counts"]["lines"]), 200)


func test_main_menu_exposes_new_audio_sliders() -> void:
	var menu := (load("res://scenes/ui/main_menu/main_menu.tscn") as PackedScene).instantiate()
	add_child_autofree(menu)
	await get_tree().process_frame
	for node_name in ["AmbienceSlider", "VoiceSlider", "UiSlider", "CaptionsCheck", "MonoCheck", "DynamicRangeOption"]:
		assert_not_null(menu.find_child(node_name, true, false), "%s exists" % node_name)
	assert_true(menu.has_method(&"_on_button_hovered"), "menu wires hover/focus sound")
	assert_true(AudioLibrary.sfx_cues().has(&"ui_hover"), "hover cue exists")


func test_sunny_scene_has_surface_detector() -> void:
	var scene := (load("res://scenes/characters/sunny.tscn") as PackedScene).instantiate()
	add_child_autofree(scene)
	await get_tree().process_frame
	assert_not_null(scene.get_node_or_null(^"SurfaceDetector"))


func test_ambience_duck_has_release_path() -> void:
	var ambience := AmbienceDirector.new()
	add_child_autofree(ambience)
	ambience.play_zone(&"menu", 0.0)
	await get_tree().process_frame
	ambience.duck(-4.0, 60.0)
	assert_almost_eq(float(ambience.get("_duck_db")), -4.0, 0.001)
	ambience.release_duck(0.0)
	assert_almost_eq(float(ambience.get("_duck_db")), 0.0, 0.001)


func test_ambience_randomizer_gets_zone_details() -> void:
	var ambience := AmbienceDirector.new()
	add_child_autofree(ambience)
	ambience.play_zone(&"labyrinth_z04", 0.0)
	await get_tree().process_frame
	var detail := ambience.get("_detail") as AudioStreamPlayer
	assert_not_null(detail)
	assert_true(detail.stream is AudioStreamRandomizer, "detail uses AudioStreamRandomizer")
	var randomizer := detail.stream as AudioStreamRandomizer
	assert_gt(randomizer.streams_count, 0)


func test_voice_lifecycle_closes_without_output_device() -> void:
	var voice := VoiceDirector.new()
	add_child_autofree(voice)
	var started := []
	var finished := []
	voice.voice_started.connect(func(id: StringName) -> void: started.append(id))
	voice.voice_finished.connect(func(id: StringName) -> void: finished.append(id))
	voice.register_line(&"test_line", AudioStreamWAV.new())
	assert_true(voice.play_line(&"test_line"))
	assert_eq(started, [&"test_line"])
	assert_eq(finished, [&"test_line"])
	assert_eq(voice.current_line(), &"")


func test_play_music_and_sfx_are_noops_without_errors() -> void:
	var director := get_node_or_null(^"/root/AudioDirector")
	assert_not_null(director)
	director.call(&"play_music", &"menu", 0.0)
	await get_tree().process_frame
	assert_eq(director.get("music").call(&"current_cue_id"), &"menu")
	assert_true(director.call(&"play_sfx", &"footstep_stone", Vector3.INF, -4.0))
	assert_true(director.call(&"play_ui", &"ui_click"))
	assert_false(director.call(&"play_voice", &"missing_line"))
