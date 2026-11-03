class_name LootItemData
extends Resource
## Описание предмета, который может выпасть из таблицы лута.
##
## Это не замена EquipmentItemData: здесь только данные для ролла и показа
## в тосте. Надеваемые вещи по-прежнему живут в resources/equipment/.

enum Category {
	CURRENCY,
	MATERIAL,
	CONSUMABLE,
	TOOL,
	EQUIPMENT,
	MEMORY,
	KEY,
	RELIC,
}

@export var id: StringName = &""
@export var display_name := ""
@export var category: Category = Category.MATERIAL
@export_range(1, 99, 1) var stack_max := 5
@export_multiline var description := ""
## CANON / TEXT / GD / GD_FUTURE. GD_FUTURE не попадает в обычный ролл.
@export var canon_status: StringName = &"GD"
@export var tags: PackedStringArray = []
@export var icon: Texture2D


func is_valid() -> bool:
	return id != &"" and not display_name.strip_edges().is_empty()
