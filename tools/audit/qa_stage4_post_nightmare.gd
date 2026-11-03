extends Node3D
## Stage 4 QA: continuous post-nightmare demo playthrough P05 -> B02.
## Runs the real scenes, real Interactable/TriggerZone/DialogueRunner code and
## captures screenshots. It does not use direct scene loading as a substitute
## for the gameplay layer; portals are checked for availability and the next
## scene is then spawned manually so the harness survives.
##   godot --path . res://tools/audit/qa_stage4_post_nightmare.tscn -- --out=<dir>

const P05 := "res://scenes/locations/post_nightmare/police_precinct.tscn"
const P06 := "res://scenes/locations/post_nightmare/academy_approach.tscn"
const P07 := "res://scenes/locations/post_nightmare/academy_gate.tscn"
const P08 := "res://scenes/locations/post_nightmare/academy_campus.tscn"
const P09 := "res://scenes/locations/post_nightmare/academy_sleeper_center.tscn"
const B01 := "res://scenes/locations/post_nightmare/black_sea_platform.tscn"
const B02 := "res://scenes/locations/post_nightmare/tide_descent.tscn"

var _out := ""
var _fails := 0
var _passes := 0
var _current: Node


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
	if _out.is_empty():
		push_error("qa_stage4_post_nightmare: need --out=<dir>")
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	get_tree().root.size = Vector2i(1600, 900)
	await get_tree().process_frame
	await _run()
	print("QA_STAGE4_POST_RESULT pass=", _passes, " fail=", _fails)
	get_tree().quit(0 if _fails == 0 else 1)


func _run() -> void:
	NightmareRunState.reset()
	# The harness spawns scenes as children, not as current_scene, so the
	# GreyboxLocation demo bootstrap does not run. The real menu launch sets
	# this flag; mirror it here to test the rest of the chain.
	NightmareRunState.set_flag(&"post_nightmare_started")
	_check(await _p05(), "P05 police precinct")
	_check(await _p06(), "P06 academy approach")
	_check(await _p07(), "P07 academy gate")
	_check(await _p08(), "P08 academy campus")
	_check(await _p09(), "P09 sleeper center")
	_check(await _b01(), "B01 black sea platform")
	_check(await _b02(), "B02 tide descent")


# ---------------------------------------------------------------------------
# P05
# ---------------------------------------------------------------------------

func _p05() -> bool:
	var scene := await _spawn(P05)
	if scene == null:
		return false
	var player := scene.get_node_or_null(^"Player") as Node3D
	_check(player != null, "P05 player exists")
	_check(_flag(&"post_nightmare_started"), "P05 post_nightmare_started")
	var hud := scene.get_node_or_null(^"GameplayHud")
	_check(hud != null, "P05 gameplay HUD created")
	_check(scene.get_node_or_null(^"JettInteract") != null, "P05 Jett interactable")
	var mirror := scene.get_node_or_null(^"MirrorInteract") as Interactable
	_check(mirror != null and not mirror.enabled, "P05 mirror locked before Jett")
	await _capture("P05_01_spawn")

	var jett := scene.get_node_or_null(^"JettInteract") as Interactable
	if jett == null:
		_fail("P05 Jett missing")
		await _free(scene)
		return false
	jett.interact()
	await _finish_dialogues(scene)
	_check(_flag(&"p05_jett_talked"), "P05 Jett dialogue flag")
	_check(_flag(&"flaw_clear_conscience"), "P05 flaw flag")
	_check(mirror.enabled, "P05 mirror unlocked")
	await _capture("P05_02_jett")

	mirror.interact()
	await _finish_dialogues(scene)
	_check(_flag(&"p05_mirror_seen"), "P05 mirror seen")
	_check(_flag(&"shadow_sight_unlocked"), "P05 shadow sight")
	await _capture("P05_03_mirror")

	var exit := scene.get_node_or_null(^"ExitTrigger") as TriggerZone
	_check(exit != null, "P05 exit trigger")
	if exit != null:
		exit.fire()
		await _wait(0.1)
	_check(_flag(&"p05_completed"), "P05 completed flag")
	var portal := scene.get_node_or_null(^"Portals/ToAcademyApproach") as LevelPortal
	_check(portal != null and portal.is_available(), "P05 portal available after exit")
	await _capture("P05_04_exit")
	await _free(scene)
	return true


# ---------------------------------------------------------------------------
# P06
# ---------------------------------------------------------------------------

