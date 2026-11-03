class_name AmbienceDirector
extends Node
## Crossfades a two-layer ambience bed for the current location.

signal zone_changed(zone_id: StringName)

const SILENT_DB := -80.0

var _zones: Dictionary = {}
var _bed: AudioStreamPlayer
var _mid: AudioStreamPlayer
var _detail: AudioStreamPlayer
var _detail_streams: Array[AudioStream] = []
var _detail_base_db := -18.0
var _detail_timer := 0.0
var _rng := RandomNumberGenerator.new()
var _current_id: StringName = &""
var _request := 0
var _base_bed_db := -14.0
var _base_mid_db := -20.0
var _duck_db := 0.0
var _duck_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	_zones = AudioLibrary.ambience_zones()
	_bed = _make_player("Bed")
	_mid = _make_player("Mid")
	_detail = _make_player("Detail")


func _exit_tree() -> void:
	stop(0.0)
	_zones = {}


func play_zone(zone_id: StringName, fade := 2.0) -> void:
	var zone: Dictionary = _zones.get(zone_id, {})
	if zone.is_empty():
		push_warning("AmbienceDirector: unknown zone '%s'" % zone_id)
		return
	if zone_id == _current_id:
		return

	_request += 1
	var request := _request
	_current_id = zone_id

	if fade > 0.01:
		await _fade_out(fade * 0.35)
		if request != _request:
			return

	var bed_db := float(zone.get("bed_db", -14.0))
	var mid_db := float(zone.get("mid_db", -20.0))
	_base_bed_db = bed_db
	_base_mid_db = mid_db
	_set_player(_bed, zone.get("bed"), bed_db, fade > 0.01)
	_set_player(_mid, zone.get("mid"), mid_db, fade > 0.01)
	_prepare_details(zone)

	if fade <= 0.01:
		return
	if _bed.stream == null and _mid.stream == null:
		return
	var tween := create_tween().set_parallel()
	if _bed.stream != null:
		tween.tween_property(_bed, "volume_db", bed_db + _duck_db, fade)
	if _mid.stream != null:
		tween.tween_property(_mid, "volume_db", mid_db + _duck_db, fade)
	await tween.finished
	if request != _request:
		return
	zone_changed.emit(zone_id)


func _process(delta: float) -> void:
	if _detail == null or _detail.stream == null or _detail_streams.is_empty():
		return
	if _detail.playing:
		return
	_detail_timer = maxf(_detail_timer - delta, 0.0)
	if _detail_timer > 0.0:
		return
	_detail.volume_db = _detail_base_db + _duck_db
	if AudioLibrary.playback_enabled():
		_detail.play()
	_detail_timer = _rng.randf_range(8.0, 18.0)


func _prepare_details(zone: Dictionary) -> void:
	_detail.stop()
	_detail.stream = null
	_detail_streams.clear()
	var raw: Variant = zone.get("details", [])
	if raw is Array:
		for stream in raw:
			if stream is AudioStream:
				_detail_streams.append(stream)
	_detail_base_db = float(zone.get("detail_db", -18.0))
	_detail_timer = _rng.randf_range(3.0, 7.0)
	if _detail_streams.is_empty():
		return
	var randomizer := AudioStreamRandomizer.new()
	randomizer.random_pitch = 0.06
	randomizer.random_volume_offset_db = -2.0
	for stream in _detail_streams:
		randomizer.add_stream(-1, stream)
	_detail.stream = randomizer
	_detail.volume_db = _detail_base_db


func duck(amount_db: float, duration: float) -> void:
	if _duck_tween != null and _duck_tween.is_valid():
		_duck_tween.kill()
	_duck_db = minf(amount_db, 0.0)
	_apply_duck(0.12)
	_duck_tween = create_tween()
	_duck_tween.tween_interval(maxf(duration, 0.05))
	_duck_tween.tween_callback(func() -> void:
		_duck_db = 0.0
		_apply_duck(0.25)
	)


func release_duck(fade := 0.25) -> void:
	if _duck_tween != null and _duck_tween.is_valid():
		_duck_tween.kill()
	_duck_tween = null
	_duck_db = 0.0
	_apply_duck(fade)


func _apply_duck(fade: float) -> void:
	var tween := create_tween().set_parallel()
	var count := 0
	if _bed != null and _bed.stream != null:
		tween.tween_property(_bed, "volume_db", _base_bed_db + _duck_db, fade)
		count += 1
	if _mid != null and _mid.stream != null:
		tween.tween_property(_mid, "volume_db", _base_mid_db + _duck_db, fade)
		count += 1
	if _detail != null and _detail.stream != null and _detail.playing:
		tween.tween_property(_detail, "volume_db", _detail_base_db + _duck_db, fade)
		count += 1
	if count == 0:
		tween.kill()


func stop(fade := 1.0) -> void:
	if _duck_tween != null and _duck_tween.is_valid():
		_duck_tween.kill()
	_duck_tween = null
	_duck_db = 0.0
	_request += 1
	var request := _request
	_current_id = &""
	if fade <= 0.01:
		_bed.stop()
		_mid.stop()
		_detail.stop()
		_bed.stream = null
		_mid.stream = null
		_detail.stream = null
		_detail_streams.clear()
		return
	await _fade_out(fade)
	if request != _request:
		return
	_bed.stop()
	_mid.stop()
	_detail.stop()
	_bed.stream = null
	_mid.stream = null
	_detail.stream = null
	_detail_streams.clear()


func current_zone_id() -> StringName:
	return _current_id


func _make_player(player_name: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = player_name
	player.bus = &"Ambience"
	player.max_polyphony = 1
	add_child(player)
	return player


func _set_player(player: AudioStreamPlayer, stream: AudioStream, volume_db: float, start_silent: bool) -> void:
	player.stop()
	player.stream = stream
	if stream != null:
		AudioLibrary.ensure_loop(stream)
	player.volume_db = (SILENT_DB if start_silent else volume_db) if stream != null else SILENT_DB
	if stream != null and AudioLibrary.playback_enabled():
		player.play()


func _fade_out(fade: float) -> void:
	var playing: Array[AudioStreamPlayer] = []
	for player in [_bed, _mid, _detail]:
		if player.playing:
			playing.append(player)
	if playing.is_empty():
		return
	var tween := create_tween().set_parallel()
	for player in playing:
		tween.tween_property(player, "volume_db", SILENT_DB, fade)
	await tween.finished
