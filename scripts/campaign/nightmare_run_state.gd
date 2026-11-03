extends Node
## Состояние прохождения Первого Кошмара между сценами.
##
## Autoload. Хранит только сюжетные флаги и предметы, а не ссылки на узлы:
## поэтому состояние переживает change_scene_to_file() и не зависит от того,
## какая сцена сейчас загружена. Кампания вызывает reset() при старте и по R.

signal flag_changed(name: StringName, value: bool)
signal item_changed(id: StringName, count: int)
signal beat_changed(beat_id: StringName)
signal checkpoint_changed(checkpoint_id: StringName, position: Vector3)
signal bestiary_unlocked(entry_id: StringName, event_id: StringName)
signal quest_changed(quest_id: StringName, state: StringName)
signal quest_objective_changed(quest_id: StringName, objective_id: StringName, progress: int, required: int)
signal currency_changed(currency_id: StringName, amount: int)
signal memory_unlocked(memory_id: StringName)
signal equipment_changed(ids: Dictionary)
signal inventory_changed(ids: Dictionary)
signal state_reset
signal state_restored

## Сюжетные предметы, которые разрешено хранить в инвентаре.
## Атрибуты вроде Mark of Divinity хранятся сюжетными флагами, а не здесь.
const ITEM_IDS: Array[StringName] = [
	&"key",
	&"silver_bell",
	&"cloak",
	&"boots",
	&"flasks",
	&"sword",
	&"puppeteer_shroud",
	&"shadow_blessing",
	# Generic loot stored by LootPoolRoller. Currency (soul_shard) and
	# Memories live in their own registries and are not listed here.
	&"provisions",
	&"water_skin",
	&"field_medkit",
	&"rope",
	&"oil_flask",
	&"torch",
	&"carapace_plate",
	&"carapace_claw",
	&"carapace_joint",
	&"centurion_scythe_fragment",
	&"demon_fat",
	&"blood_fiend_fang",
	&"bone_spear",
	&"ancient_coral_plate",
	&"reef_warden_helm",
	&"reef_warden_plate",
	&"reef_warden_greaves",
	&"iron_sword_worn",
	&"iron_sword_used",
	&"iron_sword_fine",
	&"leather_cuirass_worn",
	&"leather_cuirass_used",
	&"bandit_cloak",
]

## Legacy flag names are read-only migration aliases. New writes always use
## the canonical name; aliases never enter _flags or snapshot().
const FLAG_ALIASES: Dictionary = {
	&"precinct_mirror_seen": &"p05_mirror_seen",
	&"precinct_exit_seen": &"p05_completed",
	&"academy_jet_seen": &"jett_advice_heard",
	&"academy_checkpoint_seen": &"p06_checkpoint_passed",
	&"academy_gate_checked": &"academy_gate_passed",
	&"academy_campus_guide_seen": &"dorm_assigned",
	&"sleeper_ready": &"capsule_entered",
	&"black_sea_stars_seen": &"statue_seen",
	&"black_sea_sword_seen": &"statue_seen",
	&"black_sea_descent_seen": &"b01_completed",
	&"tide_descent_warning_seen": &"tide_seen",
	&"demo_m1_completed": &"post_nightmare_demo_completed",
	&"demo_completed": &"post_nightmare_completed",
}

var _flags: Dictionary = {}
var _items: Dictionary = {}
## id записи бестиария -> событие, которым она открыта. Отдельный набор
## переживает смену сцен и попадает в snapshot; UI читает ресурсы записи.
var _bestiary: Dictionary = {}
## Состояние заданий: quest_id -> { state, objectives, reward_claimed }.
## Сами описания заданий живут в .tres, здесь только изменяемый прогресс.
var _quests: Dictionary = {}
## Счётчики валюты (кристаллы души и т.п.). Не занимают слоты инвентаря.
var _currency: Dictionary = {}
## Открытые Памяти. Уникальные id, без количества и слотов.
var _memories: Dictionary = {}
## Надетое: body/weapon/accessories. Только ID, без ссылок на Resource/сцену.
var _equipment: Dictionary = {}
## Физические мешки лута, ещё не подобранные игроком. Ключ — bag_id.
## Значение: { scene, position, drops, drop_flag, collected_flag }.
var _loot_bags: Dictionary = {}
## Стеки демо/equipment-инвентаря: id -> count. Не путать с сюжетными _items.
var _inventory: Dictionary = {}
var _tracked_quest: StringName = &""
var _current_beat_id: StringName = &""
var _checkpoint_id: StringName = &""
var _checkpoint_position := Vector3.ZERO
var _has_checkpoint_position := false


