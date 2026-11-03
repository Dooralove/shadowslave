extends SceneTree
## Builds typed M1 scene-audio and scene-VFX profiles.
##
## Run after assets/audio/m1 is imported and build_demo_cues.gd has rebuilt the
## cue addendum:
##   godot --headless --path . --script res://tools/audio/build_m1_profiles.gd

const AUDIO_DIR := "res://resources/audio/scene_profiles/"
const VFX_DIR := "res://resources/audio/scene_vfx_profiles/"


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(AUDIO_DIR))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(VFX_DIR))
	_build_audio_profiles()
	_build_vfx_profiles()
	print("M1 scene profiles built.")
	quit(0)


func _build_audio_profiles() -> void:
	var p05 := _base_audio(&"p05_police_precinct", "police_precinct", "res://scenes/locations/post_nightmare/police_precinct.tscn", &"m1_precinct", &"precinct_hall")
	p05.loops.append(_ae(&"p05_hvac", Vector3(0.0, 2.3, -2.0), -2.0, 0.0, true))
	p05.loops.append(_ae(&"p05_radio_chatter", Vector3(1.0, 1.2, -2.8), -5.0, 0.0, true))
	p05.enter_events.append(_ae(&"p05_cell_door", Vector3(0.0, 1.2, 15.4), -7.0, 0.8))
	p05.enter_events.append(_ae(&"p05_paper_rustle", Vector3(5.0, 1.0, -18.2), -14.0, 1.4))
	p05.trigger_events.append(_ae(&"p05_cell_door", Vector3(0.0, 1.2, 15.4), -5.0, 0.0, false, &"", &"precinct_exit"))
	p05.trigger_events.append(_ae(&"p05_cell_door", Vector3(0.0, 1.2, 15.4), -5.0, 0.0, false, &"", &"p05_exit"))
	p05.interactions[&"precinct_mirror"] = &"p05_mirror_whisper"
	p05.interactions[&"p05_mirror"] = &"p05_mirror_whisper"
	p05.interactions[&"precinct_jett"] = &"ui_confirm"
	p05.interactions[&"p05_jett"] = &"ui_confirm"
	p05.interactions[&"jett"] = &"ui_confirm"
	p05.interactions[&"desk_officer"] = &"ui_confirm"
	p05.interactions[&"interrogation_officer"] = &"ui_confirm"
	_save_audio(p05)

	var p06 := _base_audio(&"p06_academy_approach", "academy_approach", "res://scenes/locations/post_nightmare/academy_approach.tscn", &"m1_academy", &"outdoor")
	p06.loops.append(_ae(&"p06_car_idle", Vector3(-3.4, 0.6, 18.6), -4.0, 0.0, true))
	p06.trigger_events.append(_ae(&"p06_car_door", Vector3(-4.8, 1.0, 18.0), -5.0, 0.0, false, &"", &"academy_jet"))
	p06.trigger_events.append(_ae(&"p06_car_door", Vector3(-4.8, 1.0, 18.0), -5.0, 0.0, false, &"", &"p06_jett"))
	p06.interactions[&"academy_checkpoint"] = &"p06_checkpoint_beep"
	p06.interactions[&"p06_checkpoint"] = &"p06_checkpoint_beep"
	p06.interactions[&"jett"] = &"ui_confirm"
	p06.interactions[&"p06_jett"] = &"ui_confirm"
	_save_audio(p06)

	var p07 := _base_audio(&"p07_academy_gate", "academy_gate", "res://scenes/locations/post_nightmare/academy_gate.tscn", &"m1_academy", &"outdoor")
	p07.loops.append(_ae(&"p07_flag_flap", Vector3(-4.0, 2.0, 20.0), -8.0, 0.0, true))
	p07.interactions[&"academy_gate_checkpoint"] = &"p07_gate_scan"
	p07.interactions[&"p07_gate"] = &"p07_gate_scan"
	p07.interactions[&"academy_gate"] = &"p07_gate_scan"
	p07.interactions[&"gate_guard"] = &"ui_confirm"
	p07.interactions[&"p07_guard"] = &"ui_confirm"
	p07.flag_events.append(_ae(&"p07_gate_scan", Vector3(5.5, 1.2, 3.0), -3.0, 0.0, false, &"academy_gate_passed"))
	p07.flag_events.append(_ae(&"world_wind_gust", Vector3(5.0, 1.5, 2.0), -9.0, 0.0, false, &"nephis_seen_at_gate"))
	_save_audio(p07)

	var p08 := _base_audio(&"p08_academy_campus", "academy_campus", "res://scenes/locations/post_nightmare/academy_campus.tscn", &"m1_academy", &"academy_hall")
	p08.loops.append(_ae(&"p08_crowd_walla", Vector3(0.0, 1.0, 0.0), -8.0, 0.0, true))
	p08.interactions[&"academy_campus_guide"] = &"ui_confirm"
	p08.interactions[&"campus_guide"] = &"ui_confirm"
	p08.interactions[&"academy_terminal"] = &"p08_terminal_beep"
	p08.interactions[&"campus_terminal"] = &"p08_terminal_beep"
	p08.interactions[&"terminal"] = &"p08_terminal_beep"
	p08.flag_events.append(_ae(&"p08_terminal_beep", Vector3(-2.5, 1.2, 4.0), -2.0, 0.0, false, &"dorm_assigned"))
	_save_audio(p08)

	var p09 := _base_audio(&"p09_sleeper_center", "academy_sleeper_center", "res://scenes/locations/post_nightmare/academy_sleeper_center.tscn", &"m1_sleeper", &"sleeper_hall")
	p09.loops.append(_ae(&"p09_hvac", Vector3(0.0, 2.5, -10.0), -3.0, 0.0, true))
	p09.loops.append(_ae(&"p09_capsule_hum", Vector3(0.0, 1.0, -25.5), -5.0, 0.0, true))
	p09.interactions[&"sleeper_capsule"] = &"p09_capsule_hiss"
	p09.interactions[&"p09_capsule"] = &"p09_capsule_hiss"
	p09.interactions[&"academy_julius"] = &"ui_confirm"
	p09.interactions[&"rock"] = &"ui_confirm"
	p09.interactions[&"kasper"] = &"ui_confirm"
	p09.interactions[&"cassia"] = &"ui_confirm"
	p09.interactions[&"medic"] = &"ui_confirm"
	p09.flag_events.append(_ae(&"p09_induction_tone", Vector3(0.0, 1.2, -25.5), -4.0, 0.0, false, &"induction_seen"))
	p09.flag_events.append(_ae(&"world_wind_gust", Vector3(0.0, 1.2, -16.0), -7.0, 0.0, false, &"academy_month_passed"))
	_save_audio(p09)

	var b01 := _base_audio(&"b01_black_sea", "black_sea_platform", "res://scenes/locations/post_nightmare/black_sea_platform.tscn", &"m1_black_sea", &"black_sea")
	b01.loops.append(_ae(&"b01_sea_lap", Vector3(0.0, -8.0, 0.0), -5.0, 0.0, true))
	b01.interactions[&"black_sea_stars"] = &"b01_statue_groan"
	b01.interactions[&"b01_stars"] = &"b01_statue_groan"
	b01.interactions[&"black_sea_sword"] = &"world_azure_blade"
	b01.interactions[&"b01_sword"] = &"world_azure_blade"
	b01.interactions[&"black_sea_shroud"] = &"b01_shroud_flare"
	b01.interactions[&"b01_shroud"] = &"b01_shroud_flare"
	b01.interactions[&"shroud"] = &"b01_shroud_flare"
	b01.interactions[&"black_sea_descent"] = &"b02_rockfall_small"
	b01.interactions[&"b01_descent"] = &"b02_rockfall_small"
	var shroud_audio: SceneAudioEvent = _ae(&"b01_shroud_flare", Vector3(0.0, 1.2, 5.2), -3.0, 0.0, false, &"shroud_summoned")
	shroud_audio.persistent = true
	b01.flag_events.append(shroud_audio)
	b01.flag_events.append(_ae(&"b01_statue_groan", Vector3(0.0, 1.2, 5.2), -6.0, 0.0, false, &"statue_seen"))
	_save_audio(b01)

	var b02 := _base_audio(&"b02_tide_descent", "tide_descent", "res://scenes/locations/post_nightmare/tide_descent.tscn", &"m1_descent", &"descent")
	b02.loops.append(_ae(&"b02_water_flow", Vector3(0.0, -5.5, -20.0), -4.0, 0.0, true))
	b02.enter_events.append(_ae(&"b02_wave_crash", Vector3(0.0, -5.0, -20.0), -8.0, 1.2))
	b02.enter_events.append(_ae(&"world_coral_groan", Vector3(3.0, -5.0, -20.0), -9.0, 2.4))
	b02.trigger_events.append(_ae(&"world_tide_warning", Vector3(0.0, 1.2, 15.0), -4.0, 0.0, false, &"", &"tide_descent_warning"))
	b02.trigger_events.append(_ae(&"world_tide_warning", Vector3(0.0, 1.2, 15.0), -4.0, 0.0, false, &"", &"b02_tide_warning"))
	b02.flag_events.append(_ae(&"b02_wave_crash", Vector3(0.0, -5.0, -20.0), -7.0, 0.0, false, &"tide_seen"))
	_save_audio(b02)


