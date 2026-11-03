extends Node
## Autoload CutsceneDirector: один владелец жизненного цикла кат-сцены.

signal cutscene_started(definition: CutsceneDefinition)
signal cutscene_finished(definition: CutsceneDefinition, result: int)
signal cutscene_skipped(definition: CutsceneDefinition, elapsed: float)
signal cutscene_aborted(definition: CutsceneDefinition, reason: String)
signal shot_changed(shot_id: StringName)
signal skip_availability_changed(available: bool)
signal state_changed(state: int)
signal event_received(name: StringName)

const HISTORY_PATH := "user://cutscene_history.cfg"
const HARD_TIMEOUT_EXTRA := 5.0
const DEFAULT_SKIP_HOLD := 0.6
const KEY_SCENE_SKIP_HOLD := 1.2

var fast_mode := false
var debug_force_skip := false

var _ui: CutsceneUI
var _current_run: CutsceneRun
var _last_result := -1
var _seen: Dictionary = {}
var _skip_held := false
var _skip_hold := 0.0
var _skip_prompt_visible := false
var _event_buffer: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_input_actions()
	_load_history()
	_ui = CutsceneUI.new()
	_ui.name = "CutsceneUI"
	add_child(_ui)
	set_process(false)
	set_process_unhandled_input(false)


func start_stage(stage: CutsceneStage) -> bool:
	return _begin_run(stage) != null


func play_stage(stage: CutsceneStage) -> int:
	var run := _begin_run(stage)
	if run == null:
		return _last_result if _last_result >= 0 else CutsceneTypes.Result.INVALID
	await run.finished
	return run.result


func is_playing() -> bool:
	return _current_run != null


func is_locked() -> bool:
	return _current_run != null and _current_run.state == CutsceneTypes.State.PLAYING


func get_current() -> CutsceneDefinition:
	return _current_run.definition if _current_run != null else null


func get_current_run() -> CutsceneRun:
	return _current_run


func get_last_result() -> int:
	return _last_result


func get_state() -> int:
	return _current_run.state if _current_run != null else CutsceneTypes.State.IDLE


func get_debug_state() -> Dictionary:
	var run := _current_run
	return {
		"state": CutsceneTypes.State.keys()[get_state()],
		"id": run.definition.id if run != null and run.definition != null else &"",
		"elapsed": run.elapsed if run != null else 0.0,
		"shot": run.current_shot if run != null else &"",
		"skip_available": can_skip(),
		"locked": is_locked(),
		"result": run.result if run != null else _last_result,
		"actors": run.actors.keys() if run != null else [],
		"abort_reason": run.abort_reason if run != null else "",
	}


func request_skip(force := false) -> bool:
	var run := _current_run
	if run == null or run.state != CutsceneTypes.State.PLAYING:
		return false
	if not force and not can_skip():
		return false
	run.cancelled = true
	if run.context != null:
		run.context.cancelled = true
	_cancel_visuals(run)
	if run.script_node != null and is_instance_valid(run.script_node):
		run.script_node.queue_free()
	cutscene_skipped.emit(run.definition, run.elapsed)
	_finish_run(run, CutsceneTypes.Result.SKIPPED)
	return true


func abort(reason := "") -> void:
	var run := _current_run
	if run == null:
		return
	run.abort_reason = reason
	run.cancelled = true
	if run.context != null:
		run.context.cancelled = true
	_cancel_visuals(run)
	if run.script_node != null and is_instance_valid(run.script_node):
		run.script_node.queue_free()
	cutscene_aborted.emit(run.definition, reason)
	_finish_run(run, CutsceneTypes.Result.ABORTED)


func can_skip() -> bool:
	var run := _current_run
	if run == null or run.definition == null:
		return false
	if debug_force_skip:
		return true
	if run.elapsed < run.definition.min_skip_time:
		return false
	match run.definition.skip_policy:
		CutsceneDefinition.SkipPolicy.NEVER:
			return false
		CutsceneDefinition.SkipPolicy.AFTER_FIRST_VIEW:
			return has_seen(run.definition.id)
		CutsceneDefinition.SkipPolicy.ALWAYS:
			return true
		CutsceneDefinition.SkipPolicy.DEBUG_ONLY:
			return OS.is_debug_build()
	return false


