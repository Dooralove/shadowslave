extends Node3D
## QA campaign tour: scripted end-to-end run of the First Nightmare in a real
## window, with screenshots at key phases. This is an automated playthrough, not
## a human input session. It exercises the same public/scene APIs as the GUT
## route tests, but as one continuous process.
##   godot --path . res://tools/audit/qa_campaign_tour.tscn -- --out=<dir>

const ENTRY := "res://scenes/campaign/campaign_entry.tscn"
const PASS := "res://scenes/campaign/first_nightmare_pass.tscn"
const CAMP_WRAPPER := "res://scenes/campaign/caravan_site_arrival.tscn"
const CAMP := "res://scenes/locations/caravan_site/caravan_site_art.tscn"
const PILGRIM := "res://scenes/locations/pilgrim_path/pilgrim_path_art.tscn"
const SANCTUARY := "res://scenes/campaign/sanctuary_arrival.tscn"
const APPRAISAL := "res://scenes/campaign/appraisal_arrival.tscn"
const FINALE := "res://scenes/campaign/finale_arrival.tscn"

var _out := ""
var _fails := 0
var _passes := 0
var _current: Node


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
	if _out.is_empty():
		push_error("qa_campaign_tour: need --out=<dir>")
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	get_tree().root.size = Vector2i(1920, 1080)
	await get_tree().process_frame
	await _run()
	print("QA_TOUR_RESULT pass=", _passes, " fail=", _fails)
	get_tree().quit(0 if _fails == 0 else 1)


func _run() -> void:
	NightmareRunState.reset()
	_check(await _prologue(), "prologue B01-B16")
	_check(await _march(), "S01 march")
	_check(await _camp(), "S02-S06 camp")
	_check(await _pilgrim(), "S07-S12 pilgrim")
	_check(await _sanctuary(), "S13 sanctuary")
	_check(await _appraisal(), "S14 appraisal")
	_check(await _finale(), "S15 finale")


func _prologue() -> bool:
	var entry := await _spawn(ENTRY, {"autostart": false, "transition_enabled": false})
	entry.call(&"start")
	var prologue := entry.get_node("Prologue") as SliceDirector
	prologue.fast_mode = true
	prologue.runner.fast_mode = true
	var captured_b01 := false
	for i in 900:
		if prologue.beat == SliceDirector.Beat.B01_OPENING and not captured_b01:
			while prologue.ui.fade.color.a > 0.05:
				await get_tree().process_frame
			await _capture("01_B01_park")
			captured_b01 = true
		if prologue.beat >= SliceDirector.Beat.B16_RUNES:
			break
		if prologue.runner.running:
			prologue.runner.advance()
		elif prologue.ui.rune_status.showing:
			break
		elif prologue.awaiting != &"":
			prologue.notify(prologue.awaiting)
		await get_tree().process_frame
	await _capture("02_B16_runes")
	var ok := prologue.beat >= SliceDirector.Beat.B16_RUNES
	ok = ok and NightmareRunState.has_flag(&"mark_of_divinity")
	await _free(entry)
	return ok


func _march() -> bool:
	var scene := await _spawn(PASS, {
		"autostart": false, "transition_enabled": false, "fast_mode": true,
		"debug_direct_scene": false,
	})
	scene.call(&"start")
	var sunny := scene.get_node("Sunny") as SunnyController
	_check(sunny.chain_restrained, "march chain restrained")
	await _capture("03_S01_march")
	scene.call(&"_begin_transition")
	await _wait(0.2)
	var ok := NightmareRunState.has_flag(&"march_intro_seen") and NightmareRunState.has_flag(&"camp_reached")
	ok = ok and not sunny.chain_restrained
	await _free(scene)
	return ok