## Полный сброс перед новым прохождением или отладочным запуском.
func reset() -> void:
	_flags.clear()
	_items.clear()
	_bestiary.clear()
	_quests.clear()
	_currency.clear()
	_memories.clear()
	_equipment.clear()
	_loot_bags.clear()
	_inventory.clear()
	_tracked_quest = &""
	_current_beat_id = &""
	_checkpoint_id = &""
	_checkpoint_position = Vector3.ZERO
	_has_checkpoint_position = false
	state_reset.emit()



## Resolve a legacy flag name to the canonical key without touching state.
static func canonical_flag(flag_name: StringName) -> StringName:
	var key := StringName(flag_name)
	return StringName(FLAG_ALIASES.get(key, key))


func set_flag(flag_name: StringName, value := true) -> void:
	var key := canonical_flag(flag_name)
	var enabled := bool(value)
	var previous := _flags.has(key)
	if previous == enabled:
		return
	if enabled:
		_flags[key] = true
	else:
		_flags.erase(key)
	flag_changed.emit(key, enabled)


func clear_flag(flag_name: StringName) -> void:
	set_flag(flag_name, false)


func has_flag(flag_name: StringName) -> bool:
	return _flags.has(canonical_flag(flag_name))


func get_flag(flag_name: StringName, default_value := false) -> bool:
	return bool(_flags.get(canonical_flag(flag_name), default_value))


## Все перечисленные флаги должны быть установлены.
func require(flags: Array[StringName]) -> bool:
	for flag in flags:
		if not has_flag(flag):
			return false
	return true


## Открывает запись бестиария ровно один раз. Повторное событие не создаёт
## дубль и не перезаписывает исходное событие открытия.
func unlock_bestiary(entry_id: StringName, event_id: StringName = &"") -> bool:
	var key := StringName(entry_id)
	if key == &"" or _bestiary.has(key):
		return false
	_bestiary[key] = StringName(event_id)
	bestiary_unlocked.emit(key, StringName(event_id))
	return true


func has_bestiary(entry_id: StringName) -> bool:
	return _bestiary.has(StringName(entry_id))


func get_bestiary_event(entry_id: StringName) -> StringName:
	return StringName(_bestiary.get(StringName(entry_id), &""))


func get_bestiary_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for key in _bestiary.keys():
		result.append(StringName(key))
	result.sort()
	return result


func get_bestiary_events() -> Dictionary:
	return _bestiary.duplicate(true)


## ---------------------------------------------------------------------------
## Задания
## ---------------------------------------------------------------------------

func set_quest_state(quest_id: StringName, state: StringName) -> void:
	var id := StringName(quest_id)
	if id == &"":
		return
	var record: Dictionary = _quests.get(id, {})
	var previous := StringName(record.get("state", &""))
	var next := StringName(state)
	if previous == next:
		return
	record["state"] = next
	_quests[id] = record
	quest_changed.emit(id, next)


func get_quest_state(quest_id: StringName) -> StringName:
	var record: Variant = _quests.get(StringName(quest_id), null)
	if record is Dictionary:
		return StringName(record.get("state", &""))
	return &""


func has_quest(quest_id: StringName) -> bool:
	return get_quest_state(quest_id) != &""


func get_quest_objective_progress(quest_id: StringName, objective_id: StringName) -> int:
	var record: Variant = _quests.get(StringName(quest_id), null)
	if not (record is Dictionary):
		return 0
	var objectives: Variant = record.get("objectives", {})
	if not (objectives is Dictionary):
		return 0
	return int(objectives.get(StringName(objective_id), 0))


func set_quest_objective_progress(
	quest_id: StringName,
	objective_id: StringName,
	progress: int,
	required := 0
) -> void:
	var id := StringName(quest_id)
	var objective_key := StringName(objective_id)
	if id == &"" or objective_key == &"":
		return
	var record: Dictionary = _quests.get(id, {})
	var objectives: Dictionary = record.get("objectives", {})
	var previous := int(objectives.get(objective_key, 0))
	var next := maxi(progress, 0)
	if previous == next:
		return
	objectives[objective_key] = next
	record["objectives"] = objectives
	_quests[id] = record
	quest_objective_changed.emit(id, objective_key, next, maxi(required, 0))


