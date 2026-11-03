class_name CutsceneContext
extends RefCounted
## Фасад, через который сценарий кат-сцены говорит с движком.
## Всё, что ждёт, помечено await. Прямые Input, make_current,
## get_tree().paused и change_scene_to_file в сценариях запрещены.

var director
var run: CutsceneRun
var stage: CutsceneStage
var scene: Node
var player: SunnyController
var camera: CutsceneCamera3D
var ui: CutsceneUI
var fast := false
var cancelled := false


func wait(seconds: float) -> void:
	if cancelled:
		return
	if fast or seconds <= 0.0:
		await director.get_tree().process_frame
		return
	await director.get_tree().create_timer(seconds, false).timeout


func next_frame() -> void:
	await director.get_tree().process_frame


func wait_until(condition: Callable, timeout := 10.0) -> bool:
	var deadline := Time.get_ticks_msec() + int(maxf(timeout, 0.0) * 1000.0)
	while not bool(condition.call()):
		if cancelled or Time.get_ticks_msec() > deadline:
			return false
		await next_frame()
	return true


func actor(id: StringName) -> CutsceneActor:
	if cancelled:
		return null
	var found := director.find_actor(id) as CutsceneActor
	if found == null:
		fail("actor '%s' not found" % id)
		return null
	if not run.actors.has(id):
		run.actors[id] = found
		run.actor_snapshots[id] = found.snapshot()
		found.fast_mode = fast
		found.begin()
	return found


func marker(id: StringName) -> Node3D:
	if cancelled:
		return null
	if stage != null:
		var found := stage.get_marker(id)
		if found != null:
			return found
	if scene != null:
		var fallback := scene.get_node_or_null(NodePath("Spawns/%s" % String(id))) as Node3D
		if fallback != null:
			return fallback
	fail("marker '%s' not found" % id)
	return null


func shot(id: StringName) -> Camera3D:
	if cancelled:
		return null
	if stage != null:
		var found := stage.get_shot(id)
		if found != null:
			return found
	if scene != null:
		var fallback := scene.get_node_or_null(NodePath("Shots/%s" % String(id))) as Camera3D
		if fallback != null:
			return fallback
	fail("shot '%s' not found" % id)
	return null


func prop(id: StringName) -> Node3D:
	if cancelled:
		return null
	var found: Node3D = stage.get_prop(id) if stage != null else null
	if found == null:
		fail("prop '%s' not found" % id)
		return null
	if not run.prop_snapshots.has(found):
		run.prop_snapshots[found] = {
			"transform": found.global_transform,
			"visible": found.visible,
		}
	return found


func find(path: NodePath) -> Node:
	if stage != null:
		var found := stage.get_node_or_null(path)
		if found != null:
			return found
	if scene != null:
		return scene.get_node_or_null(path)
	return null


func dialogue(sequence: DialogueSequence) -> void:
	if cancelled:
		return
	if sequence == null:
		fail("dialogue sequence is null")
		return
	var runner := ui.get_dialogue_runner() if ui != null else null
	if runner == null:
		fail("DialogueRunner is not available")
		return
	await runner.run(sequence)
	if cancelled:
		return


func dialogue_by_id(id: StringName) -> void:
	var path := "res://resources/dialogue/%s.tres" % String(id)
	if not ResourceLoader.exists(path):
		fail("dialogue resource not found: %s" % path)
		return
	var sequence := load(path) as DialogueSequence
	await dialogue(sequence)


func say(text: String, speaker: StringName, duration := 0.0) -> void:
	var line := DialogueLine.new()
	line.speaker = speaker
	line.text = text
	line.duration = duration
	var sequence := DialogueSequence.new()
	sequence.lines = [line]
	await dialogue(sequence)


func flag(name: StringName, value := true) -> void:
	var state = _state()
	if state == null:
		return
	state.set_flag(name, value)


func clear_flag(name: StringName) -> void:
	flag(name, false)


func item(id: StringName, count := 1) -> void:
	var state = _state()
	if state == null:
		return
	var current := int(state.get_item_count(id))
	state.set_item(id, maxi(current, count))


func remove_item(id: StringName, count := 1) -> void:
	var state = _state()
	if state != null:
		state.remove_item(id, count)


func checkpoint(id: StringName, position := Vector3.ZERO, has_position := false) -> void:
	var state = _state()
	if state == null:
		return
	state.set_checkpoint(id, position, has_position)


func event(name: StringName) -> void:
	director.notify_event(name)


func await_event(name: StringName, timeout := 10.0) -> bool:
	return await director.wait_for_event(name, timeout)


func create_tween() -> Tween:
	return director.create_tween_for_script(run)


func commit() -> void:
	director.commit_run(run)


func fail(reason: String) -> void:
	cancelled = true
	director.abort(reason)


func _state():
	return director.get_node_or_null(^"/root/NightmareRunState")
