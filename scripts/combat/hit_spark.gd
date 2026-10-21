class_name HitSpark
extends Node
## Подтверждение контакта: короткая яркая вспышка в точке попадания.
## Появляется только по факту попадания (MeleeAttack.hit_landed), урон не трогает.

@export var attack: MeleeAttack
@export var color := Color(1.0, 0.85, 0.55, 1.0)
@export var size := 0.18
@export var duration := 0.15
## Насколько точка контакта вынесена от центра хёртбокса цели к атакующему, м.
@export var surface_offset := 0.35


func _ready() -> void:
	attack.hit_landed.connect(_on_hit_landed)


## Точка контакта: на поверхности цели со стороны зоны удара, на высоте зоны удара.
func contact_point(target: Hurtbox) -> Vector3:
	var zone := (attack.get_node("CollisionShape3D") as Node3D).global_position
	var center := target.global_position + Vector3.UP
	var shape := target.get_node_or_null("CollisionShape3D") as Node3D
	if shape:
		center = shape.global_position
	var toward := zone - center
	toward.y = 0.0
	var point := center + toward.normalized() * minf(surface_offset, toward.length())
	point.y = zone.y
	return point


func _on_hit_landed(target: Hurtbox) -> void:
	var spark := MeshInstance3D.new()
	spark.add_to_group("hit_spark")
	var mesh := SphereMesh.new()
	mesh.radius = size
	mesh.height = size * 2.0
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	mesh.material = material
	spark.mesh = mesh
	spark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Вспышка остаётся на месте контакта, а не едет вместе с персонажем.
	var host := get_tree().current_scene if get_tree().current_scene else get_tree().root
	host.add_child(spark)
	spark.global_position = contact_point(target)
	var tween := spark.create_tween().set_parallel()
	tween.tween_property(spark, "scale", Vector3.ONE * 2.2, duration).from(Vector3.ONE * 0.6)
	tween.tween_property(material, "albedo_color:a", 0.0, duration)
	tween.chain().tween_callback(spark.queue_free)