func _p06() -> bool:
	var scene := await _spawn(P06)
	if scene == null:
		return false
	_check(_flag(&"p05_completed"), "P06 keeps P05 completion")
	var jet := scene.get_node_or_null(^"JetTrigger") as TriggerZone
	_check(jet != null, "P06 Jet trigger")
	if jet != null:
		jet.fire()
	await _finish_dialogues(scene)
	_check(_flag(&"jett_advice_heard"), "P06 Jett advice")
	await _capture("P06_01_jet")

	var checkpoint := scene.get_node_or_null(^"CheckpointInteract") as Interactable
	_check(checkpoint != null and checkpoint.enabled, "P06 checkpoint interactable")
	if checkpoint != null:
		checkpoint.interact()
	await _finish_dialogues(scene)
	_check(_flag(&"p06_checkpoint_passed"), "P06 checkpoint passed")
	var portal := scene.get_node_or_null(^"Portals/ToAcademyGate") as LevelPortal
	_check(portal != null and portal.is_available(), "P06 portal to gate available")
	_check(_flag(&"jett_advice_heard"), "P06 portal gate prerequisite")
	await _capture("P06_02_checkpoint")
	await _free(scene)
	return true


# ---------------------------------------------------------------------------
# P07
# ---------------------------------------------------------------------------

func _p07() -> bool:
	var scene := await _spawn(P07)
	if scene == null:
		return false
	var trigger := scene.get_node_or_null(^"NephisGateTrigger") as TriggerZone
	_check(trigger != null, "P07 Nephis trigger")
	if trigger != null:
		trigger.fire()
	await _wait(0.1)
	_check(_flag(&"nephis_seen_at_gate"), "P07 Nephis seen")
	await _capture("P07_01_nephis")

	var checkout := scene.get_node_or_null(^"GateCheckpointInteract") as Interactable
	_check(checkout != null and checkout.enabled, "P07 gate checkpoint interactable")
	if checkout != null:
		checkout.interact()
	await _finish_dialogues(scene)
	_check(_flag(&"academy_gate_passed"), "P07 gate passed")
	var portal := scene.get_node_or_null(^"Portals/ToCampus") as LevelPortal
	_check(portal != null and portal.enabled and portal.is_available(), "P07 portal to campus available")
	await _capture("P07_02_passed")
	await _free(scene)
	return true


# ---------------------------------------------------------------------------
# P08
# ---------------------------------------------------------------------------

func _p08() -> bool:
	var scene := await _spawn(P08)
	if scene == null:
		return false
	var guide := scene.get_node_or_null(^"CampusGuideInteract") as Interactable
	_check(guide != null and not guide.enabled, "P08 guide locked before assignment")
	var terminal := scene.get_node_or_null(^"CampusTerminal") as Interactable
	_check(terminal != null and terminal.enabled, "P08 campus terminal available")
	if terminal != null:
		terminal.interact()
	await _finish_dialogues(scene)
	_check(_flag(&"dorm_assigned"), "P08 dorm assigned")
	_check(terminal != null and not terminal.enabled, "P08 terminal disables after use")
	var portal := scene.get_node_or_null(^"Portals/ToSleeper") as LevelPortal
	_check(portal != null and portal.enabled and portal.is_available(), "P08 portal to sleeper available")
	await _capture("P08_01_terminal")
	await _free(scene)
	return true


# ---------------------------------------------------------------------------
# P09
# ---------------------------------------------------------------------------

func _p09() -> bool:
	var scene := await _spawn(P09)
	if scene == null:
		return false
	var capsule := scene.get_node_or_null(^"CapsuleInteract") as Interactable
	_check(capsule != null and not capsule.enabled, "P09 capsule locked before induction")
	var cassia := scene.get_node_or_null(^"CassiaTrigger") as TriggerZone
	_check(cassia != null, "P09 Cassia trigger")
	if cassia != null:
		cassia.fire()
	await _wait(0.1)
	_check(_flag(&"cassia_seen"), "P09 Cassia seen")
	await _capture("P09_01_cassia")

	var rock := scene.get_node_or_null(^"RockInteract") as Interactable
	_check(rock != null and rock.enabled, "P09 induction rock available")
	if rock != null:
		rock.interact()
	await _finish_dialogues(scene)
	_check(_flag(&"induction_seen"), "P09 induction seen")
	_check(_flag(&"kasper_met"), "P09 Kasper met")
	_check(capsule != null and capsule.enabled, "P09 capsule unlocked")
	await _capture("P09_02_induction")

	var kasper := scene.get_node_or_null(^"KasperInteract") as Interactable
	if kasper != null:
		kasper.interact()
		await _finish_dialogues(scene)
	var portal := scene.get_node_or_null(^"Portals/ToBlackSea") as LevelPortal
	# The capsule handler starts the real scene transition. Suppress only that
	# transition so the harness can continue, but keep the handler's flags.
	if portal != null:
		portal.set(&"_used", true)
	if capsule != null:
		capsule.interact()
		await _finish_dialogues(scene)
	_check(_flag(&"capsule_entered"), "P09 capsule entered")
	_check(_flag(&"academy_month_passed"), "P09 month passed")
	_check(portal != null and portal.enabled, "P09 portal to Black Sea enabled")
	await _capture("P09_03_capsule")
	await _free(scene)
	return true


# ---------------------------------------------------------------------------
# B01
# ---------------------------------------------------------------------------