func _base_audio(
	id: StringName,
	location: String,
	scene_path: String,
	music: StringName,
	reverb: StringName
) -> SceneAudioProfile:
	var profile := SceneAudioProfile.new()
	profile.id = id
	profile.location_id = StringName(location)
	profile.scene_path = scene_path
	profile.music_id = music
	profile.ambience_id = &"m1_%s" % ("precinct" if location == "police_precinct" else "academy" if location in ["academy_approach", "academy_gate", "academy_campus"] else "sleeper" if location == "academy_sleeper_center" else "black_sea" if location == "black_sea_platform" else "descent")
	profile.music_intensity = 0.42
	profile.reverb_profile = reverb
	return profile


func _ae(
	cue: StringName,
	position: Vector3,
	volume_db := 0.0,
	delay := 0.0,
	loop := false,
	flag := &"",
	trigger := &""
) -> SceneAudioEvent:
	var event := SceneAudioEvent.new()
	event.cue_id = cue
	event.position = position
	event.volume_db = volume_db
	event.delay = delay
	event.loop = loop
	event.flag = flag
	event.trigger = trigger
	return event


func _save_audio(profile: SceneAudioProfile) -> void:
	var path := AUDIO_DIR + String(profile.id) + ".tres"
	var error := ResourceSaver.save(profile, path)
	print("audio ", path, " = ", error)


