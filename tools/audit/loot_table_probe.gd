extends SceneTree
## Read-only probe of the placed loot caches and their actual deterministic rolls.
##
## Usage:
##   godot --headless --path . -s tools/audit/loot_table_probe.gd

const SCENE_PATH := "res://scenes/locations/forgotten_shore_labyrinth/labyrinth_first_fragment.tscn"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var packed := load(SCENE_PATH) as PackedScene
	if packed == null:
		push_error("loot_table_probe: cannot load scene")
		quit(2)
		return
	var scene := packed.instantiate() as Node3D
	var secrets := scene.get_node_or_null(^"Gameplay/Interactables/Secrets")
	if secrets == null:
		push_error("loot_table_probe: Secrets node missing")
		scene.free()
		quit(2)
		return

	var ids: Array[StringName] = []
	for child in secrets.get_children():
		if not (child is LootCache):
			continue
		var cache := child as LootCache
		ids.append(cache.container_id)
		var drops := cache.roll_drops()
		print(
			"CACHE %s pool=%s future=%s -> %s" % [
				String(cache.container_id),
				String(cache.loot_pool.id) if cache.loot_pool != null else "<null>",
				str(cache.include_future),
				LootPoolRoller.format_drops(drops),
			]
		)

	# Duplicate unique set pieces across the two relic caches.
	var relic_ids: Array[StringName] = []
	for id in ids:
		if String(id).contains("ossuary"):
			relic_ids.append(id)
	var unique_seen: Dictionary = {}
	for id in relic_ids:
		var cache := _find_cache(secrets, id)
		if cache == null or cache.loot_pool == null:
			continue
		var rng := LootPoolRoller.seeded_rng(hash(String(id)) ^ 0x5EAF00D)
		for drop in LootPoolRoller.roll(cache.loot_pool, rng, cache.include_future):
			if drop.unique:
				unique_seen[drop.get_id()] = int(unique_seen.get(drop.get_id(), 0)) + drop.count
	print("UNIQUE_RELIC_DROPS %s" % str(unique_seen))

	# Economy summary over 1000 rolls of every container pool.
	for id in ids:
		var cache := _find_cache(secrets, id)
		if cache == null or cache.loot_pool == null:
			continue
		var total := 0
		var min_total := 999
		var max_total := 0
		var shards := 0
		for seed_value in range(1000):
			var rng := LootPoolRoller.seeded_rng(seed_value)
			var drops := LootPoolRoller.roll(cache.loot_pool, rng, cache.include_future)
			var count := 0
			for drop in drops:
				count += drop.count
				if drop.get_id() == &"soul_shard":
					shards += drop.count
			total += count
			min_total = mini(min_total, count)
			max_total = maxi(max_total, count)
		print(
			"STATS %s avg_items=%.2f min=%d max=%d avg_shards=%.2f" % [
				String(id),
				float(total) / 1000.0,
				min_total,
				max_total,
				float(shards) / 1000.0,
			]
		)
	scene.free()
	quit(0)


func _find_cache(root: Node, id: StringName) -> LootCache:
	for child in root.get_children():
		if child is LootCache and (child as LootCache).container_id == id:
			return child as LootCache
	return null
