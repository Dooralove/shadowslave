class_name WeaponData
extends EquipmentItemData
## Оружие на сокете. В альфе оружие меняет только визуал; боевые тайминги
## остаются у CombatController/MeleeAttack.
##
## Оружие имеет два положения: в руке (grip_socket) и на поясе/за спине
## (sheath_socket). EquipmentComponent переставляет один и тот же визуал,
## а не создаёт вторую копию.

@export var attack_data: AttackData
## Сокет в руке. Основной для боя.
@export var grip_socket: StringName = &"hand_r"
## Сокет в покое: hips (пояс) или back (за спиной).
@export var sheath_socket: StringName = &"hips"

@export_group("Sheathed transform")
## Смещение относительно кости ножен.
@export var sheath_offset := Vector3.ZERO
@export var sheath_rotation_degrees := Vector3.ZERO
@export var sheath_scale := Vector3.ONE
## Показывать оружие в ножнах. false — просто скрыть, если сокет не найден.
@export var visible_when_sheathed := true


func _init() -> void:
	slot = Slot.WEAPON


func get_grip_transform() -> Transform3D:
	return get_visual_transform()


func get_sheath_transform() -> Transform3D:
	var basis := Basis.from_euler(Vector3(
		deg_to_rad(sheath_rotation_degrees.x),
		deg_to_rad(sheath_rotation_degrees.y),
		deg_to_rad(sheath_rotation_degrees.z)
	))
	basis = basis.scaled(sheath_scale)
	return Transform3D(basis, sheath_offset)


func validate() -> PackedStringArray:
	var errors := super.validate()
	if grip_socket == &"":
		errors.append("grip_socket пуст")
	if sheath_socket == &"" and visible_when_sheathed:
		errors.append("sheath_socket пуст, но visible_when_sheathed=true")
	if sheath_scale == Vector3.ZERO:
		errors.append("sheath_scale не может быть нулевым")
	return errors