func mark_seen(id: StringName) -> void:
	if id == &"":
		return
	_seen[id] = true
	_save_history()


func has_seen(id: StringName) -> bool:
	return _seen.has(id)


func clear_history() -> void:
	_seen.clear()
	if FileAccess.file_exists(HISTORY_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(HISTORY_PATH))


func find_actor(id: StringName) -> CutsceneActor:
	for node in get_tree().get_nodes_in_group(&"cutscene_actor"):
		var actor := node as CutsceneActor
		if actor != null and actor.actor_id == id:
			return actor
	return null


func notify_event(event_name: StringName) -> void:
	if event_name == &"":
		return
	_event_buffer[event_name] = Time.get_ticks_msec()
	event_received.emit(event_name)


func wait_for_event(event_name: StringName, timeout := 10.0) -> bool:
	if event_name == &"":
		return false
	var deadline := Time.get_ticks_msec() + int(maxf(timeout, 0.0) * 1000.0)
	if _event_buffer.has(event_name):
		var age := Time.get_ticks_msec() - int(_event_buffer[event_name])
		if age <= 1000:
			return true
	while Time.get_ticks_msec() <= deadline:
		var received: StringName = await event_received
		if received == event_name:
			return true
	return false


func create_tween_for_script(run: CutsceneRun) -> Tween:
	if run == null or run.script_node == null or not is_instance_valid(run.script_node):
		return null
	return run.script_node.create_tween()


func commit_run(run: CutsceneRun) -> void:
	if run != null:
		_apply_completion(run)


func reset_for_tests() -> void:
	if _current_run != null:
		_current_run.cancelled = true
		_finish_run(_current_run, CutsceneTypes.Result.ABORTED)
	_current_run = null
	_seen.clear()
	_last_result = -1
	fast_mode = false
	_skip_held = false
	_skip_hold = 0.0
	_skip_prompt_visible = false
	if _ui != null:
		_ui.set_fast_mode(false)
		_ui.hide_for_idle()
		_ui.set_hud_visible(true)
	set_process(false)
	set_process_unhandled_input(false)


func _begin_run(stage: CutsceneStage) -> CutsceneRun:
	if _current_run != null:
		_last_result = CutsceneTypes.Result.BUSY
		return null
	if stage == null or not is_instance_valid(stage) or not stage.is_inside_tree():
		_last_result = CutsceneTypes.Result.INVALID
		push_error("CutsceneDirector: stage is null or not in tree")
		return null
	var definition := stage.definition
	if definition == null:
		_last_result = CutsceneTypes.Result.INVALID
		push_error("CutsceneDirector: stage '%s' has no definition" % stage.name)
		return null
	if definition.cutscene_script == null:
		_last_result = CutsceneTypes.Result.INVALID
		push_error("CutsceneDirector: definition '%s' has no cutscene_script" % definition.id)
		return null
	if not definition.cutscene_script.can_instantiate():
		_last_result = CutsceneTypes.Result.INVALID
		push_error("CutsceneDirector: cutscene_script for '%s' cannot be instantiated" % definition.id)
		return null
	if definition.max_duration <= 0.0:
		_last_result = CutsceneTypes.Result.INVALID
		push_error("CutsceneDirector: definition '%s' has invalid max_duration" % definition.id)
		return null

	var state := get_node_or_null(^"/root/NightmareRunState")
	if definition.once and state != null and bool(state.call(&"has_flag", definition.get_once_flag())):
		_last_result = CutsceneTypes.Result.ALREADY_COMPLETED
		return null
	if not definition.has_required_flags(state):
		_last_result = CutsceneTypes.Result.BLOCKED
		return null
	if definition.has_blocking_flags(state):
		_last_result = CutsceneTypes.Result.BLOCKED
		return null

	var run := CutsceneRun.new()
	run.definition = definition
	run.stage = stage
	run.scene = get_tree().current_scene
	if run.scene == null:
		run.scene = stage
	run.ui = _ui
	run.ui_snapshot = _ui.snapshot()
	_snapshot_player(run)
	_lock_player(run)
	_ui.set_fast_mode(fast_mode)
	_ui.begin_run(definition)
	if definition.hide_hud:
		_ui.set_hud_visible(false)

	var player_camera := _get_player_camera(run.player)
	run.camera = CutsceneCamera3D.new()
	run.camera.name = "CutsceneCamera"
	run.camera.stage = stage
	run.camera.scene = run.scene
	run.camera.player_camera = player_camera
	run.camera.fast_mode = fast_mode
	run.camera.shot_changed.connect(_on_shot_changed)
	run.scene.add_child(run.camera)
	run.camera.setup_from_camera(player_camera)
	run.camera.make_current()

	var script_node := CutsceneScript.new()
	script_node.name = "CutsceneScript"
	script_node.set_script(definition.cutscene_script)
	stage.add_child(script_node)
	run.script_node = script_node

	var context := CutsceneContext.new()
	context.director = self
	context.run = run
	context.stage = stage
	context.scene = run.scene
	context.player = run.player
	context.camera = run.camera
	context.ui = _ui
	context.fast = fast_mode
	run.context = context

	_current_run = run
	_last_result = -1
	run.state = CutsceneTypes.State.PLAYING
	_skip_held = false
	_skip_hold = 0.0
	_skip_prompt_visible = can_skip()
	_ui.show_skip_prompt(_skip_prompt_visible)
	set_process(true)
	set_process_unhandled_input(true)
	cutscene_started.emit(definition)
	state_changed.emit(CutsceneTypes.State.PLAYING)
	call_deferred(&"_execute_run", run)
	return run


