class_name ArmorSetData
extends EquipmentItemData
## Цельный комплект брони.
##
## MVP сознательно не делит броню на кирасу/наручи/поножи: один сет — один
## визуал и один слот BODY. Позже ArmorSetData можно расширить массивом
## ArmorPieceData, не меняя EquipmentComponent.

enum Mode {
	## Броня надевается поверх тела; скрываются только указанные части одежды.
	OVERLAY,
	## Броня включает тело/голову/руки; базовая модель скрывается целиком.
	REPLACEMENT,
}

@export var mode: Mode = Mode.OVERLAY
## Смысловые зоны покрытия: torso, arms, legs, head, feet. Нужны UI и будущим сетам.
@export var coverage: PackedStringArray = ["torso", "arms", "legs"]
## Скрывать все узлы, имя которых начинается с префикса. Для P1 это
## автоматически покрывает _LOD1/_LOD2 и новые LOD-копии одежды.
@export var hide_part_prefixes: PackedStringArray = []

@export_group("LOD")
## Включать LOD-переключение, если в visual_scene есть меши _LOD1/_LOD2.
@export var enable_lod := true
## Дистанция перехода LOD0 -> LOD1, м.
@export var lod1_distance := 8.0
## Дистанция перехода LOD1 -> LOD2, м.
@export var lod2_distance := 18.0


func _init() -> void:
	slot = Slot.BODY


func validate() -> PackedStringArray:
	var errors := super.validate()
	# OVERLAY может сознательно не скрывать одежду: альфа-сет надевается поверх
	# готового персонажа, пока нет отдельного base-body ассета.
	return errors
