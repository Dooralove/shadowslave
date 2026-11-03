class_name VoiceDirector
extends Node
## Non-positional dialogue voice player. The manifest is intentionally empty
## until generated voice files exist; a missing line is a silent no-op.

signal voice_started(line_id: StringName)
signal voice_finished(line_id: StringName)

const LINES_DIR := "res://assets/audio/voice/lines/"
const BARKS_DIR := "res://assets/audio/voice/barks/"

var manifest: Dictionary = {}
var _player: AudioStreamPlayer
var _current: StringName = &""


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.name = "Voice"
	_player.bus = &"Voice"
	_player.max_polyphony = 1
	add_child(_player)
	_player.finished.connect(_on_finished)


func _exit_tree() -> void:
	stop()
	manifest.clear()


func register_line(line_id: StringName, stream: AudioStream) -> void:
	manifest[line_id] = stream


func register_path(line_id: StringName, path: String) -> void:
	var stream := load(path) as AudioStream
	if stream != null:
		manifest[line_id] = stream


func has_line(line_id: StringName) -> bool:
	return manifest.has(line_id) or not _find_voice_path(line_id).is_empty()


func set_paused(paused: bool) -> void:
	if _player != null:
		_player.stream_paused = paused


func play_line(line_id: StringName, volume_offset_db := 0.0) -> bool:
	if get_tree() != null and get_tree().paused:
		return false
	var stream: AudioStream = manifest.get(line_id)
	if stream == null:
		var path := _find_voice_path(line_id)
		if path.is_empty():
			return false
		stream = load(path) as AudioStream
		if stream == null:
			return false
		manifest[line_id] = stream
	if _current != &"":
		stop()
	_player.stream = stream
	_player.volume_db = volume_offset_db
	_current = line_id
	voice_started.emit(line_id)
	if AudioLibrary.playback_enabled():
		_player.play()
	else:
		# No output device: close the lifecycle immediately so ducking cannot stick.
		voice_finished.emit(line_id)
		_current = &""
	return true


func stop() -> void:
	var finished_id := _current
	_player.stop()
	_player.stream = null
	_current = &""
	if finished_id != &"":
		voice_finished.emit(finished_id)


func current_line() -> StringName:
	return _current


func _find_voice_path(line_id: StringName) -> String:
	var folder := BARKS_DIR if String(line_id).begins_with("bark_") else LINES_DIR
	for extension in [".wav", ".ogg"]:
		var path: String = folder + String(line_id) + String(extension)
		if FileAccess.file_exists(path):
			return path
	return ""


func _on_finished() -> void:
	if _current != &"":
		voice_finished.emit(_current)
	_current = &""
