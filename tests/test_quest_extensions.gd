extends GutTest
## A04 regression tests: canonical flags, quest adapters, choice backend,
## tide locks, final gates and map flag filtering.

const TIDE_SCRIPT := preload("res://scripts/locations/forgotten_shore_labyrinth/tide_controller.gd")
const SUNNY_SCENE := preload("res://scenes/characters/sunny_waking.tscn")
const POLICE_SCENE := preload("res://scenes/locations/post_nightmare/police_precinct.tscn")
const FINALE_CARD := preload("res://scenes/campaign/post_nightmare_finale.tscn")
const PROBE_QUEST := &"a04_probe_quest"


class ProbePortal extends LevelPortal:
	var commits: Array[String] = []

	func _commit_scene_change(scene_path: String) -> int:
		commits.append(scene_path)
		return OK

	func _resolve_fade_layer() -> FadeLayer:
		return fade_layer


class FakeWaitTide extends Node3D:
	var low_calls := 0
	var high_calls := 0

	func advance_to_low() -> bool:
		low_calls += 1
		return true

	func advance_to_high() -> bool:
		high_calls += 1
		return true


func before_each() -> void:
	_cleanup_probe()
	QuestSystem.deactivate_scope()
	NightmareRunState.reset()
	LevelPortal.clear_pending_spawn()
	LevelPortal.clear_active_transition()


func after_each() -> void:
	_cleanup_probe()
	QuestSystem.deactivate_scope()
	NightmareRunState.reset()
	LevelPortal.clear_pending_spawn()
	LevelPortal.clear_active_transition()


func _cleanup_probe() -> void:
	QuestSystem._definitions.erase(PROBE_QUEST)
	QuestSystem._scope_order.erase(PROBE_QUEST)


func _make_probe_quest() -> QuestDefinition:
	var objective := QuestObjective.new()
	objective.id = &"probe_talk"
	objective.text = "Поговорить"
	objective.kind = QuestObjective.Kind.TALK
	objective.target_id = &"a04_probe_npc"
	var definition := QuestDefinition.new()
	definition.id = PROBE_QUEST
	definition.scope = &"forgotten_shore"
	definition.title = "A04 probe"
	definition.auto_start = false
	definition.show_available = false
	definition.objectives = [objective]
	definition.completion_flag = &"a04_probe_complete"
	return definition


func test_aliases_are_read_but_never_written_to_snapshot() -> void:
	NightmareRunState.set_flag(&"precinct_mirror_seen")
	assert_true(NightmareRunState.has_flag(&"p05_mirror_seen"))
	assert_true(NightmareRunState.has_flag(&"precinct_mirror_seen"))
	var snapshot := NightmareRunState.snapshot()
	assert_true(snapshot.flags.has(&"p05_mirror_seen"))
	assert_false(snapshot.flags.has(&"precinct_mirror_seen"))

	NightmareRunState.reset()
	NightmareRunState.restore({"flags": {&"demo_completed": true}})
	assert_true(NightmareRunState.has_flag(&"post_nightmare_completed"))
	assert_true(NightmareRunState.has_flag(&"demo_completed"))
	assert_false(NightmareRunState.snapshot().flags.has(&"demo_completed"))


func test_inspectable_requires_flags_and_is_one_shot() -> void:
	var node := QuestInspectable.new()
	node.interaction_id = &"a04_probe_clue"
	node.enabled = true
	node.required_flags = [&"a04_probe_ready"]
	node.completion_flag = &"a04_probe_seen"
	node.quest_subject = &"a04_probe_clue"
	add_child_autofree(node)
	assert_false(node.can_interact_from(Vector3.ZERO))
	NightmareRunState.set_flag(&"a04_probe_ready")
	assert_true(node.can_interact_from(Vector3.ZERO))
	node.interact()
	assert_true(NightmareRunState.has_flag(&"a04_probe_seen"))
	assert_true(node.is_completed())
	assert_false(node.enabled)


