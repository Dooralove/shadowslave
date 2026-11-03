extends SceneTree
## Functional read/write test for the generic loot layer.
##
## Creates a local NightmareRunState (autoloads are not loaded by -s), opens a
## chest twice, checks one-shot behaviour, and verifies the GD_FUTURE filter.
## Usage:
##   godot --headless --path . -s tools/audit/loot_pool_test.gd

const CHEST_SCENE := "res://scenes/loot/containers/chest_wood_iron.tscn"
const RELIC_POOL := "res://resources/loot/tables/cache_ossuary_relic_helm.tres"
const SCAVENGER_POOL := "res://resources/loot/tables/enemy_carapace_scavenger.tres"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var state_script := load("res://scripts/campaign/nightmare_run_state.gd") as GDScript
	if state_script == null:
		push_error("loot_pool_test: NightmareRunState script missing")
		quit(2)
		return
	var state: Node = root.get_node_or_null(^"NightmareRunState")
	if state == null:
		state = state_script.new()
		state.name = "NightmareRunState"
		root.add_child(state)
	state.reset()
	await process_frame

	var failures := 0
	failures += await _test_chest_once(state)
	failures += await _test_sarcophagus_lid(state)
	failures += await _test_dropper(state)
	failures += await _test_bag_persistence(state)
	failures += await _test_stack_limits(state)
	failures += await _test_cache_overflow(state)
	failures += _test_future_filter()
	failures += _test_unique_enforcement(state)
	failures += _test_scavenger_pool()

	print("LOOT_POOL_TEST failures=%d" % failures)
	quit(0 if failures == 0 else 1)


func _test_chest_once(state: Node) -> int:
	var packed := load(CHEST_SCENE) as PackedScene
	if packed == null:
		push_error("loot_pool_test: chest scene missing")
		return 1
	var chest := packed.instantiate() as LootCache
	root.add_child(chest)
	await process_frame
	if not chest.enabled:
		push_error("loot_pool_test: chest is disabled")
		return 1
	var opened_count := [0]
	chest.opened.connect(func(_id: StringName, _drops: Array) -> void:
		opened_count[0] += 1
	)
	chest.interact()
	await create_timer(0.7).timeout
	var shards := int(state.get_currency(&"soul_shard"))
	var rope := int(state.get_item_count(&"rope"))
	var flag_ok := bool(state.has_flag(&"loot_secret_z02_wreck_chest_opened"))
	var lid := chest.get_node_or_null(^"VisualRoot/Model/Lid") as Node3D
	var lid_angle := lid.rotation_degrees.x if lid != null else 0.0
	var lid_ok: bool = lid != null and absf(lid_angle - 100.0) < 1.0
	chest.interact()
	await process_frame
	var shards_after := int(state.get_currency(&"soul_shard"))
	var rope_after := int(state.get_item_count(&"rope"))
	var label := chest.get_node_or_null(^"StateLabel") as Label3D
	var label_ok: bool = label != null and label.visible and label.text == "Обыскано"
	var ok: bool = shards >= 2 and rope >= 1 and flag_ok and opened_count[0] == 1
	ok = ok and shards_after == shards and rope_after == rope and label_ok and lid_ok
	print(
		"CHEST shards=%d rope=%d flag=%s opened_signals=%d repeat_shards=%d repeat_rope=%d label=%s lid=%.1f %s" % [
			shards, rope, str(flag_ok), opened_count[0], shards_after, rope_after,
			str(label_ok), lid_angle, "OK" if ok else "FAIL",
		]
	)
	chest.queue_free()
	return 0 if ok else 1


func _test_sarcophagus_lid(state: Node) -> int:
	state.reset()
	var packed := load("res://scenes/loot/containers/ancient_tomb_sarcophagus.tscn") as PackedScene
	if packed == null:
		push_error("loot_pool_test: sarcophagus scene missing")
		return 1
	var sarc := packed.instantiate() as LootCache
	root.add_child(sarc)
	await process_frame
	var lid := sarc.get_node_or_null(^"VisualRoot/Model/Lid") as Node3D
	sarc.interact()
	await create_timer(0.9).timeout
	var angle := lid.rotation_degrees.x if lid != null else 0.0
	var ok: bool = lid != null and absf(angle - 75.0) < 1.0
	print("SARCOPHAGUS lid=%.1f %s" % [angle, "OK" if ok else "FAIL"])
	sarc.queue_free()
	return 0 if ok else 1


