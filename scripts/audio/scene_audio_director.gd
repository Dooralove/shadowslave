class_name SceneAudioDirector
extends Node
## Runtime bridge between A03 scenes and the single AudioDirector.
##
## The post-Nightmare locations are built by A03 and must not be edited by
## A09. This node watches current_scene, loads an optional typed profile and
## applies music, ambience, reverb, interaction cues, local loops, trigger
## events and flag events. If a scene has no profile it is a strict no-op, so
## existing Labyrinth and campaign audio keep their own directors.

const PROFILES := [
	preload("res://resources/audio/scene_profiles/p05_police_precinct.tres"),
	preload("res://resources/audio/scene_profiles/p06_academy_approach.tres"),
	preload("res://resources/audio/scene_profiles/p07_academy_gate.tres"),
	preload("res://resources/audio/scene_profiles/p08_academy_campus.tres"),
	preload("res://resources/audio/scene_profiles/p09_sleeper_center.tres"),
	preload("res://resources/audio/scene_profiles/b01_black_sea.tres"),
	preload("res://resources/audio/scene_profiles/b02_tide_descent.tres"),
]

var _profiles: Dictionary = {}
var _active_scene: Node
var _active_profile: SceneAudioProfile
var _last_scene: Node
var _local_loops: Array[AudioStreamPlayer3D] = []
var _vfx: SceneVfxDirector
var _state: Node
var _dialogue_runner: DialogueRunner
var _generation := 0
var _poll := 0.0
var _occlusion_poll := 0.0
const SCENE_POLL_INTERVAL := 0.05
var _next_loop_id := 1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_profiles()
	_state = get_node_or_null(^"/root/NightmareRunState")
	if _state != null and _state.has_signal(&"flag_changed"):
		if not _state.flag_changed.is_connected(_on_flag_changed):
			_state.flag_changed.connect(_on_flag_changed)
	get_tree().node_added.connect(_on_node_added)
	_vfx = SceneVfxDirector.new()
	_vfx.name = "SceneVfxDirector"
	add_child(_vfx)


func _exit_tree() -> void:
	if _state != null and _state.has_signal(&"flag_changed"):
		if _state.flag_changed.is_connected(_on_flag_changed):
			_state.flag_changed.disconnect(_on_flag_changed)
	if get_tree() != null and get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.disconnect(_on_node_added)
	_clear_active()
	if _vfx != null:
		_vfx.queue_free()


func _process(delta: float) -> void:
	# Polling is deliberate: current_scene is set after the scene is added, and
	# a timer/autoload signal would still need a one-frame guard. The check is
	# cheap and only runs four times per second.
	_poll -= delta
	if _poll <= 0.0:
		_poll = SCENE_POLL_INTERVAL
		var scene := get_tree().current_scene
		if scene != _last_scene:
			_last_scene = scene
			_apply_scene(scene)
	_occlusion_poll -= delta
	if _occlusion_poll <= 0.0:
		_occlusion_poll = 0.5
		_update_loop_occlusion()


func _load_profiles() -> void:
	for entry in PROFILES:
		var profile := entry as SceneAudioProfile
		if profile == null:
			continue
		_profiles[profile.location_id] = profile
		if not profile.scene_path.is_empty():
			_profiles[profile.scene_path] = profile


func _find_profile(scene: Node) -> SceneAudioProfile:
	if scene == null:
		return null
	var raw_location: Variant = scene.get(&"location_id")
	if raw_location != null:
		var location := StringName(raw_location)
		if _profiles.has(location):
			return _profiles[location] as SceneAudioProfile
	var path := scene.scene_file_path
	if not path.is_empty() and _profiles.has(path):
		return _profiles[path] as SceneAudioProfile
	return null


func _apply_scene(scene: Node) -> void:
	_clear_active()
	_active_scene = scene
	if scene == null:
		return
	var profile := _find_profile(scene)
	if profile == null:
		return
	_active_profile = profile
	_apply_bus(profile)
	_bind_interactables()
	_bind_triggers()
	_bind_dialogue()
	_spawn_loops(profile)
	_schedule_enter_events(profile)
	_replay_persistent_events(profile)
	if _vfx != null:
		_vfx.apply_scene(scene, profile.location_id)


