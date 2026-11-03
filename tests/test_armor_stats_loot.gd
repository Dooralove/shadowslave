extends GutTest
## Проверки статов брони, инвентаря, таблицы лута, физического подбора и
## перестановки оружия в ножны. Не трогают кампанию и сохранения.

## GUT в -s-режиме: загрузка демо-сцены может инвалидировать глобальный
## класс QuestLever; предзагрузка сохраняет порядок тестов независимым.
const _QUEST_LEVER := preload("res://scripts/quests/quest_lever.gd")

const LAB := "res://scenes/dev/equipment_lab.tscn"
const WORLD_ITEM := "res://scenes/loot/world_loot_item.tscn"

var _host: Node
var _run_state_snapshot: Dictionary


func before_each() -> void:
	_run_state_snapshot = NightmareRunState.snapshot()
	_host = Node.new()
	add_child_autofree(_host)


func after_each() -> void:
	NightmareRunState.restore(_run_state_snapshot)


func _make_item(id: StringName, display_name := "Тестовый предмет") -> EquipmentItemData:
	var item := EquipmentItemData.new()
	item.id = id
	item.display_name = display_name
	return item


func _make_armor(stats: ArmorStats, id := &"test_armor") -> ArmorItem:
	var armor := ArmorItem.new()
	armor.id = id
	armor.display_name = "Тестовая броня"
	armor.stats = stats
	return armor


func test_armor_stats_converts_armor_to_reduction() -> void:
	var stats := ArmorStats.new()
	stats.armor_value = 50.0
	stats.weight = 10.0
	assert_almost_eq(stats.get_armor_reduction(), 50.0 / 150.0, 0.0001)
	assert_eq(stats.summary_lines().size() > 0, true)


func test_character_stats_applies_armor_to_health() -> void:
	var health := HealthComponent.new()
	health.max_health = 100.0
	_host.add_child(health)
	var character := CharacterStats.new()
	character.max_carry_weight = 35.0
	_host.add_child(character)
	character.health_path = character.get_path_to(health)
	await wait_process_frames(1)

	var stats := ArmorStats.new()
	stats.armor_value = 50.0
	stats.weight = 10.0
	character.apply_items([_make_armor(stats)])

	assert_almost_eq(character.get_damage_reduction(), 50.0 / 150.0, 0.0001)
	assert_almost_eq(health.damage_reduction, 50.0 / 150.0, 0.0001)
	var applied := health.take_damage(100.0)
	assert_almost_eq(applied, 100.0 * (1.0 - 50.0 / 150.0), 0.01)


func test_encumbrance_and_passive_debuff_reduce_speed() -> void:
	var stats := ArmorStats.new()
	stats.armor_value = 10.0
	stats.weight = 30.0
	var debuff := StatModifier.new()
	debuff.stat = &"move_speed"
	debuff.operation = StatModifier.Operation.MULTIPLY
	debuff.value = 0.86
	stats.passive_debuffs.append(debuff)

	var character := CharacterStats.new()
	character.max_carry_weight = 35.0
	_host.add_child(character)
	await wait_process_frames(1)
	character.apply_items([_make_armor(stats)])

	assert_lt(character.get_move_speed_multiplier(), 0.86)
	assert_gt(character.encumbrance_ratio, 0.5)
	assert_eq(character.encumbrance_tier, CharacterStats.EncumbranceTier.HEAVY)


func test_inventory_add_remove_and_capacity() -> void:
	var inventory := InventoryComponent.new()
	inventory.capacity = 2
	_host.add_child(inventory)
	var first := _make_item(&"first")
	var second := _make_item(&"second")
	var third := _make_item(&"third")

	assert_true(inventory.add_item(first, 2))
	assert_true(inventory.add_item(second))
	assert_false(inventory.add_item(third), "третий слот должен быть отклонён")
	assert_eq(inventory.get_quantity(&"first"), 2)
	assert_true(inventory.remove_item(&"first", 1))
	assert_eq(inventory.get_quantity(&"first"), 1)
	assert_true(inventory.remove_item(&"first", 1))
	assert_false(inventory.has_item(&"first"))