func _b01() -> bool:
	var scene := await _spawn(B01)
	if scene == null:
		return false
	_check(_flag(&"b01_arrived"), "B01 arrived flag")
	_check(_flag(&"academy_month_passed"), "B01 keeps month flag")
	var stars := scene.get_node_or_null(^"StarsInteract") as Interactable
	var sword := scene.get_node_or_null(^"SwordInteract") as Interactable
	var shroud := scene.get_node_or_null(^"ShroudInteract") as Interactable
	_check(stars != null and stars.enabled, "B01 stars interactable")
	_check(sword != null and sword.enabled, "B01 sword interactable")
	_check(shroud != null and not shroud.enabled, "B01 shroud locked before statue")
	if stars != null:
		stars.interact()
		await _finish_dialogues(scene)
	_check(_flag(&"statue_seen"), "B01 statue seen")
	_check(shroud != null and shroud.enabled, "B01 shroud unlocked")
	await _capture("B01_01_statue")

	if shroud != null:
		shroud.interact()
		await _finish_dialogues(scene)
	_check(_flag(&"shroud_summoned"), "B01 shroud summoned")
	var portal := scene.get_node_or_null(^"Portals/ToCoral") as LevelPortal
	_check(portal != null and portal.enabled, "B01 coral portal enabled after shroud")
	await _capture("B01_02_shroud")

	var descent := scene.get_node_or_null(^"DescentInteract") as Interactable
	_check(descent != null and descent.enabled, "B01 descent interactable")
	if portal != null:
		portal.set(&"_used", true)
	if descent != null:
		descent.interact()
		await _finish_dialogues(scene)
	_check(_flag(&"b01_completed"), "B01 completed")
	await _capture("B01_03_descent")
	await _free(scene)
	return true


# ---------------------------------------------------------------------------
# B02
# ---------------------------------------------------------------------------

func _b02() -> bool:
	var scene := await _spawn(B02)
	if scene == null:
		return false
	_check(_flag(&"b01_completed"), "B02 keeps B01 completion")
	var trigger := scene.get_node_or_null(^"TideWarningTrigger") as TriggerZone
	_check(trigger != null, "B02 tide warning trigger")
	if trigger != null:
		trigger.fire()
	await _wait(0.1)
	_check(_flag(&"tide_seen"), "B02 tide seen")
	await _capture("B02_01_tide")
	var portal := scene.get_node_or_null(^"Portals/ToCoral") as LevelPortal
	_check(portal != null and portal.is_available(), "B02 labyrinth portal available")
	await _capture("B02_02_portal")
	await _free(scene)
	return true


# ---------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------

func _spawn(path: String) -> Node:
	var packed := load(path) as PackedScene
	if packed == null:
		_fail("cannot load " + path)
		return null
	var scene := packed.instantiate()
	add_child(scene)
	_current = scene
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	return scene


func _free(scene: Node) -> void:
	if scene != null and is_instance_valid(scene):
		scene.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
	_current = null


func _finish_dialogues(scene: Node) -> void:
	var hud := scene.get_node_or_null(^"GameplayHud")
	var runner := hud.get_node_or_null(^"DialogueRunner") as DialogueRunner if hud != null else null
	if runner == null:
		await _wait(0.1)
		return
	for _i in 240:
		if not runner.running:
			break
		runner.advance()
		await get_tree().process_frame
	await _wait(0.05)


func _capture(name: String) -> void:
	_ensure_camera(_current)
	await _wait(0.12)
	await RenderingServer.frame_post_draw
	var image := get_tree().root.get_texture().get_image()
	var path := _out.path_join(name + ".png")
	var error := image.save_png(path)
	if error != OK:
		_fail("capture %s error %d" % [name, error])
	else:
		print("QA_STAGE4_POST_CAPTURE ", path)


func _ensure_camera(scene: Node) -> void:
	if scene == null or not is_instance_valid(scene):
		return
	var player := scene.get_node_or_null(^"Player") as Node3D
	if player == null:
		player = get_tree().get_first_node_in_group(&"player") as Node3D
	if player != null:
		var rig := player.get_node_or_null(^"CameraRig") as Node3D
		var cam := rig.get_node_or_null(^"Camera") as Camera3D if rig != null else null
		if cam == null and rig != null:
			for child in rig.get_children():
				if child is Camera3D:
					cam = child as Camera3D
					break
		if cam != null:
			cam.make_current()
			return
	for node in scene.find_children("*", "Camera3D", true, false):
		(node as Camera3D).make_current()
		return


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _flag(name: StringName) -> bool:
	return NightmareRunState.has_flag(name)


func _check(condition: bool, label: String) -> void:
	if condition:
		_passes += 1
		print("QA_STAGE4_POST_PASS ", label)
	else:
		_fail("check failed: " + label)


func _fail(message: String) -> void:
	_fails += 1
	print("QA_STAGE4_POST_FAIL ", message)
