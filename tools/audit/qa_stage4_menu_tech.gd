extends Node3D
## Stage 4 QA: actual click on the new tech-demo menu entry.
##   godot --path . res://tools/audit/qa_stage4_menu_tech.tscn -- --out=<dir>

const MENU := "res://scenes/ui/main_menu/main_menu.tscn"
const LABYRINTH := "res://scenes/locations/forgotten_shore_labyrinth/labyrinth_first_fragment.tscn"

var _out := ""
var _passes := 0
var _fails := 0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
	if _out.is_empty():
		push_error("qa_stage4_menu_tech: need --out=<dir>")
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
	var button := menu.find_child("TechDemoButton", true, false) as Button
	_check(button != null, "TechDemoButton exists")
	if button == null:
		return _finish()
	var rect := button.get_global_rect()
	var center := rect.get_center()
	_check(rect.size.x > 0.0 and rect.size.y > 0.0, "TechDemoButton has a visible rect")
	await _capture("M00_tech_button")

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

	var deadline := Time.get_ticks_msec() + 12000
	while Time.get_ticks_msec() < deadline:
		var current := get_tree().current_scene
		if current != null and current.scene_file_path == LABYRINTH:
			break
		await get_tree().process_frame
	var current := get_tree().current_scene
	_check(current != null and current.scene_file_path == LABYRINTH, "tech demo scene loaded")
	_check(NightmareRunState.has_flag(&"demo_mode_full"), "demo_mode_full set by menu entry")
	_check(NightmareRunState.get_current_beat() == &"Z01", "tech demo beat Z01")
	if current != null and current.scene_file_path == LABYRINTH:
		var demo_end := current.get_node_or_null(^"Gameplay/Triggers/DemoEndZone")
		_check(
			demo_end != null and String(demo_end.get(&"disabled_by_flag")) == "demo_mode_full",
			"M1 DemoEndZone is disabled by demo_mode_full"
		)
		var final_zone := current.get_node_or_null(^"Gameplay/Triggers/FinalZone")
		_check(
			final_zone != null and String(final_zone.get(&"required_flag")) == "demo_mode_full",
			"Z18 FinalZone requires demo_mode_full"
		)
	await _capture("M01_tech_labyrinth")
	_finish()


func _finish() -> void:
	print("QA_STAGE4_MENU_RESULT pass=", _passes, " fail=", _fails)
	get_tree().quit(0 if _fails == 0 else 1)


func _capture(name: String) -> void:
	await get_tree().create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	var image := get_tree().root.get_texture().get_image()
	var path := _out.path_join(name + ".png")
	var error := image.save_png(path)
	if error != OK:
		_fail("capture %s error %d" % [name, error])
	else:
		print("QA_STAGE4_MENU_CAPTURE ", path)


func _check(condition: bool, label: String) -> void:
	if condition:
		_passes += 1
		print("QA_STAGE4_MENU_PASS ", label)
	else:
		_fail("check failed: " + label)


func _fail(message: String) -> void:
	_fails += 1
	print("QA_STAGE4_MENU_FAIL ", message)
