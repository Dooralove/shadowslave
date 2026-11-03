class_name ArmorStats
extends Resource
## Числовое описание комплекта брони. Отдельный ресурс, чтобы один и тот же
## набор статов можно было переиспользовать для визуальных вариантов сета
## и чтобы балансные значения жили в .tres, а не в коде.

@export_group("Defense")
## Плоская защита. В снижение урона переводится формулой armor/(armor+100).
@export var armor_value := 0.0
## Вес комплекта в килограммах. Влияет на переносимый вес и скорость.
@export var weight := 0.0
## Бонус к силе удара: прибавляется к урону оружия/кулака.
@export var impact_bonus := 0.0
## Сопротивление оглушению 0..1. Уменьшает длительность guard break.
@export_range(0.0, 1.0, 0.01) var stagger_resistance := 0.0
## Сопротивления по типам урона: physical, slash, pierce, blunt, fire, cold, shadow.
@export var damage_resistances: Dictionary = {}

@export_group("Movement")
## Множитель скорости передвижения. 0.92 — на 8% медленнее.
@export_range(0.5, 1.5, 0.01) var move_speed_multiplier := 1.0
## Множитель восстановления выносливости.
@export_range(0.5, 1.5, 0.01) var stamina_regen_multiplier := 1.0

@export_group("Passive")
## Положительные пассивные эффекты. Показываются в UI зелёным.
@export var passive_buffs: Array[StatModifier] = []
## Отрицательные пассивные эффекты. Показываются в UI красным.
@export var passive_debuffs: Array[StatModifier] = []
## Дополнительные модификаторы без знака: сет-бонусы, проклятия и т.п.
@export var modifiers: Array[StatModifier] = []


func all_modifiers() -> Array[StatModifier]:
	var result: Array[StatModifier] = []
	result.append_array(passive_buffs)
	result.append_array(passive_debuffs)
	result.append_array(modifiers)
	return result


func get_resistance(damage_type: StringName) -> float:
	return clampf(float(damage_resistances.get(StringName(damage_type), 0.0)), 0.0, 0.95)


## Базовое снижение урона от плоской защиты. Не включает сопротивления.
func get_armor_reduction() -> float:
	if armor_value <= 0.0:
		return 0.0
	return clampf(armor_value / (armor_value + 100.0), 0.0, 0.85)


func get_weight() -> float:
	return maxf(weight, 0.0)


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if armor_value < 0.0:
		errors.append("armor_value не может быть отрицательным")
	if weight < 0.0:
		errors.append("weight не может быть отрицательным")
	for modifier in all_modifiers():
		if modifier != null and not modifier.is_valid():
			errors.append("невалидный модификатор: %s" % modifier.describe())
	return errors


## Человекочитаемая сводка для тултипа/демо-панели.
func summary_lines() -> PackedStringArray:
	var lines := PackedStringArray()
	lines.append("Защита: %.0f (%.0f%% урона)" % [armor_value, get_armor_reduction() * 100.0])
	lines.append("Вес: %.1f кг" % weight)
	if impact_bonus != 0.0:
		lines.append("Сила удара: %+.1f" % impact_bonus)
	if stagger_resistance > 0.0:
		lines.append("Стойкость: %.0f%%" % (stagger_resistance * 100.0))
	if not damage_resistances.is_empty():
		var parts := PackedStringArray()
		for damage_type in damage_resistances.keys():
			parts.append("%s %.0f%%" % [damage_type, get_resistance(StringName(damage_type)) * 100.0])
		lines.append("Сопротивления: " + ", ".join(parts))
	if not is_equal_approx(move_speed_multiplier, 1.0):
		lines.append("Скорость: x%.2f" % move_speed_multiplier)
	if not is_equal_approx(stamina_regen_multiplier, 1.0):
		lines.append("Выносливость: x%.2f" % stamina_regen_multiplier)
	for modifier in passive_buffs:
		if modifier != null:
			lines.append("Бафф: %s" % modifier.describe())
	for modifier in passive_debuffs:
		if modifier != null:
			lines.append("Дебафф: %s" % modifier.describe())
	for modifier in modifiers:
		if modifier != null:
			lines.append(modifier.describe())
	return lines
