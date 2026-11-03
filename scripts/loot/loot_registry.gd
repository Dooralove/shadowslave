class_name LootRegistry
extends RefCounted
## Runtime-доступ к каталогу лута. Каталог загружается один раз и используется
## сериализацией мешков, стек-лимитами и UI-иконками.
##
## Это не autoload: статический кэш не меняет project.godot и не зависит от
## порядка автозагрузок.

const CATALOG_PATH := "res://resources/loot/loot_catalog.tres"

static var _catalog: LootCatalog


static func get_catalog() -> LootCatalog:
	if _catalog == null:
		_catalog = load(CATALOG_PATH) as LootCatalog
	return _catalog


static func get_item(item_id: StringName) -> LootItemData:
	var catalog := get_catalog()
	if catalog == null:
		return null
	return catalog.get_item(item_id)


static func get_icon(item_id: StringName) -> Texture2D:
	var item := get_item(item_id)
	return item.icon if item != null else null