func get_quest_objectives(quest_id: StringName) -> Dictionary:
	var record: Variant = _quests.get(StringName(quest_id), null)
	if not (record is Dictionary):
		return {}
	var objectives: Variant = record.get("objectives", {})
	return (objectives as Dictionary).duplicate(true) if objectives is Dictionary else {}


func mark_quest_reward_claimed(quest_id: StringName) -> void:
	var id := StringName(quest_id)
	if id == &"":
		return
	var record: Dictionary = _quests.get(id, {})
	if bool(record.get("reward_claimed", false)):
		return
	record["reward_claimed"] = true
	_quests[id] = record


func is_quest_reward_claimed(quest_id: StringName) -> bool:
	var record: Variant = _quests.get(StringName(quest_id), null)
	if record is Dictionary:
		return bool(record.get("reward_claimed", false))
	return false


func set_tracked_quest(quest_id: StringName) -> void:
	var next := StringName(quest_id)
	if _tracked_quest == next:
		return
	_tracked_quest = next


func get_tracked_quest() -> StringName:
	return _tracked_quest


func get_quest_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for key in _quests.keys():
		result.append(StringName(key))
	result.sort()
	return result


## ---------------------------------------------------------------------------
## Валюта и Памяти
## ---------------------------------------------------------------------------

func set_currency(currency_id: StringName, amount: int) -> void:
	var id := StringName(currency_id)
	if id == &"":
		return
	var previous := int(_currency.get(id, 0))
	var next := maxi(amount, 0)
	if previous == next:
		return
	if next <= 0:
		_currency.erase(id)
	else:
		_currency[id] = next
	currency_changed.emit(id, next)


func add_currency(currency_id: StringName, amount: int) -> void:
	if amount <= 0:
		return
	set_currency(currency_id, get_currency(currency_id) + amount)


func remove_currency(currency_id: StringName, amount := 1) -> bool:
	var id := StringName(currency_id)
	var cost := maxi(amount, 0)
	var current := get_currency(id)
	if cost <= 0 or current < cost:
		return false
	set_currency(id, current - cost)
	return true


func get_currency(currency_id: StringName) -> int:
	return int(_currency.get(StringName(currency_id), 0))


func has_currency(currency_id: StringName, amount := 1) -> bool:
	return get_currency(currency_id) >= maxi(amount, 0)


## Открывает Память ровно один раз. Памяти не попадают в инвентарь и не
## складываются в стопки: это отдельный реестр состояния.
func unlock_memory(memory_id: StringName) -> bool:
	var id := StringName(memory_id)
	if id == &"" or _memories.has(id):
		return false
	_memories[id] = true
	memory_unlocked.emit(id)
	return true


func has_memory(memory_id: StringName) -> bool:
	return _memories.has(StringName(memory_id))


func get_memories() -> Array[StringName]:
	var result: Array[StringName] = []
	for key in _memories.keys():
		result.append(StringName(key))
	result.sort()
	return result


func get_currency_wallet() -> Dictionary:
	return _currency.duplicate(true)


## Сюжетный предмет. count <= 0 удаляет предмет; значение хранится как
## количество, чтобы фляги можно было собирать по одной.
func set_item(id: StringName, count := 1) -> void:
	var key := StringName(id)
	var previous := int(_items.get(key, 0))
	var next := maxi(int(count), 0)
	if previous == next:
		return
	if next <= 0:
		_items.erase(key)
	else:
		_items[key] = next
	item_changed.emit(key, next)


func add_item(id: StringName, count := 1) -> void:
	set_item(id, get_item_count(id) + maxi(int(count), 0))


## Возвращает true, если предмета хватило и он был списан.
func remove_item(id: StringName, count := 1) -> bool:
	var key := StringName(id)
	var amount := maxi(int(count), 0)
	var current := get_item_count(key)
	if amount <= 0 or current < amount:
		return false
	set_item(key, current - amount)
	return true


func has_item(id: StringName) -> bool:
	return get_item_count(id) > 0


func get_item_count(id: StringName) -> int:
	return int(_items.get(StringName(id), 0))


