class_name RpgDemoItem
extends Resource
## Демонстрационный предмет интерфейсного прототипа.
##
## Ресурс не связан с игровым инвентарём, сохранениями и каноном. Все записи
## в demo_catalog.tres помечены как тестовые и сбрасываются при перезапуске.

enum Category {
	WEAPON,
	ARMOR,
	CONSUMABLE,
	RESOURCE,
	STORY,
}

enum Rarity {
	COMMON,
	NOTABLE,
	RARE,
	UNIQUE,
}

@export var id: StringName
@export var display_name := ""
@export var category: Category = Category.WEAPON
@export var rarity: Rarity = Rarity.COMMON
@export var icon: Texture2D
@export_multiline var description := ""
@export_multiline var flavor := ""
@export var quantity := 1
@export var weight := 0.0
@export var equipped := false
@export var is_new := false
## Пустой слот означает, что предмет нельзя экипировать.
@export var equip_slot: StringName = &""
@export var stats: Array = []
@export var properties: PackedStringArray = []
## Цена только для демонстрационной витрины; -1 — не продаётся.
@export var demo_price := -1


func is_gear() -> bool:
	return (category == Category.WEAPON or category == Category.ARMOR) and not equip_slot.is_empty()


func stack_weight() -> float:
	return weight * float(quantity)
