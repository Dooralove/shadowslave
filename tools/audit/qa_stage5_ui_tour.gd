extends Node3D
## Stage 5 QA: capture the main interfaces in a real window.
##   godot --path . res://tools/audit/qa_stage5_ui_tour.tscn -- --out=<dir>

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
		push_error("qa_stage5_ui_tour: need --out=<dir>")
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	get_tree().root.size = Vector2i(1600, 900)
	await get_tree().process_frame
	_run()


func _run() -> void:
	# Main menu + settings.
	var menu := (load(MENU) as PackedScene).instantiate()
	get_tree().root.add_child(menu)
	get_tree().current_scene = menu
	await get_tree().process_frame
	await get_tree().process_frame
	await _capture("UI_01_main_menu")
	menu.call(&"open_settings")
	await _wait(0.3)
	_check(bool(menu.call(&"is_settings_open")), "settings page opens")
	await _capture("UI_02_settings")
	menu.call(&"close_settings")
	await _wait(0.2)
	menu.queue_free()
	await get_tree().process_frame

	# Gameplay HUD / journal / inventory / map / pause.
	var scene := (load(LABYRINTH) as PackedScene).instantiate()
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	await _capture("UI_03_gameplay_hud")

	var player_menu := get_node_or_null(^"/root/PlayerMenuSystem")
	_check(player_menu != null, "PlayerMenuSystem exists")
	if player_menu != null:
		player_menu.call(&"open_menu", &"journal")
		await _wait(0.5)
		_check(bool(player_menu.call(&"is_open")), "journal opens")
		await _capture("UI_04_journal")
		player_menu.call(&"close_menu")
		await _wait(0.2)
		player_menu.call(&"open_menu", &"inventory")
		await _wait(0.5)
		_check(bool(player_menu.call(&"is_open")), "inventory opens")
		await _capture("UI_05_inventory")
		player_menu.call(&"close_menu")
		await _wait(0.2)

	var map_system := get_node_or_null(^"/root/MapSystem")
	_check(map_system != null, "MapSystem exists")
	if map_system != null:
		var opened := bool(map_system.call(&"open_map"))
		await _wait(0.5)
		_check(opened and bool(map_system.call(&"is_open")), "map opens")
		await _capture("UI_06_map")
		map_system.call(&"close_map")
		await _wait(0.2)

	var pause := get_node_or_null(^"/root/PauseMenuSystem")
	_check(pause != null, "PauseMenuSystem exists")
	if pause != null:
		_check(bool(pause.call(&"open_menu")), "pause opens")
		await _wait(0.4)
		await _capture("UI_07_pause")
		pause.call(&"close_menu")

	_finish()


func _finish() -> void:
	print("QA_STAGE5_UI_RESULT pass=", _passes, " fail=", _fails)
	get_tree().quit(0 if _fails == 0 else 1)


func _capture(name: String) -> void:
	await _wait(0.2)
	await RenderingServer.frame_post_draw
	var path := _out.path_join(name + ".png")
	var error := get_tree().root.get_texture().get_image().save_png(path)
	if error != OK:
		_fail("capture %s error %d" % [name, error])
	else:
		print("QA_STAGE5_UI_CAPTURE ", path)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _check(condition: bool, label: String) -> void:
	if condition:
		_passes += 1
		print("QA_STAGE5_UI_PASS ", label)
	else:
		_fail("check failed: " + label)


func _fail(message: String) -> void:
	_fails += 1
	print("QA_STAGE5_UI_FAIL ", message)
