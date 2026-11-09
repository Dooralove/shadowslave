@tool
class_name MannequinPoseModifier
extends SkeletonModifier3D
## Дополнительная поза поверх клипа: генерируемые NPC не имеют клипов
## «колено», «читает», «указывает», поэтому кости доворачиваются после
## AnimationPlayer. Для UAL-моделей кости не находятся — модификатор молчит,
## там работают штатные клипы.

const POSE_ROTATIONS := {
	&"kneel": {
		&"LeftUpLeg": Vector3(95.0, 0.0, 0.0),
		&"LeftLeg": Vector3(-125.0, 0.0, 0.0),
		&"LeftFoot": Vector3(-30.0, 0.0, 0.0),
		&"RightUpLeg": Vector3(-15.0, 0.0, 0.0),
		&"RightLeg": Vector3(100.0, 0.0, 0.0),
		&"RightFoot": Vector3(60.0, 0.0, 0.0),
	},
	&"read": {
		&"Head": Vector3(14.0, 0.0, 0.0),
	},
	&"point": {
		&"RightArm": Vector3(-8.0, 0.0, -80.0),
		&"RightForeArm": Vector3(-10.0, 0.0, 0.0),
	},
}

var pose: StringName = &""


func _process_modification_with_delta(_delta: float) -> void:
	if pose == &"" or not POSE_ROTATIONS.has(pose):
		return
	var skeleton := get_skeleton()
	if skeleton == null:
		return
	var rotations: Dictionary = POSE_ROTATIONS[pose]
	for bone_name in rotations:
		var bone := skeleton.find_bone(StringName(bone_name))
		if bone == -1:
			continue
		var rest := skeleton.get_bone_rest(bone).basis.get_rotation_quaternion()
		var extra := Quaternion.from_euler((rotations[bone_name] as Vector3) * (PI / 180.0))
		skeleton.set_bone_pose_rotation(bone, rest * extra)
