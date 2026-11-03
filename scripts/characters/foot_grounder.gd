class_name FootGrounder
extends Node
## Visual-only foot grounding for generated/P1 humanoids.
##
## UAL/retargeted clips and some native takes place the lowest foot 8-20 cm
## above or below the character origin. This node shifts the model mesh so the
## lowest foot stays near the ground. It never moves the CharacterBody3D,
## collider, or gameplay root.
##
## The owner must call set_grounded(false) for jump/fall/death, where feet are
## intentionally off the ground.

@export var mesh_path: NodePath
@export var skeleton_path: NodePath
@export var ground_height := 0.02
@export var max_drop := 0.22
@export var max_raise := 0.04
@export var smoothing := 3.0
@export var foot_bones: Array[StringName] = [&"LeftFoot", &"RightFoot", &"LeftToes", &"RightToes"]
@export var enabled := true

var _skeleton: Skeleton3D
var _mesh: Node3D
var _initialized := false


func _ready() -> void:
	process_priority = 100
	_resolve()


func _resolve() -> void:
	if _initialized:
		return
	var root := get_parent() as Node3D
	if root == null:
		return
	_mesh = root.get_node_or_null(mesh_path) as Node3D if not mesh_path.is_empty() else null
	if _mesh == null:
		_mesh = root.get_node_or_null("Mesh") as Node3D
	if _mesh == null:
		var meshes := root.find_children("*", "MeshInstance3D", true, false)
		if not meshes.is_empty():
			_mesh = meshes[0].get_parent() as Node3D
	_skeleton = root.get_node_or_null(skeleton_path) as Skeleton3D if not skeleton_path.is_empty() else null
	if _skeleton == null:
		var skeletons := root.find_children("*", "Skeleton3D", true, false)
		_skeleton = skeletons[0] as Skeleton3D if not skeletons.is_empty() else null
	_initialized = _mesh != null and _skeleton != null
	if not _initialized:
		push_warning("FootGrounder: no mesh/skeleton under %s" % root.name)
	set_process(_initialized)


func set_grounded(value: bool) -> void:
	enabled = value


func _process(delta: float) -> void:
	if not enabled:
		return
	if not _initialized:
		_resolve()
		if not _initialized:
			return
	var root := get_parent() as Node3D
	if root == null:
		return
	var root_y := root.global_position.y
	var lowest := INF
	for bone_name in foot_bones:
		var bone := _skeleton.find_bone(bone_name)
		if bone < 0:
			continue
		var world := _skeleton.global_transform * _skeleton.get_bone_global_pose(bone).origin
		lowest = minf(lowest, world.y - root_y)
	if not is_finite(lowest):
		return
	var correction := clampf(ground_height - lowest, -max_drop, max_raise)
	var weight := 1.0 - exp(-smoothing * delta)
	_mesh.position.y += correction * weight
