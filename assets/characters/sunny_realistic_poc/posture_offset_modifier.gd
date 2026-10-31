@tool
class_name PostureOffsetModifier
extends SkeletonModifier3D
## Постоянная поправка осанки поверх любой анимации (только прототип S2).
## После ретаргетинга клипов Quaternius UAL на скелет MakeHuman верх спины и шея наклонены вперёд сильнее,
## чем в исходнике (замер: в T-позе голова на ~12,6 см впереди таза против ~5,5 см у манекена UAL).
## Модификатор доворачивает указанные кости вокруг их локальной оси X (ось сгиба профиля
## SkeletonProfileHumanoid: «+» — сгиб вперёд). Анимации не меняются; убрать узел — вернуть исходную позу.

## Кость → поворот в градусах вокруг локальной оси X (отрицательный — выпрямить назад).
## Бёдра чуть вперёд, стопы на тот же угол назад: щиколотки были на ~11 см позади таза (у человека ~3–4 см),
## и в профиле фигура «падала» вперёд.
@export var offsets_deg := {
	&"UpperChest": -8.0, &"Neck": -10.0,
	&"LeftUpperLeg": 5.0, &"RightUpperLeg": 5.0, &"LeftFoot": -5.0, &"RightFoot": -5.0,
}


func _process_modification_with_delta(_delta: float) -> void:
	var skeleton := get_skeleton()
	if skeleton == null:
		return
	for bone_name in offsets_deg:
		var bone := skeleton.find_bone(bone_name)
		if bone == -1:
			continue
		var extra := Quaternion(Vector3.RIGHT, deg_to_rad(offsets_deg[bone_name]))
		skeleton.set_bone_pose_rotation(bone, skeleton.get_bone_pose_rotation(bone) * extra)
