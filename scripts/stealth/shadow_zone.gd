class_name ShadowZone
extends Node3D
## Тень у скалы: пока Санни внутри радиуса, Герой не может его увидеть.
## Это не коллизия и не укрытие от Тирана — только зрительная тень.

@export var radius := 1.8
@export var label := ""


func contains_point(point: Vector3) -> bool:
	var offset := point - global_position
	offset.y = 0.0
	return offset.length() <= radius


func get_debug_name() -> String:
	return label if not label.is_empty() else name