func set_current_beat(beat_id: StringName) -> void:
	var next := StringName(beat_id)
	if _current_beat_id == next:
		return
	_current_beat_id = next
	beat_changed.emit(_current_beat_id)


func get_current_beat() -> StringName:
	return _current_beat_id


func set_checkpoint(checkpoint_id: StringName, position := Vector3.ZERO, has_position := false) -> void:
	_checkpoint_id = StringName(checkpoint_id)
	_checkpoint_position = position
	_has_checkpoint_position = has_position
	checkpoint_changed.emit(_checkpoint_id, _checkpoint_position)


func get_checkpoint_id() -> StringName:
	return _checkpoint_id


func get_checkpoint_position() -> Vector3:
	return _checkpoint_position


func has_checkpoint() -> bool:
	return _checkpoint_id != &""


func has_checkpoint_position() -> bool:
	return _has_checkpoint_position


func clear_checkpoint() -> void:
	_checkpoint_id = &""
	_checkpoint_position = Vector3.ZERO
	_has_checkpoint_position = false


## Сохраняет только ID надетого. Пустые слоты нормализуются в &"".
func set_equipment_ids(ids: Dictionary) -> void:
	var normalized := _normalize_equipment_ids(ids)
	if normalized == _equipment:
		return
	_equipment = normalized
	equipment_changed.emit(_equipment.duplicate(true))


func get_equipment_ids() -> Dictionary:
	return _equipment.duplicate(true)


func has_equipment() -> bool:
	if _equipment.is_empty():
		return false
	if StringName(_equipment.get("body", &"")) != &"":
		return true
	if StringName(_equipment.get("weapon", &"")) != &"":
		return true
	var accessories_value: Variant = _equipment.get("accessories", [])
	if accessories_value is Array:
		return not (accessories_value as Array).is_empty()
	return false


func clear_equipment() -> void:
	if _equipment.is_empty():
		return
	_equipment.clear()
	equipment_changed.emit({})


func _normalize_equipment_ids(ids: Dictionary) -> Dictionary:
	var accessories: Array[StringName] = []
	var raw_accessories: Variant = ids.get("accessories", [])
	if raw_accessories is Array:
		for raw in raw_accessories:
			var accessory := StringName(raw)
			if accessory != &"":
				accessories.append(accessory)
	return {
		"body": StringName(ids.get("body", &"")),
		"weapon": StringName(ids.get("weapon", &"")),
		"accessories": accessories,
	}


## Стеки демо/equipment-инвентаря. Хранится только id -> count.
func set_inventory_ids(ids: Dictionary) -> void:
	var normalized: Dictionary = {}
	for key in ids.keys():
		var count := int(ids[key])
		if count > 0:
			normalized[StringName(key)] = count
	if normalized == _inventory:
		return
	_inventory = normalized
	inventory_changed.emit(_inventory.duplicate(true))


func get_inventory_ids() -> Dictionary:
	return _inventory.duplicate(true)


func has_inventory() -> bool:
	return not _inventory.is_empty()


func clear_inventory() -> void:
	if _inventory.is_empty():
		return
	_inventory.clear()
	inventory_changed.emit({})


## ---------------------------------------------------------------------------
## Физические мешки лута
## ---------------------------------------------------------------------------

## Регистрирует неподобранный мешок. Дропы сериализованы в Array[Dictionary],
## чтобы снимок не держал ссылки на RefCounted-объекты.
func register_loot_bag(
	bag_id: StringName,
	scene_path: String,
	position: Vector3,
	drops: Array[Dictionary],
	drop_flag: StringName = &"",
	collected_flag: StringName = &""
) -> void:
	var id := StringName(bag_id)
	if id == &"":
		return
	_loot_bags[id] = {
		"scene": scene_path,
		"position": position,
		"drops": drops.duplicate(true),
		"drop_flag": String(drop_flag),
		"collected_flag": String(collected_flag),
	}


func unregister_loot_bag(bag_id: StringName) -> void:
	_loot_bags.erase(StringName(bag_id))


func get_loot_bags(scene_path: String = "") -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for raw_id in _loot_bags.keys():
		var record: Variant = _loot_bags[raw_id]
		if not (record is Dictionary):
			continue
		var data: Dictionary = record
		if not scene_path.is_empty() and String(data.get("scene", "")) != scene_path:
			continue
		var copy: Dictionary = data.duplicate(true)
		copy["bag_id"] = String(raw_id)
		result.append(copy)
	return result


