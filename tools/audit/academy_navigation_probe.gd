extends SceneTree
## Walks the player through the Academy playable scenes with real input.
## Catches collision blockers that teleport-based probes miss (plinth steps,
## closed doors, wall gaps). Run:
##   godot --headless --path . -s tools/audit/academy_navigation_probe.gd

const GROUNDS := "res://scenes/locations/academy_playable/academy_grounds_playable.tscn"
const SLEEPER := "res://scenes/locations/academy_playable/academy_sleeper_center_playable.tscn"

var _failures := 0
var _player: Node3D
var _state: Node


func _initialize() -> void:
	create_timer(300.0).timeout.connect(_on_watchdog)
	_run.call_deferred()


func _on_watchdog() -> void:
	push_error("NAV PROBE: watchdog timeout")
	quit(2)


func _run() -> void:
	var state := root.get_node_or_null(^"NightmareRunState")
	_state = state
	if state != null:
		state.reset()
	await _load_scene(GROUNDS)
	_check(_player != null, "grounds player present")
	if _player == null:
		_finish()
		return
	# Gate road: approach from the north spawn through the checkpoint.
	await _walk(Vector3(0, 0.2, 110), 0.0, 650)
	_check(_player.global_position.z < 94.0, "gate road is traversable (z=%.1f)" % _player.global_position.z)
	# The red gate must stay closed until the checkpoint guard is passed.
	await _walk(Vector3(0, 0.2, 90), 0.0, 900)
	_check(_player.global_position.z > 70.5, "closed red gate blocks the road (z=%.1f)" % _player.global_position.z)
	_state.set_flag(&"academy_gate_passed")
	await _frames(90)
	# Long gallery to campus entry.
	await _walk(Vector3(0, 0.2, 90), 0.0, 1500)
	_check(_player.global_position.z < 55.0, "gallery to campus is traversable (z=%.1f)" % _player.global_position.z)
	# Sleeper Center plinth and entry.
	await _walk(Vector3(0, 0.2, -30), 0.0, 800)
	_check(_player.global_position.z < -45.0, "sleeper plinth/steps traversable (z=%.1f y=%.2f)" % [_player.global_position.z, _player.global_position.y])
	_check(_player.global_position.y > 1.0, "player climbs the sleeper plinth (y=%.2f)" % _player.global_position.y)
	# East to the dojo.
	await _walk(Vector3(0, 0.2, 10), -PI * 0.5, 1400)
	_check(_player.global_position.x > 34.0, "dojo approach traversable (x=%.1f)" % _player.global_position.x)
	# West to the academic wing.
	await _walk(Vector3(-30, 0.2, -30), PI * 0.5, 600)
	_check(_player.global_position.x < -35.0, "academic approach traversable (x=%.1f)" % _player.global_position.x)
	# Interior.
	await _load_scene(SLEEPER)
	_check(_player != null, "sleeper player present")
	if _player == null:
		_finish()
		return
	await _walk(Vector3(0, 0.2, 10.3), 0.0, 300)
	_check(_player.global_position.z < 5.0, "dormitory entrance traversable (z=%.1f)" % _player.global_position.z)
	await _walk(Vector3(0, 0.2, 0), 0.0, 600)
	_check(_player.global_position.z < -12.0, "dormitory to medical corridor traversable (z=%.1f)" % _player.global_position.z)
	await _walk(Vector3(0, 0.2, -18), -PI * 0.5, 200)
	_check(_player.global_position.x > 3.0, "medical to hollow gallery door traversable (x=%.1f)" % _player.global_position.x)
	await _walk(Vector3(-30, 0.2, -8.6), PI * 0.5, 300)
	_check(_player.global_position.x < -33.0, "room 07 door traversable (x=%.1f)" % _player.global_position.x)
	await _walk(Vector3(-30, 0.2, 9.0), -PI * 0.5, 300)
	_check(_player.global_position.x > -26.5, "laundry door traversable (x=%.1f)" % _player.global_position.x)
	# Real portal walk: approach the Sleeper Center on foot and let the portal
	# change the scene. This also proves the plinth/portal alignment.
	await _load_scene(GROUNDS, false)
	if _player == null:
		_finish()
		return
	_player.global_position = Vector3(0, 0.2, -40)
	_player.rotation.y = 0.0
	var rig := _player.get_node_or_null(^"CameraRig")
	if rig != null and rig.has_method(&"set_yaw"):
		rig.call(&"set_yaw", 0.0)
	await _frames(3)
	Input.action_press(&"move_forward")
	var entered := false
	for _i in 900:
		await physics_frame
		if current_scene != null and current_scene.scene_file_path.ends_with("academy_sleeper_center_playable.tscn"):
			entered = true
			break
	Input.action_release(&"move_forward")
	await _frames(20)
	_check(entered, "walking into the sleeper portal changes scene")
	var new_player := get_first_node_in_group(&"player") as Node3D
	_check(new_player != null, "portal walk keeps the player")
	if new_player != null:
		_check(new_player.global_position.distance_to(Vector3(0, 0.2, 10.3)) < 2.0, "portal walk uses FromGrounds spawn (z=%.1f)" % new_player.global_position.z)
	_finish()


func _load_scene(path: String, disable_portals := true) -> void:
	if current_scene != null:
		current_scene.queue_free()
		current_scene = null
		await _frames(4)
	var packed := load(path) as PackedScene
	if packed == null:
		push_error("NAV PROBE: cannot load " + path)
		_finish()
		return
	var scene := packed.instantiate()
	root.add_child(scene)
	current_scene = scene
	await _frames(8)
	if disable_portals:
		for portal in scene.find_children("*", "LevelPortal", true, false):
			portal.enabled = false
	_player = get_first_node_in_group(&"player") as Node3D
	await _frames(2)


func _walk(start: Vector3, yaw: float, frames: int) -> void:
	_player.global_position = start
	_player.rotation.y = yaw
	if _player is CharacterBody3D:
		(_player as CharacterBody3D).velocity = Vector3.ZERO
	var rig := _player.get_node_or_null(^"CameraRig")
	if rig != null and rig.has_method(&"set_yaw"):
		rig.call(&"set_yaw", yaw)
	await _frames(3)
	Input.action_press(&"move_forward")
	for _i in frames:
		await physics_frame
	Input.action_release(&"move_forward")
	await _frames(3)


func _frames(count: int) -> void:
	for _i in count:
		await process_frame


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS ", label)
	else:
		_failures += 1
		push_error("FAIL " + label)


func _finish() -> void:
	Input.action_release(&"move_forward")
	print("ACADEMY_NAVIGATION_PROBE failures=", _failures)
	quit(0 if _failures == 0 else 1)
