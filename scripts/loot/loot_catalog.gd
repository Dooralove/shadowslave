class_name LootCatalog
extends Resource
## Плоский каталог предметов лута. Таблицы ссылаются на те же LootItemData,
## поэтому id, название и категория не расходятся между таблицами.

@export var items: Array[LootItemData] = []


func get_item(item_id: StringName) -> LootItemData:
	for item in items:
		if item != null and item.id == item_id:
			return item
	return null


func all_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for item in items:
		if item != null and item.id != &"":
			result.append(item.id)
	return result
