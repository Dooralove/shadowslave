class_name GuardPoseModifier
extends Node
## Additive arm offset for the low UAL Sword_Idle guard.
## The source clip holds the sword hand near the hip; this raises both arms into
## a readable mid-guard without replacing the clip. Active only while blocking.
##
## Implemented as a late Node (not SkeletonModifier3D) because the runtime-created
## modifier was not applied after the AnimationPlayer in normal playback.

@export var offsets_deg := {
	&"RightUpperArm": Vector3(30.0, 0.0, 0.0),
	&"RightLowerArm": Vector3(-60.0, 0.0, 0.0),
	&"RightHand": Vector3(0.0, 0.0, 0.0),
	&"LeftUpperArm": Vector3(25.0, 0.0, 0.0),
	&"LeftLowerArm": Vector3(-50.0, 0.0, 0.0),
}
var active := false


func _ready() -> void:
	process_priority = 100


func set_active(value: bool) -> void:
	active = value


func _process(_delta: float) -> void:
	if not active:
		return
	var skeleton := get_parent() as Skeleton3D
	if skeleton == null:
		return
	for bone_name in offsets_deg:
		var bone := skeleton.find_bone(bone_name)
		if bone < 0:
			continue
		var euler: Vector3 = offsets_deg[bone_name]
		var extra := Quaternion.from_euler(euler * (PI / 180.0))
		skeleton.set_bone_pose_rotation(bone, skeleton.get_bone_pose_rotation(bone) * extra)
