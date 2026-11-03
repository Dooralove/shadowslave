extends SceneTree
## End-to-end quest walkthrough for the Academy playable segment.
##
## Uses the real Interactable / QuestNpc / portal / trigger nodes. The player
## is teleported between interaction points (navigation is covered separately
## by academy_navigation_probe.gd), while quest progression uses the same
## signals, flags and dialogue flow as normal play.
##
## Run:
##   godot --headless --path . -s tools/audit/academy_walkthrough_probe.gd

const GROUNDS := "res://scenes/locations/academy_playable/academy_grounds_playable.tscn"
const SLEEPER := "res://scenes/locations/academy_playable/academy_sleeper_center_playable.tscn"

var _failures := 0
var _state: Node
var _quests: Node
var _scene: Node3D
var _player: Node3D


func _initialize() -> void:
	create_timer(180.0).timeout.connect(_on_watchdog)
	_run.call_deferred()


func _on_watchdog() -> void:
	push_error("WALKTHROUGH: watchdog timeout")
	quit(2)


func _run() -> void:
	_state = root.get_node_or_null(^"NightmareRunState")
	_quests = root.get_node_or_null(^"QuestSystem")
	if _state == null or _quests == null:
		push_error("WALKTHROUGH: missing autoloads")
		quit(1)
		return
	_state.reset()
	await _load(GROUNDS)
	_check(_quests.is_active(&"ac_mq_01_red_gate"), "AC-MQ-01 active at start")
	# 01: gate guard + campus entry.
	await _talk("gate_guard")
	await _trigger("academy_campus_entry")
	_expect_complete(&"ac_mq_01_red_gate", "AC-MQ-01 red gate")
	# 02: terminal, sleeper entry, receptionist.
	await _use("campus_terminal")
	await _trigger("sleeper_center_entry")
	await _portal("ToSleeper", SLEEPER)
	await _talk("sleeper_receptionist")
	_expect_complete(&"ac_mq_02_city_within", "AC-MQ-02 city within")
	# 03: induction.
	await _portal("ToGrounds", GROUNDS)
	await _talk("rock_induction")
	await _talk("kasper_induction")
	await _talk("cassia_induction")
	_expect_complete(&"ac_mq_03_induction", "AC-MQ-03 induction")
	# 04: dormitory + bed.
	await _portal("ToSleeper", SLEEPER)
	await _trigger("dormitory")
	await _use("room_bed")
	_expect_complete(&"ac_mq_04_first_night", "AC-MQ-04 first night")
	# 05: schedule + interview.
	await _portal("ToGrounds", GROUNDS)
	await _use("schedule_board")
	await _talk("administrator")
	_expect_complete(&"ac_mq_05_schedule", "AC-MQ-05 schedule")
	# 06: ranking board + Kasper.
	await _use("ranking_board")
	await _talk("kasper_dining")
	_expect_complete(&"ac_mq_06_true_name", "AC-MQ-06 true name")
	# 07: Julius, star map, fire.
	await _talk("julius")
	await _use("star_map")
	await _use("fire_pit")
	_expect_complete(&"ac_mq_07_wilderness", "AC-MQ-07 wilderness")
	# 08: strike meter + Rock.
	await _use("strike_meter")
	await _talk("rock_dojo")
	_expect_complete(&"ac_mq_08_measure", "AC-MQ-08 measure")
	# 10: sparring ring + locker.
	await _trigger("dojo_ring")
	await _talk("kasper_locker")
	_expect_complete(&"ac_mq_10_sparring", "AC-MQ-10 sparring")
	# 09: shadow scout points in the sleeper.
	await _portal("ToSleeper", SLEEPER)
	await _use("shadow_point_1")
	await _use("shadow_point_2")
	await _use("shadow_point_3")
	_expect_complete(&"ac_mq_09_shadow", "AC-MQ-09 shadow")
	# 11: alarm + manual release.
	await _trigger("sleeper_center_alarm")
	await _use("manual_release")
	_expect_complete(&"ac_mq_11_storm", "AC-MQ-11 storm")
	# 12: coffee, Cassia, Hollow gallery, Julius, capsule.
	await _use("coffee_machine")
	await _talk("cassia_birthday")
	await _trigger("hollow_gallery")
	await _portal("ToGrounds", GROUNDS)
	await _talk("julius_farewell")
	await _portal("ToSleeper", SLEEPER)
	await _use("sleeper_capsule")
	_expect_complete(&"ac_mq_12_last_day", "AC-MQ-12 last day")
	# Side quests.
	await _portal("ToGrounds", GROUNDS)
	await _talk("cadet_mira")
	await _talk("cadet_ren")
	await _use("dojo_locker")
	await _talk("sergeant_holt")
	await _talk("wall_guard")
	await _use("restricted_archive")
	await _use("library_plaque")
	await _use("dojo_night_point")
	await _use("ladder_point")
	await _use("kasper_bet_point")
	await _trigger("east_turret")
	await _talk("cadet_mira_lost")
	await _portal("ToSleeper", SLEEPER)
	await _trigger("old_filtration")
	await _use("laundry_vent")
	await _use("laundry_bin")
	await _use("hollow_letter")
	await _use("kitchen_tea")
	# Validate the whole catalog.
	var completed := 0
	for quest in _quests.get_completed_quests():
		if quest.scope == &"academy":
			completed += 1
	_check(completed == 24, "all 24 academy quests completed (got %d)" % completed)
	for quest_id in [
		&"ac_sq_01_lucky_charm", &"ac_sq_02_borrowed_uniform", &"ac_sq_03_star_chart",
		&"ac_sq_04_dead_word", &"ac_sq_05_dojo_ghost", &"ac_sq_06_second_from_last",
		&"ac_sq_07_kasper_bet", &"ac_sq_08_tea_for_cassia", &"ac_sq_09_missing_cadet",
		&"ac_sq_10_maintenance_key", &"ac_sq_11_hollow_letter", &"ac_sq_12_wall_walk",
	]:
		_check(_quests.is_completed(quest_id), "side quest completed: %s" % quest_id)
	_check(_state.has_flag(&"academy_complete"), "academy_complete flag set")
	_finish()


