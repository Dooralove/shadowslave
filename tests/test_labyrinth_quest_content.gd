extends GutTest
## Сборка игрового слоя Лабиринта по маркерам: триггеры, подбор, NPC,
## противники и реальное прохождение основной цепочки через события мира.

var root: Node3D
var gameplay: Node3D
var director: LabyrinthQuestDirector


func before_each() -> void:
	QuestSystem.deactivate_scope()
	NightmareRunState.reset()
	root = Node3D.new()
	add_child_autofree(root)
	gameplay = Node3D.new()
	gameplay.name = "Gameplay"
	root.add_child(gameplay)
	_build_markers()
	director = LabyrinthQuestDirector.new()
	director.enable_gameplay = true
	director.spawn_encounters = true
	gameplay.add_child(director)
	await get_tree().process_frame
	await get_tree().process_frame


func after_each() -> void:
	QuestSystem.deactivate_scope()
	NightmareRunState.reset()


func _marker(parent: Node3D, node_name: String, position: Vector3) -> Marker3D:
	var marker := Marker3D.new()
	marker.name = node_name
	marker.position = position
	parent.add_child(marker)
	return marker


func _build_markers() -> void:
	var spawns := Node3D.new()
	spawns.name = "Spawns"
	root.add_child(spawns)
	_marker(spawns, "Start", Vector3(38, 6.2, 0))

	var markers := Node3D.new()
	markers.name = "Markers"
	root.add_child(markers)
	_marker(markers, "CampCheckpoint", Vector3(-100, 18, -5))
	_marker(markers, "RefugeCheckpoint", Vector3(-700, 18, -20))
	_marker(markers, "CliffCheckpoint", Vector3(-1320, 6, 0))
	_marker(markers, "AzureBladePickup", Vector3(0, 0, 1))

	var triggers := Node3D.new()
	triggers.name = "Triggers"
	gameplay.add_child(triggers)
	_marker(triggers, "FirstFight", Vector3.ZERO)
	_marker(triggers, "FirstSighting", Vector3(-65, 0, 0))
	_marker(triggers, "Camp", Vector3(-100, 18, -5))
	_marker(triggers, "Bridge", Vector3(-600, 6, 0))
	_marker(triggers, "Refuge", Vector3(-700, 18, -20))
	_marker(triggers, "Storm", Vector3(-1050, 6, 0))
	_marker(triggers, "Cliffs", Vector3(-1320, 6, 0))

	var interactables := Node3D.new()
	interactables.name = "Interactables"
	gameplay.add_child(interactables)
	_marker(interactables, "Campfire", Vector3(-100, 18, -5))
	_marker(interactables, "SoulShardDryPocket", Vector3(-45, 6.5, 49))
	_marker(interactables, "SoulShardTunnel", Vector3(-70, 0.5, 20))
	_marker(interactables, "SoulShardBridge", Vector3(-600, 6.5, 0))

	var encounters := Node3D.new()
	encounters.name = "Encounters"
	gameplay.add_child(encounters)
	_marker(encounters, "WoundedScavenger", Vector3(0, 0, 2))
	_marker(encounters, "PacksZ13", Vector3(-375, 0, 0))
	_marker(encounters, "TwoCarapaces", Vector3(-560, 6, 0))

	var companions := Node3D.new()
	companions.name = "Companions"
	gameplay.add_child(companions)
	_marker(companions, "Nephis", Vector3(-65, 0, 0))
	_marker(companions, "Cassia", Vector3(-65, 0, 1))


func _runtime() -> Node3D:
	return gameplay.get_node_or_null(^"Runtime") as Node3D


func test_director_spawns_gameplay_objects() -> void:
	var runtime := _runtime()
	assert_not_null(runtime, "создан Runtime")
	if runtime == null:
		return
	assert_true(QuestSystem.is_scope_active(), "QuestSystem активирован")
	assert_eq(runtime.get_node_or_null(^"Trigger_first_fork") is QuestTriggerZone, true)
	assert_eq(runtime.get_node_or_null(^"Trigger_clearing") is QuestTriggerZone, true)
	assert_not_null(runtime.get_node_or_null(^"Checkpoint_CP-SHORE-CAMP") as CheckpointZone)
	assert_not_null(runtime.get_node_or_null(^"Pickup_AzureBladePickup") as QuestPickup)
	assert_not_null(runtime.get_node_or_null(^"Pickup_SoulShardDryPocket") as QuestPickup)
	assert_not_null(runtime.get_node_or_null(^"CampfireInteractable") as Interactable)
	assert_not_null(runtime.get_node_or_null(^"NPC_Nephis") as QuestNpc)
	assert_not_null(runtime.get_node_or_null(^"NPC_Cassia") as QuestNpc)
	assert_not_null(runtime.get_node_or_null(^"WoundedScavenger") as CarapaceEnemy)
	assert_not_null(runtime.get_node_or_null(^"PackCarapace1") as CarapaceEnemy)
	assert_not_null(runtime.get_node_or_null(^"BridgeCarapace2") as CarapaceEnemy)