func _camp() -> bool:
	var wrapper := await _spawn(CAMP_WRAPPER, {
		"transition_enabled": false, "fade_in": false, "fast_mode": true,
		"debug_direct_scene": false,
	})
	await _capture("04_S02_camp_arrival")
	var sunny := wrapper.get_node("Sunny") as SunnyController
	_check(sunny.chain_restrained, "camp tethered")
	await _free(wrapper)

	var camp := await _spawn(CAMP, {})
	camp.call(&"begin_camp")
	await _capture("05_S02_camp")
	await _interact(camp, &"camp_rations")
	camp.call(&"stage_camp_vision_recognition")
	await _interact(camp, &"camp_attack")
	await _capture("06_S03_attack")
	camp.call(&"begin_larva_phase")
	await _interact(camp, &"chain_larva")
	camp.call(&"kill_larva")
	camp.call(&"show_four_larvae")
	camp.call(&"show_key")
	await _capture("07_S04_larva")
	await _interact(camp, &"hero_key")
	camp.call(&"release_chains")
	camp.call(&"finish_episode")
	camp.call(&"begin_wagon_phase")
	await _interact(camp, &"wagon_wedges")
	await _interact(camp, &"wagon_loop")
	await _interact(camp, &"wagon_push")
	camp.call(&"stage_tyrant_for_wagon")
	camp.call(&"animate_wagon_fall", true)
	await _capture("08_S05_wagon")
	camp.call(&"show_aftermath")
	camp.call(&"begin_aftermath_search")
	await _interact(camp, &"flask_a")
	await _interact(camp, &"flask_b")
	await _interact(camp, &"flask_c")
	camp.call(&"stage_bloodbane_montage")
	await _interact(camp, &"veteran")
	await _interact(camp, &"veteran_sword")
	camp.call(&"execute_veteran")
	await _capture("09_S06_aftermath")
	camp.call(&"request_night")
	await _capture("10_S06_night")
	camp.call(&"begin_dawn")
	await _capture("11_S06_dawn")
	await _interact(camp, &"dawn_exit")
	var ok := NightmareRunState.has_flag(&"dawn_departure")
	ok = ok and NightmareRunState.has_flag(&"veteran_dead")
	await _free(camp)
	return ok


func _pilgrim() -> bool:
	var path := await _spawn(PILGRIM, {})
	await _trigger(path, &"road_gap")
	await _trigger(path, &"sword")
	await _capture("12_S07_road")
	await _trigger(path, &"rest")
	path.call(&"kill_shifty")
	path.call(&"begin_dawn")
	await _capture("13_S08_alcove")
	await _trigger(path, &"scholar")
	path.call(&"abandon_scholar")
	await _trigger(path, &"cave")
	path.call(&"mark_confession")
	path.call(&"wound_sunny")
	await _capture("14_S10_cave")
	await _trigger(path, &"cave_exit")
	NightmareRunState.set_flag(&"stealth_completed")
	path.call(&"prepare_route")
	await _trigger(path, &"hero")
	await _interact(path, &"bell")
	path.call(&"begin_hero_capture")
	path.call(&"complete_hero_capture")
	await _capture("15_S12_hero")
	NightmareRunState.set_flag(&"mark_of_divinity")
	path.call(&"reach_temple")
	var ok := NightmareRunState.has_flag(&"temple_reached")
	await _free(path)
	return ok


func _sanctuary() -> bool:
	var wrapper := await _spawn(SANCTUARY, {"transition_enabled": false, "fade_in": false})
	var sanctuary := wrapper.get_node("Sanctuary") as SanctuaryController
	var ritual := sanctuary.get_node("AltarRitual") as AltarRitual
	var altar := sanctuary.get_node("Interactables/AltarOffering") as Interactable
	_configure_fast_ritual(ritual)
	altar.interact()
	await _wait(0.6)
	await _capture("16_S13_altar")
	var ok := NightmareRunState.has_flag(&"trial_completed") and NightmareRunState.has_flag(&"tyrant_death_confirmed")
	await _free(wrapper)
	return ok


func _appraisal() -> bool:
	var scene := await _spawn(APPRAISAL, {
		"fade_in": false, "transition_enabled": false, "fast_mode": true,
		"start_delay": 0.0, "end_delay": 0.0, "redirect_without_gate": false,
	})
	await _wait(0.5)
	await _capture("17_S14_appraisal")
	var ok := NightmareRunState.has_flag(&"appraisal_completed")
	await _free(scene)
	return ok


func _finale() -> bool:
	var scene := await _spawn(FINALE, {
		"fade_in": false, "fast_mode": true, "restart_enabled": false,
		"redirect_without_gate": false,
	})
	await _wait(0.5)
	await _capture("18_S15_finale")
	var ok := NightmareRunState.has_flag(&"first_nightmare_completed")
	ok = ok and NightmareRunState.has_flag(&"awakening_completed")
	await _free(scene)
	return ok