func _apply_bus(profile: SceneAudioProfile) -> void:
	var audio := get_node_or_null(^"/root/AudioDirector")
	if audio == null:
		return
	if not profile.music_id.is_empty() and audio.has_method(&"play_music"):
		audio.call(&"play_music", profile.music_id, profile.music_fade)
	if not profile.ambience_id.is_empty() and audio.has_method(&"play_ambience"):
		audio.call(&"play_ambience", profile.ambience_id, profile.ambience_fade)
	if audio.has_method(&"set_music_intensity"):
		audio.call(&"set_music_intensity", profile.music_intensity)
	if audio.has_method(&"set_reverb_profile"):
		audio.call(&"set_reverb_profile", profile.reverb_profile)


func _clear_active() -> void:
	_generation += 1
	for player in _local_loops:
		if is_instance_valid(player):
			player.stop()
			player.queue_free()
	_local_loops.clear()
	if _vfx != null:
		_vfx.clear()
	_active_profile = null
	_dialogue_runner = null


func _belongs_to_active(node: Node) -> bool:
	return _active_scene != null and (node == _active_scene or _active_scene.is_ancestor_of(node))


func _bind_interactables() -> void:
	for node in get_tree().get_nodes_in_group(&"interactable"):
		if node is Interactable and _belongs_to_active(node):
			_assign_interactable(node as Interactable)


func _assign_interactable(interactable: Interactable) -> void:
	if _active_profile == null or interactable == null:
		return
	var raw: Variant = _active_profile.interactions.get(interactable.interaction_id, null)
	if raw == null:
		return
	var cue := StringName(_first_value(raw))
	if cue.is_empty():
		return
	interactable.interact_cue = cue
	interactable.interact_volume_db = -4.0


func _bind_triggers() -> void:
	if _active_scene == null:
		return
	for node in _active_scene.find_children("*", "", true, false):
		if node is TriggerZone:
			_connect_trigger(node as TriggerZone)


func _connect_trigger(trigger: TriggerZone) -> void:
	if trigger == null or not _belongs_to_active(trigger):
		return
	if not trigger.triggered.is_connected(_on_trigger_triggered):
		trigger.triggered.connect(_on_trigger_triggered.bind(trigger))


func _bind_dialogue() -> void:
	var runner := get_tree().get_first_node_in_group(&"dialogue_runner") as DialogueRunner
	if runner != null:
		_connect_dialogue(runner)


func _connect_dialogue(runner: DialogueRunner) -> void:
	if runner == null or _dialogue_runner == runner:
		return
	_dialogue_runner = runner
	if not runner.line_started.is_connected(_on_dialogue_line_started):
		runner.line_started.connect(_on_dialogue_line_started)
	if not runner.finished.is_connected(_on_dialogue_finished):
		runner.finished.connect(_on_dialogue_finished)


func _on_node_added(node: Node) -> void:
	if _active_profile == null or not _belongs_to_active(node):
		return
	if node is Interactable:
		_assign_interactable(node as Interactable)
	elif node is TriggerZone:
		_connect_trigger(node as TriggerZone)
	elif node is DialogueRunner:
		_connect_dialogue(node as DialogueRunner)


func _on_trigger_triggered(id: StringName, trigger: TriggerZone) -> void:
	if _active_profile == null:
		return
	for event in _active_profile.trigger_events:
		if event != null and event.trigger == id:
			_play_event(event, _event_position(event))


func _on_flag_changed(flag_name: StringName, value: bool) -> void:
	if not value or _active_profile == null:
		return
	for event in _active_profile.flag_events:
		if event != null and event.flag == flag_name:
			_play_event(event, _event_position(event))


func _on_dialogue_line_started(_line: Variant, _index: int, _count: int) -> void:
	var audio := get_node_or_null(^"/root/AudioDirector")
	if audio != null:
		if audio.has_method(&"duck_music"):
			audio.call(&"duck_music", -8.0, 60.0)
		var ambience: Node = audio.get("ambience") as Node
		if ambience != null and ambience.has_method(&"duck"):
			ambience.call(&"duck", -4.0, 60.0)
	_duck_local_loops(-4.0, 0.12)


