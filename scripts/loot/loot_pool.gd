class_name LootPool
extends Resource
## Generic-пул лута для контейнеров, врагов, элит и боссов.
##
## Отличается от equipment-only LootTable: записи ссылаются на LootItemData,
## поэтому в одном пуле могут лежать валюта, материалы, расходники, обычная
## экипировка и Памяти. Награда применяется к NightmareRunState, а не к
## InventoryComponent демо-арены.
##
## guaranteed — всегда выпадает (ядро награды).
## entries — взвешенный пул; bonus_rolls задаёт число независимых роллов.
## empty_chance — шанс, что пул не даст ничего, но guaranteed останется.
## respawns = false: пул не предназначен для фарма; контейнер/враг запоминает
## факт выдачи флагом в NightmareRunState.

@export var id: StringName = &""
@export var display_name := ""
@export_multiline var description := ""
@export_enum("container", "enemy", "elite", "boss", "humanoid") var source_kind := "container"
## CANON / TEXT / GD / GD_FUTURE.
@export var canon_status: StringName = &"GD"
@export var guaranteed: Array[LootPoolEntry] = []
@export var entries: Array[LootPoolEntry] = []
@export_range(0, 8, 1) var bonus_rolls := 1
@export_range(0.0, 100.0, 0.1) var empty_chance := 0.0
@export var respawns := false
@export var tags: PackedStringArray = []


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if id == &"":
		errors.append("id пуст")
	if display_name.strip_edges().is_empty():
		errors.append("display_name пуст")
	if guaranteed.is_empty() and entries.is_empty():
		errors.append("нет ни guaranteed, ни entries")
	for index in guaranteed.size():
		var entry := guaranteed[index]
		if entry == null or not entry.is_valid():
			errors.append("guaranteed[%d] невалидна" % index)
	for index in entries.size():
		var entry := entries[index]
		if entry == null or not entry.is_valid():
			errors.append("entries[%d] невалидна" % index)
	if bonus_rolls < 0:
		errors.append("bonus_rolls < 0")
	return errors


func get_entry(item_id: StringName) -> LootPoolEntry:
	for entry in guaranteed:
		if entry != null and entry.item != null and entry.item.id == item_id:
			return entry
	for entry in entries:
		if entry != null and entry.item != null and entry.item.id == item_id:
			return entry
	return null