func _test_dropper(state: Node) -> int:
	var enemy := Node3D.new()
	enemy.name = "TestEnemy"
	var health := HealthComponent.new()
	health.name = "Health"
	health.max_health = 10.0
	enemy.add_child(health)
	var dropper := LootDropper.new()
	dropper.name = "LootDropper"
	dropper.loot_pool = load(SCAVENGER_POOL) as LootPool
	dropper.drop_flag = &"test_dropper_done"
	enemy.add_child(dropper)
	root.add_child(enemy)
	await process_frame
	var before := int(state.get_currency(&"soul_shard"))
	health.take_damage(999.0)
	await process_frame
	var after_death := int(state.get_currency(&"soul_shard"))
	var flag_ok := bool(state.has_flag(&"test_dropper_done"))
	var bags := get_nodes_in_group(&"loot_bag")
	var bag: LootBag = null
	if not bags.is_empty():
		bag = bags[0] as LootBag
	var bag_ok := bag != null
	var icon := bag.get_node_or_null(^"Icon") as Sprite3D if bag != null else null
	var icon_ok := icon != null and icon.texture != null
	var after_pickup := after_death
	if bag != null:
		bag.interact()
		await process_frame
		after_pickup = int(state.get_currency(&"soul_shard"))
	var no_auto := after_death == before
	var ok: bool = no_auto and flag_ok and bag_ok and icon_ok and after_pickup > before
	print(
		"DROPPER before=%d after_death=%d after_pickup=%d flag=%s bag=%s icon=%s %s" % [
			before, after_death, after_pickup, str(flag_ok), str(bag_ok),
			str(icon_ok), "OK" if ok else "FAIL",
		]
	)
	enemy.queue_free()
	return 0 if ok else 1


func _test_bag_persistence(state: Node) -> int:
	state.reset()
	var enemy := Node3D.new()
	enemy.name = "PersistEnemy"
	var health := HealthComponent.new()
	health.name = "Health"
	health.max_health = 10.0
	enemy.add_child(health)
	var dropper := LootDropper.new()
	dropper.name = "LootDropper"
	dropper.loot_pool = load(SCAVENGER_POOL) as LootPool
	dropper.drop_flag = &"test_persist_dropped"
	dropper.drop_seed = 999
	enemy.add_child(dropper)
	root.add_child(enemy)
	await process_frame
	health.take_damage(999.0)
	await process_frame
	var records: Array = state.get_loot_bags("")
	var record_ok: bool = records.size() == 1
	var snapshot: Dictionary = state.snapshot()
	state.reset()
	state.restore(snapshot)
	var persistence := LootBagPersistence.new()
	root.add_child(persistence)
	await process_frame
	await process_frame
	var bags := get_nodes_in_group(&"loot_bag")
	var bag: LootBag = null
	for node in bags:
		if node is LootBag and (node as LootBag).bag_id == &"test_persist_dropped_bag":
			bag = node as LootBag
			break
	var restored_ok := bag != null and not bag.drops.is_empty()
	var before := int(state.get_currency(&"soul_shard"))
	if bag != null:
		bag.interact()
		await process_frame
	var after := int(state.get_currency(&"soul_shard"))
	var cleared: bool = state.get_loot_bags("").is_empty()
	var ok: bool = record_ok and restored_ok and after > before and cleared
	print(
		"BAG_PERSIST record=%s restored=%s shards_before=%d after=%d cleared=%s %s" % [
			str(record_ok), str(restored_ok), before, after, str(cleared),
			"OK" if ok else "FAIL",
		]
	)
	enemy.queue_free()
	persistence.queue_free()
	return 0 if ok else 1