func _execute_run(run: CutsceneRun) -> void:
	if run == null or run.finished_emitted or run.cancelled:
		return
	if run.script_node == null or not is_instance_valid(run.script_node):
		_finish_run(run, CutsceneTypes.Result.ABORTED)
		return
	@warning_ignore("redundant_await")
	await run.script_node.run(run.context)
	if run.finished_emitted or run.cancelled:
		return
	_finish_run(run, CutsceneTypes.Result.COMPLETED)


func _process(delta: float) -> void:
	var run := _current_run
	if run == null:
		return
	run.elapsed += delta
	var available := can_skip()
	if available != _skip_prompt_visible:
		_skip_prompt_visible = available
		_ui.show_skip_prompt(available)
		skip_availability_changed.emit(available)
	if _skip_held and available:
		_skip_hold += delta
		var hold_time := _get_skip_hold_time()
		_ui.set_skip_progress(_skip_hold / hold_time if hold_time > 0.0 else 1.0)
		if _skip_hold >= hold_time:
			request_skip(true)
			return
	elif _skip_hold != 0.0:
		_skip_hold = 0.0
		_ui.set_skip_progress(0.0)
	if run.elapsed > run.definition.max_duration + HARD_TIMEOUT_EXTRA:
		abort("timeout")


func _unhandled_input(event: InputEvent) -> void:
	if _current_run == null:
		return
	if event.is_action_pressed(&"cutscene_skip") and can_skip():
		_skip_held = true
		_skip_hold = 0.0
		get_viewport().set_input_as_handled()
	elif event.is_action_released(&"cutscene_skip"):
		_skip_held = false
		_skip_hold = 0.0
		_ui.set_skip_progress(0.0)


func _finish_run(run: CutsceneRun, result: int) -> void:
	if run == null or run.finished_emitted:
		return
	run.finished_emitted = true
	run.result = result
	run.state = CutsceneTypes.State.CLEANING
	_cancel_visuals(run)

	if result == CutsceneTypes.Result.SKIPPED or result == CutsceneTypes.Result.ABORTED:
		_restore_actors(run)
		_restore_props(run)
		_apply_skip_end(run)
	else:
		_finalize_actors(run)

	_apply_completion(run)
	_restore_camera(run)
	_restore_hud(run)
	_unlock_player(run)

	if run.camera != null and is_instance_valid(run.camera):
		run.camera.queue_free()
	run.camera = null
	if run.script_node != null and is_instance_valid(run.script_node):
		run.script_node.queue_free()
	run.script_node = null

	if result == CutsceneTypes.Result.COMPLETED:
		mark_seen(run.definition.id)

	_current_run = null
	_last_result = result
	_skip_held = false
	_skip_hold = 0.0
	_skip_prompt_visible = false
	_ui.show_skip_prompt(false)
	_ui.hide_for_idle()
	set_process(false)
	set_process_unhandled_input(false)
	cutscene_finished.emit(run.definition, result)
	state_changed.emit(CutsceneTypes.State.IDLE)
	run.state = CutsceneTypes.State.FINISHED
	run.finished.emit(result)


