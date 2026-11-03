class_name LabyrinthAudio
extends Node
## Placeholder audio director for the 18 greybox zones of the first fragment.
## It maps player XZ position to a zone, crossfades ambience, changes music
## intensity and emits a few localized one-shots. All assets are placeholders.

const DEFAULT_ZONE_SET := "res://resources/locations/forgotten_shore_labyrinth/audio_zones.tres"
const STORM_ZONES: Array[StringName] = [&"labyrinth_z16", &"labyrinth_z17", &"labyrinth_z18"]

@export var zone_set: LabyrinthAudioZoneSet

var _zones: Array[Dictionary] = []
var _intensity_by_id: Dictionary = {}
var _detail_by_id: Dictionary = {}
var _player: Node3D
var _tide: Node
var _last_zone: StringName = &""
var _high_water := false
var _music_cue: StringName = &""
var _tide_poll := 0.0
var _detail_cooldown := 0.0
var _director: Node
var _state: Node
var _camp_night_done := false


func setup(player: Node3D, tide: Node) -> void:
	_player = player
	_tide = tide
	_apply_zone(_zone_at(_player_position()), true)


func _ready() -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group(&"player") as Node3D
	if _tide == null:
		_tide = get_node_or_null(^"../Tide/TideController")
	if zone_set == null:
		zone_set = load(DEFAULT_ZONE_SET) as LabyrinthAudioZoneSet
	_build_zone_data()
	_director = get_node_or_null(^"/root/AudioDirector")
	_state = get_node_or_null(^"/root/NightmareRunState")
	if _state != null and _state.has_signal(&"flag_changed"):
		if not _state.flag_changed.is_connected(_on_flag_changed):
			_state.flag_changed.connect(_on_flag_changed)
	if _state != null and (_state.has_flag(&"camp_night_seen") or _state.has_flag(&"post_nightmare_demo_completed")):
		call_deferred(&"_apply_camp_night")
	if _director != null and _director.has_method(&"set_reverb_profile"):
		_director.call(&"set_reverb_profile", &"outdoor")
	for zone in _zones:
		if zone["reverb_profile"] != &"":
			var rect: Rect2 = zone["rect"]
			_add_reverb_zone(
				zone["id"],
				Vector3(rect.position.x + rect.size.x * 0.5, 15.0, rect.position.y + rect.size.y * 0.5),
				Vector3(rect.size.x, 60.0, rect.size.y),
				zone["reverb_profile"]
			)


func _build_zone_data() -> void:
	_zones.clear()
	_intensity_by_id.clear()
	_detail_by_id.clear()
	if zone_set == null:
		return
	for zone in zone_set.zones:
		if zone == null:
			continue
		_zones.append({
			"id": zone.id,
			"rect": zone.rect,
			"intensity": zone.intensity,
			"detail": zone.detail,
			"reverb_profile": zone.reverb_profile,
		})
		_intensity_by_id[zone.id] = zone.intensity
		if zone.detail != &"":
			_detail_by_id[zone.id] = zone.detail


func _add_reverb_zone(zone_name: StringName, center: Vector3, size: Vector3, profile: StringName) -> void:
	var zone := ReverbZone.new()
	zone.name = String(zone_name)
	zone.position = center
	zone.profile = profile
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	zone.add_child(shape)
	add_child(zone)


func _process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	_detail_cooldown = maxf(_detail_cooldown - delta, 0.0)
	var zone := _zone_at(_player_position())
	if zone != _last_zone:
		_apply_zone(zone, false)
	_tide_poll = maxf(_tide_poll - delta, 0.0)
	if _tide_poll <= 0.0:
		_tide_poll = 0.25
		_poll_tide()


func _zone_at(position: Vector3) -> StringName:
	var point := Vector2(position.x, position.z)
	for zone in _zones:
		var rect: Rect2 = zone["rect"]
		if rect.has_point(point):
			return zone["id"]
	return &"labyrinth"


func get_zone_id() -> StringName:
	return _last_zone


func get_zone_definitions() -> Array:
	return _zones


func _player_position() -> Vector3:
	return _player.global_position if _player != null and is_instance_valid(_player) else Vector3.ZERO


func _apply_zone(zone: StringName, initial: bool) -> void:
	_last_zone = zone
	var director := get_node_or_null(^"/root/AudioDirector")
	if director == null:
		return
	var camp_zone := _camp_night_done and zone == &"labyrinth_z10"
	var target_music: StringName = &"labyrinth_storm" if zone in STORM_ZONES else (&"camp" if camp_zone else &"labyrinth")
	if target_music != _music_cue:
		_music_cue = target_music
		if director.has_method(&"play_music"):
			director.call(&"play_music", target_music, 4.0)
	if director.has_method(&"play_ambience"):
		director.call(&"play_ambience", &"m1_camp_night" if camp_zone else zone, 4.0 if initial else 2.0)
	if director.has_method(&"set_music_intensity"):
		director.call(&"set_music_intensity", float(_intensity_by_id.get(zone, 0.4)))
	if not initial and _detail_by_id.has(zone) and _detail_cooldown <= 0.0:
		_detail_cooldown = 2.0
		_play_detail(_detail_by_id[zone])


func _play_detail(cue_id: StringName) -> void:
	var director := get_node_or_null(^"/root/AudioDirector")
	if director == null or not director.has_method(&"play_sfx"):
		return
	director.call(&"play_sfx", cue_id, _player_position() + Vector3.UP * 1.2, -6.0)


func _poll_tide() -> void:
	if _tide == null or not is_instance_valid(_tide):
		return
	if not _tide.has_method(&"is_high_water"):
		return
	var high := bool(_tide.call(&"is_high_water"))
	if high == _high_water:
		return
	_high_water = high
	var director := get_node_or_null(^"/root/AudioDirector")
	if director == null or not director.has_method(&"play_sfx"):
		return
	var cue := &"world_tide_surge" if high else &"world_water_drip"
	director.call(&"play_sfx", cue, _player_position() + Vector3.UP * 0.5, -4.0)


func _on_flag_changed(flag_name: StringName, value: bool) -> void:
	if not value:
		return
	if flag_name == &"camp_night_seen" or flag_name == &"post_nightmare_demo_completed" or flag_name == &"demo_m1_completed":
		_apply_camp_night()


func _apply_camp_night() -> void:
	if _camp_night_done:
		return
	_camp_night_done = true
	if _director == null or not is_instance_valid(_director):
		return
	if _director.has_method(&"play_music"):
		_director.call(&"play_music", &"camp", 4.0)
	if _director.has_method(&"set_music_intensity"):
		_director.call(&"set_music_intensity", 0.35)
	if _director.has_method(&"play_ambience"):
		_director.call(&"play_ambience", &"m1_camp_night", 3.0)
	if _director.has_method(&"play_sfx"):
		_director.call(&"play_sfx", &"m1_camp_night_stinger", _player_position() + Vector3.UP * 1.5, -4.0)
	_music_cue = &"camp"


func _exit_tree() -> void:
	if _state != null and _state.has_signal(&"flag_changed"):
		if _state.flag_changed.is_connected(_on_flag_changed):
			_state.flag_changed.disconnect(_on_flag_changed)
	if _director == null or not is_instance_valid(_director):
		return
	if _director.has_method(&"set_reverb_profile"):
		_director.call(&"set_reverb_profile", &"outdoor")
	if _director.has_method(&"stop_music"):
		_director.call(&"stop_music", 1.0)
	if _director.has_method(&"stop_ambience"):
		_director.call(&"stop_ambience", 1.0)
