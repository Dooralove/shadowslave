class_name EquipmentLoadout
extends Resource
## Набор надетого. Хранит только ресурсы предметов, не узлы сцены.
## Для сейва используйте to_ids(); визуал всегда пересобирается заново.

@export var body: ArmorSetData
@export var weapon: WeaponData
@export var accessories: Array[EquipmentItemData] = []


func to_ids() -> Dictionary:
	var accessory_ids: Array[StringName] = []
	for item in accessories:
		if item != null and item.id != &"":
			accessory_ids.append(item.id)
	return {
		"body": body.id if body != null else &"",
		"weapon": weapon.id if weapon != null else &"",
		"accessories": accessory_ids,
	}


func is_empty() -> bool:
	return body == null and weapon == null and accessories.is_empty()


func clear() -> void:
	body = null
	weapon = null
	accessories.clear()
