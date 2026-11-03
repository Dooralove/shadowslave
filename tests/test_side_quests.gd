extends GutTest
## Stage 5/6 regression: SQ data + narrative director runtime and edge cases.
## New file (A02 integration test); A10 owns tests/, so this needs A10 review before merge.

const SQ_PATHS: Array[String] = [
	"res://resources/quests/sq_fs_01_ninth_token.tres",
	"res://resources/quests/sq_fs_02_echo_tunnel.tres",
	"res://resources/quests/sq_fs_03_truth_without_lies.tres",
	"res://resources/quests/sq_fs_04_salt_box.tres",
	"res://resources/quests/sq_fs_05_bone_bridge_master.tres",
]
const DIRECTOR := preload("res://scripts/locations/forgotten_shore_labyrinth/labyrinth_narrative_director.gd")

var _saved_catalog: QuestCatalog
var _saved_definitions: Dictionary
var _saved_scope_order: Array[StringName]


func before_each() -> void:
	_saved_catalog = QuestSystem.catalog
	_saved_definitions = QuestSystem._definitions.duplicate()
	_saved_scope_order = QuestSystem._scope_order.duplicate()
	NightmareRunState.reset()
	QuestSystem.deactivate_scope()


func after_each() -> void:
	QuestSystem.deactivate_scope()
	NightmareRunState.reset()
	QuestSystem.catalog = _saved_catalog
	QuestSystem._definitions = _saved_definitions
	QuestSystem._scope_order = _saved_scope_order


func _load_sq() -> Array[QuestDefinition]:
	var result: Array[QuestDefinition] = []
	for path in SQ_PATHS:
		var quest := load(path) as QuestDefinition
		assert_not_null(quest, "load %s" % path)
		if quest != null:
			result.append(quest)
	return result


func _install_catalog(quests: Array[QuestDefinition]) -> void:
	var catalog := QuestCatalog.new()
	catalog.scope = &"forgotten_shore"
	catalog.quests = quests
	QuestSystem.catalog = catalog
	QuestSystem._definitions = catalog.build_index()
	QuestSystem._scope_order.clear()
	for quest in quests:
		QuestSystem._scope_order.append(quest.id)
	QuestSystem.activate_scope(&"forgotten_shore")


func test_sq_data_is_valid_and_non_autostart() -> void:
	var quests := _load_sq()
	assert_eq(quests.size(), 5, "five SQ resources")
	var expected_codes := ["08", "09", "10", "11", "12"]
	for index in quests.size():
		var quest := quests[index]
		assert_true(quest.is_valid(), "%s valid" % quest.id)
		assert_eq(quest.scope, &"forgotten_shore")
		assert_eq(quest.code, expected_codes[index])
		assert_eq(quest.category, QuestDefinition.Category.SIDE)
		assert_false(quest.auto_start, "%s auto_start=false" % quest.id)
		assert_false(quest.show_available, "%s show_available=false" % quest.id)
		assert_false(quest.objectives.is_empty(), "%s has objectives" % quest.id)
		assert_false(quest.completion_flag == &"", "%s has completion flag" % quest.id)