func _cancel_visuals(run: CutsceneRun) -> void:
	if _ui != null:
		_ui.cancel_dialogue()
		_ui.cancel_tweens()
	if run.camera != null and is_instance_valid(run.camera):
		run.camera.cancel_tweens()
	for actor in run.actors.values():
		if is_instance_valid(actor):
			actor.cancel_motion()


func _snapshot_player(run: CutsceneRun) -> void:
	run.player = get_tree().get_first_node_in_group(&"player") as SunnyController
	if run.player == null:
		return
	var snapshot := {
		"mouse_mode": Input.mouse_mode,
		"input_enabled": run.player.input_enabled,
		"combat_enabled": run.player.combat_enabled,
		"physics": run.player.is_physics_processing(),
		"forced_velocity": run.player.forced_velocity,
		"unhandled_input": run.player.is_processing_unhandled_input(),
		"camera_yaw": 0.0,
		"camera_pitch": 0.0,
		"camera_input": true,
		"camera_look": true,
		"visual_yaw": 0.0,
	}
	if run.player.camera_rig != null:
		snapshot["camera_yaw"] = run.player.camera_rig.yaw
		snapshot["camera_pitch"] = run.player.camera_rig.pitch
		snapshot["camera_input"] = run.player.camera_rig.input_enabled
		snapshot["camera_look"] = run.player.camera_rig.look_enabled
	if run.player.visual != null:
		snapshot["visual_yaw"] = run.player.visual.rotation.y
	run.player_snapshot = snapshot


func _lock_player(run: CutsceneRun) -> void:
	if run.player == null:
		return
	if run.player.has_method(&"set_cutscene_mode"):
		run.player.call(&"set_cutscene_mode", true)
		return
	run.player.input_enabled = false
	run.player.combat_enabled = false
	run.player.forced_velocity = Vector3.ZERO
	run.player.set_process_unhandled_input(false)
	run.player.set_physics_process(false)
	if run.player.camera_rig != null:
		run.player.camera_rig.input_enabled = false
		run.player.camera_rig.look_enabled = false


func _unlock_player(run: CutsceneRun) -> void:
	if run.player == null or not is_instance_valid(run.player):
		return
	if run.player.has_method(&"set_cutscene_mode"):
		run.player.call(&"set_cutscene_mode", false)
	else:
		var snapshot := run.player_snapshot
		run.player.input_enabled = bool(snapshot.get("input_enabled", true))
		run.player.combat_enabled = bool(snapshot.get("combat_enabled", true))
		run.player.forced_velocity = snapshot.get("forced_velocity", Vector3.ZERO)
		run.player.set_process_unhandled_input(bool(snapshot.get("unhandled_input", true)))
		run.player.set_physics_process(bool(snapshot.get("physics", true)))
		if run.player.camera_rig != null:
			run.player.camera_rig.input_enabled = bool(snapshot.get("camera_input", true))
			run.player.camera_rig.look_enabled = bool(snapshot.get("camera_look", true))
	Input.mouse_mode = int(run.player_snapshot.get("mouse_mode", Input.MOUSE_MODE_VISIBLE)) as Input.MouseMode


func _restore_camera(run: CutsceneRun) -> void:
	if run.camera != null and is_instance_valid(run.camera):
		run.camera.cancel_tweens()
	if run.player != null and is_instance_valid(run.player) and run.player.camera_rig != null:
		var snapshot := run.player_snapshot
		var yaw := float(snapshot.get("camera_yaw", 0.0))
		if run.definition.realign_camera_on_finish and run.player.visual != null:
			yaw = run.player.visual.rotation.y
		run.player.camera_rig.set_yaw(yaw)
		run.player.camera_rig.set_pitch(float(snapshot.get("camera_pitch", run.player.camera_rig.pitch)))
		run.player.camera_rig.camera.make_current()


func _restore_hud(run: CutsceneRun) -> void:
	if _ui != null:
		_ui.restore(run.ui_snapshot)