func test_loot_table_guaranteed_and_chance() -> void:
	var item := _make_item(&"loot_a")
	var guaranteed := LootEntry.new()
	guaranteed.item = item
	guaranteed.guaranteed = true
	var rare := LootEntry.new()
	rare.item = _make_item(&"loot_b")
	rare.chance = 0.0

	var table := LootTable.new()
	table.id = &"test_table"
	table.rolls = 1
	table.guaranteed_entries = [guaranteed]
	table.entries = [rare]
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var drops := table.roll(rng)
	assert_eq(drops.size(), 1, "гарантированная строка + нулевой шанс")
	assert_eq((drops[0]["item"] as EquipmentItemData).id, &"loot_a")
	assert_eq(int(drops[0]["quantity"]), 1)


func test_world_loot_item_pickup_grants_inventory() -> void:
	var inventory := InventoryComponent.new()
	inventory.capacity = 5
	_host.add_child(inventory)
	var item := _make_item(&"world_loot")
	var node := (load(WORLD_ITEM) as PackedScene).instantiate() as WorldLootItem
	node.item = item
	node.quantity = 2
	_host.add_child(node)
	await wait_process_frames(1)

	var interactable := node.get_node("Interactable") as Interactable
	assert_not_null(interactable)
	interactable.interact()
	await wait_process_frames(1)

	assert_eq(inventory.get_quantity(&"world_loot"), 2)
	assert_false(is_instance_valid(node), "подобранный лут должен быть удалён")


func test_loot_container_grants_inventory() -> void:
	var inventory := InventoryComponent.new()
	inventory.capacity = 5
	_host.add_child(inventory)
	var item := _make_item(&"chest_loot")
	var entry := LootEntry.new()
	entry.item = item
	entry.guaranteed = true
	var table := LootTable.new()
	table.id = &"chest_table"
	table.guaranteed_entries = [entry]
	var container := LootContainer.new()
	container.loot_table = table
	container.enabled = true
	_host.add_child(container)
	await wait_process_frames(1)

	assert_true(container.open())
	assert_eq(inventory.get_quantity(&"chest_loot"), 1)
	assert_true(container.is_opened())
	assert_false(container.open(), "one_shot-контейнер не открывается дважды")


func test_weapon_stows_on_hips_and_draws_to_hand() -> void:
	var lab := (load(LAB) as PackedScene).instantiate() as Node3D
	add_child_autofree(lab)
	await wait_process_frames(2)
	var equipment := lab.get_node("Equipment") as EquipmentComponent
	var skeleton := lab.get_node("Sunny/Model/Armature/Skeleton3D") as Skeleton3D
	var hand_socket := skeleton.get_node("Socket_hand_r") as BoneAttachment3D
	assert_not_null(hand_socket)
	var weapon := hand_socket.get_child(0) as Node3D
	assert_not_null(weapon)

	equipment.set_weapon_drawn(false)
	await wait_process_frames(1)
	var hip_socket := skeleton.get_node_or_null("Socket_hips") as BoneAttachment3D
	assert_not_null(hip_socket)
	assert_eq(weapon.get_parent(), hip_socket)
	assert_true(weapon.visible)

	equipment.set_weapon_drawn(true)
	await wait_process_frames(1)
	assert_eq(weapon.get_parent(), hand_socket)
	assert_true(weapon.visible)


