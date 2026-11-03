class_name QuestReward
extends Resource
## Награда за задание. Все поля необязательные; применяются только
## заполненные. Валюта и Памяти не занимают слоты инвентаря.

@export var item_id: StringName
@export_range(1, 999, 1) var item_count := 1
@export var currency_id: StringName = &""
@export_range(0, 99999, 1) var currency_amount := 0
@export var memory_id: StringName
@export var flag: StringName
@export_range(0.0, 1000.0, 1.0) var heal_amount := 0.0
@export_multiline var text := ""


func is_empty() -> bool:
	return (
		item_id == &""
		and currency_id == &""
		and memory_id == &""
		and flag == &""
		and heal_amount <= 0.0
	)


func describe() -> String:
	if not text.strip_edges().is_empty():
		return text.strip_edges()
	var parts: Array[String] = []
	if item_id != &"":
		parts.append("%s ×%d" % [String(item_id), item_count])
	if currency_id != &"" and currency_amount > 0:
		parts.append("%s +%d" % [String(currency_id), currency_amount])
	if memory_id != &"":
		parts.append("Память: %s" % String(memory_id))
	if flag != &"":
		parts.append("флаг %s" % String(flag))
	if heal_amount > 0.0:
		parts.append("лечение %d" % roundi(heal_amount))
	return ", ".join(parts)