func test_sq_flow_with_temporary_catalog() -> void:
	var quests := _load_sq()
	assert_eq(quests.size(), 5)
	if quests.size() != 5:
		return
	_install_catalog(quests)

	assert_true(QuestSystem.start_quest(&"sq_fs_01_ninth_token"), "SQ-01 starts")
	QuestSystem.notify_event(&"interacted", &"sq_fs_01_token", 1)
	QuestSystem.notify_event(&"talked", &"theo", 1)
	assert_true(QuestSystem.is_completed(&"sq_fs_01_ninth_token"), "SQ-01 completes")

	assert_true(QuestSystem.start_quest(&"sq_fs_02_echo_tunnel"), "SQ-02 starts")
	QuestSystem.notify_event(&"reached", &"sq_fs_02_tunnel", 1)
	QuestSystem.notify_event(&"killed", &"echo_polyp", 1)
	QuestSystem.notify_event(&"interacted", &"sq_fs_02_cloak", 1)
	QuestSystem.notify_event(&"interacted", &"sq_fs_02_echo_core", 1)
	assert_true(QuestSystem.is_completed(&"sq_fs_02_echo_tunnel"), "SQ-02 completes")

	assert_true(QuestSystem.start_quest(&"sq_fs_03_truth_without_lies"), "SQ-03 starts")
	QuestSystem.notify_event(&"talked", &"theo_return", 1)
	NightmareRunState.set_flag(&"sq_fs_03_resolved")
	assert_true(QuestSystem.is_completed(&"sq_fs_03_truth_without_lies"), "SQ-03 completes")

	assert_true(QuestSystem.start_quest(&"sq_fs_04_salt_box"), "SQ-04 starts")
	NightmareRunState.set_flag(&"sq_fs_04_levers_correct")
	QuestSystem.notify_event(&"interacted", &"sq_fs_04_box_open", 1)
	assert_true(QuestSystem.is_completed(&"sq_fs_04_salt_box"), "SQ-04 completes")
	assert_eq(NightmareRunState.get_currency(&"soul_shard"), 2, "SQ-04 reward")

	assert_true(QuestSystem.start_quest(&"sq_fs_05_bone_bridge_master"), "SQ-05 starts")
	NightmareRunState.set_flag(&"sq_fs_05_resolved")
	assert_true(QuestSystem.is_completed(&"sq_fs_05_bone_bridge_master"), "SQ-05 completes")
	assert_eq(NightmareRunState.get_currency(&"soul_shard"), 2, "SQ-05 bypass gives no extra currency")


