extends Node3D
## Stage 4 QA: save/load, HUD objective and both finale paths on real scenes.
## Scenes are added directly under /root and made current_scene, so reload and
## change_scene_to_file behave exactly as in a normal game launch.
##   godot --path . res://tools/audit/qa_stage4_final_save.tscn -- --out=<dir>

const LABYRINTH := "res://scenes/locations/forgotten_shore_labyrinth/labyrinth_first_fragment.tscn"
const FINALE := "res://scenes/campaign/post_nightmare_finale.tscn"
const MAIN_MENU := "res://scenes/ui/main_menu/main_menu.tscn"

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
		push_error("qa_stage4_final_save: need --out=<dir>")
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	get_tree().root.size = Vector2i(1600, 900)
	await get_tree().process_frame
	await _run()
	print("QA_STAGE4_FINAL_RESULT pass=", _passes, " fail=", _fails)
	get_tree().quit(0 if _fails == 0 else 1)


func _run() -> void:
	NightmareRunState.reset()
	QuestSystem.deactivate_scope()
	_check(await _boot_labyrinth(), "labyrinth boot for save/HUD")
	if _scene == null:
		return
	await _hud_check()
	await _save_load()
	await _m1_finale()
	await _m1_continue()
	await _tech_finale()
	await _menu_check()


# ---------------------------------------------------------------------------
# Boot
# ---------------------------------------------------------------------------

func _boot_labyrinth() -> bool:
	var packed := load(LABYRINTH) as PackedScene
	if packed == null:
		_fail("cannot load labyrinth")
		return false
	var scene := packed.instantiate()
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene
	_scene = scene
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	_player = get_tree().get_first_node_in_group(&"player") as SunnyController
	_check(_player != null, "player exists after real scene launch")
	_check(QuestSystem.is_scope_active(), "quest scope active after real launch")
	return true


# ---------------------------------------------------------------------------
# HUD
# ---------------------------------------------------------------------------

func _hud_check() -> void:
	var hud := _scene.get_node_or_null(^"GameplayHud")
	_check(hud != null, "HUD exists")
	var line := hud.get_node_or_null(^"ObjectiveLine") as Control if hud != null else null
	_check(line != null, "objective line exists")
	if line != null:
		var text := String(line.call(&"get_objective_text"))
		_check(not text.strip_edges().is_empty(), "objective line has text: %s" % text)
		var caption := line.get_node_or_null(^"Box/Caption") as Label
		_check(caption != null and not caption.text.strip_edges().is_empty(), "objective caption visible")
		await _capture("F00_hud_objective")
	var prompt := hud.get_node_or_null(^"Prompt") as Label if hud != null else null
	_check(prompt != null, "interaction prompt exists")
	var combat := hud.get_node_or_null(^"CombatHud")
	_check(combat != null, "combat HUD exists")
	var tide := hud.get_node_or_null(^"TideIndicator")
	_check(tide != null, "tide indicator exists")


# ---------------------------------------------------------------------------
# Save / load
# ---------------------------------------------------------------------------

func _save_load() -> void:
	var save_system := get_node_or_null(^"/root/SaveSystem")
	_check(save_system != null, "SaveSystem autoload exists")
	if save_system == null:
		return
	save_system.call(&"delete_save")
	var saved_pos := _player.global_position
	var saved_shards := NightmareRunState.get_currency(&"soul_shard")
	NightmareRunState.set_flag(&"qa_save_marker")
	_check(bool(save_system.call(&"save_game", "quick")), "save_game(quick) returns true")
	var payload: Dictionary = save_system.call(&"read_save")
	_check(not payload.is_empty(), "save payload is readable")
	_check(String(payload.get("scene", "")) == LABYRINTH, "save stores labyrinth scene path")
	_check(payload.get("run_state", {}).has("flags"), "save stores run-state flags")

	# Mutate after save, then load: these changes must be rolled back.
	var scavenger := _scene.get_node_or_null(^"Gameplay/Runtime/WoundedScavenger") as CarapaceEnemy
	if scavenger != null:
		scavenger.health.take_damage(99999.0)
	NightmareRunState.add_currency(&"soul_shard", 7)
	_player.global_position = Vector3(-300, 5, 0)
	NightmareRunState.clear_flag(&"qa_save_marker")
	_check(bool(save_system.call(&"load_game", "quick")), "load_game(quick) returns true")
	await _wait_for_scene(LABYRINTH, 8.0)
	_scene = get_tree().current_scene
	_player = get_tree().get_first_node_in_group(&"player") as SunnyController
	_check(_scene != null and _scene.scene_file_path == LABYRINTH, "load reloaded the labyrinth")
	_check(_player != null, "player exists after load")
	if _player != null:
		_check(_player.global_position.distance_to(saved_pos) < 2.0, "load restored player position")
	_check(NightmareRunState.has_flag(&"qa_save_marker"), "load restored saved flag")
	_check(NightmareRunState.get_currency(&"soul_shard") == saved_shards, "load restored currency")
	var respawned := _scene.get_node_or_null(^"Gameplay/Runtime/WoundedScavenger") as CarapaceEnemy
	_check(respawned != null, "load respawns enemy killed after save")
	await _capture("F01_after_load")


# ---------------------------------------------------------------------------
# M1 finale at Z10
# ---------------------------------------------------------------------------

