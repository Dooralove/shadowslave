extends SceneTree
## Собирает типизированные ресурсы лута: предметы, каталог и пулы.
##
## Запуск:
##   godot --headless --path . -s tools/build_loot_resources.gd
##
## Скрипт идемпотентен: перезаписывает resources/loot/*.tres. Это источник
## правды для данных; ручные правки в .tres допустимы, но при следующем
## запуске будут перезаписаны.

const ITEM_DIR := "res://resources/loot/items"
const TABLE_DIR := "res://resources/loot/tables"
const CATALOG_PATH := "res://resources/loot/loot_catalog.tres"
const ICON_DIR := "res://assets/ui/loot/icons"
const ICON_NAMES := ["currency", "material", "consumable", "tool", "equipment", "memory", "key", "relic"]


func _init() -> void:
	_ensure_dir(ITEM_DIR)
	_ensure_dir(TABLE_DIR)

	var items := _build_items()
	_save_catalog(items)
	var tables := _build_tables(items)
	var errors := PackedStringArray()
	for table in tables:
		for error in table.validate():
			errors.append("%s: %s" % [String(table.id), error])
	if not errors.is_empty():
		for error in errors:
			push_error(error)
		quit(1)
		return
	print("LOOT_BUILD items=%d tables=%d" % [items.size(), tables.size()])
	quit(0)


