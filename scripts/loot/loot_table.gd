class_name LootTable
extends Resource
## Таблица лута: гарантированные строки + N независимых бросков.
##
## Результат — массив словарей {item: EquipmentItemData, quantity: int}.
## Таблица не знает, кто умер и где спавнить: это делает LootDropComponent.

@export var id: StringName = &""
## Сколько независимых бросков сделать. 0 — только guaranteed_entries.
@export var rolls := 1
## Шанс, что бросок не даст ничего (при этом гарантированные строки остаются).
@export_range(0.0, 1.0, 0.01) var empty_chance := 0.0
@export var entries: Array[LootEntry] = []
## Строки, которые выпадают всегда, независимо от rolls и empty_chance.
@export var guaranteed_entries: Array[LootEntry] = []
## Предохранитель от случайной таблицы с сотней строк.
@export var max_drops := 8


func roll(rng: RandomNumberGenerator, flags: Dictionary = {}) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if max_drops <= 0:
		return result
	for entry in guaranteed_entries:
		if entry == null or not entry.is_valid() or not entry.passes_flags(flags):
			continue
		_add_drop(result, entry.item, entry.roll_quantity(rng))
		if result.size() >= max_drops:
			return result

	for _i in range(rolls):
		if result.size() >= max_drops:
			break
		if rng.randf() < empty_chance:
			continue
		var candidates: Array[LootEntry] = []
		for entry in entries:
			if entry == null or not entry.is_valid() or not entry.passes_flags(flags):
				continue
			if rng.randf() < entry.chance:
				candidates.append(entry)
		if candidates.is_empty():
			continue
		var chosen := _weighted_pick(candidates, rng)
		if chosen != null:
			_add_drop(result, chosen.item, chosen.roll_quantity(rng))
	return result


func _weighted_pick(candidates: Array[LootEntry], rng: RandomNumberGenerator) -> LootEntry:
	var total := 0.0
	for entry in candidates:
		total += maxf(entry.weight, 0.0)
	if total <= 0.0:
		return candidates[rng.randi_range(0, candidates.size() - 1)]
	var roll := rng.randf() * total
	for entry in candidates:
		roll -= maxf(entry.weight, 0.0)
		if roll <= 0.0:
			return entry
	return candidates[candidates.size() - 1]


func _add_drop(result: Array[Dictionary], item: EquipmentItemData, quantity: int) -> void:
	if item == null or quantity <= 0:
		return
	for drop in result:
		if (drop["item"] as EquipmentItemData).id == item.id:
			drop["quantity"] = int(drop["quantity"]) + quantity
			return
	result.append({"item": item, "quantity": quantity})


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if id == &"":
		errors.append("id пуст")
	if rolls < 0:
		errors.append("rolls не может быть отрицательным")
	if max_drops < 1:
		errors.append("max_drops должен быть >= 1")
	for entry in entries:
		if entry == null or not entry.is_valid():
			errors.append("невалидная строка entries")
	for entry in guaranteed_entries:
		if entry == null or not entry.is_valid():
			errors.append("невалидная строка guaranteed_entries")
	return errors