func _m1_finale() -> void:
	NightmareRunState.clear_flag(&"demo_mode_full")
	NightmareRunState.clear_flag(&"post_nightmare_demo_completed")
	NightmareRunState.set_flag(&"shore_first_day_complete")
	NightmareRunState.set_flag(&"camp_night_seen")
	var zone := _scene.get_node_or_null(^"Gameplay/Triggers/DemoEndZone") as Area3D
	_check(zone != null, "M1 DemoEndZone exists")
	if zone == null:
		return
	_player.global_position = zone.global_position + Vector3(0, 0.3, 0)
	_player.velocity = Vector3.ZERO
	await _wait_for_scene(FINALE, 8.0)
	_check(get_tree().current_scene != null and get_tree().current_scene.scene_file_path == FINALE, "M1 finale scene loaded")
	_check(NightmareRunState.has_flag(&"demo_mode_m1"), "M1 demo_mode_m1 set")
	_check(NightmareRunState.has_flag(&"post_nightmare_demo_completed"), "M1 completion flag set")
	await _capture("F02_m1_finale_card")
	var title := _find_label(get_tree().current_scene, "Title")
	_check(title != null and title.text == "ПЕРВЫЙ ДЕНЬ", "M1 finale card title")
	_check(get_tree().current_scene.get_node_or_null(^"BackButton") != null or _find_button(get_tree().current_scene, "BackButton") != null, "finale has back button")


# ---------------------------------------------------------------------------
# M1 -> tech demo continuation
# ---------------------------------------------------------------------------

func _m1_continue() -> void:
	var card := get_tree().current_scene
	var continue_button := _find_button(card, "ContinueButton")
	_check(continue_button != null and continue_button.visible, "M1 card offers tech-demo continuation")
	if continue_button == null:
		return
	continue_button.pressed.emit()
	await _wait_for_scene(LABYRINTH, 8.0)
	_check(get_tree().current_scene != null and get_tree().current_scene.scene_file_path == LABYRINTH, "continuation loads labyrinth")
	_check(NightmareRunState.has_flag(&"demo_mode_full"), "continuation sets demo_mode_full")
	var player := get_tree().get_first_node_in_group(&"player") as SunnyController
	var camp := get_tree().current_scene.get_node_or_null(^"Spawns/CampReturn") as Node3D
	_check(player != null and camp != null, "continuation has player and CampReturn spawn")
	if player != null and camp != null:
		_check(player.global_position.distance_to(camp.global_position) < 3.0, "continuation spawns at CampReturn")
	await _capture("F03a_continue_tech")


# ---------------------------------------------------------------------------
# Tech finale at Z18
# ---------------------------------------------------------------------------

func _tech_finale() -> void:
	# Reload labyrinth through the normal load path? Use a direct launch to keep
	# this test focused on the tech finale, then set the entry flag manually.
	var packed := load(LABYRINTH) as PackedScene
	var scene := packed.instantiate()
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene
	_scene = scene
	await get_tree().process_frame
	await get_tree().physics_frame
	_player = get_tree().get_first_node_in_group(&"player") as SunnyController
	_check(_player != null, "tech: player exists")
	NightmareRunState.clear_flag(&"post_nightmare_completed")
	NightmareRunState.set_flag(&"demo_mode_full")
	var zone := _scene.get_node_or_null(^"Gameplay/Triggers/FinalZone") as Area3D
	_check(zone != null, "tech FinalZone exists")
	if zone == null:
		return
	_player.global_position = zone.global_position + Vector3(0, 0.3, 0)
	_player.velocity = Vector3.ZERO
	await _wait_for_scene(FINALE, 8.0)
	_check(get_tree().current_scene != null and get_tree().current_scene.scene_file_path == FINALE, "tech finale scene loaded")
	_check(NightmareRunState.has_flag(&"post_nightmare_completed"), "tech completion flag set")
	await _capture("F03_tech_finale_card")
	var title := _find_label(get_tree().current_scene, "Title")
	_check(title != null and title.text == "КОНЕЦ ДЕМОНСТРАЦИОННОГО ФРАГМЕНТА", "tech finale card title")


func _menu_check() -> void:
	var packed := load(MAIN_MENU) as PackedScene
	var menu := packed.instantiate()
	get_tree().root.add_child(menu)
	get_tree().current_scene = menu
	await get_tree().process_frame
	await get_tree().process_frame
	var post := menu.get_node_or_null(^"MenuPage/Frame/Column/Hero/ActionsFrame/ActionsMargin/Actions/PostNightmareButton") as Button
	_check(post != null, "main menu has PostNightmareButton")
	var tech := menu.find_child("TechDemoButton", true, false) as Button
	_check(tech != null, "main menu has a tech-demo entry")
	_check(tech != null and tech.visible, "tech-demo entry is visible")
	await _capture("F04_main_menu")


# ---------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------

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
	await _wait(0.2)
	await RenderingServer.frame_post_draw
	var image := get_tree().root.get_texture().get_image()
	var path := _out.path_join(name + ".png")
	var error := image.save_png(path)
	if error != OK:
		_fail("capture %s error %d" % [name, error])
	else:
		print("QA_STAGE4_FINAL_CAPTURE ", path)


func _find_label(root: Node, node_name: String) -> Label:
	if root == null:
		return null
	for node in root.find_children("*", "Label", true, false):
		if String(node.name) == node_name:
			return node as Label
	return null


func _find_button(root: Node, node_name: String) -> Button:
	if root == null:
		return null
	for node in root.find_children("*", "Button", true, false):
		if String(node.name) == node_name:
			return node as Button
	return null


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _check(condition: bool, label: String) -> void:
	if condition:
		_passes += 1
		print("QA_STAGE4_FINAL_PASS ", label)
	else:
		_fail("check failed: " + label)


func _fail(message: String) -> void:
	_fails += 1
	print("QA_STAGE4_FINAL_FAIL ", message)