func test_demo_equip_applies_and_removes_stats_on_player() -> void:
	var demo := (load("res://scenes/dev/equipment_loot_demo.tscn") as PackedScene).instantiate() as Node3D
	add_child_autofree(demo)
	await wait_process_frames(3)
	var equipment := demo.get_node("Equipment") as EquipmentComponent
	var health := demo.get_node("Sunny/Health") as HealthComponent
	var combat := demo.get_node("Sunny/CombatController") as CombatController
	var attack := demo.get_node("Sunny/Visual/MeleeAttack") as MeleeAttack
	var heavy := load("res://resources/equipment/armor/heavy_plate.tres") as ArmorItem

	assert_true(equipment.equip(heavy))
	await wait_process_frames(2)
	assert_almost_eq(health.damage_reduction, 55.0 / 155.0, 0.01)
	assert_almost_eq(heavy.stats.get_resistance(&"slash"), 0.22, 0.001)
	assert_almost_eq(float(health.damage_resistances.get(&"slash", 0.0)), 0.22, 0.001)
	assert_lt(combat.get_move_speed_multiplier(), 0.85)
	assert_almost_eq(attack.damage_bonus, 3.5, 0.01)
	assert_gt(health.max_health, 100.0)

	assert_true(equipment.unequip(EquipmentItemData.Slot.BODY))
	await wait_process_frames(2)
	assert_almost_eq(health.damage_reduction, 0.0, 0.001)
	assert_almost_eq(attack.damage_bonus, 0.0, 0.001)
	assert_almost_eq(health.max_health, 100.0, 0.001)


func test_health_signal_reports_new_current_after_max_change() -> void:
	var health := HealthComponent.new()
	health.max_health = 100.0
	_host.add_child(health)
	var character := CharacterStats.new()
	character.max_carry_weight = 35.0
	_host.add_child(character)
	character.health_path = character.get_path_to(health)
	await wait_process_frames(1)
	health.current_health = 50.0
	var events: Array = []
	health.health_changed.connect(
		func(current: float, maximum: float) -> void:
			events.append(Vector2(current, maximum))
	)
	var stats := ArmorStats.new()
	var buff := StatModifier.new()
	buff.stat = &"max_health"
	buff.operation = StatModifier.Operation.ADD
	buff.value = 20.0
	stats.passive_buffs.append(buff)
	character.apply_items([_make_armor(stats)])
	await wait_process_frames(1)

	assert_almost_eq(health.max_health, 120.0, 0.001)
	assert_almost_eq(health.current_health, 60.0, 0.001)
	assert_gt(events.size(), 0, "health_changed должен сообщить HUD об изменении")
	var last: Vector2 = events[events.size() - 1]
	assert_almost_eq(last.x, 60.0, 0.001, "HUD должен получить новое текущее HP")
	assert_almost_eq(last.y, 120.0, 0.001)


func test_inventory_from_ids_is_atomic() -> void:
	var inventory := InventoryComponent.new()
	inventory.capacity = 5
	_host.add_child(inventory)
	var old := _make_item(&"old_item")
	assert_true(inventory.add_item(old, 1))
	var catalog := EquipmentCatalog.new()
	var keep := _make_item(&"keep_item")
	catalog.items.append(keep)
	var ok := inventory.from_ids({"keep_item": 2, "missing_item": 1}, catalog)
	assert_false(ok)
	assert_eq(inventory.get_quantity(&"old_item"), 1, "неудачная загрузка не должна очищать старый инвентарь")
	assert_eq(inventory.get_quantity(&"keep_item"), 0)


func test_apply_ids_rejects_mismatched_rig_profile() -> void:
	var lab := (load(LAB) as PackedScene).instantiate() as Node3D
	add_child_autofree(lab)
	await wait_process_frames(2)
	var equipment := lab.get_node("Equipment") as EquipmentComponent
	var heavy := load("res://resources/equipment/armor/heavy_plate.tres") as ArmorItem
	var wrong_rig := load("res://resources/equipment/rig_profiles/p1_ual.tres") as CharacterRigProfile
	var fake := ArmorItem.new()
	fake.id = &"fake_wrong_rig"
	fake.display_name = "Wrong rig"
	fake.visual_scene = heavy.visual_scene
	fake.rig_profile = wrong_rig
	fake.stats = heavy.stats
	fake.hide_surfaces = heavy.hide_surfaces
	var catalog := EquipmentCatalog.new()
	catalog.items.append(fake)
	var old_body := equipment.get_equipped(EquipmentItemData.Slot.BODY)
	assert_false(equipment.apply_ids({"body": &"fake_wrong_rig"}, catalog))
	assert_push_error("rig_profile")
	assert_eq(equipment.get_equipped(EquipmentItemData.Slot.BODY), old_body)