func test_choice_controller_writes_once() -> void:
	var controller := QuestChoiceController.new()
	add_child_autofree(controller)
	var choices: Array[Dictionary] = [
		{"id": &"truth", "text": "Правда", "flag": &"a04_probe_choice"},
	]
	assert_true(controller.present("Выбор", choices))
	assert_true(controller.select(&"truth"))
	assert_true(NightmareRunState.has_flag(&"a04_probe_choice"))
	assert_false(controller.select(&"truth"))


func test_tide_lock_uses_world_height_with_legacy_controller() -> void:
	var water := MeshInstance3D.new()
	water.name = "WaterPlane"
	add_child_autofree(water)
	var tide := TIDE_SCRIPT.new() as Node3D
	tide.name = "Tide"
	tide.low_y = -8.0
	tide.high_y = 4.0
	tide.water_plane = water
	add_child_autofree(tide)
	tide.set_phase(0.0)
	var lock := QuestTideLock.new()
	lock.tide_controller = tide
	lock.enabled = true
	lock.completion_flag = &"a04_probe_box_open"
	add_child_autofree(lock)
	assert_true(lock.is_tide_ready())
	tide.set_phase(0.5)
	assert_false(lock.is_tide_ready())
	lock.interact()
	assert_false(NightmareRunState.has_flag(&"a04_probe_box_open"))
	tide.set_phase(0.0)
	lock.interact()
	assert_true(NightmareRunState.has_flag(&"a04_probe_box_open"))


func test_tide_wait_calls_existing_controller_method() -> void:
	var tide := FakeWaitTide.new()
	add_child_autofree(tide)
	var wait := QuestTideWait.new()
	wait.tide_controller = tide
	wait.enabled = true
	wait.target = QuestTideWait.Target.LOW
	add_child_autofree(wait)
	wait.interact()
	assert_eq(tide.low_calls, 1)
	wait.target = QuestTideWait.Target.HIGH
	wait.interact()
	assert_eq(tide.high_calls, 1)


func test_finale_gate_modes_and_flags() -> void:
	var zone := QuestFinaleZone.new()
	zone.mode = QuestFinaleZone.Mode.M1
	zone.required_flags = [&"shore_first_day_complete", &"camp_night_seen"]
	zone.completion_flag = &"post_nightmare_demo_completed"
	add_child_autofree(zone)
	zone.set_physics_process(false)
	var player := Node3D.new()
	player.add_to_group(&"player")
	add_child_autofree(player)
	zone._on_body_entered(player)
	assert_false(zone._can_finish())
	NightmareRunState.set_flag(&"shore_first_day_complete")
	NightmareRunState.set_flag(&"camp_night_seen")
	assert_true(zone._can_finish())
	NightmareRunState.set_flag(&"demo_mode_full")
	assert_false(zone._can_finish())

	var tech := QuestFinaleZone.new()
	tech.mode = QuestFinaleZone.Mode.TECH_DEMO
	add_child_autofree(tech)
	tech.set_physics_process(false)
	assert_eq(tech.completion_flag, &"post_nightmare_completed")


func test_finale_card_mode_flags() -> void:
	NightmareRunState.set_flag(&"post_nightmare_demo_completed")
	var m1_card := FINALE_CARD.instantiate()
	add_child_autofree(m1_card)
	await wait_process_frames(1)
	assert_true(NightmareRunState.has_flag(&"post_nightmare_demo_completed"))
	assert_false(NightmareRunState.has_flag(&"post_nightmare_completed"))
	var m1_title := m1_card.get_node_or_null("Center/Column/Title") as Label
	assert_not_null(m1_title)
	if m1_title != null:
		assert_eq(m1_title.text, "ПЕРВЫЙ ДЕНЬ")

	NightmareRunState.reset()
	NightmareRunState.set_flag(&"demo_mode_full")
	var tech_card := FINALE_CARD.instantiate()
	add_child_autofree(tech_card)
	await wait_process_frames(1)
	assert_true(NightmareRunState.has_flag(&"post_nightmare_completed"))
	assert_false(NightmareRunState.has_flag(&"post_nightmare_demo_completed"))
	var tech_title := tech_card.get_node_or_null("Center/Column/Title") as Label
	assert_not_null(tech_title)
	if tech_title != null:
		assert_eq(tech_title.text, "КОНЕЦ ДЕМОНСТРАЦИОННОГО ФРАГМЕНТА")