func test_director_builds_sq_runtime_from_markers() -> void:
	var quests := _load_sq()
	if quests.size() != 5:
		return
	_install_catalog(quests)
	var root := Node3D.new()
	add_child_autofree(root)
	var gameplay := Node3D.new()
	gameplay.name = "Gameplay"
	root.add_child(gameplay)
	var markers := Node3D.new()
	markers.name = "Quests"
	gameplay.add_child(markers)
	_add_marker(markers, "SQ_FS_01/Token", Vector3(23, -1.35, 30.5))
	_add_marker(markers, "SQ_FS_01/Traces/Heel", Vector3(21, -1.35, 33.5))
	_add_marker(markers, "SQ_FS_01/Traces/Shell", Vector3(14, 0.1, 8))
	_add_marker(markers, "SQ_FS_01/Traces/Blood", Vector3(-37, 0.1, 24))
	_add_marker(markers, "SQ_FS_01/Theo", Vector3(-48.5, 6.1, 48))
	_add_marker(markers, "SQ_FS_02/Tunnel", Vector3(-55, 0.2, 19))
	_add_marker(markers, "SQ_FS_02/EchoA", Vector3(-60, 0.2, 19))
	_add_marker(markers, "SQ_FS_02/EchoB", Vector3(-70, 0.2, 21))
	_add_marker(markers, "SQ_FS_02/EchoC", Vector3(-80, 0.2, 19))
	_add_marker(markers, "SQ_FS_02/Polyp", Vector3(-70, 2.1, 20))
	_add_marker(markers, "SQ_FS_02/Cloak", Vector3(-80.5, 0.2, 20.5))
	_add_marker(markers, "SQ_FS_02/Core", Vector3(-70, 2.1, 20))
	_add_marker(markers, "SQ_FS_03/TheoReturn", Vector3(-48.5, 6.1, 48))
	_add_marker(markers, "SQ_FS_03/Cord", Vector3(-47, 6.1, 47))
	_add_marker(markers, "SQ_FS_03/Cache", Vector3(-47, 6.1, 47))
	_add_marker(markers, "SQ_FS_03/Token", Vector3(-70, 0.2, 21))
	_add_marker(markers, "SQ_FS_05/Bridge", Vector3(-580, 6.2, 0))
	_add_marker(markers, "SQ_FS_05/Trail", Vector3(-590, 2.2, 19.5))
	_add_marker(markers, "SQ_FS_05/Lair", Vector3(-610, -1.8, 9))
	_add_marker(markers, "SQ_FS_05/Carcass", Vector3(-585, 2.2, 18))
	_add_marker(markers, "SQ_FS_05/Bait", Vector3(-605, 2.2, 15))
	_add_marker(markers, "SQ_FS_05/Alpha", Vector3(-600, 2.2, 18))
	_add_marker(markers, "SQ_FS_05/WestEnd", Vector3(-650, 6.2, 0))
	_add_marker(markers, "SQ_FS_05/Reward", Vector3(-610, 2.2, 9))
	_add_marker(markers, "SQ_FS_05/TideBonus", Vector3(-620, -1.8, 9))
	var director = DIRECTOR.new()
	gameplay.add_child(director)
	await get_tree().process_frame
	await get_tree().process_frame
	var runtime := gameplay.get_node_or_null(^"RuntimeNarrative") as Node3D
	assert_not_null(runtime, "RuntimeNarrative exists")
	if runtime == null:
		return
	assert_not_null(runtime.get_node_or_null(^"Narrative_SQ01_Token"), "SQ-01 token created")
	assert_not_null(runtime.get_node_or_null(^"Narrative_SQ01_Trace_Heel"), "SQ-01 trace created")
	assert_not_null(runtime.get_node_or_null(^"Narrative_SQ02_Tunnel"), "SQ-02 trigger created")
	assert_not_null(runtime.get_node_or_null(^"Narrative_SQ02_EchoA"), "SQ-02 echo A created")
	assert_not_null(runtime.get_node_or_null(^"Narrative_SQ02_EchoB"), "SQ-02 echo B created")
	assert_not_null(runtime.get_node_or_null(^"Narrative_SQ02_EchoC"), "SQ-02 echo C created")
	assert_not_null(runtime.get_node_or_null(^"Narrative_SQ02_Cloak"), "SQ-02 cloak created")
	assert_not_null(runtime.get_node_or_null(^"Narrative_SQ02_EchoCore"), "SQ-02 core created")
	assert_not_null(runtime.get_node_or_null(^"Narrative_SQ03_Cord"), "SQ-03 cord created")
	assert_not_null(runtime.get_node_or_null(^"Narrative_SQ03_Cache"), "SQ-03 cache created")
	assert_not_null(runtime.get_node_or_null(^"Narrative_SQ03_TheoToken"), "SQ-03 token created")
	assert_not_null(runtime.get_node_or_null(^"Narrative_SQ05_Bridge"), "SQ-05 bridge trigger created")
	assert_not_null(runtime.get_node_or_null(^"Narrative_SQ05_TrailMarks"), "SQ-05 trail inspectable created")
	assert_not_null(runtime.get_node_or_null(^"Narrative_SQ05_Lair"), "SQ-05 lair inspectable created")
	assert_not_null(runtime.get_node_or_null(^"Narrative_SQ05_Chum"), "SQ-05 chum created")
	assert_not_null(runtime.get_node_or_null(^"Narrative_SQ05_BaitDrop"), "SQ-05 bait created")
	assert_not_null(runtime.get_node_or_null(^"Narrative_SQ05_WestEnd"), "SQ-05 west end created")
	assert_not_null(runtime.get_node_or_null(^"Narrative_SQ05_Reward"), "SQ-05 reward created")
	assert_not_null(runtime.get_node_or_null(^"Narrative_SQ05_TideBonus"), "SQ-05 tide bonus created")


