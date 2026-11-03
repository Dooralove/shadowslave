extends Node
## Autoload audio facade. Scenes talk to this node; the child directors own
## playback. No gameplay scene should need to know about AudioStreamPlayer pools.

signal caption_requested(text: String)

const BUS_NAMES: Array[StringName] = [&"Master", &"Music", &"Ambience", &"SFX", &"Voice", &"UI"]
const DYNAMIC_RANGE_FULL := 0
const DYNAMIC_RANGE_REDUCED := 1

var music: MusicDirector
var ambience: AmbienceDirector
var sfx: SfxPool
var voice: VoiceDirector
## A09 runtime scene layer. The child is additive; the public facade below is
## unchanged. It is a no-op for scenes without a typed profile.
var scene_audio: SceneAudioDirector

const REVERB_PRESETS := {
	&"outdoor": {"room": 0.1, "damping": 0.9, "wet": 0.08, "dry": 1.0},
	&"coral_cave": {"room": 0.55, "damping": 0.45, "wet": 0.25, "dry": 1.0},
	&"bone_cave": {"room": 0.65, "damping": 0.5, "wet": 0.3, "dry": 1.0},
	&"tunnel": {"room": 0.8, "damping": 0.35, "wet": 0.4, "dry": 1.0},
	&"water": {"room": 0.45, "damping": 0.55, "wet": 0.2, "dry": 1.0},
	&"refuge": {"room": 0.35, "damping": 0.5, "wet": 0.18, "dry": 1.0},
	&"storm": {"room": 0.05, "damping": 0.95, "wet": 0.05, "dry": 1.0},
	&"sanctuary": {"room": 0.75, "damping": 0.4, "wet": 0.35, "dry": 1.0},
	&"precinct_hall": {"room": 0.38, "damping": 0.58, "wet": 0.17, "dry": 1.0},
	&"academy_hall": {"room": 0.62, "damping": 0.42, "wet": 0.24, "dry": 1.0},
	&"sleeper_hall": {"room": 0.72, "damping": 0.35, "wet": 0.3, "dry": 1.0},
	&"black_sea": {"room": 0.28, "damping": 0.62, "wet": 0.15, "dry": 1.0},
	&"descent": {"room": 0.55, "damping": 0.45, "wet": 0.22, "dry": 1.0},
}

const TARGET_LUFS := -18.0

var _base_bus_db: Dictionary = {}
var _reverb_stack: Array[StringName] = []
var _reverb_profile: StringName = &"coral_cave"
var _master_capture: AudioEffectCapture
var _compressor: AudioEffectCompressor
var _limiter: AudioEffectLimiter
var _mono_effect: AudioEffectStereoEnhance
var _caption_overlay: AudioCaptionOverlay
var _captions_enabled := true
var _master_peak_db := -80.0
var _master_rms_db := -80.0
var _paused := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_capture_base_bus_db()
	_cache_master_effects()
	_ensure_master_capture()
	_caption_overlay = AudioCaptionOverlay.new()
	_caption_overlay.name = "AudioCaptionOverlay"
	add_child(_caption_overlay)
	caption_requested.connect(_caption_overlay.show_caption)

	music = MusicDirector.new()
	music.name = "MusicDirector"
	add_child(music)

	ambience = AmbienceDirector.new()
	ambience.name = "AmbienceDirector"
	add_child(ambience)

	sfx = SfxPool.new()
	sfx.name = "SfxPool"
	add_child(sfx)
	sfx.cue_started.connect(_on_sfx_started)

	voice = VoiceDirector.new()
	voice.name = "VoiceDirector"
	add_child(voice)
	voice.voice_started.connect(_on_voice_started)
	voice.voice_finished.connect(_on_voice_finished)

	# A09 shared hook: one additive child, no public API changes. Scenes without
	# a typed profile are untouched.
	scene_audio = SceneAudioDirector.new()
	scene_audio.name = "SceneAudioDirector"
	add_child(scene_audio)

	var settings := GameSettings.new()
	settings.load_settings()
	apply_bus_levels(
		settings.master_volume,
		settings.music_volume,
		settings.ambience_volume,
		settings.sfx_volume,
		settings.voice_volume,
		settings.ui_volume
	)
	apply_accessibility(settings.captions_enabled, settings.mono_downmix, settings.dynamic_range)


