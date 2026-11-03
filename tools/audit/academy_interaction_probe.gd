extends SceneTree
## Functional gameplay probe for the Academy playable scenes.
##
## Unlike academy_gameplay_probe.gd, this script does not complete quests by
## firing events directly. It moves the player, uses the real Interactable /
## QuestNpc / LootCache / TriggerZone / LevelPortal nodes, and checks the
## resulting run state, quest progress and scene transition.
##
## Run:
##   godot --headless --path . -s tools/audit/academy_interaction_probe.gd
##
## The script intentionally avoids static type annotations for gameplay
## classes: when a script is used via -s before autoload singletons exist,
## compiling those classes would fail on their NightmareRunState references.

const GROUNDS := "res://scenes/locations/academy_playable/academy_grounds_playable.tscn"
const SLEEPER := "res://scenes/locations/academy_playable/academy_sleeper_center_playable.tscn"

var _failures := 0


func _initialize() -> void:
	create_timer(45.0).timeout.connect(_on_watchdog)
	_run.call_deferred()


func _on_watchdog() -> void:
	push_error("PROBE: watchdog timeout")
	quit(2)


func _run() -> void:
	var state := root.get_node_or_null(^"NightmareRunState")
	var quests := root.get_node_or_null(^"QuestSystem")
	if state == null or quests == null:
		push_error("PROBE: NightmareRunState or QuestSystem autoload missing")
		quit(1)
		return
	state.reset()
	var packed := load(GROUNDS) as PackedScene
	if packed == null:
		push_error("PROBE: cannot load grounds")
		quit(1)
		return
	var scene := packed.instantiate() as Node3D
	root.add_child(scene)
	current_scene = scene
	await _frames(8)
	_check(quests.is_active(&"ac_mq_01_red_gate"), "auto-started ac_mq_01_red_gate")
	var player := get_first_node_in_group(&"player") as Node3D
	_check(player != null, "player present")
	if player == null:
		_finish()
		return
	_prepare_dialogue()
	# --- Gate guard: distance gate + real dialogue interaction. ---
	var guard = scene.find_child("gate_guard", true, false)
	_check(guard != null, "gate guard spawned")
	if guard != null:
		var interactable = guard.get("interactable")
		_check(interactable != null, "gate guard interactable present")
		player.global_position = guard.global_position + Vector3(1.2, 0.0, 0.0)
		await _frames(3)
		_check(interactable.can_interact_from(player.global_position), "gate guard in interact range")
		interactable.interact()
		await _wait_dialogue()
		_check(state.has_flag(&"academy_gate_passed"), "gate guard completion flag set")
		_check(quests.get_objective_progress(&"ac_mq_01_red_gate", &"talk_guard") >= 1, "talk_guard objective advanced")
		await _frames(90)
		var blocker = scene.find_child("GateBlocker", true, false)
		_check(blocker == null, "gate blocker removed after guard dialogue")
		var pivot = scene.find_child("GatePivotLeft", true, false)
		_check(pivot != null and absf(pivot.rotation.y) > 0.5, "gate leaves swing open after guard dialogue")
	# --- Reach trigger completes the gate quest. ---
	player.global_position = Vector3(0.0, 0.2, 58.0)
	await _frames(8)
	_check(quests.get_objective_progress(&"ac_mq_01_red_gate", &"enter_campus") >= 1, "academy_campus_entry trigger fired")
	_check(quests.is_completed(&"ac_mq_01_red_gate"), "ac_mq_01_red_gate completed by walking in")
	_check(state.get_currency(&"credits") >= 10, "quest reward credits granted")
	# --- Loot cache: real interact, deterministic drops, opened flag. ---
	var cache = scene.find_child("Loot_academy_gate_locker", true, false)
	_check(cache != null, "gate locker spawned")
	if cache != null:
		player.global_position = cache.global_position + Vector3(1.0, 0.0, 0.0)
		await _frames(3)
		_check(cache.can_interact_from(player.global_position), "loot cache in interact range")
		var drops: Array = cache.roll_drops()
		_check(not drops.is_empty(), "loot cache rolls at least one drop")
		cache.interact()
		_check(cache.is_opened(), "loot cache opened by interact()")
		_check(state.has_flag(&"loot_academy_gate_locker_opened"), "loot opened flag persisted")
	# --- Hidden NPC becomes visible when its prerequisite flag is set. ---
	var locked_npc = scene.find_child("kasper_dining", true, false)
	_check(locked_npc != null, "locked NPC spawned")
	if locked_npc != null:
		_check(not locked_npc.visible, "locked NPC hidden before prerequisite")
		state.set_flag(&"ac_mq_05_complete")
		await _frames(2)
		_check(locked_npc.visible, "locked NPC appears when prerequisite set")
	# --- Portal transition to Sleeper Center. ---
	var portal = scene.find_child("ToSleeper", true, false)
	_check(portal != null, "ToSleeper portal spawned")
	if portal != null:
		_check(ResourceLoader.exists(portal.destination_scene), "portal destination exists")
		var sleeper_packed := load(SLEEPER) as PackedScene
		var sleeper_probe := sleeper_packed.instantiate() if sleeper_packed != null else null
		var spawn := sleeper_probe.find_child("FromGrounds", true, false) if sleeper_probe != null else null
		_check(spawn != null, "FromGrounds spawn exists in destination")
		if sleeper_probe != null:
			sleeper_probe.free()
		player.global_position = portal.global_position
		await _frames(3)
		# Do not await the portal coroutine: the portal node is freed by the
		# scene change, and awaiting it would never resume.
		portal.activate(player)
		await _frames(60)
		var current := current_scene
		_check(current != null and current.scene_file_path.ends_with("academy_sleeper_center_playable.tscn"), "portal loaded sleeper center")
		if current != null:
			var new_player := get_first_node_in_group(&"player") as Node3D
			_check(new_player != null, "player survives portal transition")
			if new_player != null:
				_check(new_player.global_position.distance_to(Vector3(0.0, 0.2, 10.3)) < 2.0, "player at FromGrounds spawn")
			_prepare_dialogue()
			var receptionist = current.find_child("sleeper_receptionist", true, false)
			_check(receptionist != null, "receptionist spawned")
			if receptionist != null and new_player != null:
				var talk = receptionist.get("interactable")
				new_player.global_position = receptionist.global_position + Vector3(1.0, 0.0, 0.0)
				await _frames(3)
				_check(talk.can_interact_from(new_player.global_position), "receptionist in interact range")
				talk.interact()
				await _wait_dialogue()
				_check(state.has_flag(&"dorm_assigned"), "receptionist completion flag set")
				_check(quests.get_objective_progress(&"ac_mq_02_city_within", &"register") >= 1, "register objective advanced")
			# Hidden NPC must stay hidden until its prerequisite flag is set.
			var locked_ren = current.find_child("cadet_ren_lost", true, false)
			if locked_ren != null:
				_check(not locked_ren.visible, "sleeper locked NPC hidden before prerequisite")
				state.set_flag(&"ac_mq_10_complete")
				await _frames(2)
				_check(locked_ren.visible, "sleeper locked NPC appears when prerequisite set")
	_finish()


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
	for _i in 600:
		var runner = get_first_node_in_group(&"dialogue_runner")
		if runner == null or not runner.running:
			break
		await process_frame
	await _frames(3)


func _frames(count: int) -> void:
	for _i in count:
		await process_frame


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS ", label)
	else:
		_failures += 1
		push_error("FAIL " + label)


func _finish() -> void:
	print("ACADEMY_INTERACTION_PROBE failures=", _failures)
	quit(0 if _failures == 0 else 1)
