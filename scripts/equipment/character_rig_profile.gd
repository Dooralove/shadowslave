class_name CharacterRigProfile
extends Resource
## Описание скелета, на который можно надеть skinned-броню.
##
## Профиль не хранит ссылки на сцену: он только связывает логические сокеты
## с реальными именами костей и перечисляет обязательные кости для проверки.

@export var id: StringName = &""
@export var skeleton_name: StringName = &"Skeleton3D"
## Кости, без которых скиннинг брони считается несовместимым.
@export var required_bones: PackedStringArray = []
## Логический сокет -> имя кости. Например, hand_r -> RightHand.
@export var socket_bones: Dictionary = {}
@export_multiline var notes := ""


func resolve_socket_bone(socket_id: StringName) -> StringName:
	var value: Variant = socket_bones.get(StringName(socket_id), &"")
	return StringName(value)


func missing_required_bones(skeleton: Skeleton3D) -> PackedStringArray:
	var missing := PackedStringArray()
	if skeleton == null:
		return missing
	for bone_name in required_bones:
		if skeleton.find_bone(StringName(bone_name)) < 0:
			missing.append(bone_name)
	return missing


func has_bone(skeleton: Skeleton3D, bone_name: StringName) -> bool:
	return skeleton != null and skeleton.find_bone(bone_name) >= 0
