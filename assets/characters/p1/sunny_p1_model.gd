@tool
class_name SunnyP1Model
extends Node3D
## P1-обёртка над GLB Санни: переименовывает скелет под UAL-клипы,
## добавляет LOD-переключатель и поправку осанки. Визуал, без геймплея.

@export var lod1_distance := 10.0
@export var lod2_distance := 22.0

var _prepared := false


func _ready() -> void:
	_prepare()


func _prepare() -> void:
	if _prepared:
		return
	_prepared = true
	var skeleton := find_child("GeneralSkeleton", true, false) as Skeleton3D
	if skeleton == null:
		skeleton = find_child("Skeleton3D", true, false) as Skeleton3D
		if skeleton != null:
			skeleton.name = "GeneralSkeleton"
	if skeleton != null:
		skeleton.owner = self
		skeleton.unique_name_in_owner = true
		if skeleton.get_node_or_null("PostureOffset") == null:
			var posture: Node = load("res://assets/characters/sunny_realistic_poc/posture_offset_modifier.gd").new()
			posture.name = "PostureOffset"
			skeleton.add_child(posture)
		_ensure_weapon_socket(skeleton)
		_ensure_guard_pose(skeleton)
	if get_node_or_null("CharacterLodVisibility") == null:
		var lod := CharacterLodVisibility.new()
		lod.name = "CharacterLodVisibility"
		lod.lod1_distance = lod1_distance
		lod.lod2_distance = lod2_distance
		add_child(lod)


## P1-модель не имеет weapon socket в GLB: создаём BoneAttachment3D на RightHand.
## Меч — существующий project-owned проп `short_sword.glb`; по умолчанию скрыт,
## пока CombatController не включит armed-режим.
func _ensure_weapon_socket(skeleton: Skeleton3D) -> void:
	if skeleton.get_node_or_null("WeaponSocket") != null:
		return
	var socket := BoneAttachment3D.new()
	socket.name = "WeaponSocket"
	socket.bone_name = &"RightHand"
	skeleton.add_child(socket)
	var sword_scene := load("res://assets/environments/nightmare/caravan/short_sword.glb") as PackedScene
	if sword_scene == null:
		return
	var sword := sword_scene.instantiate() as Node3D
	sword.name = "Weapon"
	sword.scale = Vector3(1.0, 1.0, 1.0)
	# Blade runs along local -Z; the hand bone's local +Y points along the fingers.
	sword.rotation_degrees = Vector3(90, 90, 0)
	socket.add_child(sword)
	socket.visible = false


func get_weapon_socket() -> BoneAttachment3D:
	var skeleton := find_child("GeneralSkeleton", true, false) as Skeleton3D
	if skeleton == null:
		var skeletons := find_children("*", "Skeleton3D", true, false)
		if not skeletons.is_empty():
			skeleton = skeletons[0] as Skeleton3D
	if skeleton == null:
		return null
	return skeleton.get_node_or_null("WeaponSocket") as BoneAttachment3D


func _ensure_guard_pose(skeleton: Skeleton3D) -> void:
	if skeleton.get_node_or_null("GuardPose") != null:
		return
	var guard: Node = load("res://scripts/characters/guard_pose_modifier.gd").new()
	guard.name = "GuardPose"
	skeleton.add_child(guard)


func get_guard_pose() -> Node:
	var skeleton := find_child("GeneralSkeleton", true, false) as Skeleton3D
	if skeleton == null:
		var skeletons := find_children("*", "Skeleton3D", true, false)
		if not skeletons.is_empty():
			skeleton = skeletons[0] as Skeleton3D
	if skeleton == null:
		return null
	return skeleton.get_node_or_null("GuardPose")