func _process(_delta: float) -> void:
	if get_tree() != null and get_tree().paused != _paused:
		apply_pause_policy(get_tree().paused)
	_update_master_meter()


func _exit_tree() -> void:
	stop_all()
	AudioLibrary.clear_cache()


func get_master_peak_db() -> float:
	return _master_peak_db


func get_master_rms_db() -> float:
	return _master_rms_db


func get_target_lufs() -> float:
	return TARGET_LUFS


func _ensure_master_capture() -> void:
	var index := AudioServer.get_bus_index(&"Master")
	if index < 0:
		return
	for effect_index in AudioServer.get_bus_effect_count(index):
		var existing := AudioServer.get_bus_effect(index, effect_index) as AudioEffectCapture
		if existing != null:
			_master_capture = existing
			return
	_master_capture = AudioEffectCapture.new()
	_master_capture.buffer_length = 0.1
	AudioServer.add_bus_effect(index, _master_capture)


func _update_master_meter() -> void:
	if _master_capture == null:
		return
	var frames := _master_capture.get_frames_available()
	if frames <= 0:
		return
	var buffer := _master_capture.get_buffer(frames)
	var peak := 0.0
	var energy := 0.0
	for frame in buffer:
		var left := absf(frame.x)
		var right := absf(frame.y)
		peak = maxf(peak, maxf(left, right))
		energy += frame.x * frame.x + frame.y * frame.y
	var count := maxf(1.0, float(buffer.size() * 2))
	_master_peak_db = linear_to_db(maxf(peak, 0.000001))
	_master_rms_db = linear_to_db(maxf(sqrt(energy / count), 0.000001))


func _cache_master_effects() -> void:
	_compressor = null
	_limiter = null
	var index := AudioServer.get_bus_index(&"Master")
	if index < 0:
		return
	for effect_index in AudioServer.get_bus_effect_count(index):
		var effect := AudioServer.get_bus_effect(index, effect_index)
		if effect is AudioEffectCompressor:
			_compressor = effect as AudioEffectCompressor
		elif effect is AudioEffectLimiter:
			_limiter = effect as AudioEffectLimiter


func apply_pause_policy(paused: bool) -> void:
	if _paused == paused:
		return
	_paused = paused
	if sfx != null:
		sfx.set_paused(paused)
	if voice != null:
		voice.set_paused(paused)


func apply_accessibility(captions_enabled: bool, mono: bool, dynamic_range: int) -> void:
	_captions_enabled = captions_enabled
	if not captions_enabled and _caption_overlay != null:
		_caption_overlay.clear()
	_set_mono_downmix(mono)
	_set_dynamic_range(dynamic_range)


func _set_mono_downmix(enabled: bool) -> void:
	var index := AudioServer.get_bus_index(&"Master")
	if index < 0:
		return
	var found := -1
	for effect_index in AudioServer.get_bus_effect_count(index):
		if AudioServer.get_bus_effect(index, effect_index) is AudioEffectStereoEnhance:
			_mono_effect = AudioServer.get_bus_effect(index, effect_index) as AudioEffectStereoEnhance
			found = effect_index
			break
	if enabled:
		if _mono_effect == null:
			_mono_effect = AudioEffectStereoEnhance.new()
			AudioServer.add_bus_effect(index, _mono_effect)
		_mono_effect.pan_pullout = 0.0
	elif _mono_effect != null and found >= 0:
		AudioServer.remove_bus_effect(index, found)
		_mono_effect = null


func _set_dynamic_range(mode: int) -> void:
	if _compressor == null:
		return
	if mode == DYNAMIC_RANGE_REDUCED:
		_compressor.threshold = -26.0
		_compressor.ratio = 4.0
	else:
		_compressor.threshold = -18.0
		_compressor.ratio = 3.0


func _on_sfx_started(cue: SfxCue) -> void:
	if _captions_enabled and cue != null and not cue.caption.is_empty():
		caption_requested.emit(cue.caption)


func play_music(cue_id: StringName, fade := 2.0) -> void:
	music.play_cue(cue_id, fade)


func stop_music(fade := 1.0) -> void:
	music.stop(fade)


func set_music_intensity(value: float) -> void:
	music.set_intensity(value)


func play_ambience(zone_id: StringName, fade := 2.0) -> void:
	ambience.play_zone(zone_id, fade)


