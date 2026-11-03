class_name StatueKnightLOD
extends Node3D
## Три уровня детализации колосса. LOD0 — полный textured GLB;
## LOD1/LOD2 — децимированные копии для дали и лабиринта.
##
## Пороги подобраны под 200-м статую: на шее и в обзорном кадре Чёрного моря
## используется LOD0, на дальнем плане — LOD1/LOD2.

@export var lod0: PackedScene
@export var lod1: PackedScene
@export var lod2: PackedScene

const LOD0_END := 420.0
const LOD1_END := 1200.0
const LOD2_END := 4000.0
const LOD_BLEND := 24.0


func _ready() -> void:
	_spawn("LOD0", lod0, 0.0, LOD0_END, true)
	_spawn("LOD1", lod1, LOD0_END, LOD1_END, false)
	_spawn("LOD2", lod2, LOD1_END, LOD2_END, false)


func _spawn(level_name: String, scene: PackedScene, begin: float, end: float, shadows: bool) -> void:
	if scene == null:
		push_warning("StatueKnightLOD: missing %s" % level_name)
		return
	var instance := scene.instantiate()
	instance.name = level_name
	add_child(instance)
	_apply_range(instance, begin, end, shadows)


func _apply_range(node: Node, begin: float, end: float, shadows: bool) -> void:
	if node is GeometryInstance3D:
		var geometry := node as GeometryInstance3D
		geometry.visibility_range_begin = begin
		geometry.visibility_range_end = end
		geometry.visibility_range_begin_margin = LOD_BLEND
		geometry.visibility_range_end_margin = LOD_BLEND
		if not shadows:
			geometry.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in node.get_children():
		_apply_range(child, begin, end, shadows)