func _build_vfx_profiles() -> void:
	var p05 := _base_vfx(&"p05_police_precinct_vfx", "police_precinct", "res://scenes/locations/post_nightmare/police_precinct.tscn")
	p05.enter_effects.append(_ve("res://scenes/environment/vfx/m1_rain_light.tscn", Vector3(0.0, 0.05, 14.0), false, 0.8))
	var p05_breath: SceneVfxEvent = _ve("res://scenes/environment/p3_breath_puff.tscn", Vector3(0.0, 1.4, 0.0), false, 0.5)
	p05_breath.attach_to = ^"Player"
	p05.enter_effects.append(p05_breath)
	_save_vfx(p05)

	var p06 := _base_vfx(&"p06_academy_approach_vfx", "academy_approach", "res://scenes/locations/post_nightmare/academy_approach.tscn")
	var p06_snow: SceneVfxEvent = _ve("res://scenes/environment/vfx/m1_snow_drift.tscn", Vector3(0.0, 4.5, 0.0), true, 1.0)
	p06_snow.attach_to = ^"Player"
	p06.loops.append(p06_snow)
	p06.loops.append(_ve("res://scenes/environment/vfx/m1_steam_vents.tscn", Vector3(-3.4, 0.8, 18.6), true, 0.7))
	_save_vfx(p06)

	var p07 := _base_vfx(&"p07_academy_gate_vfx", "academy_gate", "res://scenes/locations/post_nightmare/academy_gate.tscn")
	var p07_snow: SceneVfxEvent = _ve("res://scenes/environment/vfx/m1_snow_drift.tscn", Vector3(0.0, 4.5, 0.0), true, 1.0)
	p07_snow.attach_to = ^"Player"
	p07.loops.append(p07_snow)
	p07.loops.append(_ve("res://scenes/environment/vfx/m1_steam_vents.tscn", Vector3(6.8, 2.0, -18.8), true, 0.6))
	_save_vfx(p07)

	var p08 := _base_vfx(&"p08_academy_campus_vfx", "academy_campus", "res://scenes/locations/post_nightmare/academy_campus.tscn")
	var p08_snow: SceneVfxEvent = _ve("res://scenes/environment/vfx/m1_snow_drift.tscn", Vector3(0.0, 4.5, 0.0), true, 1.0)
	p08_snow.attach_to = ^"Player"
	p08.loops.append(p08_snow)
	p08.loops.append(_ve("res://scenes/environment/vfx/m1_steam_vents.tscn", Vector3(0.0, 1.5, 0.0), true, 0.8))
	_save_vfx(p08)

	var p09 := _base_vfx(&"p09_sleeper_center_vfx", "academy_sleeper_center", "res://scenes/locations/post_nightmare/academy_sleeper_center.tscn")
	p09.loops.append(_ve("res://scenes/environment/vfx/m1_steam_vents.tscn", Vector3(4.2, 1.0, -20.3), true, 0.6))
	p09.flag_effects.append(_ve("res://scenes/environment/vfx/m1_induction_pulse.tscn", Vector3(0.0, 1.2, -25.5), false, 1.0, &"induction_seen"))
	_save_vfx(p09)

	var b01 := _base_vfx(&"b01_black_sea_vfx", "black_sea_platform", "res://scenes/locations/post_nightmare/black_sea_platform.tscn")
	b01.loops.append(_ve("res://scenes/environment/vfx/m1_black_sea_mist.tscn", Vector3(0.0, -4.0, 0.0), true, 1.0))
	var shroud_vfx: SceneVfxEvent = _ve("res://scenes/environment/vfx/m1_shroud_ribbons.tscn", Vector3(0.0, 1.2, 0.0), false, 1.0, &"shroud_summoned")
	shroud_vfx.persistent = true
	shroud_vfx.attach_to = ^"Player"
	b01.flag_effects.append(shroud_vfx)
	_save_vfx(b01)

	var b02 := _base_vfx(&"b02_tide_descent_vfx", "tide_descent", "res://scenes/locations/post_nightmare/tide_descent.tscn")
	b02.loops.append(_ve("res://scenes/environment/vfx/m1_tide_foam.tscn", Vector3(0.0, -5.6, -20.5), true, 0.9))
	b02.trigger_effects.append(_ve("res://scenes/environment/vfx/tide_spray.tscn", Vector3(0.0, -4.0, -20.0), false, 1.0, &"", &"tide_descent_warning"))
	_save_vfx(b02)


func _base_vfx(id: StringName, location: String, scene_path: String) -> SceneVfxProfile:
	var profile := SceneVfxProfile.new()
	profile.id = id
	profile.location_id = StringName(location)
	profile.scene_path = scene_path
	return profile


func _ve(
	path: String,
	position: Vector3,
	loop := false,
	scale := 1.0,
	flag := &"",
	trigger := &""
) -> SceneVfxEvent:
	var event := SceneVfxEvent.new()
	event.scene = load(path) as PackedScene
	event.position = position
	event.loop = loop
	event.scale = scale
	event.flag = flag
	event.trigger = trigger
	return event


func _save_vfx(profile: SceneVfxProfile) -> void:
	var path := VFX_DIR + String(profile.id) + ".tres"
	var error := ResourceSaver.save(profile, path)
	print("vfx ", path, " = ", error)
