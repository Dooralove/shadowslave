extends Node3D
## Stage 4 QA: actual player attack loop and F5/F9 quick-save keys.
##   godot --path . res://tools/audit/qa_stage4_input_combat.tscn -- --out=<dir>

const LABYRINTH := "res://scenes/locations/forgotten_shore_labyrinth/labyrinth_first_fragment.tscn"

var _out := ""
var _fails := 0
var _passes := 0
var _scene: Node
var _player: SunnyController


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
	if _out.is_empty():
		push_error("qa_stage4_input_combat: need --out=<dir>")
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	get_tree().root.size = Vector2i(1600, 900)
	await get_tree().process_frame
	await _run()
	print("QA_STAGE4_INPUT_RESULT pass=", _passes, " fail=", _fails)
	get_tree().quit(0 if _fails == 0 else 1)


func _run() -> void:
	NightmareRunState.reset()
	QuestSystem.deactivate_scope()
	var packed := load(LABYRINTH) as PackedScene
	_scene = packed.instantiate()
	get_tree().root.add_child(_scene)
	get_tree().current_scene = _scene
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	_player = get_tree().get_first_node_in_group(&"player") as SunnyController
	_check(_player != null, "player exists")
	await _combat()
	await _quick_save_keys()
	await _finale_after_load()


func _combat() -> void:
	var enemy := _scene.get_node_or_null(^"Gameplay/Runtime/WoundedScavenger") as CarapaceEnemy
	_check(enemy != null, "E01 enemy exists")
	if enemy == null or _player == null:
		return
	# Stand in front of the enemy: attack hitbox is at local -Z with 1.0 reach.
	_player.global_position = enemy.global_position + Vector3(0, 0.05, 1.55)
	_player.velocity = Vector3.ZERO
	_player.visual.rotation.y = 0.0
	if _player.camera_rig != null:
		_player.camera_rig.set_yaw(0.0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var before := enemy.health.current_health
	var attacked := _player.try_attack()
	_check(attacked, "player.try_attack accepts input")
	await _wait(0.55)
	var after := enemy.health.current_health
	_check(after < before, "player attack damages enemy (%.1f -> %.1f)" % [before, after])
	await _capture("I01_player_attack")

	# Finish the enemy with actual attacks, not a debug damage call.
	var swings := 0
	while not enemy.health.is_dead() and swings < 12:
		_player.global_position = enemy.global_position + Vector3(0, 0.05, 1.55)
		_player.visual.rotation.y = 0.0
		_player.try_attack()
		swings += 1
		await _wait(0.55)
	_check(enemy.health.is_dead(), "E01 dies from player attacks (%d swings)" % swings)
	_check(NightmareRunState.has_flag(&"wounded_scavenger_slain"), "E01 kill credit from player attack")
	await _capture("I02_player_kill")


func _quick_save_keys() -> void:
	var save_system := get_node_or_null(^"/root/SaveSystem")
	_check(save_system != null, "SaveSystem exists")
	if save_system == null:
		return
	save_system.call(&"delete_save")
	var saved_pos := _player.global_position
	await _press_key(KEY_F5)
	await _wait(0.3)
	_check(bool(save_system.call(&"has_save")), "F5 writes a quick save")
	var payload: Dictionary = save_system.call(&"read_save")
	_check(not payload.is_empty(), "F5 payload readable")
	_check(String(payload.get("scene", "")) == LABYRINTH, "F5 saves labyrinth scene")

	NightmareRunState.add_currency(&"soul_shard", 9)
	_player.global_position = Vector3(100, 3, 100)
	await _press_key(KEY_F9)
	await _wait_for_scene(LABYRINTH, 8.0)
	_scene = get_tree().current_scene
	_player = get_tree().get_first_node_in_group(&"player") as SunnyController
	_check(_player != null, "F9 reload keeps player")
	if _player != null:
		_check(_player.global_position.distance_to(saved_pos) < 2.0, "F9 restores position")
	_check(NightmareRunState.get_currency(&"soul_shard") < 9, "F9 restores currency from snapshot")
	await _capture("I03_after_f9")


func _finale_after_load() -> void:
	NightmareRunState.clear_flag(&"demo_mode_full")
	NightmareRunState.clear_flag(&"post_nightmare_demo_completed")
	NightmareRunState.set_flag(&"shore_first_day_complete")
	NightmareRunState.set_flag(&"camp_night_seen")
	var zone := _scene.get_node_or_null(^"Gameplay/Triggers/DemoEndZone") as Area3D
	_check(zone != null, "M1 end zone exists")
	if zone == null or _player == null:
		return
	_player.global_position = zone.global_position + Vector3(0, 0.3, 0)
	await _wait_for_scene("res://scenes/campaign/post_nightmare_finale.tscn", 8.0)
	_check(get_tree().current_scene != null and get_tree().current_scene.scene_file_path.ends_with("post_nightmare_finale.tscn"), "M1 finale reached after F9")
	await _capture("I04_m1_finale")


func _press_key(keycode: Key) -> void:
	var down := InputEventKey.new()
	down.physical_keycode = keycode
	down.pressed = true
	Input.parse_input_event(down)
	await get_tree().process_frame
	var up := InputEventKey.new()
	up.physical_keycode = keycode
	up.pressed = false
	Input.parse_input_event(up)
	await get_tree().process_frame


func _wait_for_scene(path: String, seconds: float) -> void:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		var current := get_tree().current_scene
		if current != null and current.scene_file_path == path:
			await get_tree().process_frame
			await get_tree().physics_frame
			await get_tree().physics_frame
			return
		await get_tree().process_frame
	_fail("timeout waiting for scene " + path)
	await _wait(0.2)


func _capture(name: String) -> void:
	await _wait(0.15)
	await RenderingServer.frame_post_draw
	var image := get_tree().root.get_texture().get_image()
	var path := _out.path_join(name + ".png")
	var error := image.save_png(path)
	if error != OK:
		_fail("capture %s error %d" % [name, error])
	else:
		print("QA_STAGE4_INPUT_CAPTURE ", path)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _check(condition: bool, label: String) -> void:
	if condition:
		_passes += 1
		print("QA_STAGE4_INPUT_PASS ", label)
	else:
		_fail("check failed: " + label)


func _fail(message: String) -> void:
	_fails += 1
	print("QA_STAGE4_INPUT_FAIL ", message)
