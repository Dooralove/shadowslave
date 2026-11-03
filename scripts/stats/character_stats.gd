class_name CharacterStats
extends Node
## Агрегатор характеристик персонажа: базовые значения + надетые предметы.
##
## Броня не меняет поля персонажа напрямую. Она складывается в один набор
## totals, а компонент применяет итог к HealthComponent, CombatController и
## MeleeAttack. Благодаря этому снятие сета всегда возвращает базовые значения.

signal stats_recalculated(totals: Dictionary)
signal stat_changed(stat: StringName, previous: float, current: float)
signal encumbrance_changed(ratio: float, tier: int)

enum EncumbranceTier { LIGHT, MEDIUM, HEAVY, OVERLOADED }

@export_group("Node links")
@export var health_path: NodePath
@export var combat_controller_path: NodePath
@export var attack_path: NodePath

@export_group("Base values")
@export var base_armor := 0.0
@export var base_weight := 0.0
@export var base_impact := 0.0
@export var base_max_health := 100.0
@export var base_move_speed_multiplier := 1.0
@export var base_stamina_regen_multiplier := 1.0
@export_range(0.0, 1.0, 0.01) var base_stagger_resistance := 0.0
@export var base_resistances: Dictionary = {}

@export_group("Encumbrance")
@export var max_carry_weight := 35.0
## Доля max_carry_weight, после которой начинается штраф скорости.
@export_range(0.1, 1.0, 0.01) var encumbrance_threshold := 0.5
## Максимальный штраф скорости от перегруза.
@export_range(0.0, 0.5, 0.01) var max_encumbrance_penalty := 0.4

var totals: Dictionary = {}
var resistances: Dictionary = {}
var encumbrance_ratio := 0.0
var encumbrance_tier: EncumbranceTier = EncumbranceTier.LIGHT

var _equipped: Array[EquipmentItemData] = []
var _health: HealthComponent
var _combat: CombatController
var _attack: MeleeAttack


func _ready() -> void:
	_resolve_nodes()
	recompute()


func _resolve_nodes() -> void:
	if _health == null:
		_health = _find_node(health_path, "Health") as HealthComponent
	if _combat == null:
		_combat = _find_node(combat_controller_path, "CombatController") as CombatController
	if _attack == null:
		_attack = _find_node(attack_path, "Visual/MeleeAttack") as MeleeAttack


func _find_node(path: NodePath, fallback: String) -> Node:
	if not path.is_empty():
		var direct := get_node_or_null(path)
		if direct != null:
			return direct
	var owner_node := get_parent()
	if owner_node == null:
		return null
	return owner_node.get_node_or_null(NodePath(fallback))


## Вызывается EquipmentComponent после каждого rebuild.
func apply_loadout(loadout: EquipmentLoadout) -> void:
	_equipped.clear()
	if loadout != null:
		if loadout.body != null:
			_equipped.append(loadout.body)
		if loadout.weapon != null:
			_equipped.append(loadout.weapon)
		for accessory in loadout.accessories:
			if accessory != null:
				_equipped.append(accessory)
	recompute()


## Для инвентаря/тестов: применить произвольный набор предметов.
func apply_items(items: Array[EquipmentItemData]) -> void:
	_equipped = items.duplicate()
	recompute()