func test_sq01_token_sets_started_flag() -> void:
	var quests := _load_sq()
	if quests.size() != 5:
		return
	_install_catalog(quests)
	var root := Node3D.new()
	add_child_autofree(root)
	var gameplay := Node3D.new()
	gameplay.name = "Gameplay"
	root.add_child(gameplay)
	var markers := Node3D.new()
	markers.name = "Quests"
	gameplay.add_child(markers)
	_add_marker(markers, "SQ_FS_01/Token", Vector3(23, -1.35, 30.5))
	_add_marker(markers, "SQ_FS_01/Traces/Heel", Vector3(21, -1.35, 33.5))
	var director = DIRECTOR.new()
	gameplay.add_child(director)
	await get_tree().process_frame
	await get_tree().process_frame
	var runtime := gameplay.get_node_or_null(^"RuntimeNarrative") as Node3D
	assert_not_null(runtime, "RuntimeNarrative exists")
	if runtime == null:
		return
	var token := runtime.get_node_or_null(^"Narrative_SQ01_Token") as QuestPickup
	assert_not_null(token, "SQ-01 token exists")
	if token == null:
		return
	token.interact()
	assert_true(QuestSystem.is_active(&"sq_fs_01_ninth_token"), "token starts SQ-01")
	assert_true(NightmareRunState.has_flag(&"sq_fs_01_started"), "token sets SQ-01 started flag")
	var trace := runtime.get_node_or_null(^"Narrative_SQ01_Trace_Heel") as Node3D
	assert_not_null(trace, "SQ-01 trace exists")
	if trace != null:
		assert_true(trace.visible, "trace becomes visible after start")


func test_derived_flags_are_repaired_from_run_state() -> void:
	var quests := _load_sq()
	if quests.size() != 5:
		return
	_install_catalog(quests)
	var root := Node3D.new()
	add_child_autofree(root)
	var gameplay := Node3D.new()
	gameplay.name = "Gameplay"
	root.add_child(gameplay)
	var director = DIRECTOR.new()
	gameplay.add_child(director)
	await get_tree().process_frame
	await get_tree().process_frame

	NightmareRunState.set_flag(&"sq_fs_02_echo_a")
	NightmareRunState.set_flag(&"sq_fs_02_echo_b")
	NightmareRunState.set_flag(&"sq_fs_02_echo_c")
	assert_true(NightmareRunState.has_flag(&"sq_fs_02_polyp_found"), "all echoes derive polyp_found")

	NightmareRunState.set_flag(&"sq_fs_02_polyp_dead")
	assert_true(NightmareRunState.has_flag(&"sq_fs_02_tunnel_safe"), "polyp death makes tunnel safe")

	NightmareRunState.set_flag(&"sq_fs_05_alpha_spared")
	NightmareRunState.set_flag(&"sq_fs_05_alpha_dead")
	assert_false(NightmareRunState.has_flag(&"sq_fs_05_alpha_spared"), "dead alpha clears spared")
	assert_true(NightmareRunState.has_flag(&"sq_fs_05_low_route_safe"), "dead alpha makes low route safe")
	assert_true(NightmareRunState.has_flag(&"sq_fs_05_resolved"), "dead alpha resolves SQ-05")


func test_sq02_early_polyp_kill_is_repaired_on_start() -> void:
	var quests := _load_sq()
	if quests.size() != 5:
		return
	_install_catalog(quests)
	var root := Node3D.new()
	add_child_autofree(root)
	var gameplay := Node3D.new()
	gameplay.name = "Gameplay"
	root.add_child(gameplay)
	var director = DIRECTOR.new()
	gameplay.add_child(director)
	await get_tree().process_frame

	NightmareRunState.set_flag(&"sq_fs_01_complete")
	NightmareRunState.set_flag(&"sq_fs_02_polyp_dead")
	assert_true(QuestSystem.start_quest(&"sq_fs_02_echo_tunnel"), "SQ-02 starts after early kill")
	assert_eq(
		QuestSystem.get_objective_progress(&"sq_fs_02_echo_tunnel", &"destroy_polyp"), 1,
		"early kill is credited on start"
	)
	QuestSystem.notify_event(&"reached", &"sq_fs_02_tunnel", 1)
	QuestSystem.notify_event(&"interacted", &"sq_fs_02_cloak", 1)
	QuestSystem.notify_event(&"interacted", &"sq_fs_02_echo_core", 1)
	assert_true(QuestSystem.is_completed(&"sq_fs_02_echo_tunnel"), "SQ-02 still completes")