func _load(path: String) -> void:
	if current_scene != null:
		current_scene.queue_free()
		current_scene = null
		await _frames(4)
	var packed := load(path) as PackedScene
	if packed == null:
		push_error("WALKTHROUGH: cannot load " + path)
		_finish()
		return
	_scene = packed.instantiate() as Node3D
	root.add_child(_scene)
	current_scene = _scene
	await _frames(8)
	_player = get_first_node_in_group(&"player") as Node3D
	_prepare_dialogue()
	_check(_player != null, "player present in " + path.get_file())


func _portal(portal_name: String, destination: String) -> void:
	var portal = _scene.find_child(portal_name, true, false)
	if portal == null:
		_check(false, "portal exists: " + portal_name)
		return
	_player.global_position = portal.global_position
	await _frames(2)
	portal.activate(_player)
	for _i in 120:
		await process_frame
		if current_scene != null and current_scene.scene_file_path.ends_with(destination.get_file()):
			break
	await _frames(10)
	_check(current_scene != null and current_scene.scene_file_path.ends_with(destination.get_file()), "portal %s -> %s" % [portal_name, destination.get_file()])
	_scene = current_scene as Node3D
	_player = get_first_node_in_group(&"player") as Node3D
	_prepare_dialogue()


func _talk(node_id: String) -> void:
	var npc = _scene.find_child(node_id, true, false)
	if npc == null:
		_check(false, "NPC exists: " + node_id)
		return
	if not npc.visible:
		_check(false, "NPC visible: " + node_id)
		return
	var target = npc.get("interactable")
	if target == null or not target.enabled:
		_check(false, "NPC interactable enabled: " + node_id)
		return
	await _place_and_interact(npc, target, node_id)


func _use(node_id: String) -> void:
	var node = _scene.find_child(node_id, true, false)
	if node == null:
		_check(false, "interactable exists: " + node_id)
		return
	if not node.enabled:
		_check(false, "interactable enabled: " + node_id)
		return
	await _place_and_interact(node, node, node_id)


func _place_and_interact(node: Node3D, target, label: String) -> void:
	var placed := false
	for offset in [Vector3(1.2, 0, 0), Vector3(-1.2, 0, 0), Vector3(0, 0, 1.2), Vector3(0, 0, -1.2)]:
		_player.global_position = node.global_position + offset
		await _frames(2)
		if target.can_interact_from(_player.global_position):
			placed = true
			break
	if not placed:
		_check(false, "interaction range: " + label)
		return
	target.interact()
	await _wait_dialogue()
	await _frames(2)


func _trigger(trigger_id: String) -> void:
	var zone = _scene.find_child("Trigger_%s" % trigger_id, true, false)
	if zone == null:
		_check(false, "trigger exists: " + trigger_id)
		return
	if zone.enabled:
		zone.fire()
	await _frames(3)


func _prepare_dialogue() -> void:
	var runner = get_first_node_in_group(&"dialogue_runner")
	if runner == null:
		return
	runner.fast_mode = true
	if not runner.line_started.is_connected(_auto_advance):
		runner.line_started.connect(_auto_advance)


func _auto_advance(_line, _index: int, _count: int) -> void:
	var runner = get_first_node_in_group(&"dialogue_runner")
	if runner != null:
		runner.advance.call_deferred()


func _wait_dialogue() -> void:
	for _i in 900:
		var runner = get_first_node_in_group(&"dialogue_runner")
		if runner == null or not runner.running:
			break
		await process_frame
	await _frames(3)


func _frames(count: int) -> void:
	for _i in count:
		await process_frame


func _expect_complete(quest_id: StringName, label: String) -> void:
	_check(_quests.is_completed(quest_id), "%s completed (state=%s)" % [label, _quests.get_state(quest_id)])


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS ", label)
	else:
		_failures += 1
		push_error("FAIL " + label)


func _finish() -> void:
	print("ACADEMY_WALKTHROUGH_PROBE failures=", _failures)
	quit(0 if _failures == 0 else 1)