func recompute() -> void:
	_resolve_nodes()
	var previous := totals.duplicate()

	var armor := base_armor
	var weight := base_weight
	var impact := base_impact
	var max_health := base_max_health
	var move_speed := base_move_speed_multiplier
	var stamina_regen := base_stamina_regen_multiplier
	var stagger := base_stagger_resistance
	var merged_resistances: Dictionary = base_resistances.duplicate()

	for item in _equipped:
		var armor_item := item as ArmorItem
		if armor_item == null or armor_item.stats == null:
			continue
		var stats := armor_item.stats
		armor += stats.armor_value
		weight += stats.weight
		impact += stats.impact_bonus
		stagger += stats.stagger_resistance
		move_speed *= stats.move_speed_multiplier
		stamina_regen *= stats.stamina_regen_multiplier
		for damage_type in stats.damage_resistances.keys():
			var key := StringName(damage_type)
			merged_resistances[key] = clampf(
				float(merged_resistances.get(key, 0.0)) + float(stats.damage_resistances[damage_type]),
				0.0,
				0.95
			)

	totals = {
		&"armor": armor,
		&"weight": weight,
		&"impact": impact,
		&"max_health": max_health,
		&"move_speed": move_speed,
		&"stamina_regen": stamina_regen,
		&"stagger_resistance": stagger,
	}

	for item in _equipped:
		var armor_item := item as ArmorItem
		if armor_item == null or armor_item.stats == null:
			continue
		for modifier in armor_item.stats.all_modifiers():
			if modifier == null or not modifier.is_valid():
				continue
			var key := modifier.stat
			var current := float(totals.get(key, 0.0))
			totals[key] = modifier.apply(current)

	# Derived values.
	armor = maxf(float(totals.get(&"armor", 0.0)), 0.0)
	weight = maxf(float(totals.get(&"weight", 0.0)), 0.0)
	var armor_reduction := 0.0
	if armor > 0.0:
		armor_reduction = clampf(armor / (armor + 100.0), 0.0, 0.85)
	var flat_reduction := clampf(float(totals.get(&"damage_reduction", 0.0)), 0.0, 0.9)
	var damage_reduction := clampf(armor_reduction + flat_reduction, 0.0, 0.9)

	encumbrance_ratio = weight / maxf(max_carry_weight, 1.0)
	var penalty := 0.0
	if encumbrance_ratio > encumbrance_threshold:
		penalty = clampf(
			(encumbrance_ratio - encumbrance_threshold) * 0.6,
			0.0,
			max_encumbrance_penalty
		)
	var final_move_speed := clampf(
		float(totals.get(&"move_speed", 1.0)) * (1.0 - penalty),
		0.4,
		1.6
	)
	var final_stamina := clampf(float(totals.get(&"stamina_regen", 1.0)), 0.4, 1.6)
	var final_stagger := clampf(float(totals.get(&"stagger_resistance", 0.0)), 0.0, 0.9)

	totals[&"armor"] = armor
	totals[&"weight"] = weight
	totals[&"damage_reduction"] = damage_reduction
	totals[&"move_speed"] = final_move_speed
	totals[&"stamina_regen"] = final_stamina
	totals[&"stagger_resistance"] = final_stagger
	totals[&"max_health"] = maxf(float(totals.get(&"max_health", base_max_health)), 1.0)
	totals[&"impact"] = float(totals.get(&"impact", base_impact))
	resistances = merged_resistances
	encumbrance_tier = _tier_for(encumbrance_ratio)

	_apply_to_health()
	_apply_to_combat()
	_apply_to_attack()

	for key in totals.keys():
		var before := float(previous.get(key, 0.0))
		var after := float(totals[key])
		if not is_equal_approx(before, after):
			stat_changed.emit(StringName(key), before, after)
	encumbrance_changed.emit(encumbrance_ratio, encumbrance_tier)
	stats_recalculated.emit(totals)


func _apply_to_health() -> void:
	if _health == null:
		return
	_health.damage_reduction = float(totals.get(&"damage_reduction", 0.0))
	_health.damage_resistances = resistances.duplicate()
	var new_max := float(totals.get(&"max_health", _health.max_health))
	if not is_equal_approx(new_max, _health.max_health):
		_health.set_max_health_preserving_ratio(new_max)


func _apply_to_combat() -> void:
	if _combat == null:
		return
	_combat.set_external_move_speed_multiplier(float(totals.get(&"move_speed", 1.0)))
	_combat.set_external_stagger_resistance(float(totals.get(&"stagger_resistance", 0.0)))


func _apply_to_attack() -> void:
	if _attack == null:
		return
	_attack.set_damage_bonus(float(totals.get(&"impact", 0.0)))


func _tier_for(ratio: float) -> EncumbranceTier:
	if ratio >= 1.0:
		return EncumbranceTier.OVERLOADED
	if ratio >= 0.75:
		return EncumbranceTier.HEAVY
	if ratio >= encumbrance_threshold:
		return EncumbranceTier.MEDIUM
	return EncumbranceTier.LIGHT


func get_stat(stat: StringName) -> float:
	return float(totals.get(stat, 0.0))


func get_resistance(damage_type: StringName) -> float:
	return clampf(float(resistances.get(damage_type, 0.0)), 0.0, 0.95)


func get_damage_reduction() -> float:
	return get_stat(&"damage_reduction")


func get_move_speed_multiplier() -> float:
	return get_stat(&"move_speed")


func get_impact_bonus() -> float:
	return get_stat(&"impact")


func get_encumbrance_tier_name() -> String:
	match encumbrance_tier:
		EncumbranceTier.MEDIUM:
			return "Средняя нагрузка"
		EncumbranceTier.HEAVY:
			return "Тяжёлая нагрузка"
		EncumbranceTier.OVERLOADED:
			return "Перегруз"
		_:
			return "Лёгкая нагрузка"


func get_summary_lines() -> PackedStringArray:
	var lines := PackedStringArray()
	lines.append("Броня: %.0f (снижение %.0f%%)" % [
		get_stat(&"armor"),
		get_damage_reduction() * 100.0,
	])
	lines.append("Вес: %.1f / %.0f кг · %s" % [
		get_stat(&"weight"),
		max_carry_weight,
		get_encumbrance_tier_name(),
	])
	lines.append("Удар: %+.1f · Стойкость: %.0f%%" % [
		get_impact_bonus(),
		get_stat(&"stagger_resistance") * 100.0,
	])
	lines.append("Скорость: x%.2f · Выносливость: x%.2f" % [
		get_move_speed_multiplier(),
		get_stat(&"stamina_regen"),
	])
	return lines


func get_equipped_items() -> Array[EquipmentItemData]:
	return _equipped.duplicate()
