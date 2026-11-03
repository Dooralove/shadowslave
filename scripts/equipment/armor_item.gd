class_name ArmorItem
extends ArmorSetData
## Броня как игровой предмет: визуал + статы + пассивные эффекты.
##
## Наследует ArmorSetData, поэтому EquipmentComponent надевает её тем же
## путём, что и альфа-сеты: один BODY-слот, цельный skinned-меш, скрытие
## частей базового тела по hide_parts/hide_surfaces.

enum Rarity {
	COMMON,
	UNCOMMON,
	RARE,
	EPIC,
	LEGENDARY,
}

@export_group("Gameplay")
@export var stats: ArmorStats
@export var rarity: Rarity = Rarity.COMMON
## Идентификатор сета для будущих сет-бонусов. Пока только отображается.
@export var set_id: StringName = &""
## Требование к силе. 0 — без требования; ниже требования скорость падает.
@export var required_strength := 0.0
@export_multiline var description := ""
@export_multiline var lore := ""

@export_group("Presentation")
## Цвет метки редкости для мира/UI.
@export var rarity_color := Color(0.72, 0.72, 0.72)


func _init() -> void:
	slot = Slot.BODY


func get_stats() -> ArmorStats:
	return stats


func get_armor_value() -> float:
	return stats.armor_value if stats != null else 0.0


func get_weight() -> float:
	return stats.get_weight() if stats != null else 0.0


func get_impact_bonus() -> float:
	return stats.impact_bonus if stats != null else 0.0


func get_move_speed_multiplier() -> float:
	return stats.move_speed_multiplier if stats != null else 1.0


func get_rarity_name() -> String:
	match rarity:
		Rarity.UNCOMMON:
			return "Необычная"
		Rarity.RARE:
			return "Редкая"
		Rarity.EPIC:
			return "Эпическая"
		Rarity.LEGENDARY:
			return "Легендарная"
		_:
			return "Обычная"


func summary_lines() -> PackedStringArray:
	var lines := PackedStringArray()
	if stats != null:
		lines.append_array(stats.summary_lines())
	if required_strength > 0.0:
		lines.append("Требуемая сила: %.0f" % required_strength)
	return lines


func validate() -> PackedStringArray:
	var errors := super.validate()
	if stats == null:
		errors.append("stats не назначены")
	else:
		errors.append_array(stats.validate())
	if required_strength < 0.0:
		errors.append("required_strength не может быть отрицательным")
	return errors
