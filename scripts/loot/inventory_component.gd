class_name InventoryComponent
extends Node
## Простой инвентарь по ID предметов. Хранит ссылки на Resource, но сейв
## пишет только id + quantity. Экипировка и лут используют один и тот же
## EquipmentCatalog, поэтому после загрузки ссылки восстанавливаются.

signal item_added(item: EquipmentItemData, quantity: int)
signal item_removed(item: EquipmentItemData, quantity: int)
signal inventory_changed
signal add_failed(reason: String)

@export var capacity := 40
## Каталог нужен только для add_item_id()/from_ids(). Прямой add_item()
## работает и без него.
@export var catalog: EquipmentCatalog
## Сохранять стеки в NightmareRunState и восстанавливать при старте.
@export var persist_to_run_state := false

var _items: Dictionary = {}
var _order: Array[StringName] = []
var _persistence_ready := false
var _restoring := false


func _ready() -> void:
	add_to_group(&"player_inventory")
	if persist_to_run_state and catalog != null:
		inventory_changed.connect(_on_inventory_changed)
		_persistence_ready = true
		if not restore_from_run_state():
			save_to_run_state()
	elif persist_to_run_state:
		push_warning("InventoryComponent: persist_to_run_state без catalog")


func _on_inventory_changed() -> void:
	if persist_to_run_state and _persistence_ready and not _restoring:
		save_to_run_state()


func save_to_run_state() -> void:
	var state := _run_state()
	if state == null:
		return
	var ids := to_ids()
	if ids.is_empty():
		state.call(&"clear_inventory")
	else:
		state.call(&"set_inventory_ids", ids)


func restore_from_run_state() -> bool:
	var state := _run_state()
	if state == null or not bool(state.call(&"has_inventory")):
		return false
	_restoring = true
	var ids: Variant = state.call(&"get_inventory_ids")
	var restored := false
	if ids is Dictionary:
		restored = from_ids(ids, catalog)
	_restoring = false
	return restored


func _run_state() -> Node:
	return get_node_or_null(^"/root/NightmareRunState")


func add_item(item: EquipmentItemData, quantity := 1) -> bool:
	if item == null or item.id == &"" or quantity <= 0:
		add_failed.emit("Нельзя добавить пустой предмет")
		return false
	var key := item.id
	if _items.has(key):
		var entry: Dictionary = _items[key]
		entry["quantity"] = int(entry["quantity"]) + quantity
		_items[key] = entry
	else:
		if _items.size() >= capacity:
			add_failed.emit("Инвентарь полон")
			return false
		_items[key] = {"item": item, "quantity": quantity}
		_order.append(key)
	item_added.emit(item, quantity)
	inventory_changed.emit()
	return true


func add_item_id(item_id: StringName, quantity := 1) -> bool:
	if catalog == null:
		add_failed.emit("Не назначен EquipmentCatalog")
		return false
	var item := catalog.get_item(item_id)
	if item == null:
		add_failed.emit("Предмет %s не найден" % item_id)
		return false
	return add_item(item, quantity)


func remove_item(item_id: StringName, quantity := 1) -> bool:
	if quantity <= 0 or not _items.has(item_id):
		return false
	var entry: Dictionary = _items[item_id]
	var current := int(entry["quantity"])
	var removed := mini(current, quantity)
	entry["quantity"] = current - removed
	var item := entry["item"] as EquipmentItemData
	if int(entry["quantity"]) <= 0:
		_items.erase(item_id)
		_order.erase(item_id)
	else:
		_items[item_id] = entry
	item_removed.emit(item, removed)
	inventory_changed.emit()
	return removed > 0


func has_item(item_id: StringName) -> bool:
	return _items.has(item_id) and int(_items[item_id]["quantity"]) > 0


func get_quantity(item_id: StringName) -> int:
	if not _items.has(item_id):
		return 0
	return int(_items[item_id]["quantity"])


func get_item(item_id: StringName) -> EquipmentItemData:
	if not _items.has(item_id):
		return null
	return _items[item_id]["item"] as EquipmentItemData


## Стабильный порядок: сначала добавленные, затем остальные.
func get_entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for key in _order:
		if _items.has(key):
			result.append((_items[key] as Dictionary).duplicate())
	for key in _items.keys():
		if key in _order:
			continue
		result.append((_items[key] as Dictionary).duplicate())
	return result


func get_total_quantity() -> int:
	var total := 0
	for entry in _items.values():
		total += int((entry as Dictionary)["quantity"])
	return total


func is_full() -> bool:
	return _items.size() >= capacity


func clear() -> void:
	_items.clear()
	_order.clear()
	inventory_changed.emit()


## Для сейва: {&"item_id": quantity}. Без ссылок на сцену.
func to_ids() -> Dictionary:
	var result := {}
	for key in _items.keys():
		result[String(key)] = int(_items[key]["quantity"])
	return result


func from_ids(ids: Dictionary, source_catalog: EquipmentCatalog = null) -> bool:
	var cat := source_catalog if source_catalog != null else catalog
	if cat == null:
		add_failed.emit("from_ids без EquipmentCatalog")
		return false
	var pending: Array[Dictionary] = []
	var seen: Dictionary = {}
	for raw_id in ids.keys():
		var item_id := StringName(raw_id)
		var quantity := int(ids[raw_id])
		if quantity <= 0:
			continue
		var item := cat.get_item(item_id)
		if item == null:
			add_failed.emit("from_ids: предмет %s не найден" % item_id)
			return false
		if seen.has(item_id):
			continue
		seen[item_id] = true
		pending.append({"item": item, "quantity": quantity})
	if pending.size() > capacity:
		add_failed.emit("from_ids: предметов больше вместимости")
		return false

	# Атомарная загрузка: сначала проверяем всё, затем заменяем состояние.
	# Если add_item всё же откажет, старый инвентарь восстанавливается.
	var old_items: Dictionary = _items.duplicate(true)
	var old_order: Array[StringName] = _order.duplicate()
	clear()
	for entry in pending:
		if not add_item(entry["item"] as EquipmentItemData, int(entry["quantity"])):
			_items = old_items
			_order = old_order
			inventory_changed.emit()
			return false
	return true
