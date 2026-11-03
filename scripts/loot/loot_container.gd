class_name LootContainer
extends Interactable
## Контейнер лута: открывается кнопкой взаимодействия и выдаёт предметы
## в InventoryComponent. Не спавнит физические предметы — это отдельный
## путь для сундуков, ящиков и тайников.

signal opened(drops: Array[Dictionary])
signal loot_failed(reason: String)

@export var loot_table: LootTable
@export var inventory_path: NodePath
@export var one_shot := true
@export var open_prompt := "Открыть"
@export var empty_prompt := "Пусто"
@export var rng_seed := 0
@export var flags: Dictionary = {}

var _opened := false
var _rng := RandomNumberGenerator.new()
var _inventory: InventoryComponent


func _ready() -> void:
	super._ready()
	_rng.seed = rng_seed if rng_seed != 0 else int(Time.get_unix_time_from_system())
	prompt = open_prompt
	interacted.connect(_on_interacted)


func _on_interacted(_id: StringName) -> void:
	open()


func open() -> bool:
	if _opened and one_shot:
		return false
	if loot_table == null:
		loot_failed.emit("LootTable не назначена")
		return false
	var drops := loot_table.roll(_rng, flags)
	if drops.is_empty():
		_finish_open([])
		return true
	var inventory := _resolve_inventory()
	if inventory != null:
		if not _can_accept_all(inventory, drops):
			loot_failed.emit("Инвентарь полон")
			return false
		for drop in drops:
			var item := drop.get("item") as EquipmentItemData
			var quantity := int(drop.get("quantity", 1))
			if item == null or quantity <= 0:
				continue
			if not inventory.add_item(item, quantity):
				loot_failed.emit("Инвентарь не принял %s" % item.id)
				return false
	else:
		# Кампания: выдать в NightmareRunState по ID.
		var run_state := get_node_or_null(^"/root/NightmareRunState")
		if run_state == null or not run_state.has_method(&"add_item"):
			loot_failed.emit("Не найден ни InventoryComponent, ни NightmareRunState")
			return false
		for drop in drops:
			var item := drop.get("item") as EquipmentItemData
			var quantity := int(drop.get("quantity", 1))
			if item != null and quantity > 0:
				run_state.call(&"add_item", item.id, quantity)
	_finish_open(drops)
	return true


func _finish_open(drops: Array[Dictionary]) -> void:
	_opened = true
	enabled = false
	prompt = empty_prompt
	opened.emit(drops)


func _can_accept_all(inventory: InventoryComponent, drops: Array[Dictionary]) -> bool:
	var new_slots := 0
	for drop in drops:
		var item := drop.get("item") as EquipmentItemData
		if item != null and not inventory.has_item(item.id):
			new_slots += 1
	return inventory.get_entries().size() + new_slots <= inventory.capacity


func _resolve_inventory() -> InventoryComponent:
	if _inventory != null and is_instance_valid(_inventory):
		return _inventory
	if not inventory_path.is_empty():
		_inventory = get_node_or_null(inventory_path) as InventoryComponent
	if _inventory == null:
		_inventory = get_tree().get_first_node_in_group(&"player_inventory") as InventoryComponent
	return _inventory


func is_opened() -> bool:
	return _opened


func reset() -> void:
	_opened = false
	enabled = true
	prompt = open_prompt