func _build_items() -> Dictionary:
	var items: Dictionary = {}
	_add_item(items, &"soul_shard", "Осколок души", LootItemData.Category.CURRENCY, 999,
		"Кристаллизованная душа. Валюта Пробуждённых и ценность, которую Санни не поглощает.",
		&"CANON", ["currency", "canon"])
	_add_item(items, &"provisions", "Провизия", LootItemData.Category.CONSUMABLE, 3,
		"Мясо, водоросли и сушёные части карапаксов. Еда у костра, не бафф.",
		&"CANON", ["food", "camp"])
	_add_item(items, &"water_skin", "Мех с водой", LootItemData.Category.CONSUMABLE, 3,
		"Пресная вода в просмолённом мехе. В лабиринте дороже кристалла.",
		&"CANON", ["water", "camp"])
	_add_item(items, &"field_medkit", "Полевая аптечка", LootItemData.Category.CONSUMABLE, 1,
		"Два заряда грубых бинтов и игл. Лечение прерывается уроном.",
		&"GD", ["heal", "p0"])
	_add_item(items, &"rope", "Верёвка", LootItemData.Category.TOOL, 1,
		"Морская верёвка из водорослей. Ловушки, спуск, страховка.",
		&"CANON", ["tool", "trap"])
	_add_item(items, &"oil_flask", "Масло сколопендры", LootItemData.Category.TOOL, 3,
		"Едкая горючая смесь. Подготовка огня, а не универсальное оружие.",
		&"CANON", ["tool", "fire"])
	_add_item(items, &"torch", "Факел из кости", LootItemData.Category.TOOL, 1,
		"Кость, водоросли и жир. Светит, пока есть чем поджечь.",
		&"CANON", ["tool", "light"])
	_add_item(items, &"carapace_plate", "Пластина панциря", LootItemData.Category.MATERIAL, 5,
		"Тяжёлый хитиновый щиток карапакса. Трофей и заготовка для будущего ремонта.",
		&"CANON", ["trophy", "carapace"])
	_add_item(items, &"carapace_claw", "Клешня карапакса", LootItemData.Category.MATERIAL, 5,
		"Серповидная клешня. Острая, но хрупкая; ценится как трофей.",
		&"CANON", ["trophy", "carapace"])
	_add_item(items, &"carapace_joint", "Сочленение карапакса", LootItemData.Category.MATERIAL, 5,
		"Связка, которую Нефис называет слабым местом. Трофей охотника.",
		&"CANON", ["trophy", "carapace"])
	_add_item(items, &"centurion_scythe_fragment", "Обломок косы центуриона", LootItemData.Category.MATERIAL, 3,
		"Кусок чёрной косы. Слишком тяжёлый для кармана, слишком ценный, чтобы бросить.",
		&"CANON", ["trophy", "elite"])
	_add_item(items, &"demon_fat", "Жир демона", LootItemData.Category.MATERIAL, 5,
		"Густая масса, которая горит долго и ровно. Канонный материал свечи.",
		&"CANON", ["trophy", "fire"])
	_add_item(items, &"blood_fiend_fang", "Клык кровавого демона", LootItemData.Category.MATERIAL, 3,
		"Кость хищника, который чувствует кровь. Трофей, не оружие.",
		&"CANON", ["trophy", "blood_fiend"])
	_add_item(items, &"bone_spear", "Костяное копьё", LootItemData.Category.EQUIPMENT, 1,
		"Обломок ребра с заточенным концом. Временное оружие первых часов.",
		&"CANON", ["weapon", "improvised"])
	_add_item(items, &"starlight_legion_armor", "Броня Звёздного Легиона", LootItemData.Category.MEMORY, 1,
		"Память Центуриона: чёрный костюм и белые пластины с семью звёздами.",
		&"CANON", ["memory", "armor", "boss"])
	_add_item(items, &"midnight_shard", "Полуночный осколок", LootItemData.Category.MEMORY, 1,
		"Память Карапакса-Демона: короткая тёмная тачи с [Unbroken].",
		&"CANON", ["memory", "weapon", "boss"])
	_add_item(items, &"drop_of_ichor", "Капля ихора", LootItemData.Category.MEMORY, 1,
		"Сюжетная Память Великого Дьявола. Меняет тело и открывает Spark of Divinity.",
		&"CANON", ["memory", "boss", "story"])
	_add_item(items, &"ancient_coral_plate", "Древняя коралловая пластина", LootItemData.Category.MATERIAL, 3,
		"Фрагмент брони, выросшей в коралле. Реликвия без применения в текущем билде.",
		&"GD", ["relic", "set_material"])
	_add_item(items, &"reef_warden_helm", "Шлем Кораллового Стража", LootItemData.Category.RELIC, 1,
		"Часть реликтового сета. Надевание появится вместе с системой сетов.",
		&"GD_FUTURE", ["relic", "set_piece", "helm"])
	_add_item(items, &"reef_warden_plate", "Нагрудник Кораллового Стража", LootItemData.Category.RELIC, 1,
		"Часть реликтового сета. Пластины помнят форму рёбер, а не человека.",
		&"GD_FUTURE", ["relic", "set_piece", "chest"])
	_add_item(items, &"reef_warden_greaves", "Поножи Кораллового Стража", LootItemData.Category.RELIC, 1,
		"Часть реликтового сета. Тяжёлые, как мокрый камень.",
		&"GD_FUTURE", ["relic", "set_piece", "legs"])
	_add_item(items, &"iron_sword_worn", "Изношенный железный меч", LootItemData.Category.EQUIPMENT, 1,
		"Щербатый клинок с разболтанной рукоятью. Обычное оружие, не Память.",
		&"GD_FUTURE", ["humanoid", "weapon", "worn"])
	_add_item(items, &"iron_sword_used", "Подержанный железный меч", LootItemData.Category.EQUIPMENT, 1,
		"Рабочий клинок с парой зазубрин. Обычное оружие, не Память.",
		&"GD_FUTURE", ["humanoid", "weapon", "used"])
	_add_item(items, &"iron_sword_fine", "Целый железный меч", LootItemData.Category.EQUIPMENT, 1,
		"Ухоженный клинок. Редкость для разбойника, но всё ещё не Память.",
		&"GD_FUTURE", ["humanoid", "weapon", "fine"])
	_add_item(items, &"leather_cuirass_worn", "Потёртая кожаная куртка", LootItemData.Category.EQUIPMENT, 1,
		"Кожа, пропитанная солью и потом. Слабая защита.",
		&"GD_FUTURE", ["humanoid", "armor", "worn"])
	_add_item(items, &"leather_cuirass_used", "Кожаная куртка", LootItemData.Category.EQUIPMENT, 1,
		"Ещё крепкая куртка с нашитыми пластинами.",
		&"GD_FUTURE", ["humanoid", "armor", "used"])
	_add_item(items, &"bandit_cloak", "Плащ разбойника", LootItemData.Category.EQUIPMENT, 1,
		"Тёмный плащ с чужой кровью на подоле. Обычная ткань.",
		&"GD_FUTURE", ["humanoid", "armor", "cloak"])
	return items