func _restore_actors(run: CutsceneRun) -> void:
	for id in run.actors:
		var actor := run.actors[id] as CutsceneActor
		if actor == null or not is_instance_valid(actor):
			continue
		actor.cancel_motion()
		if run.actor_snapshots.has(id):
			actor.restore(run.actor_snapshots[id])


func _finalize_actors(run: CutsceneRun) -> void:
	for actor in run.actors.values():
		if is_instance_valid(actor):
			actor.finish(true)


func _restore_props(run: CutsceneRun) -> void:
	for node in run.prop_snapshots:
		if not is_instance_valid(node):
			continue
		var data: Dictionary = run.prop_snapshots[node]
		if node is Node3D:
			node.global_transform = data.get("transform", node.global_transform)
			node.visible = bool(data.get("visible", true))


func _apply_skip_end(run: CutsceneRun) -> void:
	var definition := run.definition
	if definition == null:
		return
	for actor_id in definition.skip_end_hidden:
		var actor := find_actor(actor_id)
		if actor != null:
			actor.hide()
	for actor_id in definition.skip_end_markers:
		var actor := find_actor(actor_id)
		var marker := run.stage.get_marker(StringName(definition.skip_end_markers[actor_id]))
		if actor != null and marker != null and actor.body != null:
			actor.body.global_position = marker.global_position
			if actor.visual != null:
				actor.visual.rotation.y = marker.global_rotation.y
	if definition.skip_end_player_marker != &"" and run.player != null:
		var marker := run.stage.get_marker(definition.skip_end_player_marker)
		if marker != null:
			run.player.global_position = marker.global_position
			run.player.velocity = Vector3.ZERO
			if run.player.visual != null:
				run.player.visual.rotation.y = marker.global_rotation.y


func _apply_completion(run: CutsceneRun) -> void:
	var definition := run.definition
	var state := get_node_or_null(^"/root/NightmareRunState")
	if definition == null or state == null:
		return
	for flag in definition.completion_flags:
		state.call(&"set_flag", flag, true)
	for flag in definition.completion_clear_flags:
		state.call(&"set_flag", flag, false)
	for item_id in definition.completion_items:
		var key := StringName(str(item_id))
		var target := int(definition.completion_items[item_id])
		var current := int(state.call(&"get_item_count", key))
		state.call(&"set_item", key, maxi(current, target))
	for item_id in definition.completion_remove_items:
		state.call(&"remove_item", StringName(str(item_id)), int(definition.completion_remove_items[item_id]))
	if definition.completion_checkpoint != &"":
		state.call(
			&"set_checkpoint",
			definition.completion_checkpoint,
			definition.completion_checkpoint_position,
			definition.completion_checkpoint_has_position
		)
	if definition.once:
		var once_flag := definition.get_once_flag()
		if once_flag != &"":
			state.call(&"set_flag", once_flag, true)


func _get_player_camera(player: SunnyController) -> Camera3D:
	if player != null and player.camera_rig != null:
		return player.camera_rig.camera
	return get_viewport().get_camera_3d()


func _get_skip_hold_time() -> float:
	if _current_run != null and _current_run.definition != null and _current_run.definition.key_scene:
		return KEY_SCENE_SKIP_HOLD
	return DEFAULT_SKIP_HOLD


func _on_shot_changed(shot_id: StringName) -> void:
	if _current_run != null:
		_current_run.current_shot = shot_id
	shot_changed.emit(shot_id)


func _ensure_input_actions() -> void:
	if InputMap.has_action(&"cutscene_skip"):
		return
	InputMap.add_action(&"cutscene_skip")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_BACKSPACE
	InputMap.action_add_event(&"cutscene_skip", key)
	var joy := InputEventJoypadButton.new()
	joy.button_index = JOY_BUTTON_BACK
	InputMap.action_add_event(&"cutscene_skip", joy)


func _load_history() -> void:
	_seen.clear()
	var config := ConfigFile.new()
	if config.load(HISTORY_PATH) != OK:
		return
	for key in config.get_section_keys("seen"):
		_seen[StringName(key)] = true


func _save_history() -> void:
	var config := ConfigFile.new()
	for id in _seen:
		config.set_value("seen", String(id), true)
	config.save(HISTORY_PATH)
