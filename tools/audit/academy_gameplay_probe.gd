extends SceneTree
## Headless gameplay probe for the Academy playable scenes and 24 quests.
## Run:
##   godot --headless --path . -s tools/audit/academy_gameplay_probe.gd

var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var quests := root.get_node_or_null(^"QuestSystem")
	if quests == null:
		push_error("PROBE: QuestSystem autoload missing")
		quit(1)
		return
	quests.call(&"activate_scope", &"academy")
	_check(quests.active_scope == &"academy", "academy scope active")
	var definitions: Array = []
	for path in DirAccess.get_files_at("res://resources/quests/academy"):
		if not path.ends_with(".tres") or path == "quest_catalog_academy.tres":
			continue
		var quest := load("res://resources/quests/academy/%s" % path) as QuestDefinition
		if quest != null and quest.scope == &"academy":
			definitions.append(quest)
	_check(definitions.size() == 24, "24 academy quest resources (got %d)" % definitions.size())
	var main_count := 0
	for quest in definitions:
		if quest.category == QuestDefinition.Category.MAIN:
			main_count += 1
	_check(main_count == 12, "12 main quests (got %d)" % main_count)
	# Complete every quest by notifying its required objectives.
	var completed := 0
	for quest in definitions:
		if not quests.call(&"start_quest", quest.id, true):
			# It may already be active/completed.
			pass
		for objective in quest.objectives:
			if objective.optional:
				continue
			quests.call(&"notify_event", objective.event_id(), objective.target_id, objective.required_count)
		if quests.call(&"is_completed", quest.id):
			completed += 1
		else:
			push_warning("PROBE: quest not completed: %s state=%s" % [quest.id, quests.call(&"get_state", quest.id)])
	_check(completed == 24, "all 24 quests complete (got %d)" % completed)
	# Loot pools load and one cache is interactable.
	for pool_path in [
		"res://resources/loot/academy/academy_locker_pool.tres",
		"res://resources/loot/academy/academy_supply_pool.tres",
		"res://resources/loot/academy/academy_medical_pool.tres",
	]:
		var pool := load(pool_path) as LootPool
		_check(pool != null and pool.validate().is_empty(), "loot pool valid: %s" % pool_path)
	# Scene load smoke test: instantiate both wrappers and count content.
	for scene_path in [
		"res://scenes/locations/academy_playable/academy_grounds_playable.tscn",
		"res://scenes/locations/academy_playable/academy_sleeper_center_playable.tscn",
	]:
		var packed := load(scene_path) as PackedScene
		_check(packed != null, "scene loads: %s" % scene_path)
		if packed == null:
			continue
		var instance := packed.instantiate()
		root.add_child(instance)
		current_scene = instance
		await process_frame
		await process_frame
		await process_frame
		var npc_count := instance.find_children("*", "QuestNpc", true, false).size()
		var interactable_count := instance.find_children("*", "Interactable", true, false).size()
		var loot_count := instance.find_children("*", "LootCache", true, false).size()
		var portal_count := instance.find_children("*", "LevelPortal", true, false).size()
		print("PROBE_SCENE ", scene_path, " npc=", npc_count, " interactables=", interactable_count, " loot=", loot_count, " portals=", portal_count)
		_check(npc_count > 0, "scene has NPCs: %s" % scene_path)
		_check(interactable_count > 0, "scene has interactables: %s" % scene_path)
		_check(loot_count > 0, "scene has loot: %s" % scene_path)
		_check(portal_count > 0, "scene has portal: %s" % scene_path)
		instance.queue_free()
		await process_frame
	print("ACADEMY_GAMEPLAY_PROBE failures=", _failures)
	quit(0 if _failures == 0 else 1)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS ", label)
	else:
		_failures += 1
		push_error("FAIL " + label)
