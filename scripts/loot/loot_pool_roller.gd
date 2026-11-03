class_name LootPoolRoller
extends RefCounted
## Детерминированный ролл generic-пулов лута.
##
## Контейнеры используют seed от своего id, поэтому перезагрузка не даёт
## новый результат. Враги используют seed от таблицы и координаты спавна.
## GD_FUTURE-записи по умолчанию отфильтрованы: канонический проход не должен
## получать выдуманные бандитские мечи или реликтовые сеты.

const FUTURE_STATUS := &"GD_FUTURE"


static func roll(
	pool: LootPool,
	rng: RandomNumberGenerator,
	include_future := false
) -> Array[LootDrop]:
	var drops: Array[LootDrop] = []
	if pool == null or rng == null:
		return drops
	if not include_future and pool.canon_status == FUTURE_STATUS:
		return drops
	for entry in pool.guaranteed:
		if _allowed(entry, include_future):
			drops.append(_make_drop(entry, rng, pool.id))
	if pool.bonus_rolls > 0 and pool.empty_chance > 0.0:
		if rng.randf() * 100.0 < pool.empty_chance:
			return _merge(drops)
	for _index in pool.bonus_rolls:
		var entry := _pick_weighted(pool.entries, rng, include_future)
		if entry != null:
			drops.append(_make_drop(entry, rng, pool.id))
	return _merge(drops)


## Выдаёт дропы в NightmareRunState. Возвращает то, что не поместилось
## из-за stack_max: LootBag/LootCache оставляют это в мире, а не удаляют.
static func apply(drops: Array[LootDrop], run_state: Node = null) -> Array[LootDrop]:
	var leftovers: Array[LootDrop] = []
	var state := run_state if run_state != null else _run_state()
	if state == null:
		return drops.duplicate()
	for drop in drops:
		if drop == null or not drop.is_valid():
			continue
		if drop.unique and _already_owned(state, drop):
			continue
		var category := drop.get_category()
		match category:
			LootItemData.Category.CURRENCY:
				if state.has_method(&"add_currency"):
					state.call(&"add_currency", drop.get_id(), drop.count)
			LootItemData.Category.MEMORY:
				if state.has_method(&"unlock_memory"):
					state.call(&"unlock_memory", drop.get_id())
			LootItemData.Category.KEY:
				if _item_count(state, drop.get_id()) <= 0 and state.has_method(&"add_item"):
					state.call(&"add_item", drop.get_id(), 1)
			_:
				if not state.has_method(&"add_item"):
					leftovers.append(drop)
					continue
				var item := drop.item
				var max_stack := maxi(item.stack_max, 1) if item != null else 1
				var current := _item_count(state, drop.get_id())
				if category in [LootItemData.Category.EQUIPMENT, LootItemData.Category.RELIC]:
					if current >= 1:
						continue
					max_stack = 1
				var room := maxi(max_stack - current, 0)
				if room <= 0:
					leftovers.append(drop)
					continue
				var add_count := mini(drop.count, room)
				state.call(&"add_item", drop.get_id(), add_count)
				if add_count < drop.count:
					var rest := _copy_drop(drop)
					rest.count = drop.count - add_count
					leftovers.append(rest)
	return leftovers


static func _item_count(state: Node, item_id: StringName) -> int:
	if state.has_method(&"get_item_count"):
		return int(state.call(&"get_item_count", item_id))
	return 0


static func _copy_drop(drop: LootDrop) -> LootDrop:
	var copy := LootDrop.new()
	copy.item = drop.item
	copy.count = drop.count
	copy.condition = drop.condition
	copy.unique = drop.unique
	copy.source_table_id = drop.source_table_id
	return copy


static func merge_drops(drops: Array[LootDrop]) -> Array[LootDrop]:
	return _merge(drops)


static func format_drops(drops: Array[LootDrop]) -> String:
	var parts := PackedStringArray()
	for drop in drops:
		if drop != null and drop.is_valid():
			parts.append(drop.to_text())
	return ", ".join(parts)


static func seeded_rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


static func serialize_drops(drops: Array[LootDrop]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for drop in drops:
		if drop == null or not drop.is_valid():
			continue
		result.append({
			"item_id": String(drop.get_id()),
			"count": drop.count,
			"condition": drop.condition,
			"unique": drop.unique,
			"source": String(drop.source_table_id),
		})
	return result


static func deserialize_drops(data: Array) -> Array[LootDrop]:
	var result: Array[LootDrop] = []
	for entry in data:
		if not (entry is Dictionary):
			continue
		var item_id := StringName(entry.get("item_id", ""))
		if item_id == &"":
			continue
		var item := LootRegistry.get_item(item_id)
		if item == null:
			continue
		var drop := LootDrop.new()
		drop.item = item
		drop.count = maxi(int(entry.get("count", 1)), 1)
		drop.condition = clampf(float(entry.get("condition", 1.0)), 0.0, 1.0)
		drop.unique = bool(entry.get("unique", false))
		drop.source_table_id = StringName(entry.get("source", ""))
		result.append(drop)
	return result


static func _allowed(entry: LootPoolEntry, include_future: bool) -> bool:
	if entry == null or entry.item == null or not entry.is_valid():
		return false
	if not include_future and entry.item.canon_status == FUTURE_STATUS:
		return false
	return true


static func _pick_weighted(
	entries: Array[LootPoolEntry],
	rng: RandomNumberGenerator,
	include_future: bool
) -> LootPoolEntry:
	var total := 0.0
	for entry in entries:
		if _allowed(entry, include_future):
			total += entry.weight
	if total <= 0.0:
		return null
	var pick := rng.randf() * total
	for entry in entries:
		if not _allowed(entry, include_future):
			continue
		pick -= entry.weight
		if pick <= 0.0:
			return entry
	return null


static func _make_drop(
	entry: LootPoolEntry,
	rng: RandomNumberGenerator,
	pool_id: StringName
) -> LootDrop:
	var drop := LootDrop.new()
	drop.item = entry.item
	drop.count = entry.roll_count(rng)
	drop.condition = entry.roll_condition(rng)
	drop.unique = entry.unique
	drop.source_table_id = pool_id
	return drop


static func _merge(drops: Array[LootDrop]) -> Array[LootDrop]:
	var merged: Array[LootDrop] = []
	var index: Dictionary = {}
	for drop in drops:
		if drop == null or not drop.is_valid():
			continue
		var key := "%s|%d|%s" % [
			String(drop.get_id()),
			int(round(drop.condition * 100.0)),
			str(drop.unique),
		]
		if index.has(key):
			var existing: LootDrop = merged[int(index[key])]
			existing.count += drop.count
			continue
		index[key] = merged.size()
		merged.append(drop)
	return merged


static func _already_owned(state: Node, drop: LootDrop) -> bool:
	if drop.get_category() == LootItemData.Category.MEMORY:
		if state.has_method(&"has_memory"):
			return bool(state.call(&"has_memory", drop.get_id()))
		return false
	if state.has_method(&"has_item"):
		return bool(state.call(&"has_item", drop.get_id()))
	return false


static func _run_state() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null(^"NightmareRunState")
