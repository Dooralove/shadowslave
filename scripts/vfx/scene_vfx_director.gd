class_name SceneVfxDirector
extends Node
## Applies a SceneVfxProfile to the active scene without touching A03 files.
##
## The director is a child of SceneAudioDirector. It owns only particle scene
## instances; it never changes collision, navigation, markers or gameplay.
## One-shot nodes free themselves, loop nodes are freed on scene change.

const PROFILES := [
	preload("res://resources/audio/scene_vfx_profiles/p05_police_precinct_vfx.tres"),
	preload("res://resources/audio/scene_vfx_profiles/p06_academy_approach_vfx.tres"),
	preload("res://resources/audio/scene_vfx_profiles/p07_academy_gate_vfx.tres"),
	preload("res://resources/audio/scene_vfx_profiles/p08_academy_campus_vfx.tres"),
	preload("res://resources/audio/scene_vfx_profiles/p09_sleeper_center_vfx.tres"),
	preload("res://resources/audio/scene_vfx_profiles/b01_black_sea_vfx.tres"),
	preload("res://resources/audio/scene_vfx_profiles/b02_tide_descent_vfx.tres"),
]

var _profiles: Dictionary = {}
var _active_scene: Node3D
var _active_profile: SceneVfxProfile
var _loops: Array[Node3D] = []
var _state: Node
var _generation := 0
var _next_id := 1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for entry in PROFILES:
		var profile := entry as SceneVfxProfile
		if profile == null:
			continue
		_profiles[profile.location_id] = profile
		if not profile.scene_path.is_empty():
			_profiles[profile.scene_path] = profile
	_state = get_node_or_null(^"/root/NightmareRunState")
	if _state != null and _state.has_signal(&"flag_changed"):
		if not _state.flag_changed.is_connected(_on_flag_changed):
			_state.flag_changed.connect(_on_flag_changed)


func _exit_tree() -> void:
	if _state != null and _state.has_signal(&"flag_changed"):
		if _state.flag_changed.is_connected(_on_flag_changed):
			_state.flag_changed.disconnect(_on_flag_changed)
	clear()


func apply_scene(scene: Node, location_id: StringName) -> void:
	clear()
	_active_scene = scene as Node3D
	if _active_scene == null:
		return
	_active_profile = _profiles.get(location_id, null) as SceneVfxProfile
	if _active_profile == null:
		return
	for event in _active_profile.loops:
		if event != null and event.loop:
			_spawn(event, true)
	for event in _active_profile.enter_effects:
		if event != null:
			if event.delay > 0.0:
				var generation := _generation
				var timer := get_tree().create_timer(event.delay)
				timer.timeout.connect(func() -> void:
					if generation == _generation:
						_spawn(event, event.loop)
				)
			else:
				_spawn(event, event.loop)
	_replay_persistent_events()
	_bind_triggers()


func clear() -> void:
	_generation += 1
	for node in _loops:
		if is_instance_valid(node):
			node.queue_free()
	_loops.clear()
	_active_profile = null


func _bind_triggers() -> void:
	if _active_scene == null:
		return
	for node in _active_scene.find_children("*", "", true, false):
		if node is TriggerZone:
			var trigger := node as TriggerZone
			if not trigger.triggered.is_connected(_on_trigger_triggered):
				trigger.triggered.connect(_on_trigger_triggered.bind(trigger))


func _replay_persistent_events() -> void:
	if _state == null or _active_profile == null:
		return
	for event in _active_profile.flag_effects:
		if event != null and event.persistent and not event.flag.is_empty() and _state.has_flag(event.flag):
			_spawn(event, event.loop)


func _on_trigger_triggered(id: StringName, trigger: TriggerZone) -> void:
	if _active_profile == null:
		return
	for event in _active_profile.trigger_effects:
		if event != null and event.trigger == id:
			_spawn(event, event.loop)


func _on_flag_changed(flag_name: StringName, value: bool) -> void:
	if not value or _active_profile == null:
		return
	for event in _active_profile.flag_effects:
		if event != null and event.flag == flag_name:
			_spawn(event, event.loop)


func _spawn(event: SceneVfxEvent, loop: bool, world_position := Vector3.INF) -> Node3D:
	if event == null or event.scene == null or _active_scene == null or not is_instance_valid(_active_scene):
		return null
	var inst := event.scene.instantiate() as Node3D
	if inst == null:
		return null
	inst.name = "M1Vfx%02d" % _next_id
	_next_id += 1
	var parent: Node = _active_scene
	var attach := _active_scene.get_node_or_null(event.attach_to) as Node3D
	if attach != null:
		parent = attach
	parent.add_child(inst)
	if attach != null:
		inst.position = event.position
	else:
		inst.global_position = world_position if world_position.is_finite() else _active_scene.to_global(event.position)
	inst.rotation.y = event.rotation_y
	inst.scale = Vector3.ONE * (event.scale if event.scale > 0.0 else 1.0)
	var lifetime := 1.5
	for node in inst.find_children("*", "GPUParticles3D", true, false):
		var particles := node as GPUParticles3D
		if particles == null:
			continue
		particles.restart()
		particles.emitting = true
		lifetime = maxf(lifetime, particles.lifetime + 0.25)
	if loop:
		_loops.append(inst)
	else:
		var weak: WeakRef = weakref(inst)
		var timer: SceneTreeTimer = get_tree().create_timer(lifetime)
		timer.timeout.connect(func() -> void:
			var node: Node3D = weak.get_ref() as Node3D
			if node != null and is_instance_valid(node):
				node.queue_free()
		)
	return inst
