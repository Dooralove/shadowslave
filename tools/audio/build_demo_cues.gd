extends SceneTree
## Builds the demo-fragment audio addendum.
##
## The addendum is merged by AudioLibrary at runtime. It keeps the generated
## demo cues and the Labyrinth storm/camp overrides out of the large base cue
## table, so the base library can still be regenerated independently.
##
## Run:
##   godot --headless --path . --script res://tools/audio/build_demo_cues.gd

const OUT := "res://resources/audio/audio_cue_library_demo.tres"
const BASE := "res://resources/audio/audio_cue_library.tres"
const DEMO := "res://assets/audio/demo"
const M1 := "res://assets/audio/m1"


func _init() -> void:
	var base := load(BASE) as AudioCueLibrary
	if base == null:
		push_error("build_demo_cues: missing base library")
		quit(1)
		return
	var addendum := AudioCueLibrary.new()

	# --- Creature cues -----------------------------------------------------
	addendum.sfx.append(_sfx(&"creature_carapace_chitter", [
		DEMO + "/sfx/creature_carapace_chitter_01.wav",
	], SfxCue.Priority.HIGH, -4.0, 0.92, 1.05, 1.6, 2, 35.0, 7.0, ""));
	addendum.sfx.append(_sfx(&"creature_carapace_click", [
		DEMO + "/sfx/creature_carapace_click_01.wav",
	], SfxCue.Priority.LOW, -12.0, 0.88, 1.12, 0.45, 2, 25.0, 4.0, ""));
	addendum.sfx.append(_sfx(&"creature_carapace_attack", [
		DEMO + "/sfx/creature_carapace_attack_01.wav",
	], SfxCue.Priority.HIGH, -3.0, 0.94, 1.06, 0.3, 2, 35.0, 7.0, ""));
	addendum.sfx.append(_sfx(&"creature_carapace_death", [
		DEMO + "/sfx/creature_carapace_death_01.wav",
	], SfxCue.Priority.CRITICAL, -2.0, 0.9, 1.04, 0.2, 2, 45.0, 9.0, ""));

	# --- World / event cues ------------------------------------------------
	addendum.sfx.append(_sfx(&"world_tide_warning", [
		DEMO + "/sfx/world_tide_warning_01.wav",
	], SfxCue.Priority.CRITICAL, -2.0, 0.96, 1.02, 8.0, 1, 120.0, 20.0, "Прилив поднимается"));
	addendum.sfx.append(_sfx(&"world_water_splash", [
		DEMO + "/sfx/world_water_splash_01.wav",
	], SfxCue.Priority.MEDIUM, -8.0, 0.9, 1.1, 0.15, 3, 30.0, 5.0, ""));
	addendum.sfx.append(_sfx(&"world_wind_gust", [
		DEMO + "/sfx/world_wind_gust_01.wav",
	], SfxCue.Priority.LOW, -10.0, 0.94, 1.06, 2.0, 2, 60.0, 10.0, ""));
	addendum.sfx.append(_sfx(&"world_azure_blade", [
		DEMO + "/sfx/world_azure_blade_01.wav",
	], SfxCue.Priority.HIGH, -3.0, 0.98, 1.02, 0.5, 1, 50.0, 8.0, "Лезвие поёт"));
	addendum.sfx.append(_sfx(&"world_soul_shard", [
		DEMO + "/sfx/world_soul_shard_01.wav",
	], SfxCue.Priority.MEDIUM, -5.0, 0.98, 1.02, 0.5, 1, 35.0, 5.0, ""));
	addendum.sfx.append(_sfx(&"world_echo_whisper", [
		DEMO + "/sfx/world_echo_whisper_01.wav",
	], SfxCue.Priority.HIGH, -8.0, 0.96, 1.04, 2.0, 1, 45.0, 8.0, "Шёпот Эха"));
	addendum.sfx.append(_sfx(&"world_stone_shift", [
		DEMO + "/sfx/world_stone_shift_01.wav",
	], SfxCue.Priority.MEDIUM, -8.0, 0.92, 1.06, 1.5, 1, 50.0, 8.0, ""))
	addendum.sfx.append(_sfx(&"world_campfire_rest", [
		DEMO + "/sfx/world_campfire_rest_01.wav",
	], SfxCue.Priority.HIGH, -4.0, 0.96, 1.04, 1.0, 1, 25.0, 4.0, "Костёр трещит"));

	# --- M1 post-Nightmare SFX -------------------------------------------
	addendum.sfx.append(_sfx(&"p05_cell_door", [
		M1 + "/sfx/p05_cell_door_01.wav",
	], SfxCue.Priority.HIGH, -5.0, 0.94, 1.04, 0.8, 1, 30.0, 5.0, "Дверь камеры"));
	addendum.sfx.append(_sfx(&"p05_radio_chatter", [
		M1 + "/sfx/p05_radio_chatter_01.wav",
	], SfxCue.Priority.LOW, -9.0, 0.97, 1.03, 0.0, 1, 18.0, 3.0, "", true));
	addendum.sfx.append(_sfx(&"p05_mirror_whisper", [
		M1 + "/sfx/p05_mirror_whisper_01.wav",
	], SfxCue.Priority.HIGH, -7.0, 0.97, 1.03, 1.0, 1, 22.0, 4.0, "Шёпот в зеркале"));
	addendum.sfx.append(_sfx(&"p05_paper_rustle", [
		M1 + "/sfx/p05_paper_rustle_01.wav",
	], SfxCue.Priority.LOW, -11.0, 0.95, 1.05, 0.4, 2, 12.0, 2.0, ""));
	addendum.sfx.append(_sfx(&"p05_hvac", [
		M1 + "/sfx/p05_hvac_01.wav",
	], SfxCue.Priority.LOW, -12.0, 1.0, 1.0, 0.0, 1, 20.0, 4.0, "", true));
	addendum.sfx.append(_sfx(&"p06_car_idle", [
		M1 + "/sfx/p06_car_idle_01.wav",
	], SfxCue.Priority.LOW, -10.0, 0.98, 1.02, 0.0, 1, 28.0, 4.0, "", true));
	addendum.sfx.append(_sfx(&"p06_car_door", [
		M1 + "/sfx/p06_car_door_01.wav",
	], SfxCue.Priority.MEDIUM, -7.0, 0.95, 1.05, 0.5, 1, 24.0, 4.0, ""));
	addendum.sfx.append(_sfx(&"p06_checkpoint_beep", [
		M1 + "/sfx/p06_checkpoint_beep_01.wav",
	], SfxCue.Priority.HIGH, -6.0, 0.99, 1.01, 0.6, 1, 22.0, 3.0, "КПП: проверка"));
	addendum.sfx.append(_sfx(&"p07_gate_scan", [
		M1 + "/sfx/p07_gate_scan_01.wav",
	], SfxCue.Priority.HIGH, -6.0, 0.98, 1.02, 1.0, 1, 25.0, 4.0, "Сканер ворот"));
	addendum.sfx.append(_sfx(&"p07_flag_flap", [
		M1 + "/sfx/p07_flag_flap_01.wav",
	], SfxCue.Priority.LOW, -11.0, 0.96, 1.04, 0.0, 2, 30.0, 6.0, ""));
	addendum.sfx.append(_sfx(&"p08_terminal_beep", [
		M1 + "/sfx/p08_terminal_beep_01.wav",
	], SfxCue.Priority.HIGH, -6.0, 0.99, 1.01, 0.5, 1, 18.0, 2.5, "Терминал: Sleeper Center, сектор B"));
	addendum.sfx.append(_sfx(&"p08_crowd_walla", [
		M1 + "/sfx/p08_crowd_walla_01.wav",
	], SfxCue.Priority.LOW, -12.0, 0.98, 1.02, 0.0, 1, 26.0, 5.0, "", true));
	addendum.sfx.append(_sfx(&"p09_hvac", [
		M1 + "/sfx/p09_hvac_01.wav",
	], SfxCue.Priority.LOW, -12.0, 1.0, 1.0, 0.0, 1, 22.0, 4.0, "", true));
	addendum.sfx.append(_sfx(&"p09_induction_tone", [
		M1 + "/sfx/p09_induction_tone_01.wav",
	], SfxCue.Priority.CRITICAL, -5.0, 0.98, 1.02, 2.0, 1, 30.0, 5.0, "Индукция"));
	addendum.sfx.append(_sfx(&"p09_capsule_hiss", [
		M1 + "/sfx/p09_capsule_hiss_01.wav",
	], SfxCue.Priority.HIGH, -6.0, 0.97, 1.03, 1.0, 1, 22.0, 3.0, "Капсула"));
	addendum.sfx.append(_sfx(&"p09_capsule_hum", [
		M1 + "/sfx/p09_capsule_hum_01.wav",
	], SfxCue.Priority.LOW, -13.0, 1.0, 1.0, 0.0, 1, 12.0, 2.0, "", true));
	addendum.sfx.append(_sfx(&"b01_sea_lap", [
		M1 + "/sfx/b01_sea_lap_01.wav",
	], SfxCue.Priority.LOW, -14.0, 0.98, 1.02, 0.0, 1, 90.0, 20.0, "", true));
	addendum.sfx.append(_sfx(&"b01_statue_groan", [
		M1 + "/sfx/b01_statue_groan_01.wav",
	], SfxCue.Priority.HIGH, -8.0, 0.94, 1.04, 1.4, 1, 45.0, 10.0, "Статуя"));
	addendum.sfx.append(_sfx(&"b01_shroud_flare", [
		M1 + "/sfx/b01_shroud_flare_01.wav",
	], SfxCue.Priority.CRITICAL, -4.0, 0.96, 1.04, 1.0, 1, 30.0, 5.0, "Плащ"));
	addendum.sfx.append(_sfx(&"b02_water_flow", [
		M1 + "/sfx/b02_water_flow_01.wav",
	], SfxCue.Priority.LOW, -13.0, 0.98, 1.02, 0.0, 1, 40.0, 8.0, "", true));
	addendum.sfx.append(_sfx(&"b02_wave_crash", [
		M1 + "/sfx/b02_wave_crash_01.wav",
	], SfxCue.Priority.HIGH, -5.0, 0.96, 1.04, 1.0, 1, 60.0, 12.0, "Прилив"));
	addendum.sfx.append(_sfx(&"b02_rockfall_small", [
		M1 + "/sfx/b02_rockfall_small_01.wav",
	], SfxCue.Priority.MEDIUM, -9.0, 0.92, 1.08, 0.8, 1, 30.0, 5.0, ""));
	addendum.sfx.append(_sfx(&"m1_camp_night_stinger", [
		M1 + "/sfx/m1_camp_night_stinger_01.wav",
	], SfxCue.Priority.CRITICAL, -5.0, 0.98, 1.02, 3.0, 1, 25.0, 5.0, "Ночь у костра"));

	# --- M1 music ---------------------------------------------------------
	for cue in _m1_music_cues():
		addendum.music.append(cue)

	# --- M1 ambience ------------------------------------------------------
	addendum.ambience.append(_zone(&"m1_precinct", M1 + "/ambience/m1_precinct.wav", -12.0, -22.0))
	addendum.ambience.append(_zone(&"m1_academy", M1 + "/ambience/m1_academy.wav", -12.0, -22.0))
	addendum.ambience.append(_zone(&"m1_sleeper", M1 + "/ambience/m1_sleeper.wav", -12.0, -22.0))
	addendum.ambience.append(_zone(&"m1_black_sea", M1 + "/ambience/m1_black_sea.wav", -13.0, -23.0))
	addendum.ambience.append(_zone(&"m1_descent", M1 + "/ambience/m1_descent.wav", -13.0, -23.0))
	addendum.ambience.append(_zone(&"m1_camp_night", M1 + "/ambience/m1_camp_night.wav", -12.0, -22.0))

	# --- Storm music -------------------------------------------------------
	var storm := MusicCue.new()
	storm.id = &"labyrinth_storm"
	storm.bpm = 48.0
	storm.key = "D minor"
	storm.layers.append(_layer(&"base", DEMO + "/music/labyrinth_storm_base.ogg", -14.0, -60.0, -8.0))
	storm.layers.append(_layer(&"pulse", DEMO + "/music/labyrinth_storm_pulse.ogg", -22.0, -60.0, -12.0))
	storm.layers.append(_layer(&"melody", DEMO + "/music/labyrinth_storm_melody.ogg", -25.0, -60.0, -15.0))
	addendum.music.append(storm)

	# --- Ambience overrides ----------------------------------------------
	# Keep the existing bed/mid where they work; add local detail and a real
	# storm/campfire layer only where the demo needs it.
	addendum.ambience.append(_override(base, &"labyrinth_z02", [], [
		DEMO + "/sfx/creature_carapace_click_01.wav",
	]))
	addendum.ambience.append(_override(base, &"labyrinth_z10", [], [
		DEMO + "/sfx/world_wind_gust_01.wav",
	]))
	addendum.ambience.append(_override(base, &"labyrinth_z13", [], [
		DEMO + "/sfx/creature_carapace_chitter_01.wav",
	]))
	addendum.ambience.append(_override(base, &"labyrinth_z16", [], [
		DEMO + "/sfx/world_wind_gust_01.wav",
	]))
	var storm_zone := _override(base, &"labyrinth_z17", [], [
		DEMO + "/sfx/world_water_splash_01.wav",
	], DEMO + "/ambience/storm_rain_loop_01.ogg")
	storm_zone.bed_db = -5.0
	addendum.ambience.append(storm_zone)
	addendum.ambience.append(_override(base, &"labyrinth_z18", [], [
		DEMO + "/sfx/world_wind_gust_01.wav",
		DEMO + "/sfx/world_stone_shift_01.wav",
	]))

	var error := ResourceSaver.save(addendum, OUT)
	print("Saved %s: %s (music=%d, sfx=%d, ambience=%d)" % [
		OUT, error, addendum.music.size(), addendum.sfx.size(), addendum.ambience.size()
	])
	quit(0 if error == OK else 1)


