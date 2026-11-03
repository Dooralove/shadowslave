class_name EquipmentCatalog
extends Resource
## Плоский каталог предметов для альфы. Для масштабирования можно разбить
## на несколько каталогов по сетам, не меняя EquipmentComponent.

@export var items: Array[EquipmentItemData] = []


func get_item(item_id: StringName) -> EquipmentItemData:
	for item in items:
		if item != null and item.id == item_id:
			return item
	return null


func get_armor(item_id: StringName) -> ArmorSetData:
	return get_item(item_id) as ArmorSetData


func get_weapon(item_id: StringName) -> WeaponData:
	return get_item(item_id) as WeaponData


func all_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for item in items:
		if item != null and item.id != &"":
			result.append(item.id)
	return result
