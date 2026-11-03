extends Node3D
## Stage 5 QA: actual click on the main-menu M1 entry.
##   godot --path . res://tools/audit/qa_stage5_menu_m1.tscn -- --out=<dir>

const MENU := "res://scenes/ui/main_menu/main_menu.tscn"
const P05 := "res://scenes/locations/post_nightmare/police_precinct.tscn"

var _out := ""
var _passes := 0
var _fails := 0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
	if _out.is_empty():
		push_error("qa_stage5_menu_m1: need --out=<dir>")
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	get_tree().root.size = Vector2i(1600, 900)
	await get_tree().process_frame
	_run()


func _run() -> void:
	NightmareRunState.reset()
	var menu := (load(MENU) as PackedScene).instantiate()
	get_tree().root.add_child(menu)
	get_tree().current_scene = menu
	await get_tree().process_frame
	await get_tree().process_frame
	var button := menu.find_child("PostNightmareButton", true, false) as Button
	_check(button != null, "PostNightmareButton exists")
	if button == null:
		return _finish()
	await _capture("MM_01_menu")
	var center := button.get_global_rect().get_center()
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = center
	Input.parse_input_event(down)
	await get_tree().process_frame
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = center
	Input.parse_input_event(up)
	var deadline := Time.get_ticks_msec() + 10000
	while Time.get_ticks_msec() < deadline:
		var current := get_tree().current_scene
		if current != null and current.scene_file_path == P05:
			break
		await get_tree().process_frame
	var current := get_tree().current_scene
	_check(current != null and current.scene_file_path == P05, "M1 entry loads PolicePrecinct")
	_check(NightmareRunState.has_flag(&"post_nightmare_started"), "post_nightmare_started set")
	_check(NightmareRunState.get_current_beat() == &"P05", "beat P05")
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	_check(player != null, "P05 player exists")
	await _capture("MM_02_p05")
	_finish()


func _finish() -> void:
	print("QA_STAGE5_MENU_M1_RESULT pass=", _passes, " fail=", _fails)
	get_tree().quit(0 if _fails == 0 else 1)


func _capture(name: String) -> void:
	await get_tree().create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	var path := _out.path_join(name + ".png")
	var error := get_tree().root.get_texture().get_image().save_png(path)
	if error != OK:
		_fail("capture %s error %d" % [name, error])
	else:
		print("QA_STAGE5_MENU_M1_CAPTURE ", path)


func _check(condition: bool, label: String) -> void:
	if condition:
		_passes += 1
		print("QA_STAGE5_MENU_M1_PASS ", label)
	else:
		_fail("check failed: " + label)


func _fail(message: String) -> void:
	_fails += 1
	print("QA_STAGE5_MENU_M1_FAIL ", message)
