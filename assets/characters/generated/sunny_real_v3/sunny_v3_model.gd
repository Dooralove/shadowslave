class_name SunnyV3Model
extends Node3D
## Native AnimationPlayer wrapper for the image-to-3D Sunny v3 GLB.
##
## The generated humanoid clips arrive as one-shots. Locomotion clips are
## looped here, and the long downhill walk take is trimmed to a clean in-place
## cycle (`WalkClean`). The landing roll's forward drift is removed so the
## controller owns movement; the vertical part of the roll is kept.
##
## The scene root can carry a FootGrounder; this script only prepares clips.

const LOOPING: Array[StringName] = [
	&"HumanStandingIdle",
	&"HumanRelaxedWalkLoopF",
	&"HumanSprintLoop",
]
const WALK_SOURCE := &"HumanRelaxedWalkLoopF"
const WALK_CLEAN := &"WalkClean"
## The source take is 4.13 s long and walks downhill. 0.8-1.8 s is a clean
## left/right gait cycle with both feet near the centre at the seam.
const WALK_START := 0.8
const WALK_END := 1.8
const SWORD_SCENE := preload("res://assets/environments/nightmare/caravan/short_sword.glb")
const SWORD_ATTACK_SCENE := preload("res://assets/characters/equipment/animations/sunny_v3_sword_attack.glb")
const GUARD_POSE := preload("res://scripts/characters/guard_pose_modifier.gd")

@export var ground_offset := -0.09
## Optional visual weapon socket for generated humanoids that use armed mode.
## CombatController discovers it through get_weapon_socket().
@export var weapon_socket := false

var _player: AnimationPlayer
var _guard_pose: Node


func _ready() -> void:
	var model := get_node_or_null(^"Model") as Node3D
	if model != null:
		model.position.y += ground_offset
	if weapon_socket:
		_ensure_weapon_socket()
	_ensure_guard_pose()
	_player = get_node_or_null(^"Model/AnimationPlayer") as AnimationPlayer
	if _player == null:
		push_warning("SunnyV3Model: native AnimationPlayer not found")
		return
	for clip in LOOPING:
		var animation := _player.get_animation(clip)
		if animation != null:
			animation.loop_mode = Animation.LOOP_LINEAR
	_ensure_sword_attack_clip()
	_build_clean_walk()
	_flatten_root_motion(&"HumanLandrollR", false)
	_flatten_root_motion(&"HumanRelaxedWalkLoopF", true)


func get_animation_player() -> AnimationPlayer:
	return _player


func _ensure_weapon_socket() -> void:
	var skeleton := find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton == null:
		skeleton = find_child("GeneralSkeleton", true, false) as Skeleton3D
	if skeleton == null:
		push_warning("SunnyV3Model: weapon_socket enabled but no skeleton")
		return
	if skeleton.get_node_or_null("WeaponSocket") != null:
		return
	var socket := BoneAttachment3D.new()
	socket.name = "WeaponSocket"
	socket.bone_name = &"RightHand"
	skeleton.add_child(socket)
	var sword := SWORD_SCENE.instantiate() as Node3D
	if sword == null:
		return
	sword.name = "Weapon"
	sword.rotation_degrees = Vector3(90, 90, 0)
	for mesh in sword.find_children("*", "MeshInstance3D", true, false):
		mesh.add_to_group(&"lod_ignore")
	socket.add_child(sword)
	socket.visible = false


func get_weapon_socket() -> BoneAttachment3D:
	var skeleton := find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton == null:
		skeleton = find_child("GeneralSkeleton", true, false) as Skeleton3D
	if skeleton == null:
		return null
	return skeleton.get_node_or_null("WeaponSocket") as BoneAttachment3D