func _sfx(
	id: StringName,
	paths: Array,
	priority: int,
	volume_db: float,
	pitch_min: float,
	pitch_max: float,
	cooldown: float,
	max_instances: int,
	max_distance: float,
	unit_size: float,
	caption: String,
	loop := false
) -> SfxCue:
	var cue := SfxCue.new()
	cue.id = id
	cue.bus = &"SFX"
	cue.priority = priority
	cue.volume_db = volume_db
	cue.pitch_min = pitch_min
	cue.pitch_max = pitch_max
	cue.cooldown = cooldown
	cue.max_instances = max_instances
	cue.spatial = true
	cue.max_distance = max_distance
	cue.unit_size = unit_size
	cue.caption = caption
	cue.loop = loop
	for path in paths:
		var stream := load(path) as AudioStream
		if stream != null:
			cue.streams.append(stream)
		else:
			push_warning("build_demo_cues: missing stream %s" % path)
	return cue


func _layer(layer_name: StringName, path: String, default_db: float, min_db: float, max_db: float) -> MusicLayer:
	var layer := MusicLayer.new()
	layer.layer_name = layer_name
	layer.stream = load(path) as AudioStream
	layer.default_db = default_db
	layer.min_db = min_db
	layer.max_db = max_db
	return layer


func _m1_music_cues() -> Array[MusicCue]:
	var result: Array[MusicCue] = []
	var specs := [
		{"id": &"m1_precinct", "bpm": 68.0, "key": "F minor", "db": -13.0},
		{"id": &"m1_academy", "bpm": 72.0, "key": "D minor", "db": -12.0},
		{"id": &"m1_sleeper", "bpm": 60.0, "key": "F minor", "db": -13.0},
		{"id": &"m1_black_sea", "bpm": 56.0, "key": "C minor", "db": -13.0},
		{"id": &"m1_descent", "bpm": 64.0, "key": "D minor", "db": -12.0},
	]
	for spec in specs:
		var cue := MusicCue.new()
		cue.id = StringName(spec["id"])
		cue.bpm = float(spec["bpm"])
		cue.key = String(spec["key"])
		var base_db: float = float(spec["db"])
		cue.layers.append(_layer(&"base", M1 + "/music/%s_base.ogg" % cue.id, base_db, -60.0, base_db + 6.0))
		cue.layers.append(_layer(&"pulse", M1 + "/music/%s_pulse.ogg" % cue.id, base_db - 8.0, -60.0, base_db - 2.0))
		cue.layers.append(_layer(&"melody", M1 + "/music/%s_melody.ogg" % cue.id, base_db - 11.0, -60.0, base_db - 5.0))
		result.append(cue)
	return result


func _zone(zone_id: StringName, bed_path: String, bed_db: float, mid_db: float) -> AmbienceZone:
	var zone := AmbienceZone.new()
	zone.id = zone_id
	zone.bed = load(bed_path) as AudioStream
	zone.bed_db = bed_db
	zone.mid_db = mid_db
	return zone


func _override(
	base: AudioCueLibrary,
	zone_id: StringName,
	extra_mids: Array,
	extra_details: Array,
	override_bed := ""
) -> AmbienceZone:
	var source: AmbienceZone = null
	for zone in base.ambience:
		if zone != null and zone.id == zone_id:
			source = zone
			break
	var out := AmbienceZone.new()
	out.id = zone_id
	if source != null:
		out.bed = source.bed
		out.mid = source.mid
		out.bed_db = source.bed_db
		out.mid_db = source.mid_db
		out.detail_db = source.detail_db
		out.details = source.details.duplicate()
	if not override_bed.is_empty():
		out.bed = load(override_bed) as AudioStream
	if not extra_mids.is_empty():
		out.mid = load(extra_mids[0]) as AudioStream
		out.mid_db = -19.0
	for path in extra_details:
		var stream := load(path) as AudioStream
		if stream != null:
			out.details.append(stream)
	return out
