class_name AudioLibrary
extends RefCounted
## Loads the typed cue import table and exposes dictionary views for the directors.
##
## Cue data lives in resources/audio/audio_cue_library.tres (music, SFX, ambience).
## Generated placeholder assets are project-owned; see docs/ASSET_LICENSES.md.

const LIBRARY_PATH := "res://resources/audio/audio_cue_library.tres"
## Demo-fragment additions: new cues and a small set of deliberate zone
## overrides. Preloaded so the exported build has an explicit dependency.
const ADDENDUM := preload("res://resources/audio/audio_cue_library_demo.tres")

static var _library: AudioCueLibrary
static var _addendum: AudioCueLibrary
static var _music_cache: Dictionary = {}
static var _sfx_cache: Dictionary = {}
static var _ambience_cache: Dictionary = {}
## Test-only switch: exercise AudioStreamPlayer.play() in headless dummy audio.
static var force_playback_for_tests := false


## Headless runs have no output device; skip play() to avoid dummy playback leaks.
## Tests can opt into actual player state with force_playback_for_tests.
static func playback_enabled() -> bool:
	return force_playback_for_tests or DisplayServer.get_name() != "headless"


static func clear_cache() -> void:
	_library = null
	_addendum = null
	_music_cache.clear()
	_sfx_cache.clear()
	_ambience_cache.clear()


static func _get_library() -> AudioCueLibrary:
	if _library == null:
		_library = load(LIBRARY_PATH) as AudioCueLibrary
		if _library == null:
			push_warning("AudioLibrary: missing cue library %s" % LIBRARY_PATH)
			_library = AudioCueLibrary.new()
	return _library


static func _get_addendum() -> AudioCueLibrary:
	if _addendum == null:
		_addendum = ADDENDUM as AudioCueLibrary
		if _addendum == null:
			_addendum = AudioCueLibrary.new()
	return _addendum


static func music_cues() -> Dictionary:
	if not _music_cache.is_empty():
		return _music_cache
	for cue in _get_library().music:
		if cue != null:
			_music_cache[cue.id] = cue
	for cue in _get_addendum().music:
		if cue != null:
			_music_cache[cue.id] = cue
	return _music_cache


static func sfx_cues() -> Dictionary:
	if not _sfx_cache.is_empty():
		return _sfx_cache
	for cue in _get_library().sfx:
		if cue != null:
			_sfx_cache[cue.id] = cue
	for cue in _get_addendum().sfx:
		if cue != null:
			_sfx_cache[cue.id] = cue
	return _sfx_cache


static func ambience_zones() -> Dictionary:
	if not _ambience_cache.is_empty():
		return _ambience_cache
	for zone in _get_library().ambience:
		if zone == null:
			continue
		_ambience_cache[zone.id] = _zone_dict(zone)
	for zone in _get_addendum().ambience:
		if zone == null:
			continue
		_ambience_cache[zone.id] = _zone_dict(zone)
	return _ambience_cache


static func _zone_dict(zone: AmbienceZone) -> Dictionary:
	return {
		"bed": zone.bed,
		"mid": zone.mid,
		"bed_db": zone.bed_db,
		"mid_db": zone.mid_db,
		"details": zone.details,
		"detail_db": zone.detail_db,
	}


## Imported OGG/WAV files default to one-shot. Ambience/music directors use
## shared loops, so make the intent explicit at the point of playback.
static func ensure_loop(stream: AudioStream) -> void:
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	elif stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		var bytes_per_sample := 2 if wav.format == AudioStreamWAV.FORMAT_16_BITS else 1
		var channels := 2 if wav.stereo else 1
		var samples := wav.data.size() / maxi(1, bytes_per_sample * channels)
		if samples > 0:
			wav.loop_end = samples
