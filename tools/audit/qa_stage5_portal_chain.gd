extends Node3D
## Stage 5 QA: real LevelPortal chain P05 -> ... -> B02 -> Labyrinth.
##   godot --path . res://tools/audit/qa_stage5_portal_chain.tscn -- --out=<dir>

const P05 := "res://scenes/locations/post_nightmare/police_precinct.tscn"
const P06 := "res://scenes/locations/post_nightmare/academy_approach.tscn"
const P07 := "res://scenes/locations/post_nightmare/academy_gate.tscn"
const P08 := "res://scenes/locations/post_nightmare/academy_campus.tscn"
const P09 := "res://scenes/locations/post_nightmare/academy_sleeper_center.tscn"
const B01 := "res://scenes/locations/post_nightmare/black_sea_platform.tscn"
const B02 := "res://scenes/locations/post_nightmare/tide_descent.tscn"
const LAB := "res://scenes/locations/forgotten_shore_labyrinth/labyrinth_first_fragment.tscn"

var _out := ""
var _passes := 0
var _fails := 0
var _scene: Node


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
	if _out.is_empty():
		push_error("qa_stage5_portal_chain: need --out=<dir>")
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	get_tree().root.size = Vector2i(1600, 900)
	await get_tree().process_frame
	_run()


func _run() -> void:
	NightmareRunState.reset()
	# P05.
	await _spawn(P05)
	NightmareRunState.set_flag(&"p05_jett_talked")
	NightmareRunState.set_flag(&"p05_mirror_seen")
	NightmareRunState.set_flag(&"p05_completed")
	await _portal_and_wait("Portals/ToAcademyApproach", P06, "P05->P06")
	# P06.
	NightmareRunState.set_flag(&"jett_advice_heard")
	await _portal_and_wait("Portals/ToAcademyGate", P07, "P06->P07")
	# P07.
	NightmareRunState.set_flag(&"academy_gate_passed")
	await _portal_and_wait("Portals/ToCampus", P08, "P07->P08")
	# P08.
	NightmareRunState.set_flag(&"dorm_assigned")
	await _portal_and_wait("Portals/ToSleeper", P09, "P08->P09")
	# P09.
	NightmareRunState.set_flag(&"induction_seen")
	NightmareRunState.set_flag(&"capsule_entered")
	await _portal_and_wait("Portals/ToBlackSea", B01, "P09->B01")
	# B01.
	NightmareRunState.set_flag(&"statue_seen")
	NightmareRunState.set_flag(&"shroud_summoned")
	await _portal_and_wait("Portals/ToCoral", B02, "B01->B02")
	# B02.
	NightmareRunState.set_flag(&"b01_completed")
	await _portal_and_wait("Portals/ToCoral", LAB, "B02->Labyrinth")
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	_check(player != null, "labyrinth player exists after chain")
	_finish()


func _spawn(path: String) -> void:
	var packed := load(path) as PackedScene
	_check(packed != null, "load " + path)
	if packed == null:
		return
	_scene = packed.instantiate()
	get_tree().root.add_child(_scene)
	get_tree().current_scene = _scene
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().physics_frame


func _portal_and_wait(portal_path: String, expected: String, label: String) -> void:
	var portal := _scene.get_node_or_null(NodePath(portal_path)) as LevelPortal
	_check(portal != null, label + " portal exists")
	if portal == null:
		return
	if not portal.enabled:
		portal.enabled = true
	var ok := await portal.activate()
	_check(ok, label + " activate")
	await _wait_scene(expected, 10.0)
	var current := get_tree().current_scene
	_check(current != null and current.scene_file_path == expected, label + " scene loaded")
	_scene = current
	await get_tree().process_frame
	await get_tree().physics_frame


func _wait_scene(path: String, seconds: float) -> void:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		var current := get_tree().current_scene
		if current != null and current.scene_file_path == path:
			return
		await get_tree().process_frame
	_fail("timeout waiting for " + path)


func _finish() -> void:
	print("QA_STAGE5_PORTAL_RESULT pass=", _passes, " fail=", _fails)
	get_tree().quit(0 if _fails == 0 else 1)


func _check(condition: bool, label: String) -> void:
	if condition:
		_passes += 1
		print("QA_STAGE5_PORTAL_PASS ", label)
	else:
		_fail("check failed: " + label)


func _fail(message: String) -> void:
	_fails += 1
	print("QA_STAGE5_PORTAL_FAIL ", message)
