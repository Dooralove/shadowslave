class_name EquipmentABTest
extends Resource
## Минимальная конфигурация A/B-теста: два цельных сета на одном риге.
## В кампанию не сохраняется; используется только dev-сценой.

@export var variant_a: ArmorSetData
@export var variant_b: ArmorSetData
@export var active_variant: StringName = &"A"


func get_variant(variant: StringName) -> ArmorSetData:
	if variant == &"A":
		return variant_a
	if variant == &"B":
		return variant_b
	return null


func switch_variant() -> ArmorSetData:
	active_variant = &"B" if active_variant == &"A" else &"A"
	return get_variant(active_variant)
