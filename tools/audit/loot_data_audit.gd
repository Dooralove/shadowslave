extends SceneTree
## Read-only integrity audit of loot data and placed caches.
##
## Checks:
##  - catalog/item uniqueness and validity;
##  - pool validity, item references, source kinds, roll configuration;
##  - every catalog item is used by at least one pool;
##  - every placed LootCache has a unique id, a valid pool, prompt, radius;
##  - every cache has a VisualRoot/Model and a Glow;
##  - caches have no collision body (reported as INFO, not a failure).
##
## Usage:
##   godot --headless --path . -s tools/audit/loot_data_audit.gd

const CATALOG_PATH := "res://resources/loot/loot_catalog.tres"
const TABLE_DIR := "res://resources/loot/tables"
const SCENE_PATH := "res://scenes/locations/forgotten_shore_labyrinth/labyrinth_first_fragment.tscn"
const ALLOWED_SOURCE_KINDS := ["container", "enemy", "elite", "boss", "humanoid"]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var failures := 0
	var catalog := load(CATALOG_PATH) as LootCatalog
	if catalog == null:
		push_error("loot_data_audit: catalog missing")
		quit(2)
		return
	var item_ids: Dictionary = {}
	for item in catalog.items:
		if item == null or not item.is_valid():
			failures += 1
			print("ITEM INVALID")
			continue
		if item_ids.has(item.id):
			failures += 1
			print("ITEM DUPLICATE %s" % String(item.id))
		item_ids[item.id] = item
		if item.stack_max <= 0:
			failures += 1
			print("ITEM STACK_INVALID %s" % String(item.id))
	print("ITEMS count=%d unique=%d" % [catalog.items.size(), item_ids.size()])

	var pools: Dictionary = {}
	var used_items: Dictionary = {}
	var dir := DirAccess.open(TABLE_DIR)
	if dir == null:
		push_error("loot_data_audit: tables dir missing")
		quit(2)
		return
	dir.list_dir_begin()
	var file := dir.get_next()
	while file != "":
		if file.ends_with(".tres"):
			var pool := load(TABLE_DIR.path_join(file)) as LootPool
			if pool == null:
				failures += 1
				print("POOL LOAD_FAIL %s" % file)
				file = dir.get_next()
				continue
			if pools.has(pool.id):
				failures += 1
				print("POOL DUPLICATE %s" % String(pool.id))
			pools[pool.id] = pool
			for error in pool.validate():
				failures += 1
				print("POOL INVALID %s: %s" % [String(pool.id), error])
			if not ALLOWED_SOURCE_KINDS.has(pool.source_kind):
				failures += 1
				print("POOL SOURCE_KIND %s: %s" % [String(pool.id), pool.source_kind])
			if pool.entries.is_empty() and pool.bonus_rolls != 0:
				failures += 1
				print("POOL ROLLS_WITHOUT_ENTRIES %s" % String(pool.id))
			if not pool.entries.is_empty() and pool.bonus_rolls <= 0:
				failures += 1
				print("POOL ENTRIES_WITHOUT_ROLLS %s" % String(pool.id))
			for entry in pool.guaranteed:
				if entry != null and entry.item != null:
					used_items[entry.item.id] = true
					if not item_ids.has(entry.item.id):
						failures += 1
						print("POOL MISSING_ITEM %s -> %s" % [String(pool.id), String(entry.item.id)])
			for entry in pool.entries:
				if entry != null and entry.item != null:
					used_items[entry.item.id] = true
					if not item_ids.has(entry.item.id):
						failures += 1
						print("POOL MISSING_ITEM %s -> %s" % [String(pool.id), String(entry.item.id)])
		file = dir.get_next()
	dir.list_dir_end()
	print("POOLS count=%d unique=%d" % [pools.size(), pools.size()])

	for item_id in item_ids.keys():
		if not used_items.has(item_id):
			failures += 1
			print("ITEM UNUSED %s" % String(item_id))

	var packed := load(SCENE_PATH) as PackedScene
	if packed == null:
		push_error("loot_data_audit: labyrinth scene missing")
		quit(2)
		return
	var scene := packed.instantiate() as Node3D
	var secrets := scene.get_node_or_null(^"Gameplay/Interactables/Secrets")
	if secrets == null:
		push_error("loot_data_audit: Secrets node missing")
		scene.free()
		quit(2)
		return
	var cache_ids: Dictionary = {}
	var cache_count := 0
	for child in secrets.get_children():
		if not (child is LootCache):
			continue
		cache_count += 1
		var cache := child as LootCache
		if cache.container_id == &"":
			failures += 1
			print("CACHE EMPTY_ID %s" % cache.name)
		elif cache_ids.has(cache.container_id):
			failures += 1
			print("CACHE DUPLICATE_ID %s" % String(cache.container_id))
		cache_ids[cache.container_id] = true
		if cache.loot_pool == null:
			failures += 1
			print("CACHE NO_POOL %s" % String(cache.container_id))
		elif not pools.has(cache.loot_pool.id):
			failures += 1
			print("CACHE UNKNOWN_POOL %s -> %s" % [String(cache.container_id), String(cache.loot_pool.id)])
		if cache.prompt.strip_edges().is_empty():
			failures += 1
			print("CACHE EMPTY_PROMPT %s" % String(cache.container_id))
		if cache.radius <= 0.0:
			failures += 1
			print("CACHE BAD_RADIUS %s" % String(cache.container_id))
		if not cache.enabled:
			failures += 1
			print("CACHE DISABLED %s" % String(cache.container_id))
		var visual := cache.get_node_or_null(^"VisualRoot/Model")
		if visual == null:
			failures += 1
			print("CACHE NO_MODEL %s" % String(cache.container_id))
		if cache.get_node_or_null(^"Glow") == null:
			failures += 1
			print("CACHE NO_GLOW %s" % String(cache.container_id))
		if cache.get_node_or_null(^"StateLabel") == null:
			failures += 1
			print("CACHE NO_STATE_LABEL %s" % String(cache.container_id))
		var has_collision := cache.get_node_or_null(^"StaticBody3D") != null
		if not has_collision:
			failures += 1
			print("CACHE NO_COLLISION %s" % String(cache.container_id))
		print("CACHE %s pool=%s future=%s collision=%s" % [
			String(cache.container_id),
			String(cache.loot_pool.id) if cache.loot_pool != null else "<null>",
			str(cache.include_future),
			str(has_collision),
		])
	scene.free()
	print("CACHES count=%d unique=%d" % [cache_count, cache_ids.size()])
	print("LOOT_DATA_AUDIT failures=%d" % failures)
	quit(0 if failures == 0 else 1)