func _ensure_guard_pose() -> void:
	var skeleton := find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton == null:
		skeleton = find_child("GeneralSkeleton", true, false) as Skeleton3D
	if skeleton == null:
		return
	_guard_pose = skeleton.get_node_or_null("GuardPose")
	if _guard_pose != null:
		return
	_guard_pose = GUARD_POSE.new()
	_guard_pose.name = "GuardPose"
	# v3/Nightmare use Mixamo-style arm bone names; the shared modifier's
	# default offsets target the P1 UE-style names.
	_guard_pose.set(&"offsets_deg", {
		&"RightArm": Vector3(0.0, 0.0, 45.0),
		&"RightForeArm": Vector3(0.0, 0.0, -45.0),
		&"LeftArm": Vector3(0.0, 0.0, -45.0),
		&"LeftForeArm": Vector3(0.0, 0.0, 45.0),
	})
	skeleton.add_child(_guard_pose)


func get_guard_pose() -> Node:
	return _guard_pose


func _ensure_sword_attack_clip() -> void:
	if _player == null or _player.has_animation(&"Sword_Attack"):
		return
	var source_scene := SWORD_ATTACK_SCENE.instantiate()
	var source_player := source_scene.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if source_player == null:
		source_scene.free()
		return
	var source_library := source_player.get_animation_library(&"")
	var source_animation: Animation
	if source_library != null:
		var names := source_library.get_animation_list()
		if not names.is_empty():
			source_animation = source_library.get_animation(names[0])
	if source_animation != null:
		var library := _player.get_animation_library(&"")
		if library != null:
			library.add_animation(&"Sword_Attack", source_animation.duplicate())
	source_scene.free()


func _build_clean_walk() -> void:
	var source := _player.get_animation(WALK_SOURCE)
	if source == null:
		return
	var clean := _trim_and_flatten(source, WALK_START, WALK_END)
	clean.loop_mode = Animation.LOOP_LINEAR
	var library := _player.get_animation_library(&"")
	if library == null:
		return
	if library.has_animation(WALK_CLEAN):
		library.remove_animation(WALK_CLEAN)
	library.add_animation(WALK_CLEAN, clean)


func _trim_and_flatten(source: Animation, start: float, end: float) -> Animation:
	var anim := source.duplicate() as Animation
	var span := end - start
	for i in range(anim.get_track_count() - 1, -1, -1):
		for k in range(anim.track_get_key_count(i) - 1, -1, -1):
			var t := anim.track_get_key_time(i, k)
			if t < start - 0.0001 or t > end + 0.0001:
				anim.track_remove_key(i, k)
		for k in anim.track_get_key_count(i):
			anim.track_set_key_time(i, k, anim.track_get_key_time(i, k) - start)
	_flatten_hips(anim, span, true)
	anim.length = span
	return anim


## Removes linear Hips drift. Forward (Z) is always removed; vertical (Y) only
## for locomotion, because the landing roll's height change is intentional.
func _flatten_hips(anim: Animation, span: float, flatten_y: bool) -> void:
	var hips_track := -1
	for i in anim.get_track_count():
		if anim.track_get_type(i) == Animation.TYPE_POSITION_3D:
			var bone := StringName(anim.track_get_path(i).get_concatenated_subnames())
			if bone == &"Hips":
				hips_track = i
				break
	if hips_track < 0:
		return
	var n := anim.track_get_key_count(hips_track)
	if n < 2:
		return
	var first: Vector3 = anim.track_get_key_value(hips_track, 0)
	var last: Vector3 = anim.track_get_key_value(hips_track, n - 1)
	var dy := last.y - first.y if flatten_y else 0.0
	var dz := last.z - first.z
	for k in n:
		var t := anim.track_get_key_time(hips_track, k) / maxf(span, 0.001)
		var v: Vector3 = anim.track_get_key_value(hips_track, k)
		v.y -= dy * t
		v.z -= dz * t
		anim.track_set_key_value(hips_track, k, v)


func _flatten_root_motion(clip: StringName, flatten_y: bool) -> void:
	var anim := _player.get_animation(clip)
	if anim == null:
		return
	_flatten_hips(anim, anim.length, flatten_y)
