extends SceneTree
## Checks that M1 flag/trigger events reach both the SFX pool and VFX layer.
## This is read-only with respect to gameplay state: flags are restored at end.

const P05 := "res://scenes/locations/post_nightmare/police_precinct.tscn"
const P06 := "res://scenes/locations/post_nightmare/academy_approach.tscn"
const P07 := "res://scenes/locations/post_nightmare/academy_gate.tscn"
const P08 := "res://scenes/locations/post_nightmare/academy_campus.tscn"
const P09 := "res://scenes/locations/post_nightmare/academy_sleeper_center.tscn"
const B01 := "res://scenes/locations/post_nightmare/black_sea_platform.tscn"
const B02 := "res://scenes/locations/post_nightmare/tide_descent.tscn"

var _failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var audio := root.get_node_or_null(^"AudioDirector")
	if audio == null:
		printerr("AudioDirector missing")
		quit(1)
		return
	var state := root.get_node_or_null(^"NightmareRunState")
	if state == null:
		printerr("NightmareRunState missing")
		quit(1)
		return

	await _open_scene(P05)
	var exit_trigger := current_scene.get_node_or_null(^"ExitTrigger") as TriggerZone
	if exit_trigger == null:
		_fail("P05 ExitTrigger missing")
	else:
		exit_trigger.fire()
		await create_timer(0.15).timeout
		_check_played(audio, &"p05_cell_door")

	await _open_scene(P06)
	var jet_trigger := current_scene.get_node_or_null(^"JetTrigger") as TriggerZone
	if jet_trigger == null:
		_fail("P06 JetTrigger missing")
	else:
		jet_trigger.fire()
		await create_timer(0.15).timeout
		_check_played(audio, &"p06_car_door")

	await _open_scene(P07)
	state.set_flag(&"nephis_seen_at_gate", true)
	await create_timer(0.15).timeout
	_check_played(audio, &"world_wind_gust")
	state.set_flag(&"nephis_seen_at_gate", false)
	state.set_flag(&"academy_gate_passed", true)
	await create_timer(0.15).timeout
	_check_played(audio, &"p07_gate_scan")
	state.set_flag(&"academy_gate_passed", false)

	await _open_scene(P08)
	state.set_flag(&"dorm_assigned", true)
	await create_timer(0.15).timeout
	_check_played(audio, &"p08_terminal_beep")
	state.set_flag(&"dorm_assigned", false)

	await _open_scene(P09)
	state.set_flag(&"induction_seen", true)
	await create_timer(0.15).timeout
	_check_played(audio, &"p09_induction_tone")
	_check_vfx(current_scene, 2)
	state.set_flag(&"induction_seen", false)
	state.set_flag(&"academy_month_passed", true)
	await create_timer(0.15).timeout
	_check_played(audio, &"world_wind_gust")
	state.set_flag(&"academy_month_passed", false)

	await _open_scene(B01)
	state.set_flag(&"shroud_summoned", true)
	await create_timer(0.15).timeout
	_check_played(audio, &"b01_shroud_flare")
	_check_vfx(current_scene, 2)
	state.set_flag(&"shroud_summoned", false)

	await _open_scene(B02)
	var trigger := current_scene.get_node_or_null(^"TideWarningTrigger") as TriggerZone
	if trigger == null:
		_fail("B02 TideWarningTrigger missing")
	else:
		trigger.fire()
		await create_timer(0.15).timeout
		_check_played(audio, &"world_tide_warning")
		_check_vfx(current_scene, 2)

	if _failures.is_empty():
		print("EVENT VALIDATION PASS")
		quit(0)
	else:
		for failure in _failures:
			printerr("FAIL: ", failure)
		quit(1)


func _open_scene(path: String) -> void:
	if current_scene != null:
		current_scene.queue_free()
		await create_timer(0.25).timeout
	var packed := load(path) as PackedScene
	var scene := packed.instantiate()
	root.add_child(scene)
	current_scene = scene
	await create_timer(0.8).timeout


func _check_played(audio: Node, cue: StringName) -> void:
	var sfx: Node = audio.get("sfx") as Node
	var last: Dictionary = sfx.get("_last_played")
	if not last.has(cue):
		_fail("cue not played: %s" % cue)


func _check_vfx(scene: Node, minimum: int) -> void:
	var count := scene.find_children("M1Vfx*", "", true, false).size()
	if count < minimum:
		_fail("vfx count %d < %d in %s" % [count, minimum, scene.name])


func _fail(message: String) -> void:
	_failures.append(message)
	printerr("FAIL: ", message)
