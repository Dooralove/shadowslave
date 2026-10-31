@tool
class_name HorsePlaceholder
extends Node3D
## Временная лошадь (CC0, Quaternius «Farm Animals»). Корень стоит на земле и смотрит в -Z, как всадник.

const POSE_CLIPS := {&"idle": &"Idle", &"walk": &"WalkSlow", &"trot": &"Walk", &"run": &"Run"}

@export_enum("idle", "walk", "trot", "run") var pose := "idle":
	set(value):
		pose = value
		if is_inside_tree():
			_play_pose()
## Масть. Грива, хвост и копыта остаются тёмными.
@export var coat_color := Color(0.36, 0.2, 0.12):
	set(value):
		coat_color = value
		if is_inside_tree():
			_apply_coat()

@onready var _mesh: MeshInstance3D = $Model/Armature/Skeleton3D/Horse
@onready var _player: AnimationPlayer = $Model/AnimationPlayer


func _ready() -> void:
	_apply_coat()
	_play_pose()


func _apply_coat() -> void:
	var coat := (_mesh.mesh.surface_get_material(0) as BaseMaterial3D).duplicate() as BaseMaterial3D
	coat.albedo_color = coat_color
	coat.roughness = 0.8
	_mesh.set_surface_override_material(0, coat)


func _play_pose() -> void:
	var clip: StringName = POSE_CLIPS[StringName(pose)]
	_player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(get_path())
	_player.play(clip)
	_player.seek(rng.randf() * _player.current_animation_length, true)