## Копия для отладки, сохранения или сравнения в тестах.
func snapshot() -> Dictionary:
	var result := {
		"flags": _flags.duplicate(true),
		"items": _items.duplicate(true),
	}
	if not _bestiary.is_empty():
		result["bestiary"] = _bestiary.duplicate(true)
	if not _quests.is_empty():
		result["quests"] = _quests.duplicate(true)
	if not _currency.is_empty():
		result["currency"] = _currency.duplicate(true)
	if not _memories.is_empty():
		result["memories"] = _memories.duplicate(true)
	if has_equipment():
		result["equipment"] = _equipment.duplicate(true)
	if has_inventory():
		result["inventory"] = _inventory.duplicate(true)
	if not _loot_bags.is_empty():
		result["loot_bags"] = _loot_bags.duplicate(true)
	if _tracked_quest != &"":
		result["tracked_quest"] = _tracked_quest
	if _current_beat_id != &"":
		result["current_beat_id"] = _current_beat_id
	if _checkpoint_id != &"":
		result["checkpoint_id"] = _checkpoint_id
	if _has_checkpoint_position:
		result["checkpoint_position"] = _checkpoint_position
	return result


func restore(snapshot_value: Dictionary) -> void:
	reset()
	var flags_value: Variant = snapshot_value.get("flags", {})
	if flags_value is Dictionary:
		for key in flags_value:
			if bool(flags_value[key]):
				# Old saves may contain an alias. Canonicalise on restore and
				# never keep both names in state.
				_flags[canonical_flag(StringName(key))] = true
	var items_value: Variant = snapshot_value.get("items", {})
	if items_value is Dictionary:
		for key in items_value:
			var count := int(items_value[key])
			if count > 0:
				_items[StringName(key)] = count
	var bestiary_value: Variant = snapshot_value.get("bestiary", {})
	if bestiary_value is Dictionary:
		for key in bestiary_value:
			if StringName(key) != &"":
				_bestiary[StringName(key)] = StringName(bestiary_value[key])
	var quests_value: Variant = snapshot_value.get("quests", {})
	if quests_value is Dictionary:
		for key in quests_value:
			var queued: Variant = quests_value[key]
			if not (queued is Dictionary):
				continue
			var record: Dictionary = {}
			record["state"] = StringName(queued.get("state", &""))
			var objectives_value: Variant = queued.get("objectives", {})
			var objectives: Dictionary = {}
			if objectives_value is Dictionary:
				for objective_key in objectives_value:
					objectives[StringName(objective_key)] = int(objectives_value[objective_key])
			record["objectives"] = objectives
			record["reward_claimed"] = bool(queued.get("reward_claimed", false))
			_quests[StringName(key)] = record
	var currency_value: Variant = snapshot_value.get("currency", {})
	if currency_value is Dictionary:
		for key in currency_value:
			var amount := int(currency_value[key])
			if amount > 0:
				_currency[StringName(key)] = amount
	var memories_value: Variant = snapshot_value.get("memories", {})
	if memories_value is Dictionary:
		for key in memories_value:
			if bool(memories_value[key]):
				_memories[StringName(key)] = true
	var equipment_value: Variant = snapshot_value.get("equipment", {})
	if equipment_value is Dictionary:
		set_equipment_ids(equipment_value)
	var inventory_value: Variant = snapshot_value.get("inventory", {})
	if inventory_value is Dictionary:
		set_inventory_ids(inventory_value)
	var loot_bags_value: Variant = snapshot_value.get("loot_bags", {})
	if loot_bags_value is Dictionary:
		for key in loot_bags_value:
			var record: Variant = loot_bags_value[key]
			if record is Dictionary:
				_loot_bags[StringName(key)] = (record as Dictionary).duplicate(true)
	_tracked_quest = StringName(snapshot_value.get("tracked_quest", &""))
	if snapshot_value.has("current_beat_id"):
		_current_beat_id = StringName(snapshot_value["current_beat_id"])
	if snapshot_value.has("checkpoint_id"):
		_checkpoint_id = StringName(snapshot_value["checkpoint_id"])
	if snapshot_value.has("checkpoint_position") and snapshot_value["checkpoint_position"] is Vector3:
		_checkpoint_position = snapshot_value["checkpoint_position"]
		_has_checkpoint_position = true
	state_restored.emit()
