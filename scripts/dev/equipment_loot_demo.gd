extends Node3D
## Демо-сцена брони и лута.
##
## Показывает полный цикл: надеть сет → статы применяются к персонажу →
## убить манекен → выпадает физический лут → подобрать → надеть другой сет.
## Сцена dev-only и не подключена к кампании.

const SCOUT := preload("res://resources/equipment/armor/scout_leather.tres")
const MERCENARY := preload("res://resources/equipment/armor/mercenary_medium.tres")
const HEAVY := preload("res://resources/equipment/armor/heavy_plate.tres")
const WORLD_ITEM := preload("res://scenes/loot/world_loot_item.tscn")

@onready var equipment: EquipmentComponent = $Equipment
@onready var stats: CharacterStats = $Stats
@onready var inventory: InventoryComponent = $Inventory
@onready var dummy: CharacterBody3D = $Dummy
@onready var dummy_mesh: MeshInstance3D = $Dummy/Mesh
@onready var dummy_health: HealthComponent = $Dummy/Health
@onready var loot_drop: LootDropComponent = $Dummy/LootDrop
@onready var chest: LootContainer = $Chest
@onready var stats_label: Label = $UI/StatsLabel
@onready var inventory_label: Label = $UI/InventoryLabel
@onready var toast_label: Label = $UI/ToastLabel
@onready var hint_label: Label = $UI/HintLabel

var _toast_left := 0.0


func _ready() -> void:
	hint_label.text = (
		"1/2/3 — сеты   4 — оружие   5 — убить манекен   6 — сундук   "
		+ "7 — тестовый дроп   8 — очистить инвентарь   R — сброс"
	)
	equipment.equipment_changed.connect(_on_equipment_changed)
	equipment.equipment_failed.connect(_on_equipment_failed)
	equipment.weapon_drawn_changed.connect(_on_weapon_drawn_changed)
	stats.stats_recalculated.connect(_on_stats_recalculated)
	inventory.inventory_changed.connect(_on_inventory_changed)
	inventory.item_added.connect(_on_item_added)
	inventory.add_failed.connect(_on_inventory_failed)
	loot_drop.loot_dropped.connect(_on_loot_dropped)
	loot_drop.drop_failed.connect(_on_loot_failed)
	chest.opened.connect(_on_chest_opened)
	chest.loot_failed.connect(_on_loot_failed)
	dummy_health.died.connect(_on_dummy_died)
	_refresh_stats()
	_refresh_inventory()
	_toast("Демо готово: нажмите 1/2/3, чтобы надеть сет")


func _process(delta: float) -> void:
	if _toast_left <= 0.0:
		return
	_toast_left = maxf(_toast_left - delta, 0.0)
	if _toast_left <= 0.0:
		toast_label.text = ""


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_1:
			_equip(SCOUT)
		KEY_2:
			_equip(MERCENARY)
		KEY_3:
			_equip(HEAVY)
		KEY_4:
			equipment.set_weapon_drawn(not equipment.weapon_drawn)
		KEY_5:
			_kill_dummy()
		KEY_6:
			_open_chest()
		KEY_7:
			_spawn_test_drop()
		KEY_8:
			inventory.clear()
			_toast("Инвентарь очищен")
		KEY_R:
			_reset_demo()


func _equip(item: EquipmentItemData) -> void:
	if equipment.equip(item):
		_toast("Надето: %s" % item.display_name)
	else:
		_toast("Не удалось надеть: %s" % item.display_name)
	_refresh_stats()


func _kill_dummy() -> void:
	if dummy_health.is_dead():
		_toast("Манекен уже мёртв — нажмите R для сброса")
		return
	dummy_health.take_damage(dummy_health.max_health)
	dummy_mesh.visible = false


func _open_chest() -> void:
	if not chest.open():
		_toast("Сундук не открылся")


func _spawn_test_drop() -> void:
	var node := WORLD_ITEM.instantiate() as WorldLootItem
	if node == null:
		return
	node.item = HEAVY
	node.quantity = 1
	add_child(node)
	node.global_position = $Sunny.global_position + Vector3(0.0, 0.7, -1.2)
	node.apply_launch(Vector3(0.0, 1.1, -1.4))
	_toast("Тестовый дроп: тяжёлые латы")


func _reset_demo() -> void:
	dummy_health.revive()
	dummy_mesh.visible = true
	loot_drop.reset_dropped()
	chest.reset()
	inventory.clear()
	equipment.apply_ids({
		"body": &"scout_leather",
		"weapon": &"short_sword_alpha",
		"accessories": [&"water_flask_alpha"],
	})
	equipment.set_weapon_drawn(true)
	_refresh_stats()
	_refresh_inventory()
	_toast("Демо сброшено")


func _on_equipment_changed(_slot: int, _item: EquipmentItemData) -> void:
	_refresh_stats()


func _on_equipment_failed(reason: String) -> void:
	_toast("Экипировка: %s" % reason)


func _on_weapon_drawn_changed(drawn: bool) -> void:
	_toast("Оружие: %s" % ("в руке" if drawn else "на поясе"))


func _on_stats_recalculated(_totals: Dictionary) -> void:
	_refresh_stats()


func _on_inventory_changed() -> void:
	_refresh_inventory()


func _on_item_added(item: EquipmentItemData, quantity: int) -> void:
	_toast("Получено: %s x%d" % [item.display_name, quantity])


func _on_inventory_failed(reason: String) -> void:
	_toast("Инвентарь: %s" % reason)


func _on_loot_dropped(drops: Array[Dictionary]) -> void:
	_toast("Выпало: %s" % _drops_text(drops))


func _on_chest_opened(drops: Array[Dictionary]) -> void:
	_toast("Сундук: %s" % _drops_text(drops))


func _on_loot_failed(reason: String) -> void:
	_toast("Лут: %s" % reason)


func _on_dummy_died() -> void:
	dummy_mesh.visible = false
	_toast("Манекен побеждён — лут выпал")


func _drops_text(drops: Array[Dictionary]) -> String:
	var names := PackedStringArray()
	for drop in drops:
		var item := drop.get("item") as EquipmentItemData
		if item != null:
			names.append("%s x%d" % [item.display_name, int(drop.get("quantity", 1))])
	return ", ".join(names) if not names.is_empty() else "пусто"


func _refresh_stats() -> void:
	var lines := PackedStringArray()
	var body := equipment.get_equipped(EquipmentItemData.Slot.BODY) as ArmorItem
	if body != null:
		lines.append("%s · %s" % [body.display_name, body.get_rarity_name()])
		lines.append(body.description)
		lines.append_array(body.summary_lines())
	else:
		lines.append("Броня не надета")
	lines.append("")
	lines.append_array(stats.get_summary_lines())
	var weapon := equipment.get_equipped(EquipmentItemData.Slot.WEAPON)
	lines.append("Оружие: %s" % (weapon.display_name if weapon != null else "нет"))
	lines.append("Положение: %s" % ("в руке" if equipment.weapon_drawn else "на поясе"))
	stats_label.text = "\n".join(lines)


func _refresh_inventory() -> void:
	var entries := inventory.get_entries()
	if entries.is_empty():
		inventory_label.text = "Инвентарь: пуст"
		return
	var parts := PackedStringArray()
	for entry in entries:
		var item := entry.get("item") as EquipmentItemData
		if item != null:
			parts.append("%s x%d" % [item.display_name, int(entry.get("quantity", 1))])
	inventory_label.text = "Инвентарь: " + ", ".join(parts)


func _toast(text: String) -> void:
	toast_label.text = text
	_toast_left = 4.0
