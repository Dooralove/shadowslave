class_name Mannequin
extends Node3D
## Временный NPC из примитивов (S1). Заменяется реалистичной моделью без изменения сценария:
## постановки двигают этот узел, а не его меши.

@export var body_color := Color(0.35, 0.36, 0.4)
@export var head_color := Color(0.72, 0.62, 0.55)
## Множитель роста относительно ~1,75 м.
@export var height_scale := 1.0
@export var width_scale := 1.0


func _ready() -> void:
	scale = Vector3(width_scale, height_scale, width_scale)
	_tint($Body as MeshInstance3D, body_color)
	_tint($Head as MeshInstance3D, head_color)


func _tint(mesh: MeshInstance3D, color: Color) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.85
	mesh.material_override = material
