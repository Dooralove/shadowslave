class_name LootDrop
extends RefCounted
## Результат одного ролла: предмет, количество и (необязательно) износ.

var item: LootItemData
var count := 1
var condition := 1.0
var unique := false
var source_table_id: StringName = &""


func get_id() -> StringName:
	return item.id if item != null else &""


func get_display_name() -> String:
	return item.display_name if item != null else ""


func get_category() -> int:
	return item.category if item != null else LootItemData.Category.MATERIAL


func is_valid() -> bool:
	return item != null and item.is_valid() and count > 0


func to_text() -> String:
	if not is_valid():
		return ""
	var suffix := ""
	var category := get_category()
	if category == LootItemData.Category.EQUIPMENT or category == LootItemData.Category.RELIC:
		if condition < 0.35:
			suffix = " (сильно изношен)"
		elif condition < 0.7:
			suffix = " (подержан)"
	return "%s ×%d%s" % [get_display_name(), count, suffix]
