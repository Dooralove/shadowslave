class_name EquipmentItemData
extends Resource
## Базовое описание надеваемого объекта.
##
## Броня — цельный skinned-комплект. Оружие и аксессуары — обычные статические
## меши на BoneAttachment3D. Ресурс не знает о сцене персонажа: привязку
## выполняет EquipmentComponent.

enum Slot {
	BODY,
	WEAPON,
	ACCESSORY,
}

@export var id: StringName = &""
@export var display_name := ""
@export var slot: Slot = Slot.BODY

## Сцена визуала: для брони — GLB/tscn с одним или несколькими skinned-мешами,
## для оружия/аксессуара — обычный MeshInstance3D.
@export var visual_scene: PackedScene
## Профиль скелета, под который собран визуал. Пустой — проверить только по сцене.
@export var rig_profile: CharacterRigProfile

@export_group("Body coverage")
## Имена узлов базовой модели, которые нужно скрыть (например, "sweater").
@export var hide_parts: PackedStringArray = []
## Индексы surface внутри одного MeshInstance3D. Используется, если меш не разделён.
@export var hide_surfaces: PackedInt32Array = []

@export_group("Attachment")
## Логический сокет для оружия/аксессуара: hand_r, hips, back, head.
@export var attach_socket: StringName = &""
@export var visual_offset := Vector3.ZERO
@export var visual_rotation_degrees := Vector3.ZERO
@export var visual_scale := Vector3.ONE

@export_group("Metadata")
@export var tags: PackedStringArray = []
@export var ab_variant: StringName = &""
@export_multiline var notes := ""


func get_visual_transform() -> Transform3D:
	var basis := Basis.from_euler(Vector3(
		deg_to_rad(visual_rotation_degrees.x),
		deg_to_rad(visual_rotation_degrees.y),
		deg_to_rad(visual_rotation_degrees.z)
	))
	basis = basis.scaled(visual_scale)
	return Transform3D(basis, visual_offset)


## Возвращает список проблем, а не молча роняет экипировку.
func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if id == &"":
		errors.append("id пуст")
	if visual_scene == null:
		errors.append("visual_scene не назначена")
	if rig_profile == null:
		errors.append("rig_profile не назначен")
	if slot == Slot.WEAPON:
		var grip: Variant = get(&"grip_socket")
		if attach_socket == &"" and (grip == null or StringName(grip) == &""):
			errors.append("для оружия не задан attach_socket/grip_socket")
	elif slot == Slot.ACCESSORY and attach_socket == &"":
		errors.append("для аксессуара не задан attach_socket")
	if visual_scale == Vector3.ZERO:
		errors.append("visual_scale не может быть нулевым")
	return errors