func test_main_chain_runs_from_world_events() -> void:
	var runtime := _runtime()
	assert_not_null(runtime)
	if runtime == null:
		return
	# 1. Развилка: триггер и первый бой.
	var fork := runtime.get_node(^"Trigger_first_fork") as QuestTriggerZone
	fork.fire()
	await get_tree().process_frame
	assert_true(NightmareRunState.has_flag(&"shore_fork_reached"), "триггер развилки выставил флаг")
	assert_true(QuestSystem.is_active(&"first_blood"), "первый бой начался")

	var wounded := runtime.get_node(^"WoundedScavenger") as CarapaceEnemy
	assert_not_null(wounded)
	if wounded != null:
		wounded.health.take_damage(999.0)
	await get_tree().process_frame
	assert_true(QuestSystem.is_completed(&"first_blood"), "карапакс закрыл первый бой")
	assert_true(QuestSystem.is_active(&"azure_blade"), "клинок стал доступен")

	# 2. Подбор клинка: награда-Память, а не предмет инвентаря.
	var blade := runtime.get_node(^"Pickup_AzureBladePickup") as QuestPickup
	assert_not_null(blade)
	if blade != null:
		blade.interact()
	await get_tree().process_frame
	assert_true(QuestSystem.is_completed(&"azure_blade"), "клинок закрыл задание")
	assert_true(NightmareRunState.has_memory(&"azure_blade"), "Память открыта")

	# 3. Встреча: NPC отвечает на существующий Interactable.
	NightmareRunState.set_flag(&"shore_clearing_reached")
	var nephis := runtime.get_node(^"NPC_Nephis") as QuestNpc
	assert_not_null(nephis)
	if nephis != null:
		assert_true(nephis.interactable.enabled, "Нефис доступна после входа в прогалину")
		nephis.dialogue = null
		nephis.interactable.interact()
		await get_tree().process_frame
	assert_eq(
		QuestSystem.get_objective_progress(&"first_day", &"meet_nephis"), 1,
		"разговор закрыл цель встречи"
	)

	# 4. Лагерь: триггер завершает основное задание и выдаёт награду.
	var camp := runtime.get_node(^"Trigger_camp") as QuestTriggerZone
	camp.fire()
	await get_tree().process_frame
	assert_true(QuestSystem.is_completed(&"first_day"), "основное задание закрыто")
	assert_true(NightmareRunState.has_flag(&"shore_first_day_complete"))
	# 5 + 3 от заданий. Лут карапакса лежит в LootBag и не выдаётся
	# автоматически; тест его не подбирает.
	assert_eq(NightmareRunState.get_currency(&"soul_shard"), 8, "награды боя и основного задания")
	assert_true(QuestSystem.is_active(&"camp_rest"), "у костра появилось задание")


func test_azure_blade_waits_for_first_blood() -> void:
	var runtime := _runtime()
	assert_not_null(runtime)
	if runtime == null:
		return
	var blade := runtime.get_node(^"Pickup_AzureBladePickup") as QuestPickup
	assert_not_null(blade)
	if blade == null:
		return
	assert_false(blade.visible, "клинок скрыт до смерти карапакса")
	assert_false(blade.enabled, "клинок нельзя взять раньше задания")
	var wounded := runtime.get_node(^"WoundedScavenger") as CarapaceEnemy
	if wounded != null:
		wounded.health.take_damage(999.0)
	await get_tree().process_frame
	assert_true(blade.visible, "клинок появился после первого боя")
	assert_true(blade.enabled, "клинок стал доступен")


func test_pickup_grants_currency_and_flag() -> void:
	var runtime := _runtime()
	assert_not_null(runtime)
	if runtime == null:
		return
	var shard := runtime.get_node(^"Pickup_SoulShardTunnel") as QuestPickup
	assert_not_null(shard)
	if shard == null:
		return
	shard.interact()
	assert_eq(NightmareRunState.get_currency(&"soul_shard"), 1)
	assert_true(NightmareRunState.has_flag(&"soul_shard_tunnel"))
	assert_false(shard.visible, "подобранный предмет скрыт")
	assert_eq(
		QuestSystem.get_objective_progress(&"crystal_cache", &"collect_shards"), 1,
		"цель исследования обновилась"
	)