func test_equipment_ids_persist_in_run_state() -> void:
	NightmareRunState.reset()
	var demo := (load("res://scenes/dev/equipment_loot_demo.tscn") as PackedScene).instantiate() as Node3D
	add_child_autofree(demo)
	await wait_process_frames(3)
	var equipment := demo.get_node("Equipment") as EquipmentComponent
	assert_eq(StringName(NightmareRunState.get_equipment_ids().get("body", &"")), &"scout_leather")

	var heavy := load("res://resources/equipment/armor/heavy_plate.tres") as ArmorItem
	assert_true(equipment.equip(heavy))
	await wait_process_frames(1)
	var saved := NightmareRunState.get_equipment_ids()
	assert_eq(StringName(saved.get("body", &"")), &"heavy_plate")

	var snapshot := NightmareRunState.snapshot()
	NightmareRunState.reset()
	assert_false(NightmareRunState.has_equipment())
	NightmareRunState.restore(snapshot)
	assert_eq(StringName(NightmareRunState.get_equipment_ids().get("body", &"")), &"heavy_plate")

	NightmareRunState.set_equipment_ids(saved)
	assert_true(equipment.unequip(EquipmentItemData.Slot.BODY))
	NightmareRunState.set_equipment_ids(saved)
	assert_true(equipment.restore_from_run_state())
	assert_eq(equipment.get_equipped(EquipmentItemData.Slot.BODY).id, &"heavy_plate")


func test_health_damage_type_resistance() -> void:
	var health := HealthComponent.new()
	health.max_health = 100.0
	_host.add_child(health)
	health.damage_resistances = {&"slash": 0.5}
	var applied := health.take_damage(20.0, &"slash")
	assert_almost_eq(applied, 10.0, 0.001)
	assert_almost_eq(health.current_health, 90.0, 0.001)


func test_inventory_ids_round_trip() -> void:
	var catalog := EquipmentCatalog.new()
	var first := _make_item(&"round_a")
	var second := _make_item(&"round_b")
	catalog.items.append(first)
	catalog.items.append(second)
	var source := InventoryComponent.new()
	source.capacity = 5
	_host.add_child(source)
	assert_true(source.add_item(first, 2))
	assert_true(source.add_item(second, 1))
	var target := InventoryComponent.new()
	target.capacity = 5
	_host.add_child(target)
	assert_true(target.from_ids(source.to_ids(), catalog))
	assert_eq(target.get_quantity(&"round_a"), 2)
	assert_eq(target.get_quantity(&"round_b"), 1)


func test_loot_container_rejects_when_full() -> void:
	var inventory := InventoryComponent.new()
	inventory.capacity = 1
	_host.add_child(inventory)
	assert_true(inventory.add_item(_make_item(&"filler"), 1))
	var entry := LootEntry.new()
	entry.item = _make_item(&"overflow_loot")
	entry.guaranteed = true
	var table := LootTable.new()
	table.id = &"full_table"
	table.guaranteed_entries = [entry]
	var container := LootContainer.new()
	container.loot_table = table
	container.enabled = true
	_host.add_child(container)
	await wait_process_frames(1)
	assert_false(container.open())
	assert_false(container.is_opened())


