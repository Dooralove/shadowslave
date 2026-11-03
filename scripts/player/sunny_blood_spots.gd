class_name SunnyBloodSpots
extends Node3D
## N13: красные пятна на пальцах Санни. Это визуальная подсказка, без текста.
## Узел живёт на POC-модели и сам появляется только после ночи.

@export var skeleton_path: NodePath = ^"Visual/ModelPoc/Mesh/Sunny/GeneralSkeleton"
@export var spot_bones: Array[StringName] = [
	&"index_01_l",
	&"index_02_l",
	&"middle_02_r",
]
@export var spot_color := Color(0.38, 0.015, 0.01, 1.0)

var _skeleton: Skeleton3D
var _spots: Array[MeshInstance3D] = []
var _spots_visible := false


func _ready() -> void:
	_skeleton = get_node_or_null(skeleton_path) as Skeleton3D
	if _skeleton == null:
		# Ищем скелет именно POC-модели, а не скрытого placeholder-а в Visual/Model.
		var model_root := get_parent().get_node_or_null(^"Visual/ModelPoc")
		if model_root != null:
			_skeleton = _find_skeleton(model_root)
	if _skeleton == null:
		_skeleton = _find_skeleton(get_parent())
	_build_spots()
	set_spots_visible(
		NightmareRunState.has_flag(&"flasks_poisoned")
		and NightmareRunState.has_flag(&"night_passed")
	)


func _find_skeleton(node: Node) -> Skeleton3D:
	if node == null:
		return null
	if node is Skeleton3D:
		return node as Skeleton3D
	for child in node.get_children():
		var found := _find_skeleton(child)
		if found != null:
			return found
	return null


func set_spots_visible(value: bool) -> void:
	_spots_visible = value
	visible = value
	set_process(value)
	for spot in _spots:
		spot.visible = value


func are_spots_visible() -> bool:
	return _spots_visible


func _process(_delta: float) -> void:
	if not _spots_visible or _skeleton == null:
		return
	for index in _spots.size():
		var bone_index := _skeleton.find_bone(spot_bones[index])
		if bone_index < 0:
			continue
		_spots[index].global_transform = _skeleton.global_transform * _skeleton.get_bone_global_pose(bone_index)


func _build_spots() -> void:
	if _skeleton == null:
		push_warning("SunnyBloodSpots: skeleton not found at %s" % skeleton_path)
		return
	var material := StandardMaterial3D.new()
	material.albedo_color = spot_color
	material.roughness = 0.92
	material.emission_enabled = true
	material.emission = Color(0.25, 0.005, 0.003, 1.0)
	material.emission_energy_multiplier = 0.25
	for bone_name in spot_bones:
		var spot := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.022
		sphere.height = 0.044
		sphere.radial_segments = 8
		sphere.rings = 4
		spot.mesh = sphere
		spot.material_override = material
		spot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		spot.name = "Spot_%s" % bone_name
		add_child(spot)
		_spots.append(spot)
	visible = false