func _add_item(
	items: Dictionary,
	id: StringName,
	display_name: String,
	category: int,
	stack_max: int,
	description: String,
	canon_status: StringName,
	tags: Array
) -> void:
	var item := LootItemData.new()
	item.id = id
	item.display_name = display_name
	item.category = category
	item.stack_max = stack_max
	item.description = description
	item.canon_status = canon_status
	item.tags = PackedStringArray(tags)
	item.icon = _icon_for_category(category)
	item.resource_name = String(id)
	var path := "%s/%s.tres" % [ITEM_DIR, String(id)]
	var error := ResourceSaver.save(item, path)
	if error != OK:
		push_error("Не удалось сохранить предмет %s: %s" % [String(id), error])
	else:
		item.take_over_path(path)
	items[id] = item


func _build_tables(items: Dictionary) -> Array[LootPool]:
	var tables: Array[LootPool] = []

	tables.append(_table(
		&"cache_wreck_chest", "Сундук с затонувшего судна", "container", &"GD",
		"Кованый сундук, выброшенный приливом. Практичный salvage, без записок и чужих скелетов.",
		[_entry(items[&"soul_shard"], 2, 3, 100.0, 1.0, 1.0, false, "Канонная валюта; фиксированное ядро."),
		 _entry(items[&"rope"], 1, 1, 100.0, 0.8, 1.0, false, "Канонный инструмент.")],
		[_entry(items[&"oil_flask"], 1, 1, 30.0),
		 _entry(items[&"provisions"], 1, 2, 30.0),
		 _entry(items[&"water_skin"], 1, 1, 20.0),
		 _entry(items[&"field_medkit"], 1, 1, 10.0),
		 _entry(items[&"bone_spear"], 1, 1, 10.0, 0.45, 0.8, false, "Временное оружие, не Память.")],
		2, ["tide_wrack", "z02", "z11", "z14", "z17"]
	))

	tables.append(_table(
		&"cache_barrel_cluster", "Тайные бочки", "container", &"GD",
		"Три бочки, спрятанные за коралловой массой. Внутри — то, что пережило соль.",
		[_entry(items[&"provisions"], 1, 1, 100.0),
		 _entry(items[&"water_skin"], 1, 1, 100.0)],
		[_entry(items[&"oil_flask"], 1, 1, 25.0),
		 _entry(items[&"soul_shard"], 1, 2, 30.0),
		 _entry(items[&"carapace_plate"], 1, 1, 15.0),
		 _entry(items[&"rope"], 1, 1, 10.0),
		 _entry(items[&"torch"], 1, 1, 10.0),
		 _entry(items[&"field_medkit"], 1, 1, 10.0)],
		2, ["salvage", "z09", "z13", "z16"]
	))

	tables.append(_table(
		&"cache_ossuary_common", "Коралловый оссуарий", "container", &"GD",
		"Сухой карман с костяной кучей. Здесь хоронят то, что море не забрало.",
		[_entry(items[&"soul_shard"], 3, 5, 100.0),
		 _entry(items[&"ancient_coral_plate"], 1, 1, 100.0, 0.6, 1.0, false, "Реликтовый материал, не Память.")],
		[_entry(items[&"field_medkit"], 1, 1, 30.0),
		 _entry(items[&"carapace_plate"], 1, 2, 25.0),
		 _entry(items[&"bone_spear"], 1, 1, 20.0, 0.5, 0.9),
		 _entry(items[&"torch"], 1, 1, 15.0),
		 _entry(items[&"oil_flask"], 1, 1, 10.0)],
		1, ["ossuary", "z06"]
	))

	# Two separate relic pools guarantee different set pieces. A single shared
	# pool with fixed container seeds could (and did) miss all three pieces on
	# both sarcophagi, making the "rare armour" unreachable in the actual run.
	tables.append(_table(
		&"cache_ossuary_relic_helm", "Саркофаг Кораллового Стража — шлем", "container", &"GD",
		"Саркофаг высокого убежища. Гарантирует шлем сета; остальные части — бонус. GD-расширение, не канон.",
		[_entry(items[&"soul_shard"], 4, 6, 100.0),
		 _entry(items[&"ancient_coral_plate"], 1, 1, 100.0, 0.7, 1.0, false, "Материал сета."),
		 _entry(items[&"reef_warden_helm"], 1, 1, 100.0, 0.8, 1.0, true, "Реликтовый сет; GD_FUTURE.")],
		[_entry(items[&"reef_warden_greaves"], 1, 1, 15.0, 0.8, 1.0, true, "Реликтовый сет; GD_FUTURE."),
		 _entry(items[&"reef_warden_plate"], 1, 1, 10.0, 0.8, 1.0, true, "Реликтовый сет; GD_FUTURE."),
		 _entry(items[&"field_medkit"], 1, 1, 20.0),
		 _entry(items[&"soul_shard"], 1, 3, 30.0)],
		1, ["ossuary", "relic", "z15"]
	))

	tables.append(_table(
		&"cache_ossuary_relic_plate", "Саркофаг Кораллового Стража — нагрудник", "container", &"GD",
		"Саркофаг на утёсах. Гарантирует нагрудник сета; остальные части — бонус. GD-расширение, не канон.",
		[_entry(items[&"soul_shard"], 4, 6, 100.0),
		 _entry(items[&"ancient_coral_plate"], 1, 1, 100.0, 0.7, 1.0, false, "Материал сета."),
		 _entry(items[&"reef_warden_plate"], 1, 1, 100.0, 0.8, 1.0, true, "Реликтовый сет; GD_FUTURE.")],
		[_entry(items[&"reef_warden_greaves"], 1, 1, 15.0, 0.8, 1.0, true, "Реликтовый сет; GD_FUTURE."),
		 _entry(items[&"reef_warden_helm"], 1, 1, 10.0, 0.8, 1.0, true, "Реликтовый сет; GD_FUTURE."),
		 _entry(items[&"field_medkit"], 1, 1, 20.0),
		 _entry(items[&"soul_shard"], 1, 3, 30.0)],
		1, ["ossuary", "relic", "z18"]
	))

	tables.append(_table(
		&"enemy_carapace_scavenger", "Карапакс-мусорщик", "enemy", &"CANON",
		"Обычный карапакс: кристалл души, хитин и иногда мясо. Памяти не выпадают.",
		[_entry(items[&"soul_shard"], 1, 1, 100.0, 1.0, 1.0, false, "Канон: кристалл из карапакса, гл. 34.")],
		[_entry(items[&"carapace_plate"], 1, 1, 45.0),
		 _entry(items[&"carapace_claw"], 1, 1, 30.0),
		 _entry(items[&"carapace_joint"], 1, 1, 20.0),
		 _entry(items[&"provisions"], 1, 1, 5.0)],
		1, ["carapace", "z03", "z13", "z14"]
	))

	tables.append(_table(
		&"elite_carapace_centurion", "Карапакс-Центурион", "elite", &"CANON",
		"Элита: больше кристаллов, обломок косы и Память Starlight Legion Armor.",
		[_entry(items[&"soul_shard"], 3, 3, 100.0),
		 _entry(items[&"carapace_plate"], 2, 2, 100.0),
		 _entry(items[&"centurion_scythe_fragment"], 1, 1, 100.0),
		 _entry(items[&"starlight_legion_armor"], 1, 1, 100.0, 1.0, 1.0, true, "Канон: Память Центуриона, гл. 52.")],
		[_entry(items[&"carapace_joint"], 1, 2, 40.0),
		 _entry(items[&"carapace_claw"], 1, 1, 30.0),
		 _entry(items[&"field_medkit"], 1, 1, 15.0),
		 _entry(items[&"soul_shard"], 1, 2, 15.0)],
		1, ["elite", "centurion", "future_zone"]
	))

	tables.append(_table(
		&"boss_carapace_demon", "Карапакс-Демон", "boss", &"CANON",
		"Босс: Полуночный осколок, жир демона и тяжёлые пластины.",
		[_entry(items[&"soul_shard"], 8, 8, 100.0),
		 _entry(items[&"demon_fat"], 2, 2, 100.0),
		 _entry(items[&"carapace_plate"], 3, 3, 100.0),
		 _entry(items[&"midnight_shard"], 1, 1, 100.0, 1.0, 1.0, true, "Канон: Память Демона, гл. 74.")],
		[_entry(items[&"carapace_joint"], 2, 3, 50.0),
		 _entry(items[&"carapace_claw"], 2, 2, 30.0),
		 _entry(items[&"field_medkit"], 1, 1, 20.0)],
		1, ["boss", "demon", "future_zone"]
	))

	tables.append(_table(
		&"boss_great_devil", "Великий Дьявол", "boss", &"CANON",
		"Финальный босс Древа: Капля ихора и большое количество кристаллов.",
		[_entry(items[&"drop_of_ichor"], 1, 1, 100.0, 1.0, 1.0, true, "Канон: гл. 81."),
		 _entry(items[&"soul_shard"], 20, 20, 100.0),
		 _entry(items[&"demon_fat"], 5, 5, 100.0)],
		[],
		0, ["boss", "great_devil", "future_zone"]
	))

	tables.append(_table(
		&"enemy_blood_fiend", "Кровавый Демон", "enemy", &"CANON",
		"Хищник, который чувствует кровь. Клык — трофей, не оружие.",
		[_entry(items[&"soul_shard"], 2, 2, 100.0),
		 _entry(items[&"blood_fiend_fang"], 1, 1, 100.0)],
		[_entry(items[&"carapace_plate"], 1, 1, 20.0),
		 _entry(items[&"field_medkit"], 1, 1, 20.0)],
		1, ["blood_fiend", "future_zone"]
	))

	tables.append(_table(
		&"enemy_humanoid_bandit", "Разбойник / охотник Гунлауга", "humanoid", &"GD_FUTURE",
		"Будущие люди-противники. Падает то, что надето и что в руках; Памяти не выпадают — они уничтожаются с владельцем.",
		[_entry(items[&"soul_shard"], 1, 2, 100.0)],
		[_entry(items[&"iron_sword_worn"], 1, 1, 25.0, 0.15, 0.35, false, "Износ: сильно щербатый."),
		 _entry(items[&"iron_sword_used"], 1, 1, 25.0, 0.4, 0.7, false, "Износ: рабочий."),
		 _entry(items[&"iron_sword_fine"], 1, 1, 10.0, 0.8, 1.0, false, "Износ: ухоженный."),
		 _entry(items[&"leather_cuirass_worn"], 1, 1, 20.0, 0.15, 0.4),
		 _entry(items[&"leather_cuirass_used"], 1, 1, 15.0, 0.45, 0.75),
		 _entry(items[&"bandit_cloak"], 1, 1, 15.0, 0.4, 0.9),
		 _entry(items[&"provisions"], 1, 1, 10.0),
		 _entry(items[&"rope"], 1, 1, 5.0)],
		2, ["humanoid", "bandit", "future"]
	))

	for table in tables:
		table.resource_name = String(table.id)
		ResourceSaver.save(table, "%s/%s.tres" % [TABLE_DIR, String(table.id)])
	return tables