func test_loot_drop_component_spawns_on_death() -> void:
	var owner := CharacterBody3D.new()
	var health := HealthComponent.new()
	health.name = "Health"
	health.max_health = 30.0
	owner.add_child(health)
	var drop := LootDropComponent.new()
	drop.name = "LootDrop"
	drop.world_item_scene = load("res://scenes/loot/world_loot_item.tscn") as PackedScene
	drop.spawn_parent = owner
	var entry := LootEntry.new()
	entry.item = _make_item(&"death_loot")
	entry.guaranteed = true
	var table := LootTable.new()
	table.id = &"death_table"
	table.guaranteed_entries = [entry]
	drop.loot_table = table
	owner.add_child(drop)
	_host.add_child(owner)
	await wait_process_frames(2)
	health.take_damage(health.max_health)
	await wait_process_frames(3)
	assert_true(drop.has_dropped())
	assert_gt(owner.find_children("*", "RigidBody3D", true, false).size(), 0)


func test_world_loot_uses_explicit_inventory_path() -> void:
	# Group fallback would pick `grouped` first; the explicit path must win.
	var grouped := InventoryComponent.new()
	grouped.capacity = 5
	_host.add_child(grouped)
	var explicit := InventoryComponent.new()
	explicit.capacity = 5
	_host.add_child(explicit)
	var node := (load(WORLD_ITEM) as PackedScene).instantiate() as WorldLootItem
	node.item = _make_item(&"explicit_loot")
	_host.add_child(node)
	node.inventory_path = node.get_path_to(explicit)
	await wait_process_frames(1)
	(node.get_node("Interactable") as Interactable).interact()
	await wait_process_frames(1)
	assert_eq(explicit.get_quantity(&"explicit_loot"), 1)
	assert_eq(grouped.get_quantity(&"explicit_loot"), 0)


func test_weapon_without_sheath_is_allowed() -> void:
	var lab := (load(LAB) as PackedScene).instantiate() as Node3D
	add_child_autofree(lab)
	await wait_process_frames(2)
	var equipment := lab.get_node("Equipment") as EquipmentComponent
	var skeleton := lab.get_node("Sunny/Model/Armature/Skeleton3D") as Skeleton3D
	var source := load("res://resources/equipment/weapons/short_sword_alpha.tres") as WeaponData
	var weapon := WeaponData.new()
	weapon.id = &"fake_no_sheath"
	weapon.display_name = "No sheath"
	weapon.visual_scene = source.visual_scene
	weapon.rig_profile = source.rig_profile
	weapon.grip_socket = &"hand_r"
	weapon.sheath_socket = &""
	weapon.visible_when_sheathed = false
	assert_true(equipment.equip(weapon))
	await wait_process_frames(1)
	equipment.set_weapon_drawn(false)
	await wait_process_frames(1)
	var hand_socket := skeleton.get_node("Socket_hand_r") as BoneAttachment3D
	var visual := hand_socket.get_child(0) as Node3D
	assert_not_null(visual)
	assert_false(visual.visible)


func test_demo_inventory_persists_stacks() -> void:
	NightmareRunState.reset()
	var demo := (load("res://scenes/dev/equipment_loot_demo.tscn") as PackedScene).instantiate() as Node3D
	add_child_autofree(demo)
	await wait_process_frames(3)
	var inventory := demo.get_node("Inventory") as InventoryComponent
	var item := _make_item(&"persisted_stack")
	var catalog := EquipmentCatalog.new()
	catalog.items.append(item)
	inventory.catalog = catalog

	assert_true(inventory.add_item(item, 3))
	await wait_process_frames(1)
	assert_eq(int(NightmareRunState.get_inventory_ids().get(&"persisted_stack", 0)), 3)

	var snapshot := NightmareRunState.snapshot()
	NightmareRunState.reset()
	assert_false(NightmareRunState.has_inventory())
	NightmareRunState.restore(snapshot)
	assert_eq(int(NightmareRunState.get_inventory_ids().get(&"persisted_stack", 0)), 3)

	inventory.clear()
	await wait_process_frames(1)
	assert_false(NightmareRunState.has_inventory())
	NightmareRunState.set_inventory_ids({&"persisted_stack": 3})
	assert_true(inventory.restore_from_run_state())
	assert_eq(inventory.get_quantity(&"persisted_stack"), 3)