# ---------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------

func _spawn(path: String, overrides: Dictionary) -> Node:
	var packed := load(path) as PackedScene
	if packed == null:
		_fail("cannot load " + path)
		return null
	var audio := get_node_or_null(^"/root/AudioDirector")
	if audio != null and audio.has_method(&"clear_captions"):
		audio.call(&"clear_captions")
	var scene := packed.instantiate()
	for key in overrides:
		if scene.get(key) != null or scene.has_method(&"get"):
			scene.set(key, overrides[key])
	add_child(scene)
	_current = scene
	await get_tree().process_frame
	await get_tree().physics_frame
	return scene


func _free(scene: Node) -> void:
	if scene == _current:
		_current = null
	if scene != null and is_instance_valid(scene):
		scene.queue_free()
		await get_tree().process_frame


func _interact(site: Node, id: StringName) -> void:
	var point := site.call(&"get_interactable", id) as Interactable
	if point == null:
		_fail("missing interactable %s" % id)
		return
	point.interact()
	await get_tree().process_frame


func _trigger(site: Node, id: StringName) -> void:
	var zone := site.call(&"get_trigger", id) as TriggerZone
	if zone == null:
		_fail("missing trigger %s" % id)
		return
	zone.fire()
	await get_tree().process_frame


func _capture(name: String) -> void:
	_ensure_camera(_current)
	await _wait(0.08)
	await RenderingServer.frame_post_draw
	var image := get_tree().root.get_texture().get_image()
	var path := _out.path_join(name + ".png")
	var error := image.save_png(path)
	if error != OK:
		_fail("capture %s error %d" % [name, error])
	else:
		print("QA_TOUR_CAPTURE ", path)


func _ensure_camera(scene: Node) -> void:
	if scene == null or not is_instance_valid(scene):
		return
	var player := scene.get_node_or_null(^"Sunny") as Node3D
	if player == null:
		player = scene.get_tree().get_first_node_in_group(&"player") as Node3D
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
	var cam := Camera3D.new()
	cam.name = "QATourCamera"
	cam.fov = 60.0
	cam.far = 400.0
	scene.add_child(cam)
	cam.global_position = Vector3(0, 2.5, 6)
	cam.look_at(Vector3(0, 1.2, 0), Vector3.UP)
	cam.make_current()


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _check(condition: bool, label: String) -> void:
	if condition:
		_passes += 1
		print("QA_TOUR_PASS ", label)
	else:
		_fail("check failed: " + label)


func _fail(message: String) -> void:
	_fails += 1
	print("QA_TOUR_FAIL ", message)


func _configure_fast_ritual(ritual: AltarRitual) -> void:
	var catalog := SpellMessageCatalog.new()
	catalog.messages = [
		_message(&"altar_sacrifice", "Ты предложил себя в жертву богам."),
		_message(&"altar_gods_dead", "Боги мертвы и не могут тебя услышать."),
		_message(&"altar_mark_of_divinity", "Твоя душа несёт знак божественности."),
		_message(&"altar_temple_slave", "Ты — храмовый раб."),
		_message(&"altar_shadow_god_stirs", "Бог Тени пробуждается в вечном сне."),
		_message(&"altar_blessing_beyond_grave", "Он посылает благословение из-за пределов смерти."),
		_message(&"altar_child_of_shadows", "Дитя Теней, прими своё благословение!"),
		_message(&"altar_tyrant_slain", "Ты убил пробуждённого тирана — Горного Короля."),
		_message(&"altar_wake_up", "Просыпайся, Санлесс! Твой кошмар окончен."),
		_message(&"altar_prepare_appraisal", "Приготовься к оценке…"),
	]
	ritual.messages = catalog
	ritual.spell_overlay = null
	ritual.start_delay = 0.0
	ritual.line_gap = 0.0
	ritual.finale_delay = 0.0
	ritual.fast_mode = true


func _message(id: StringName, text: String) -> SpellMessage:
	var message := SpellMessage.new()
	message.id = id
	message.text = text
	message.duration = 0.0
	return message
