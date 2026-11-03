class_name LootDropComponent
extends Node3D
## Спавнит физический лут при смерти владельца.
##
## Компонент слушает HealthComponent.died, бросает LootTable и создаёт
## WorldLootItem в мире. Он не выдаёт предметы напрямую в инвентарь: подбор
## остаётся действием игрока (Interactable/Area3D), поэтому лут можно
## подсветить, толкнуть и оставить на земле.

signal loot_dropped(drops: Array[Dictionary])
signal drop_failed(reason: String)

const DEFAULT_WORLD_ITEM := "res://scenes/loot/world_loot_item.tscn"

@export var loot_table: LootTable
@export var health_path: NodePath
## Куда складывать заспавненные предметы. Пусто — current_scene.
@export var spawn_parent: Node3D
## Явный путь к InventoryComponent для заспавненных предметов. Пусто — группа
## player_inventory (нужно только в сценах с одним инвентарём).
@export var inventory_path: NodePath
@export var world_item_scene: PackedScene
@export var drop_radius := 0.65
@export var spawn_height := 0.55
@export var launch_force := 2.2
@export var rng_seed := 0
## Дополнительные флаги для условий строк таблицы.
@export var flags: Dictionary = {}
@export var auto_drop := true
## Разрешить повторный вызов drop_loot() (например, для тестового сундука).
@export var allow_repeat := false

var _health: HealthComponent
var _rng := RandomNumberGenerator.new()
var _dropped := false


func _ready() -> void:
	_rng.seed = rng_seed if rng_seed != 0 else int(Time.get_unix_time_from_system())
	_resolve_health()
	if _health != null and auto_drop:
		_health.died.connect(_on_health_died)
	if _health != null and _health.is_dead():
		_on_health_died()


func _resolve_health() -> void:
	if not health_path.is_empty():
		_health = get_node_or_null(health_path) as HealthComponent
	if _health == null:
		_health = get_parent().get_node_or_null(^"Health") as HealthComponent


func set_loot_table(value: LootTable) -> void:
	loot_table = value


func set_flag(flag: StringName, value := true) -> void:
	flags[flag] = value


func has_dropped() -> bool:
	return _dropped


func reset_dropped() -> void:
	_dropped = false


func _on_health_died() -> void:
	if _dropped and not allow_repeat:
		return
	drop_loot()


## Публичный вход для тестов/скриптовых сцен: не требует реальной смерти.
func drop_loot() -> Array[Dictionary]:
	if loot_table == null:
		drop_failed.emit("LootTable не назначена")
		return []
	if _dropped and not allow_repeat:
		return []
	var drops := loot_table.roll(_rng, flags)
	if drops.is_empty():
		_dropped = true
		loot_dropped.emit(drops)
		return drops
	for drop in drops:
		var item := drop.get("item") as EquipmentItemData
		var quantity := int(drop.get("quantity", 1))
		if item == null or quantity <= 0:
			continue
		_spawn_world_item(item, quantity)
	_dropped = true
	loot_dropped.emit(drops)
	return drops


func _spawn_world_item(item: EquipmentItemData, quantity: int) -> WorldLootItem:
	var packed := world_item_scene
	if packed == null:
		packed = load(DEFAULT_WORLD_ITEM) as PackedScene
	if packed == null:
		drop_failed.emit("Не найден world_loot_item.tscn")
		return null
	var node := packed.instantiate() as WorldLootItem
	if node == null:
		drop_failed.emit("Сцена лута не является WorldLootItem")
		return null
	node.item = item
	node.quantity = quantity
	node.inventory_path = inventory_path
	var parent := spawn_parent
	if parent == null:
		parent = get_tree().current_scene as Node3D
	if parent == null:
		parent = get_parent() as Node3D
	if parent == null:
		node.free()
		drop_failed.emit("Нет родителя для спавна лута")
		return null
	parent.add_child(node)
	var angle := _rng.randf_range(0.0, TAU)
	var radius := _rng.randf_range(0.0, drop_radius)
	var offset := Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
	node.global_position = global_position + Vector3.UP * spawn_height + offset
	var direction := (offset.normalized() + Vector3.UP * 0.65).normalized()
	node.apply_launch(direction * launch_force)
	return node
