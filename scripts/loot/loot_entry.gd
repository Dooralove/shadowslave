class_name LootEntry
extends Resource
## Одна строка таблицы лута. Шанс проверяется отдельно от веса: сначала
## бросок «выпало ли», затем взвешенный выбор среди выпавших строк.

@export var item: EquipmentItemData
## 1.0 — гарантированно, 0.0 — никогда. Для guaranteed=true шанс игнорируется.
@export_range(0.0, 1.0, 0.01) var chance := 1.0
@export var min_quantity := 1
@export var max_quantity := 1
## Относительный вес при выборе среди нескольких подходящих строк.
@export var weight := 1.0
## Если true, строка всегда попадает в результат (в пределах rolls).
@export var guaranteed := false
## Необязательные условия по флагам NightmareRunState/квестов.
@export var required_flag: StringName = &""
@export var excluded_flag: StringName = &""


func is_valid() -> bool:
	return item != null and item.id != &"" and weight > 0.0 and max_quantity >= min_quantity


func passes_flags(flags: Dictionary) -> bool:
	if required_flag != &"" and not bool(flags.get(required_flag, false)):
		return false
	if excluded_flag != &"" and bool(flags.get(excluded_flag, false)):
		return false
	return true


func roll_quantity(rng: RandomNumberGenerator) -> int:
	return rng.randi_range(min_quantity, max_quantity)