func test_sq05_west_first_bypass_without_start() -> void:
	var quests := _load_sq()
	if quests.size() != 5:
		return
	_install_catalog(quests)
	var root := Node3D.new()
	add_child_autofree(root)
	var gameplay := Node3D.new()
	gameplay.name = "Gameplay"
	root.add_child(gameplay)
	var markers := Node3D.new()
	markers.name = "Quests"
	gameplay.add_child(markers)
	_add_marker(markers, "SQ_FS_05/WestEnd", Vector3(-650, 6.2, 0))
	var director = DIRECTOR.new()
	gameplay.add_child(director)
	await get_tree().process_frame
	await get_tree().process_frame
	var runtime := gameplay.get_node_or_null(^"RuntimeNarrative") as Node3D
	assert_not_null(runtime, "RuntimeNarrative missing")
	if runtime == null:
		return
	var west := runtime.get_node_or_null(^"Narrative_SQ05_WestEnd") as QuestTriggerZone
	assert_not_null(west, "WestEnd trigger missing")
	if west == null:
		return
	west.fire()
	assert_true(NightmareRunState.has_flag(&"sq_fs_05_alpha_spared"), "west-first bypass spares alpha")
	assert_true(NightmareRunState.has_flag(&"sq_fs_05_resolved"), "west-first bypass resolves SQ-05")
	assert_false(NightmareRunState.has_flag(&"sq_fs_05_alpha_dead"), "west-first bypass does not kill alpha")
	assert_eq(NightmareRunState.get_currency(&"soul_shard"), 0, "west-first bypass gives no shards")
	assert_true(QuestSystem.start_quest(&"sq_fs_05_bone_bridge_master"), "SQ-05 starts after bypass")
	assert_true(QuestSystem.is_completed(&"sq_fs_05_bone_bridge_master"), "SQ-05 completes from saved bypass flag")
	assert_eq(NightmareRunState.get_currency(&"soul_shard"), 0, "no duplicate reward on start")


func test_sq05_early_alpha_kill_is_credited_on_start() -> void:
	var quests := _load_sq()
	if quests.size() != 5:
		return
	_install_catalog(quests)
	var root := Node3D.new()
	add_child_autofree(root)
	var gameplay := Node3D.new()
	gameplay.name = "Gameplay"
	root.add_child(gameplay)
	var director = DIRECTOR.new()
	gameplay.add_child(director)
	await get_tree().process_frame

	NightmareRunState.set_flag(&"sq_fs_05_alpha_dead")
	assert_true(NightmareRunState.has_flag(&"sq_fs_05_low_route_safe"), "alpha death makes low route safe")
	assert_true(NightmareRunState.has_flag(&"sq_fs_05_resolved"), "alpha death resolves SQ-05")
	assert_true(QuestSystem.start_quest(&"sq_fs_05_bone_bridge_master"), "SQ-05 starts")
	assert_eq(
		QuestSystem.get_objective_progress(&"sq_fs_05_bone_bridge_master", &"kill_alpha"), 1,
		"early alpha kill is credited on start"
	)
	assert_true(QuestSystem.is_completed(&"sq_fs_05_bone_bridge_master"), "SQ-05 completes from kill")


func _add_marker(parent: Node3D, path: String, position: Vector3) -> void:
	var parts := path.split("/")
	var current := parent
	for index in parts.size():
		var node := current.get_node_or_null(NodePath(parts[index])) as Node3D
		if node == null:
			node = Node3D.new()
			node.name = parts[index]
			current.add_child(node)
		if index == parts.size() - 1:
			node.position = position
		current = node
