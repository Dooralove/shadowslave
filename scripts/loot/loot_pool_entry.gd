class_name LootPoolEntry
extends Resource
## Одна взвешенная запись generic-пула лута.
##
## condition_min/max — только метаданные износа для будущей системы состояния.
## В текущем прототипе износ кодируется отдельными item id (worn/used/fine),
## потому что прочности и ремонта в игре нет.

@export var item: LootItemData
@export_range(1, 999, 1) var min_count := 1
@export_range(1, 999, 1) var max_count := 1
@export_range(0.0, 1000.0, 0.1) var weight := 1.0
@export_range(0.0, 1.0, 0.01) var condition_min := 1.0
@export_range(0.0, 1.0, 0.01) var condition_max := 1.0
@export var unique := false
@export_multiline var notes := ""


func roll_count(rng: RandomNumberGenerator) -> int:
	var low := mini(min_count, max_count)
	var high := maxi(min_count, max_count)
	return rng.randi_range(maxi(low, 1), maxi(high, 1))


func roll_condition(rng: RandomNumberGenerator) -> float:
	var low := minf(condition_min, condition_max)
	var high := maxf(condition_min, condition_max)
	return rng.randf_range(clampf(low, 0.0, 1.0), clampf(high, 0.0, 1.0))


func is_valid() -> bool:
	return item != null and item.is_valid() and weight > 0.0
