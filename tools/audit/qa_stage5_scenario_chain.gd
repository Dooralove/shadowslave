extends Node3D
## Stage 5 QA: First Nightmare finale -> Post-Nightmare P05 continuation.
##   godot --path . res://tools/audit/qa_stage5_scenario_chain.tscn -- --out=<dir>

const FINALE := "res://scenes/campaign/finale_arrival.tscn"
const P05 := "res://scenes/locations/post_nightmare/police_precinct.tscn"

var _out := ""
var _passes := 0
var _fails := 0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
	if _out.is_empty():
		push_error("qa_stage5_scenario_chain: need --out=<dir>")
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	get_tree().root.size = Vector2i(1600, 900)
	await get_tree().process_frame
	_run()


func _run() -> void:
	NightmareRunState.reset()
	for flag in [
		&"first_nightmare_completed", &"first_nightmare_finished",
		&"awakening_completed", &"appraisal_completed", &"trial_completed",
		&"temple_reached", &"mark_of_divinity", &"shadow_core_awakened",
	]:
		NightmareRunState.set_flag(flag)
	var finale := (load(FINALE) as PackedScene).instantiate()
	finale.set(&"fast_mode", true)
	finale.set(&"line_delay", 0.0)
	get_tree().root.add_child(finale)
	get_tree().current_scene = finale
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(0.5).timeout
	var button := finale.find_child("ContinueButton", true, false) as Button
	_check(button != null, "First Nightmare finale has ContinueButton")
	if button == null:
		return _finish()
	button.pressed.emit()
	var deadline := Time.get_ticks_msec() + 10000
	while Time.get_ticks_msec() < deadline:
		var current := get_tree().current_scene
		if current != null and current.scene_file_path == P05:
			break
		await get_tree().process_frame
	var current := get_tree().current_scene
	_check(current != null and current.scene_file_path == P05, "continue loads PolicePrecinct")
	_check(NightmareRunState.has_flag(&"post_nightmare_started"), "post_nightmare_started set")
	_check(NightmareRunState.get_current_beat() == &"P05", "beat is P05")
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	_check(player != null, "P05 player exists after continue")
	_finish()


func _finish() -> void:
	print("QA_STAGE5_SCENARIO_RESULT pass=", _passes, " fail=", _fails)
	get_tree().quit(0 if _fails == 0 else 1)


func _capture(name: String) -> void:
	await get_tree().create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	var path := _out.path_join(name + ".png")
	var error := get_tree().root.get_texture().get_image().save_png(path)
	if error != OK:
		_fail("capture %s error %d" % [name, error])
	else:
		print("QA_STAGE5_SCENARIO_CAPTURE ", path)


func _check(condition: bool, label: String) -> void:
	if condition:
		_passes += 1
		print("QA_STAGE5_SCENARIO_PASS ", label)
	else:
		_fail("check failed: " + label)


func _fail(message: String) -> void:
	_fails += 1
	print("QA_STAGE5_SCENARIO_FAIL ", message)