func _on_dialogue_finished() -> void:
	var audio := get_node_or_null(^"/root/AudioDirector")
	if audio == null:
		return
	var music: Node = audio.get("music") as Node
	if music != null and music.has_method(&"release_duck"):
		music.call(&"release_duck", 0.35)
	var ambience: Node = audio.get("ambience") as Node
	if ambience != null and ambience.has_method(&"release_duck"):
		ambience.call(&"release_duck", 0.35)
	_duck_local_loops(0.0, 0.35)


func _spawn_loops(profile: SceneAudioProfile) -> void:
	for event in profile.loops:
		if event != null:
			_spawn_loop(event)


func _spawn_loop(event: SceneAudioEvent) -> void:
	var cue: SfxCue = AudioLibrary.sfx_cues().get(event.cue_id) as SfxCue
	if cue == null or cue.streams.is_empty():
		push_warning("SceneAudioDirector: missing loop cue '%s'" % event.cue_id)
		return
	var player := AudioStreamPlayer3D.new()
	player.name = "SceneLoop%02d" % _next_loop_id
	_next_loop_id += 1
	player.stream = cue.streams[0]
	AudioLibrary.ensure_loop(player.stream)
	player.bus = &"Ambience"
	player.volume_db = cue.volume_db + event.volume_db
	player.unit_size = event.unit_size if event.unit_size > 0.0 else cue.unit_size
	player.max_distance = event.max_distance if event.max_distance > 0.0 else cue.max_distance
	player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_LOGARITHMIC
	add_child(player)
	player.global_position = _event_position(event)
	player.set_meta(&"base_db", player.volume_db)
	if AudioLibrary.playback_enabled():
		player.play()
	_local_loops.append(player)


func _schedule_enter_events(profile: SceneAudioProfile) -> void:
	for event in profile.enter_events:
		if event == null:
			continue
		if event.delay <= 0.0:
			_play_event(event, _event_position(event))
			continue
		var generation := _generation
		var timer := get_tree().create_timer(event.delay)
		timer.timeout.connect(func() -> void:
			if generation == _generation:
				_play_event(event, _event_position(event))
		)


func _replay_persistent_events(profile: SceneAudioProfile) -> void:
	if _state == null:
		return
	for event in profile.flag_events:
		if event != null and event.persistent and not event.flag.is_empty() and _state.has_flag(event.flag):
			_play_event(event, _event_position(event))


func _play_event(event: SceneAudioEvent, position := Vector3.INF) -> void:
	if event == null:
		return
	if event.loop:
		_spawn_loop(event)
		return
	var audio := get_node_or_null(^"/root/AudioDirector")
	if audio == null or not audio.has_method(&"play_sfx"):
		return
	var target := position if position.is_finite() else _event_position(event)
	audio.call(&"play_sfx", event.cue_id, target, event.volume_db)


func _event_position(event: SceneAudioEvent) -> Vector3:
	if _active_scene is Node3D:
		return (_active_scene as Node3D).to_global(event.position)
	return event.position


func _update_loop_occlusion() -> void:
	if _active_profile == null or _local_loops.is_empty():
		return
	var audio := get_node_or_null(^"/root/AudioDirector")
	if audio == null or not audio.has_method(&"apply_3d_occlusion"):
		return
	for player in _local_loops:
		if is_instance_valid(player) and player.playing:
			audio.call(&"apply_3d_occlusion", player, player.global_position)


func _duck_local_loops(amount_db: float, fade: float) -> void:
	for player in _local_loops:
		if not is_instance_valid(player):
			continue
		var base := float(player.get_meta(&"base_db", player.volume_db))
		var target := base + amount_db
		var tween := create_tween()
		tween.tween_property(player, "volume_db", target, fade)


func _first_value(value: Variant) -> String:
	if value is Array:
		return String(value[0]) if not value.is_empty() else ""
	return String(value)