func stop_ambience(fade := 1.0) -> void:
	ambience.stop(fade)


func play_sfx(cue_id: StringName, position := Vector3.INF, volume_offset_db := 0.0) -> bool:
	return sfx.play(cue_id, position, volume_offset_db)


func play_ui(cue_id: StringName, volume_offset_db := 0.0) -> bool:
	return sfx.play_ui(cue_id, volume_offset_db)


func play_voice(line_id: StringName) -> bool:
	return voice.play_line(line_id)


func duck_music(amount_db: float, duration: float) -> void:
	music.duck(amount_db, duration)


func set_reverb_profile(profile: StringName) -> void:
	_reverb_profile = profile
	_reverb_stack.clear()
	_apply_reverb(profile)


func push_reverb_profile(profile: StringName) -> void:
	_reverb_stack.append(profile)
	_reverb_profile = profile
	_apply_reverb(_reverb_stack.back())


func pop_reverb_profile(profile: StringName) -> void:
	var index := _reverb_stack.rfind(profile)
	if index >= 0:
		_reverb_stack.remove_at(index)
	var active: StringName = _reverb_stack.back() if not _reverb_stack.is_empty() else &"outdoor"
	_reverb_profile = active
	_apply_reverb(active)


func get_reverb_profile() -> StringName:
	return _reverb_profile


func _apply_reverb(profile: StringName) -> void:
	var preset: Dictionary = REVERB_PRESETS.get(profile, REVERB_PRESETS[&"coral_cave"])
	var index := AudioServer.get_bus_index(&"Reverb")
	if index < 0 or AudioServer.get_bus_effect_count(index) == 0:
		return
	var effect := AudioServer.get_bus_effect(index, 0) as AudioEffectReverb
	if effect == null:
		return
	effect.room_size = float(preset["room"])
	effect.damping = float(preset["damping"])
	effect.wet = float(preset["wet"])
	effect.dry = float(preset["dry"])


func get_listener_position() -> Vector3:
	var camera := get_viewport().get_camera_3d()
	if camera != null:
		return camera.global_position
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	return player.global_position if player != null else Vector3.ZERO


func apply_3d_occlusion(player: AudioStreamPlayer3D, source_position: Vector3, source_rid := RID()) -> void:
	if player == null:
		return
	var exclude: Array[RID] = []
	var player_node := get_tree().get_first_node_in_group(&"player") as CollisionObject3D
	if player_node != null:
		exclude.append(player_node.get_rid())
	if source_rid.is_valid():
		exclude.append(source_rid)
	var result := AudioOcclusion.evaluate(
		get_viewport().world_3d,
		get_listener_position(),
		source_position,
		1,
		exclude
	)
	player.attenuation_filter_cutoff_hz = result["cutoff"]
	player.attenuation_filter_db = result["filter_db"]


func stop_all() -> void:
	if music != null:
		music.stop(0.0)
	if ambience != null:
		ambience.stop(0.0)
	if sfx != null:
		sfx.stop_all()
	if voice != null:
		voice.stop()


func apply_bus_levels(master: float, music_level: float, ambience_level: float, sfx_level: float, voice_level: float, ui_level: float) -> void:
	_apply_bus(&"Master", master)
	_apply_bus(&"Music", music_level)
	_apply_bus(&"Ambience", ambience_level)
	_apply_bus(&"SFX", sfx_level)
	_apply_bus(&"Voice", voice_level)
	_apply_bus(&"UI", ui_level)


func _apply_bus(bus_name: StringName, value: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index < 0:
		return
	var base := float(_base_bus_db.get(bus_name, 0.0))
	AudioServer.set_bus_mute(index, value <= 0.001)
	AudioServer.set_bus_volume_db(index, base + linear_to_db(maxf(value, 0.001)))


func _capture_base_bus_db() -> void:
	for bus_name in BUS_NAMES:
		var index := AudioServer.get_bus_index(bus_name)
		if index >= 0:
			_base_bus_db[bus_name] = AudioServer.get_bus_volume_db(index)


func _on_voice_started(_line_id: StringName) -> void:
	if music != null:
		music.duck(-8.0, 60.0)
	if ambience != null:
		ambience.duck(-4.0, 60.0)


func _on_voice_finished(_line_id: StringName) -> void:
	if music != null:
		music.release_duck(0.35)
	if ambience != null:
		ambience.release_duck(0.35)
