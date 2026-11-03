class_name MusicDirector
extends Node
## Plays layered music cues. Each layer is a separate AudioStreamPlayer so
## vertical intensity changes do not restart the loop.

signal cue_changed(cue_id: StringName)

const MAX_LAYERS := 6
const SILENT_DB := -80.0

var _cues: Dictionary = {}
var _layers: Array[AudioStreamPlayer] = []
var _current_cue: MusicCue
var _current_id: StringName = &""
var _request := 0
var _intensity := 0.5
var _duck_db := 0.0
var _duck_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_cues = AudioLibrary.music_cues()
	for i in MAX_LAYERS:
		var player := AudioStreamPlayer.new()
		player.name = "Layer%d" % (i + 1)
		player.bus = &"Music"
		player.max_polyphony = 1
		add_child(player)
		_layers.append(player)


func _exit_tree() -> void:
	stop(0.0)
	_cues = {}


func play_cue(cue_id: StringName, fade := 2.0) -> void:
	var cue: MusicCue = _cues.get(cue_id)
	if cue == null:
		push_warning("MusicDirector: unknown cue '%s'" % cue_id)
		return
	if cue_id == _current_id:
		return
	if _duck_tween != null and _duck_tween.is_valid():
		_duck_tween.kill()
	_duck_tween = null

	_request += 1
	var request := _request
	_current_id = cue_id
	_current_cue = cue
	_intensity = 0.5
	_duck_db = 0.0

	if fade > 0.01:
		await _fade_out(fade * 0.35)
		if request != _request:
			return

	for player in _layers:
		player.stop()
		player.stream = null
		player.volume_db = SILENT_DB

	for i in mini(_layers.size(), cue.layers.size()):
		var layer := cue.layers[i]
		if layer.stream == null:
			continue
		var player := _layers[i]
		player.stream = layer.stream
		AudioLibrary.ensure_loop(layer.stream)
		player.volume_db = SILENT_DB
		if AudioLibrary.playback_enabled():
			player.play()

	await _fade_in(fade)
	if request != _request:
		return
	cue_changed.emit(cue_id)


func set_intensity(value: float) -> void:
	_intensity = clampf(value, 0.0, 1.0)
	_apply_volumes(0.35)


func duck(amount_db: float, duration: float) -> void:
	if _duck_tween != null and _duck_tween.is_valid():
		_duck_tween.kill()
	_duck_db = minf(amount_db, 0.0)
	_apply_volumes(0.12)
	_duck_tween = create_tween()
	_duck_tween.tween_interval(maxf(duration, 0.05))
	_duck_tween.tween_callback(func() -> void:
		_duck_db = 0.0
		_apply_volumes(0.25)
	)


func release_duck(fade := 0.25) -> void:
	if _duck_tween != null and _duck_tween.is_valid():
		_duck_tween.kill()
	_duck_db = 0.0
	_apply_volumes(fade)


func stop(fade := 1.0) -> void:
	if _duck_tween != null and _duck_tween.is_valid():
		_duck_tween.kill()
	_duck_tween = null
	_request += 1
	var request := _request
	_current_id = &""
	_current_cue = null
	if fade <= 0.01:
		for player in _layers:
			player.stop()
			player.stream = null
			player.volume_db = SILENT_DB
		return
	await _fade_out(fade)
	if request != _request:
		return
	for player in _layers:
		player.stop()
		player.stream = null
		player.volume_db = SILENT_DB


func current_cue_id() -> StringName:
	return _current_id


func is_playing() -> bool:
	for player in _layers:
		if player.playing:
			return true
	return false


func _apply_volumes(fade: float) -> void:
	if _current_cue == null:
		return
	var count := mini(_layers.size(), _current_cue.layers.size())
	if count <= 0:
		return
	var tween := create_tween().set_parallel()
	for i in count:
		var layer := _current_cue.layers[i]
		var target := _layer_db(layer, _intensity) + _duck_db
		tween.tween_property(_layers[i], "volume_db", target, fade)


func _layer_db(layer: MusicLayer, intensity: float) -> float:
	if intensity <= 0.5:
		return lerpf(layer.min_db, layer.default_db, intensity * 2.0)
	return lerpf(layer.default_db, layer.max_db, (intensity - 0.5) * 2.0)


func _fade_in(fade: float) -> void:
	if _current_cue == null or fade <= 0.01:
		_apply_volumes(0.0)
		return
	var count := mini(_layers.size(), _current_cue.layers.size())
	if count <= 0:
		return
	var tween := create_tween().set_parallel()
	for i in count:
		var layer := _current_cue.layers[i]
		tween.tween_property(_layers[i], "volume_db", _layer_db(layer, _intensity) + _duck_db, fade)
	await tween.finished


func _fade_out(fade: float) -> void:
	if fade <= 0.01:
		return
	var playing: Array[AudioStreamPlayer] = []
	for player in _layers:
		if player.playing:
			playing.append(player)
	if playing.is_empty():
		return
	var tween := create_tween().set_parallel()
	for player in playing:
		tween.tween_property(player, "volume_db", SILENT_DB, fade)
	await tween.finished
