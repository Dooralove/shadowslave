class_name SfxPool
extends Node
## Fixed-size 3D/2D/UI pools with simple priority and cooldown handling.

signal cue_started(cue: SfxCue)

const POOL_3D := 16
const POOL_2D := 12
const POOL_UI := 4

var _cues: Dictionary = {}
var _players_3d: Array[AudioStreamPlayer3D] = []
var _players_2d: Array[AudioStreamPlayer] = []
var _players_ui: Array[AudioStreamPlayer] = []
var _last_played: Dictionary = {}


func _ready() -> void:
	_cues = AudioLibrary.sfx_cues()
	for i in POOL_3D:
		var player := AudioStreamPlayer3D.new()
		player.name = "Sfx3D_%02d" % (i + 1)
		player.bus = &"SFX"
		player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_LOGARITHMIC
		player.attenuation_filter_cutoff_hz = 5000.0
		player.unit_size = 6.0
		player.max_distance = 60.0
		player.max_polyphony = 1
		add_child(player)
		_players_3d.append(player)
	for i in POOL_2D:
		var player := AudioStreamPlayer.new()
		player.name = "Sfx2D_%02d" % (i + 1)
		player.bus = &"SFX"
		player.max_polyphony = 1
		add_child(player)
		_players_2d.append(player)
	for i in POOL_UI:
		var player := AudioStreamPlayer.new()
		player.name = "Ui_%02d" % (i + 1)
		player.bus = &"UI"
		player.max_polyphony = 1
		add_child(player)
		_players_ui.append(player)


func _exit_tree() -> void:
	stop_all()
	_cues = {}


func set_paused(paused: bool) -> void:
	for player in _players_3d:
		player.stream_paused = paused
	for player in _players_2d:
		player.stream_paused = paused
	# UI sounds intentionally keep playing while the game is paused.


func play(cue_id: StringName, position := Vector3.INF, volume_offset_db := 0.0) -> bool:
	if get_tree() != null and get_tree().paused:
		return false
	var cue: SfxCue = _cues.get(cue_id)
	if cue == null:
		push_warning("SfxPool: unknown cue '%s'" % cue_id)
		return false
	if cue.loop:
		push_warning("SfxPool: '%s' is a loop; use AmbienceDirector" % cue_id)
		return false
	if not _can_play(cue):
		return false
	var spatial := cue.spatial and position.is_finite()
	var pool: Array = _players_3d if spatial else _players_2d
	return _play_in_pool(cue, pool, position if spatial else Vector3.INF, volume_offset_db)


func play_ui(cue_id: StringName, volume_offset_db := 0.0) -> bool:
	var cue: SfxCue = _cues.get(cue_id)
	if cue == null:
		push_warning("SfxPool: unknown UI cue '%s'" % cue_id)
		return false
	if not _can_play(cue):
		return false
	return _play_in_pool(cue, _players_ui, Vector3.INF, volume_offset_db)


func stop_all() -> void:
	for player in _players_3d:
		player.stop()
		player.stream = null
	for player in _players_2d:
		player.stop()
		player.stream = null
	for player in _players_ui:
		player.stop()
		player.stream = null


func _can_play(cue: SfxCue) -> bool:
	if cue.streams.is_empty():
		return false
	var now := Time.get_ticks_msec() / 1000.0
	var last := float(_last_played.get(cue.id, -1000.0))
	if cue.cooldown > 0.0 and now - last < cue.cooldown:
		return false
	if _count_active(cue.id) >= cue.max_instances:
		return false
	return true


func _count_active(cue_id: StringName) -> int:
	var count := 0
	for player in _players_3d:
		if player.playing and player.get_meta(&"cue_id", &"") == cue_id:
			count += 1
	for player in _players_2d:
		if player.playing and player.get_meta(&"cue_id", &"") == cue_id:
			count += 1
	for player in _players_ui:
		if player.playing and player.get_meta(&"cue_id", &"") == cue_id:
			count += 1
	return count


func _play_in_pool(cue: SfxCue, pool: Array, position: Vector3, volume_offset_db: float) -> bool:
	if not _can_replace(pool, int(cue.priority)):
		return false
	var player: Node = _acquire(pool)
	if player == null:
		return false
	var stream = cue.streams[randi() % cue.streams.size()]
	var pitch := randf_range(cue.pitch_min, cue.pitch_max)
	player.stop()
	player.stream = stream
	player.bus = cue.bus
	player.volume_db = cue.volume_db + volume_offset_db
	player.pitch_scale = pitch
	if player is AudioStreamPlayer3D:
		player.global_position = position
		player.max_distance = cue.max_distance
		player.unit_size = cue.unit_size
		var director := get_parent()
		if director != null and director.has_method(&"apply_3d_occlusion"):
			director.call(&"apply_3d_occlusion", player, position)
		else:
			player.attenuation_filter_cutoff_hz = AudioOcclusion.CLEAR_CUTOFF
			player.attenuation_filter_db = AudioOcclusion.CLEAR_DB
	player.set_meta(&"cue_id", cue.id)
	player.set_meta(&"priority", int(cue.priority))
	player.set_meta(&"started", Time.get_ticks_msec())
	if AudioLibrary.playback_enabled():
		player.play()
	cue_started.emit(cue)
	_last_played[cue.id] = Time.get_ticks_msec() / 1000.0
	return true


func _can_replace(pool: Array, incoming_priority: int) -> bool:
	if _has_free(pool):
		return true
	return incoming_priority >= _lowest_active_priority(pool)


func _has_free(pool: Array) -> bool:
	for player in pool:
		if not player.playing:
			return true
	return false


func _lowest_active_priority(pool: Array) -> int:
	var lowest := 999
	for player in pool:
		if player.playing:
			lowest = mini(lowest, int(player.get_meta(&"priority", 0)))
	return lowest


func _acquire(pool: Array) -> Node:
	for player in pool:
		if not player.playing:
			return player
	var best: Node = null
	var best_priority := 999
	var best_started := 9223372036854775807
	for player in pool:
		var priority := int(player.get_meta(&"priority", 0))
		var started := int(player.get_meta(&"started", 0))
		# Steal the least important voice, oldest first among equals.
		if priority < best_priority or (priority == best_priority and started < best_started):
			best = player
			best_priority = priority
			best_started = started
	return best