func _table(
	id: StringName,
	display_name: String,
	source_kind: String,
	canon_status: StringName,
	description: String,
	guaranteed: Array,
	entries: Array,
	bonus_rolls: int,
	tags: Array
) -> LootPool:
	var table := LootPool.new()
	table.id = id
	table.display_name = display_name
	table.source_kind = source_kind
	table.canon_status = canon_status
	table.description = description
	table.guaranteed = _entry_array(guaranteed)
	table.entries = _entry_array(entries)
	table.bonus_rolls = bonus_rolls
	table.empty_chance = 0.0
	table.respawns = false
	table.tags = PackedStringArray(tags)
	return table


func _entry_array(value: Array) -> Array[LootPoolEntry]:
	var result: Array[LootPoolEntry] = []
	for item in value:
		if item is LootPoolEntry:
			result.append(item as LootPoolEntry)
	return result


func _entry(
	item: LootItemData,
	min_count: int,
	max_count: int,
	weight: float,
	condition_min := 1.0,
	condition_max := 1.0,
	unique := false,
	notes := ""
) -> LootPoolEntry:
	var entry := LootPoolEntry.new()
	entry.item = item
	entry.min_count = min_count
	entry.max_count = max_count
	entry.weight = weight
	entry.condition_min = condition_min
	entry.condition_max = condition_max
	entry.unique = unique
	entry.notes = notes
	return entry


func _icon_for_category(category: int) -> Texture2D:
	var index := clampi(category, 0, ICON_NAMES.size() - 1)
	var path := "%s/loot_%s.png" % [ICON_DIR, ICON_NAMES[index]]
	var texture := load(path) as Texture2D
	if texture == null:
		push_warning("Не найден icon %s" % path)
	return texture


func _save_catalog(items: Dictionary) -> void:
	var catalog := LootCatalog.new()
	catalog.resource_name = "loot_catalog"
	var ordered: Array[LootItemData] = []
	for item in items.values():
		ordered.append(item as LootItemData)
	ordered.sort_custom(func(a: LootItemData, b: LootItemData) -> bool:
		return String(a.id) < String(b.id)
	)
	catalog.items = ordered
	var error := ResourceSaver.save(catalog, CATALOG_PATH)
	if error != OK:
		push_error("Не удалось сохранить каталог лута: %s" % error)


func _ensure_dir(path: String) -> void:
	var absolute := ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(absolute)