func test_start_quest_id_runs_before_talk_event() -> void:
	var definition := _make_probe_quest()
	QuestSystem.activate_scope(&"forgotten_shore")
	QuestSystem._definitions[PROBE_QUEST] = definition
	QuestSystem._scope_order.append(PROBE_QUEST)
	var npc := QuestNpc.new()
	npc.npc_id = &"a04_probe_npc"
	npc.start_quest_id = PROBE_QUEST
	npc.one_shot = true
	var interactable := Interactable.new()
	interactable.name = "Interactable"
	interactable.enabled = true
	interactable.interaction_id = &"a04_probe_npc"
	npc.add_child(interactable)
	add_child_autofree(npc)
	interactable.interact()
	await wait_process_frames(1)
	assert_true(QuestSystem.is_completed(PROBE_QUEST))
	assert_eq(QuestSystem.get_objective_progress(PROBE_QUEST, &"probe_talk"), 1)
	assert_true(NightmareRunState.has_flag(&"a04_probe_complete"))
	interactable.interact()
	await wait_process_frames(1)
	assert_eq(QuestSystem.get_objective_progress(PROBE_QUEST, &"probe_talk"), 1)


func test_choice_closes_on_state_reset() -> void:
	var controller := QuestChoiceController.new()
	add_child_autofree(controller)
	var choices: Array[Dictionary] = [{"id": &"truth", "text": "Правда"}]
	assert_true(controller.present("Выбор", choices))
	NightmareRunState.reset()
	assert_false(controller.is_active())


func test_map_flags_contract() -> void:
	var marker := MapMarker.new()
	marker.id = &"a04_probe_marker"
	marker.hide_when_flag = &"a04_probe_hidden"
	var map := MapDefinition.new()
	map.markers = [marker]
	assert_eq(map.visible_markers({}).size(), 1)
	assert_eq(map.visible_markers({"a04_probe_hidden": true}).size(), 0)
	marker.hide_when_flag = &""
	marker.show_when_flag = &"a04_probe_shown"
	assert_eq(map.visible_markers({}).size(), 0)
	assert_eq(map.visible_markers({"a04_probe_shown": true}).size(), 1)


func test_p05_does_not_activate_quest_scope() -> void:
	var location := POLICE_SCENE.instantiate()
	add_child_autofree(location)
	await wait_process_frames(1)
	assert_eq(QuestSystem.active_scope, &"", "P05 не активирует forgotten_shore")


func test_portal_retriggers_when_required_flag_appears() -> void:
	var fade := FadeLayer.new()
	add_child_autofree(fade)
	var portal := ProbePortal.new()
	portal.destination_scene = "res://scenes/campaign/campaign_entry.tscn"
	portal.trigger_on_body = true
	portal.body_trigger_ignore_frames = 0
	portal.required_flags = [&"a04_probe_gate"]
	portal.fade_out_duration = 0.0
	portal.fade_layer = fade
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2, 2, 2)
	shape.shape = box
	portal.add_child(shape)
	add_child_autofree(portal)
	var sunny := SUNNY_SCENE.instantiate() as SunnyController
	add_child_autofree(sunny)
	portal._on_body_entered(sunny)
	await wait_process_frames(2)
	assert_eq(portal.commits.size(), 0, "флаг ещё не выставлен")
	NightmareRunState.set_flag(&"a04_probe_gate")
	await wait_process_frames(4)
	assert_eq(portal.commits.size(), 1, "флаг открывает портал, пока игрок внутри")