func _test_stack_limits(state: Node) -> int:
	state.reset()
	state.add_item(&"provisions", 3)
	var item := LootRegistry.get_item(&"provisions")
	var drop := LootDrop.new()
	drop.item = item
	drop.count = 2
	var drops: Array[LootDrop] = []
	drops.append(drop)
	var packed := load("res://scenes/loot/loot_bag.tscn") as PackedScene
	var bag := packed.instantiate() as LootBag
	bag.bag_id = &"test_stack_bag"
	bag.drops = drops
	root.add_child(bag)
	await process_frame
	bag.interact()
	await process_frame
	var held := int(state.get_item_count(&"provisions"))
	var retained: bool = bag.enabled and not bag.drops.is_empty() and bag.drops[0].count == 2
	state.set_item(&"provisions", 1)
	bag.interact()
	await process_frame
	var after := int(state.get_item_count(&"provisions"))
	var freed := not is_instance_valid(bag)
	var ok: bool = held == 3 and retained and after == 3 and freed
	print(
		"STACK_LIMIT held=%d retained=%s after=%d freed=%s %s" % [
			held, str(retained), after, str(freed), "OK" if ok else "FAIL",
		]
	)
	return 0 if ok else 1


func _test_cache_overflow(state: Node) -> int:
	state.reset()
	state.add_item(&"provisions", 3)
	var packed := load("res://scenes/loot/containers/loot_barrel_cluster.tscn") as PackedScene
	var cache := packed.instantiate() as LootCache
	root.add_child(cache)
	await process_frame
	cache.interact()
	await process_frame
	var held := int(state.get_item_count(&"provisions"))
	var overflow: LootBag = null
	for node in get_nodes_in_group(&"loot_bag"):
		if node is LootBag and String((node as LootBag).bag_id).contains("overflow"):
			overflow = node as LootBag
			break
	var overflow_ok := overflow != null and not overflow.drops.is_empty()
	state.set_item(&"provisions", 0)
	if overflow != null:
		overflow.interact()
		await process_frame
	var after := int(state.get_item_count(&"provisions"))
	var ok: bool = held == 3 and overflow_ok and after >= 1
	print(
		"CACHE_OVERFLOW held=%d overflow=%s after=%d %s" % [
			held, str(overflow_ok), after, "OK" if ok else "FAIL",
		]
	)
	cache.queue_free()
	if overflow != null and is_instance_valid(overflow):
		overflow.queue_free()
	return 0 if ok else 1


func _test_future_filter() -> int:
	var pool := load(RELIC_POOL) as LootPool
	if pool == null:
		push_error("loot_pool_test: relic pool missing")
		return 1
	var future_without := 0
	var future_with := 0
	for seed_value in range(100):
		var rng := LootPoolRoller.seeded_rng(seed_value)
		for drop in LootPoolRoller.roll(pool, rng, false):
			if String(drop.get_id()).begins_with("reef_warden_"):
				future_without += 1
		rng = LootPoolRoller.seeded_rng(seed_value)
		for drop in LootPoolRoller.roll(pool, rng, true):
			if String(drop.get_id()).begins_with("reef_warden_"):
				future_with += 1
	var ok: bool = future_without == 0 and future_with > 0
	print(
		"FUTURE_FILTER without=%d with=%d %s" % [
			future_without, future_with, "OK" if ok else "FAIL",
		]
	)
	return 0 if ok else 1


func _test_unique_enforcement(state: Node) -> int:
	state.reset()
	var pool := load(RELIC_POOL) as LootPool
	if pool == null:
		push_error("loot_pool_test: relic pool missing for unique test")
		return 1
	var rng := LootPoolRoller.seeded_rng(777)
	var drops := LootPoolRoller.roll(pool, rng, true)
	LootPoolRoller.apply(drops, state)
	LootPoolRoller.apply(drops, state)
	var count := int(state.get_item_count(&"reef_warden_helm"))
	var ok: bool = count == 1
	print("UNIQUE helm_count=%d %s" % [count, "OK" if ok else "FAIL"])
	return 0 if ok else 1


func _test_scavenger_pool() -> int:
	var pool := load(SCAVENGER_POOL) as LootPool
	if pool == null:
		push_error("loot_pool_test: scavenger pool missing")
		return 1
	var rng := LootPoolRoller.seeded_rng(12345)
	var drops := LootPoolRoller.roll(pool, rng, false)
	var has_shard := false
	for drop in drops:
		if drop.get_id() == &"soul_shard":
			has_shard = true
	var ok: bool = not drops.is_empty() and has_shard
	print("SCAVENGER drops=%s %s" % [LootPoolRoller.format_drops(drops), "OK" if ok else "FAIL"])
	return 0 if ok else 1

